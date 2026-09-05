from __future__ import annotations

import logging
from time import monotonic
from typing import Any

from app.clients.bridge import BridgeHTTPError, PrestaShopBridgeClient
from app.clients.prestashop import PrestaShopClient, PrestaShopError
from app.schemas.address import AddressIn, AddressOut, CountryOut
from app.services.normalizers import localized, to_bool, to_int, unwrap_collection


logger = logging.getLogger(__name__)

# PrestaShop Address webservice supporte display="full" de manière native et fiable.
# Ne pas spécifier de liste personnalisée avec "active" car le champ "active"
# n'existe pas sur la ressource addresses dans PrestaShop et cause une 500.
ADDRESS_DISPLAY = "full"

# Pour countries : id, name, iso_code, active sont supportés.
COUNTRY_DISPLAY = "[id,name,iso_code,active]"
COUNTRY_CACHE_TTL_SECONDS = 300


class AddressesService:
    _country_cache: dict[int, tuple[float, str]] = {}
    _morocco_country_cache: tuple[float, int] | None = None

    def __init__(
        self,
        ps: PrestaShopClient,
        bridge: PrestaShopBridgeClient | None = None,
    ):
        self.ps = ps
        self.bridge = bridge

    async def list_for_customer(self, customer_id: int) -> list[AddressOut]:
        payload = await self._addresses_payload(customer_id)
        rows = [
            row
            for row in unwrap_collection(payload, "addresses")
            if to_int(row.get("id_customer")) == customer_id
            and not to_bool(row.get("deleted"), False)
        ]
        if not rows:
            return []

        countries = await self._country_names(
            {to_int(row.get("id_country")) for row in rows}
        )

        return [
            self._row_to_address_out(row, countries)
            for row in rows
        ]

    def _row_to_address_out(
        self,
        row: dict[str, Any],
        countries: dict[int, str],
    ) -> AddressOut:
        """Convertit un dictionnaire d'adresse en AddressOut."""
        country_id = to_int(row.get("id_country") or row.get("country_id"))
        return AddressOut(
            id=to_int(row.get("id")),
            alias=self._optional(row.get("alias")),
            firstname=self._optional(row.get("firstname")),
            lastname=self._optional(row.get("lastname")),
            company=self._optional(row.get("company")),
            address1=str(row.get("address1") or ""),
            address2=self._optional(row.get("address2")),
            postcode=self._optional(row.get("postcode")),
            city=str(row.get("city") or ""),
            country=countries.get(country_id),
            country_id=country_id or None,
            state_id=to_int(row.get("id_state") or row.get("state_id")) or None,
            phone=self._optional(row.get("phone")),
            phone_mobile=self._optional(row.get("phone_mobile")),
        )

    async def _addresses_payload(self, customer_id: int) -> dict[str, Any]:
        """Récupère les adresses PS pour un client en display=full."""
        filters = {"id_customer": f"[{customer_id}]"}
        try:
            return await self.ps.list_resource(
                "addresses",
                display=ADDRESS_DISPLAY,
                filters=filters,
                limit="0,100",
            )
        except PrestaShopError:
            logger.exception(
                "Erreur PrestaShop GET /addresses customer_id=%s. "
                "Vérifier les permissions Webservice (GET addresses).",
                customer_id,
            )
            raise

    async def _country_names(self, country_ids: set[int]) -> dict[int, str]:
        clean_ids = {country_id for country_id in country_ids if country_id}
        if not clean_ids:
            return {}

        now = monotonic()
        output: dict[int, str] = {}
        missing: list[int] = []
        for country_id in clean_ids:
            cached = self.__class__._country_cache.get(country_id)
            if cached and cached[0] > now:
                output[country_id] = cached[1]
            else:
                missing.append(country_id)

        if missing:
            try:
                payload = await self.ps.list_resource(
                    "countries",
                    display=COUNTRY_DISPLAY,
                    filters={"id": "[" + "|".join(str(x) for x in missing) + "]"},
                    limit=f"0,{len(missing)}",
                    params={"language": self.ps.settings.prestashop_language_id},
                )
                for row in unwrap_collection(payload, "countries"):
                    country_id = to_int(row.get("id"))
                    name = localized(
                        row.get("name"),
                        self.ps.settings.prestashop_language_id,
                    ).strip()
                    if country_id and name:
                        output[country_id] = name
                        self.__class__._country_cache[country_id] = (
                            now + COUNTRY_CACHE_TTL_SECONDS,
                            name,
                        )
            except PrestaShopError:
                logger.exception(
                    "Erreur PrestaShop /countries pour ids=%s",
                    missing,
                )

        return output

    async def countries(self) -> list[CountryOut]:
        payload = await self.ps.list_resource(
            "countries",
            display=COUNTRY_DISPLAY,
            limit="0,250",
            params={"language": self.ps.settings.prestashop_language_id},
        )
        rows = unwrap_collection(payload, "countries")
        countries: list[CountryOut] = []
        for row in rows:
            country_id = to_int(row.get("id"))
            if not to_bool(row.get("active"), True):
                continue
            name = localized(
                row.get("name"),
                self.ps.settings.prestashop_language_id,
            ).strip()
            if country_id and name:
                countries.append(CountryOut(id=country_id, name=name))
        return countries

    async def create(self, customer_id: int, payload: AddressIn) -> AddressOut:
        existing = await self.list_for_customer(customer_id)
        if existing:
            raise BridgeHTTPError(
                409,
                "Une adresse existe déjà. Modifiez l'adresse existante.",
            )

        address_payload = await self._address_payload(customer_id, payload)
        result = await self._bridge_address("create", customer_id, address_payload)

        address_id = to_int(result.get("id") or result.get("id_address"))
        if not address_id:
            raise BridgeHTTPError(
                502,
                "Pont PrestaShop: création adresse sans id retourné par le bridge.",
            )

        # Construire AddressOut directement depuis les données connues + id retourné par le bridge.
        # Pas de relecture secondaire fragile qui risquerait de transformer un succès en 502.
        morocco_country_id = to_int(address_payload.get("country_id"))
        countries = await self._country_names({morocco_country_id} if morocco_country_id else set())

        row = {
            "id": address_id,
            "id_customer": customer_id,
            **address_payload,
            "id_country": morocco_country_id,
        }
        return self._row_to_address_out(row, countries)

    async def update(
        self,
        customer_id: int,
        address_id: int,
        payload: AddressIn,
    ) -> AddressOut:
        address_payload = await self._address_payload(customer_id, payload)
        result = await self._bridge_address(
            "update",
            customer_id,
            {
                **address_payload,
                "address_id": address_id,
            },
        )
        updated_id = to_int(result.get("id") or result.get("id_address")) or address_id

        morocco_country_id = to_int(address_payload.get("country_id"))
        countries = await self._country_names({morocco_country_id} if morocco_country_id else set())

        row = {
            "id": updated_id,
            "id_customer": customer_id,
            **address_payload,
            "id_country": morocco_country_id,
        }
        return self._row_to_address_out(row, countries)

    async def _bridge_address(
        self,
        action: str,
        customer_id: int,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        if self.bridge is None:
            raise BridgeHTTPError(501, "Bridge PrestaShop requis pour les adresses.")
        morocco_country_id = to_int(payload.get("morocco_country_id"))
        logger.info(
            "Bridge addresses action=%s customer_id=%s morocco_country_id=%s",
            action,
            customer_id,
            morocco_country_id,
        )
        result = await self.bridge.post(
            f"addresses?action={action}",
            {
                "customer_id": customer_id,
                "morocco_country_id": morocco_country_id,
                "address": payload,
            },
        )
        data = result.get("data", result)
        if not isinstance(data, dict):
            raise BridgeHTTPError(502, "Pont PrestaShop: réponse adresse invalide.")
        return data

    async def _address_payload(
        self,
        customer_id: int,
        payload: AddressIn,
    ) -> dict[str, Any]:
        data = payload.model_dump(mode="json")
        morocco_country_id = await self._morocco_country_id()
        requested_country_id = to_int(data.get("country_id"))
        if requested_country_id and requested_country_id != morocco_country_id:
            raise BridgeHTTPError(422, "Seules les adresses au Maroc sont acceptées.")
        data["country_id"] = morocco_country_id
        data["morocco_country_id"] = morocco_country_id
        return data

    async def _morocco_country_id(self) -> int:
        now = monotonic()
        cached = self.__class__._morocco_country_cache
        if cached and cached[0] > now:
            return cached[1]

        logger.info("Recherche id_country Maroc dans PrestaShop (sans filtre PS).")
        try:
            payload = await self.ps.list_resource(
                "countries",
                display="[id,iso_code,active]",
                limit="0,250",
                params={"language": self.ps.settings.prestashop_language_id},
            )
        except Exception:
            logger.exception("Erreur PrestaShop lors de la récupération des pays.")
            raise

        for row in unwrap_collection(payload, "countries"):
            country_id = to_int(row.get("id"))
            iso_code = str(row.get("iso_code") or "").strip().upper()
            if country_id and iso_code == "MA":
                logger.info(
                    "Maroc trouvé : id_country=%s iso_code=%s",
                    country_id,
                    iso_code,
                )
                self.__class__._morocco_country_cache = (
                    now + COUNTRY_CACHE_TTL_SECONDS,
                    country_id,
                )
                return country_id

        raise BridgeHTTPError(502, "Pays Maroc introuvable dans PrestaShop.")

    def _optional(self, value: Any) -> str | None:
        text = str(value or "").strip()
        return text or None
