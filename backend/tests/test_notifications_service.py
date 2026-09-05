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
