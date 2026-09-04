from __future__ import annotations

import logging
from time import monotonic
from typing import Any

from app.clients.prestashop import PrestaShopClient, PrestaShopError
from app.schemas.address import AddressOut
from app.services.normalizers import localized, to_bool, to_int, unwrap_collection


logger = logging.getLogger(__name__)

ADDRESS_DISPLAY = (
    "["
    "id,"
    "id_customer,"
    "alias,"
    "firstname,"
    "lastname,"
    "company,"
    "address1,"
    "address2,"
    "postcode,"
    "city,"
    "id_country,"
    "id_state,"
    "phone,"
    "phone_mobile,"
    "active,"
    "deleted"
    "]"
)
COUNTRY_DISPLAY = "[id,name]"
COUNTRY_CACHE_TTL_SECONDS = 300


class AddressesService:
    _country_cache: dict[int, tuple[float, str]] = {}

    def __init__(self, ps: PrestaShopClient):
        self.ps = ps

    async def list_for_customer(self, customer_id: int) -> list[AddressOut]:
        payload = await self._addresses_payload(customer_id)
        rows = [
            row
            for row in unwrap_collection(payload, "addresses")
            if to_int(row.get("id_customer")) == customer_id
            and to_bool(row.get("active"), True)
            and not to_bool(row.get("deleted"), False)
        ]
        if not rows:
            return []

        countries = await self._country_names(
            {to_int(row.get("id_country")) for row in rows}
        )

        return [
            AddressOut(
                id=to_int(row.get("id")),
                alias=self._optional(row.get("alias")),
                firstname=self._optional(row.get("firstname")),
                lastname=self._optional(row.get("lastname")),
                company=self._optional(row.get("company")),
                address1=str(row.get("address1") or ""),
                address2=self._optional(row.get("address2")),
                postcode=self._optional(row.get("postcode")),
                city=str(row.get("city") or ""),
                country=countries.get(to_int(row.get("id_country"))),
                country_id=to_int(row.get("id_country")) or None,
                state_id=to_int(row.get("id_state")) or None,
                phone=self._optional(row.get("phone")),
                phone_mobile=self._optional(row.get("phone_mobile")),
            )
            for row in rows
        ]

    async def _addresses_payload(self, customer_id: int) -> dict[str, Any]:
        filters = {"id_customer": f"[{customer_id}]"}
        try:
            return await self.ps.list_resource(
                "addresses",
                display=ADDRESS_DISPLAY,
                filters=filters,
                limit="0,100",
            )
        except PrestaShopError:
            logger.warning(
                "PrestaShop a refusé /addresses avec display=%s pour customer_id=%s. "
                "Nouvel essai sans display.",
                ADDRESS_DISPLAY,
                customer_id,
            )
            try:
                return await self.ps.list_resource(
                    "addresses",
                    filters=filters,
                    limit="0,100",
                )
            except PrestaShopError:
                logger.exception(
                    "Erreur PrestaShop /addresses pour customer_id=%s. "
                    "Vérifier permission GET addresses et filtre id_customer.",
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

    def _optional(self, value: Any) -> str | None:
        text = str(value or "").strip()
        return text or None
