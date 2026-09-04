import pytest

from app.services.store_context import StoreContextService

pytestmark = pytest.mark.anyio


class DummySettings:
    prestashop_language_id = 3


class FakePrestaShopClient:
    async def list_resource(
        self,
        resource,
        *,
        display=None,
        filters=None,
        limit=None,
        sort=None,
        params=None,
    ):
        if resource == "languages":
            return {
                "languages": [
                    {
                        "id": "1",
                        "name": "English",
                        "iso_code": "en",
                        "locale": "en-US",
                        "language_code": "en-us",
                        "active": "0",
                        "is_rtl": "0",
                    },
                    {
                        "id": "3",
                        "name": "Français",
                        "iso_code": "fr",
                        "locale": "fr-FR",
                        "language_code": "fr-fr",
                        "active": "1",
                        "is_rtl": "0",
                    },
                ]
            }

        if resource == "currencies":
            return {
                "currencies": [
                    {
                        "id": "1",
                        "name": "Dirham marocain",
                        "iso_code": "MAD",
                        "symbol": "MAD",
                        "precision": "2",
                        "conversion_rate": "1.0",
                        "active": "1",
                        "deleted": "0",
                    },
                    {
                        "id": "2",
                        "name": "Euro",
                        "iso_code": "EUR",
                        "symbol": "€",
                        "precision": "2",
                        "conversion_rate": "0.092",
                        "active": "0",
                        "deleted": "0",
                    },
                ]
            }

        return {}


async def test_store_context_returns_only_active_public_data():
    StoreContextService._languages_cache = None
    StoreContextService._currencies_cache = None

    service = StoreContextService(
        FakePrestaShopClient(),
        DummySettings(),
    )

    context = await service.context()

    assert context.language["default_id"] == 3
    assert [
        language["id"]
        for language in context.language["available"]
    ] == [3]
    assert context.currency["default_id"] == 1
    assert [
        currency["iso_code"]
        for currency in context.currency["available"]
    ] == ["MAD"]
