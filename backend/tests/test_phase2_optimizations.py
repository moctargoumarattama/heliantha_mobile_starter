from unittest.mock import AsyncMock, patch

import pytest

from app.clients.prestashop import PrestaShopClient
from app.core.config import Settings
from app.schemas.notification import NotificationType
import app.services.geo as geo_module
from app.services.geo import get_morocco_country_id
from app.services.notifications import NotificationService
from app.services.orders import OrdersService

pytestmark = pytest.mark.anyio


async def test_fcm_failure_is_non_blocking_and_does_not_crash(tmp_path):
    settings = Settings(
        app_env="development",
        jwt_secret="super_secret_for_tests_at_least_32_chars_long!",
        notifications_db_path=str(tmp_path / "test_notif.db"),
    )
    service = NotificationService(settings)

    with patch.object(service, "_send_fcm", side_effect=RuntimeError("FCM network error")):
        notif = await service.create_notification(
            customer_id=123,
            type_=NotificationType.ORDER_STATUS,
            title="Test status",
            body="Your order is shipped",
            order_id=42,
            status_key="shipped",
        )
        assert notif is not None
        assert notif.title == "Test status"
        assert notif.order_id == 42


def test_cors_dev_vs_prod():
    dev_settings = Settings(
        app_env="development",
        jwt_secret="dev_secret_at_least_32_characters_long_for_test!",
        cors_origins="https://app.heliantha.ma",
    )
    origins_dev = dev_settings.cors_origin_list
    assert "https://app.heliantha.ma" in origins_dev
    assert "http://localhost:3000" in origins_dev
    assert "*" not in origins_dev

    prod_settings = Settings(
        app_env="production",
        jwt_secret="production_secret_at_least_32_characters_long!",
        cors_origins="https://app.heliantha.ma",
    )
    origins_prod = prod_settings.cors_origin_list
    assert origins_prod == ["https://app.heliantha.ma"]
    assert "http://localhost:3000" not in origins_prod


async def test_orders_payload_attempts_rich_display_first():
    mock_ps = AsyncMock(spec=PrestaShopClient)
    mock_ps.settings = Settings(
        app_env="development",
        jwt_secret="secret_for_testing_purposes_only_32_chars!",
    )
    mock_ps.list_resource.return_value = {
        "orders": [
            {
                "id": 10,
                "reference": "REF10",
                "total_paid": "120.00",
                "current_state": 3,
                "date_add": "2026-03-01",
                "id_customer": 99,
            }
        ]
    }
    service = OrdersService(mock_ps, bridge=AsyncMock())
    payload = await service._orders_payload(customer_id=99)
    assert "orders" in payload
    assert mock_ps.list_resource.call_count == 1
    call_kwargs = mock_ps.list_resource.call_args.kwargs
    assert "display" in call_kwargs


async def test_order_state_names_use_configured_language_and_french_fallback():
    OrdersService._state_cache = {}
    mock_ps = AsyncMock(spec=PrestaShopClient)
    mock_ps.settings = Settings(
        app_env="development",
        jwt_secret="secret_for_testing_purposes_only_32_chars!",
        prestashop_language_id=3,
    )
    mock_ps.list_resource.return_value = {
        "order_states": [
            {"id": "3", "name": "En cours de préparation"},
            {"id": "14", "name": "Waiting for payment"},
        ]
    }

    service = OrdersService(mock_ps, bridge=AsyncMock())
    states = await service._state_names({3, 14})

    assert states[3] == "En cours de préparation"
    assert states[14] == "En attente de paiement"
    assert mock_ps.list_resource.call_args.kwargs["params"] == {"language": 3}


async def test_order_state_cache_is_scoped_by_language():
    OrdersService._state_cache = {
        (1, 3): (9999999999.0, "Processing in progress"),
    }
    mock_ps = AsyncMock(spec=PrestaShopClient)
    mock_ps.settings = Settings(
        app_env="development",
        jwt_secret="secret_for_testing_purposes_only_32_chars!",
        prestashop_language_id=3,
    )
    mock_ps.list_resource.return_value = {
        "order_states": [
            {"id": "3", "name": "En cours de préparation"},
        ]
    }

    service = OrdersService(mock_ps, bridge=AsyncMock())
    states = await service._state_names({3})

    assert states[3] == "En cours de préparation"
    mock_ps.list_resource.assert_awaited_once()


async def test_morocco_country_id_shared_cache():
    geo_module._morocco_country_cache = None
    mock_ps = AsyncMock(spec=PrestaShopClient)
    mock_ps.settings = Settings(
        app_env="development",
        jwt_secret="secret_for_testing_purposes_only_32_chars!",
    )
    mock_ps.list_resource.return_value = {
        "countries": [
            {"id": "1", "iso_code": "FR"},
            {"id": "144", "iso_code": "MA"},
        ]
    }

    id_1 = await get_morocco_country_id(mock_ps)
    assert id_1 == 144
    assert mock_ps.list_resource.call_count == 1

    id_2 = await get_morocco_country_id(mock_ps)
    assert id_2 == 144
    assert mock_ps.list_resource.call_count == 1
