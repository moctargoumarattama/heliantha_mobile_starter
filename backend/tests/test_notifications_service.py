import pytest

from app.core.config import Settings
from app.schemas.notification import NotificationType
from app.services.notifications import NotificationService


@pytest.fixture()
def service(tmp_path):
    return NotificationService(
        Settings(
            notification_db_path=str(tmp_path / "notifications.sqlite3"),
        )
    )


@pytest.mark.anyio
async def test_order_status_duplicate_creates_one_notification(service):
    payload = dict(
        type_=NotificationType.ORDER_STATUS,
        customer_id=10,
        order_id=55,
        status_key="order-3",
        title="Commande en préparation",
        body="Votre commande est mise à jour.",
    )

    first = await service.create_notification(**payload)
    second = await service.create_notification(**payload)

    assert first is not None
    assert second is None
    assert len(service.list_notifications(10)) == 1


@pytest.mark.anyio
async def test_payment_status_duplicate_creates_one_notification(service):
    payload = dict(
        type_=NotificationType.PAYMENT_STATUS,
        customer_id=10,
        order_id=55,
        status_key="payment-paid-2",
        title="Paiement confirmé",
        body="Votre paiement est confirmé.",
    )

    assert await service.create_notification(**payload) is not None
    assert await service.create_notification(**payload) is None


@pytest.mark.anyio
async def test_favorite_back_in_stock_transition_only(service):
    service.watch_favorite(customer_id=10, product_id=339, in_stock=False)

    first = await service.favorite_stock_changed(
        product_id=339,
        in_stock=True,
        product_name="Panneau solaire",
    )
    second = await service.favorite_stock_changed(
        product_id=339,
        in_stock=True,
        product_name="Panneau solaire",
    )
    await service.favorite_stock_changed(
        product_id=339,
        in_stock=False,
        product_name="Panneau solaire",
    )
    third = await service.favorite_stock_changed(
        product_id=339,
        in_stock=True,
        product_name="Panneau solaire",
    )

    assert first == 1
    assert second == 0
    assert third == 1


def test_customer_isolation(service):
    service._insert_notification(
        customer_id=10,
        type_=NotificationType.ORDER_STATUS,
        title="A",
        body="A",
        order_id=1,
        status_key="order-1",
    )
    service._insert_notification(
        customer_id=11,
        type_=NotificationType.ORDER_STATUS,
        title="B",
        body="B",
        order_id=2,
        status_key="order-1",
    )

    assert [row.title for row in service.list_notifications(10)] == ["A"]


def test_prestashop_event_order_created_and_status_update(service):
    from unittest.mock import AsyncMock
    from starlette.testclient import TestClient
    from app.main import app
    from app.api.deps import get_ps_client, get_notification_service
    from app.core.security import create_access_token
    from app.core.config import get_settings

    settings = get_settings()
    mock_ps = AsyncMock()

    async def mock_get_resource(resource, resource_id, params=None):
        if resource == "orders":
            return {
                "order": {
                    "id": resource_id,
                    "reference": "HELIANTHA-REF-42",
                    "id_customer": 15,
                    "current_state": 3,
                    "total_paid_tax_incl": 250.0,
                }
            }
        elif resource == "order_states":
            return {
                "order_state": {
                    "id": resource_id,
                    "name": [{"id": 1, "value": "En cours de préparation"}],
                    "paid": 0,
                }
            }
        return {}

    mock_ps.get_resource = AsyncMock(side_effect=mock_get_resource)
    mock_ps.settings = settings

    app.dependency_overrides[get_ps_client] = lambda: mock_ps
    app.dependency_overrides[get_notification_service] = lambda: service

    try:
        client = TestClient(app)

        # 1. Test unauthorized if wrong secret
        resp_unauth = client.post(
            "/v1/notifications/prestashop-event",
            json={
                "type": "ORDER_STATUS",
                "order_id": 42,
                "status_key": "order-created-42",
                "metadata": {"event": "order_created", "source": "actionValidateOrder"},
            },
            headers={"X-Heliantha-Bridge-Secret": "wrong_secret"},
        )
        assert resp_unauth.status_code == 401

        # 2. Test order creation event with bridge secret
        secret = settings.mobile_bridge_secret
        resp_created = client.post(
            "/v1/notifications/prestashop-event",
            json={
                "type": "ORDER_STATUS",
                "order_id": 42,
                "status_key": "order-created-42",
                "metadata": {"event": "order_created", "source": "actionValidateOrder"},
            },
            headers={"X-Heliantha-Bridge-Secret": secret},
        )
        assert resp_created.status_code == 200
        data = resp_created.json()
        assert data["success"] is True
        assert data["meta"]["created"] is True
        assert data["data"]["title"] == "Commande enregistrée"
        assert "HELIANTHA-REF-42" in data["data"]["body"]
        assert "🎉 Merci pour votre confiance !" in data["data"]["body"]
        assert data["data"]["order_id"] == 42

        # 3. Test duplicate order creation event is ignored
        resp_dup = client.post(
            "/v1/notifications/prestashop-event",
            json={
                "type": "ORDER_STATUS",
                "order_id": 42,
                "status_key": "order-created-42",
                "metadata": {"event": "order_created", "source": "actionValidateOrder"},
            },
            headers={"X-Heliantha-Bridge-Secret": secret},
        )
        assert resp_dup.status_code == 200
        assert resp_dup.json()["meta"]["created"] is False
        assert resp_dup.json()["data"] is None

        # 4. Test subsequent status change in Back Office
        resp_status = client.post(
            "/v1/notifications/prestashop-event",
            json={
                "type": "ORDER_STATUS",
                "order_id": 42,
                "status_key": "order-3",
                "metadata": {"source": "actionOrderStatusPostUpdate", "state_id": 3},
            },
            headers={"X-Heliantha-Bridge-Secret": secret},
        )
        assert resp_status.status_code == 200
        data_status = resp_status.json()
        assert data_status["meta"]["created"] is True
        assert data_status["data"]["title"] == "En cours de préparation"
        assert "HELIANTHA-REF-42" in data_status["data"]["body"]

        # 5. Connected customer (id=15) can see both notifications in /v1/notifications
        token = create_access_token(customer_id=15, email="customer15@heliantha.ma", settings=settings)
        resp_list = client.get("/v1/notifications", headers={"Authorization": f"Bearer {token}"})
        assert resp_list.status_code == 200
        notifs = resp_list.json()["data"]
        assert len(notifs) == 2
        titles = [n["title"] for n in notifs]
        assert "En cours de préparation" in titles
        assert "Commande enregistrée" in titles

        # 6. Another customer (id=99) sees ZERO notifications (strict customer isolation)
        token_other = create_access_token(customer_id=99, email="other@heliantha.ma", settings=settings)
        resp_other = client.get("/v1/notifications", headers={"Authorization": f"Bearer {token_other}"})
        assert resp_other.status_code == 200
        assert len(resp_other.json()["data"]) == 0
    finally:
        app.dependency_overrides.pop(get_ps_client, None)
        app.dependency_overrides.pop(get_notification_service, None)


def test_prestashop_event_order_created_when_webservice_is_unavailable(service):
    """
    Reproduces production bug where PrestaShop Webservice returns 404 / unavailable
    immediately upon order creation.
    Thanks to direct bridge payload (customer_id, order_id, reference),
    FastAPI bypasses the Webservice call and creates the notification successfully.
    """
    from unittest.mock import AsyncMock
    from starlette.testclient import TestClient
    from app.main import app
    from app.api.deps import get_ps_client, get_notification_service
    from app.core.security import create_access_token
    from app.core.config import get_settings
    from app.clients.prestashop import PrestaShopError

    settings = get_settings()
    mock_ps = AsyncMock()

    # Webservice FAILS with 404 / error if called
    mock_ps.get_resource = AsyncMock(side_effect=PrestaShopError("PrestaShop 404 sur orders/88: Commande introuvable"))
    mock_ps.settings = settings

    app.dependency_overrides[get_ps_client] = lambda: mock_ps
    app.dependency_overrides[get_notification_service] = lambda: service

    try:
        client = TestClient(app)
        secret = settings.mobile_bridge_secret

        payload = {
            "type": "ORDER_STATUS",
            "order_id": 88,
            "customer_id": 25,
            "reference": "HELIANTHA-PROD-88",
            "state_id": 3,
            "event": "order_created",
            "status_key": "order-created-88",
            "title": "Commande enregistrée",
            "message": "🎉 Merci pour votre confiance ! Votre commande n°HELIANTHA-PROD-88 a bien été enregistrée. Notre équipe s'en occupe.",
            "metadata": {
                "source": "actionValidateOrder",
                "event": "order_created",
                "reference": "HELIANTHA-PROD-88",
                "customer_id": 25,
            },
        }

        # 1. Post event: should succeed without calling ps.get_resource
        resp = client.post(
            "/v1/notifications/prestashop-event",
            json=payload,
            headers={"X-Heliantha-Bridge-Secret": secret},
        )
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["success"] is True
        assert data["meta"]["created"] is True
        assert data["data"]["title"] == "Commande enregistrée"
        assert "HELIANTHA-PROD-88" in data["data"]["body"]
        assert "🎉 Merci pour votre confiance !" in data["data"]["body"]
        assert data["data"]["order_id"] == 88

        # Verify ps.get_resource was NEVER called for order_created!
        mock_ps.get_resource.assert_not_called()

        # 2. GET /v1/notifications for customer_id=25 returns the notification
        token_25 = create_access_token(customer_id=25, email="customer25@heliantha.ma", settings=settings)
        resp_list = client.get("/v1/notifications", headers={"Authorization": f"Bearer {token_25}"})
        assert resp_list.status_code == 200
        items = resp_list.json()["data"]
        assert len(items) == 1
        assert items[0]["title"] == "Commande enregistrée"
        assert items[0]["order_id"] == 88
        assert "HELIANTHA-PROD-88" in items[0]["body"]

        # 3. Second call with same status_key does not create a duplicate
        resp_dup = client.post(
            "/v1/notifications/prestashop-event",
            json=payload,
            headers={"X-Heliantha-Bridge-Secret": secret},
        )
        assert resp_dup.status_code == 200
        assert resp_dup.json()["meta"]["created"] is False
        assert resp_dup.json()["data"] is None

        # Verify notifications count is still 1
        resp_list_dup = client.get("/v1/notifications", headers={"Authorization": f"Bearer {token_25}"})
        assert len(resp_list_dup.json()["data"]) == 1
    finally:
        app.dependency_overrides.pop(get_ps_client, None)
        app.dependency_overrides.pop(get_notification_service, None)
