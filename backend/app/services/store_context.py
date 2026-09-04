from __future__ import annotations

from time import monotonic
from typing import Any

from app.clients.prestashop import PrestaShopClient
from app.core.config import Settings
from app.schemas.store import CurrencyOut, LanguageOut, StoreContextOut
from app.services.normalizers import localized, to_bool, to_float, to_int
from app.services.normalizers import unwrap_collection


STORE_CONTEXT_CACHE_TTL_SECONDS = 300


class StoreContextService:
    _languages_cache: tuple[float, list[LanguageOut]] | None = None
    _currencies_cache: tuple[float, list[CurrencyOut]] | None = None

    def __init__(
        self,
        ps: PrestaShopClient,
        settings: Settings,
    ):
        self.ps = ps
        self.settings = settings

    async def context(self) -> StoreContextOut:
        languages = await self.active_languages()
        currencies = await self.active_currencies()

        return StoreContextOut(
            language={
                "default_id": self.default_language_id(languages),
                "available": [
                    language.model_dump()
                    for language in languages
                ],
            },
            currency={
                "default_id": self.default_currency_id(currencies),
                "available": [
                    currency.model_dump()
                    for currency in currencies
                ],
            },
        )

    async def active_languages(self) -> list[LanguageOut]:
        now = monotonic()
        cached = self.__class__._languages_cache

        if cached and cached[0] > now:
            return list(cached[1])

        payload = await self.ps.list_resource(
            "languages",
            display=(
                "["
                "id,"
                "name,"
                "iso_code,"
                "locale,"
                "language_code,"
                "active,"
                "is_rtl"
                "]"
            ),
            limit="0,100",
        )

        languages: list[LanguageOut] = []

        for row in unwrap_collection(payload, "languages"):
            if not to_bool(row.get("active"), False):
                continue

            language_id = to_int(row.get("id"))
            name = localized(
                row.get("name"),
                self.settings.prestashop_language_id,
            ).strip()

            if not language_id or not name:
                continue

            languages.append(
                LanguageOut(
                    id=language_id,
                    name=name,
                    iso_code=_clean_optional(row.get("iso_code")),
                    locale=_clean_optional(row.get("locale")),
                    language_code=_clean_optional(row.get("language_code")),
                    active=True,
                    is_rtl=to_bool(row.get("is_rtl"), False),
                )
            )

        self.__class__._languages_cache = (
            now + STORE_CONTEXT_CACHE_TTL_SECONDS,
            languages,
        )

        return list(languages)

    async def active_currencies(self) -> list[CurrencyOut]:
        now = monotonic()
        cached = self.__class__._currencies_cache

        if cached and cached[0] > now:
            return list(cached[1])

        payload = await self.ps.list_resource(
            "currencies",
            display=(
                "["
                "id,"
                "name,"
                "iso_code,"
                "symbol,"
                "precision,"
                "conversion_rate,"
                "active,"
                "deleted"
                "]"
            ),
            limit="0,100",
        )

        currencies: list[CurrencyOut] = []

        for row in unwrap_collection(payload, "currencies"):
            if not to_bool(row.get("active"), False):
                continue

            if to_bool(row.get("deleted"), False):
                continue

            currency_id = to_int(row.get("id"))
            iso_code = str(row.get("iso_code") or "").strip()
            name = localized(
                row.get("name"),
                self.settings.prestashop_language_id,
            ).strip() or iso_code
            symbol = str(row.get("symbol") or iso_code).strip()

            if not currency_id or not iso_code:
                continue

            currencies.append(
                CurrencyOut(
                    id=currency_id,
                    name=name,
                    iso_code=iso_code,
                    symbol=symbol,
                    precision=to_int(row.get("precision"), 2),
                    conversion_rate=to_float(row.get("conversion_rate"), 1.0),
                    active=True,
                )
            )

        self.__class__._currencies_cache = (
            now + STORE_CONTEXT_CACHE_TTL_SECONDS,
            currencies,
        )

        return list(currencies)

    def default_language_id(
        self,
        languages: list[LanguageOut] | None = None,
    ) -> int:
        if languages:
            for language in languages:
                if language.id == self.settings.prestashop_language_id:
                    return language.id
            return languages[0].id

        return self.settings.prestashop_language_id

    def default_currency_id(
        self,
        currencies: list[CurrencyOut] | None = None,
    ) -> int | None:
        if not currencies:
            return None

        for currency in currencies:
            if currency.conversion_rate == 1.0:
                return currency.id

        return currencies[0].id

    async def currency_for(
        self,
        currency_id: int | None,
    ) -> CurrencyOut | None:
        currencies = await self.active_currencies()

        if currency_id is not None:
            for currency in currencies:
                if currency.id == currency_id:
                    return currency

        default_currency_id = self.default_currency_id(currencies)

        for currency in currencies:
            if currency.id == default_currency_id:
                return currency

        return None


def _clean_optional(value: Any) -> str | None:
    text = str(value or "").strip()
    return text or None
