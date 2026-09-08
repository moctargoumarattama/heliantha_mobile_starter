from __future__ import annotations

import hmac

from fastapi import APIRouter, Depends, Header, HTTPException

from app.api.deps import get_catalog_service, get_notification_service, get_ps_client
from app.clients.prestashop import PrestaShopClient
from app.core.config import Settings, get_settings
from app.core.security import get_current_identity
from app.schemas.notification import (
    DeviceTokenIn,
    NotificationType,
    PrestaShopOrderEventIn,
    PrestaShopStockEventIn,
)
from app.services.catalog import CatalogService
from app.services.normalizers import localized, to_bool, to_int
from app.services.notifications import NotificationService


router = APIRouter(tags=["notifications"])


@router.post("/notifications/device")
async def register_device(
    payload: DeviceTokenIn,
    identity: dict = Depends(get_current_identity),
    service: NotificationService = Depends(get_notification_service),
) -> dict:
    service.register_device(int(identity["sub"]), payload)
    return {"success": True, "data": None, "meta": None, "error": None}


@router.delete("/notifications/device")
async def delete_device(
    token: str | None = None,
    identity: dict = Depends(get_current_identity),
    service: NotificationService = Depends(get_notification_service),
) -> dict:
    service.delete_device(int(identity["sub"]), token)
    return {"success": True, "data": None, "meta": None, "error": None}


@router.get("/notifications")
async def list_notifications(
    identity: dict = Depends(get_current_identity),
    service: NotificationService = Depends(get_notification_service),
) -> dict:
    customer_id = int(identity["sub"])
    rows = service.list_notifications(customer_id)
    return {
        "success": True,
        "data": [row.model_dump() for row in rows],
        "meta": {"unread": service.unread_count(customer_id)},
        "error": None,
    }


@router.post("/notifications/{notification_id}/read")
async def mark_notification_read(
    notification_id: int,
    identity: dict = Depends(get_current_identity),
    service: NotificationService = Depends(get_notification_service),
) -> dict:
    if not service.mark_read(int(identity["sub"]), notification_id):
        raise HTTPException(status_code=404, detail="Notification introuvable.")
    return {"success": True, "data": None, "meta": None, "error": None}


@router.post("/favorites/{product_id}")
async def add_favorite_watch(
    product_id: int,
    identity: dict = Depends(get_current_identity),
    service: NotificationService = Depends(get_notification_service),
    catalog: CatalogService = Depends(get_catalog_service),
) -> dict:
    products = await catalog.products_by_ids([product_id])
    product = products[0] if products else None
    service.watch_favorite(
        int(identity["sub"]),
        product_id,
        bool(product and product.available),
    )
    return {"success": True, "data": None, "meta": None, "error": None}


@router.delete("/favorites/{product_id}")
async def delete_favorite_watch(
    product_id: int,
    identity: dict = Depends(get_current_identity),
    service: NotificationService = Depends(get_notification_service),
) -> dict:
    service.unwatch_favorite(int(identity["sub"]), product_id)
    return {"success": True, "data": None, "meta": None, "error": None}


@router.post("/notifications/prestashop-event")
async def prestashop_event(
    payload: PrestaShopOrderEventIn,
    x_heliantha_bridge_secret: str = Header(default=""),
    settings: Settings = Depends(get_settings),
    ps: PrestaShopClient = Depends(get_ps_client),
    service: NotificationService = Depends(get_notification_service),
) -> dict:
    if not _valid_webhook_secret(settings, x_heliantha_bridge_secret):
        raise HTTPException(status_code=401, detail="Acces refuse.")

    is_created = (
        payload.event == "order_created"
        or payload.metadata.get("event") == "order_created"
        or (payload.status_key and "created" in payload.status_key)
    )

    customer_id = payload.customer_id or to_int(payload.metadata.get("customer_id"))
    reference = str(payload.reference or payload.metadata.get("reference") or "").strip()

    # CAS CRÉATION COMMANDE / ORDER_CREATED :
    # Si customer_id + order_id + reference sont fournis directement par le bridge PrestaShop,
    # NE PAS appeler ps.get_resource("orders", ...) pour éviter les 404 lors de la création synchrone.
    if is_created and customer_id and payload.order_id and reference:
        title = payload.title or "Commande enregistrée"
        raw_body = payload.message or (
            f"🎉 Merci pour votre confiance ! Votre commande n°{reference} a bien été enregistrée. Notre équipe s'en occupe."
        )
        body = (
            raw_body
            .replace("{reference}", reference)
            .replace("REFERENCE", reference)
        )
        status_key = payload.status_key or f"order-created-{payload.order_id}"

        row = await service.create_notification(
            customer_id=customer_id,
            type_=payload.type,
            title=title,
            body=body,
            order_id=payload.order_id,
            status_key=status_key,
            metadata={**payload.metadata, "route": f"/orders/{payload.order_id}"},
        )
        return {
            "success": True,
            "data": row.model_dump() if row else None,
            "meta": {"created": row is not None},
            "error": None,
        }

    # CAS CHANGEMENT DE STATUT (ou création sans données complètes dans le payload) :
    order = None
    try:
        order_payload = await ps.get_resource(
            "orders",
            payload.order_id,
            params={
                "display": "[id,reference,id_customer,current_state,total_paid_tax_incl]"
            },
        )
        if isinstance(order_payload, dict):
            order = order_payload.get("order")
    except Exception:
        order = None

    if isinstance(order, dict):
        customer_id = to_int(order.get("id_customer")) or customer_id
        state_id = to_int(order.get("current_state")) or payload.state_id or to_int(payload.metadata.get("state_id"))
        reference = str(order.get("reference") or reference or payload.order_id)
    else:
        state_id = payload.state_id or to_int(payload.metadata.get("state_id"))
        reference = reference or str(payload.order_id)

    if not customer_id:
        raise HTTPException(status_code=404, detail="Commande introuvable.")

    paid = False
    state_name = "Statut mis à jour"
    if state_id:
        try:
            state_name, paid = await _order_state(ps, state_id)
        except Exception:
            pass

    status_key = payload.status_key or f"{payload.type.value.lower()}-{state_id or 0}"

    if payload.title:
        title = payload.title
    elif is_created:
        title = "Commande enregistrée"
    elif payload.type == NotificationType.PAYMENT_STATUS:
        title = "Paiement confirme" if paid else state_name
    else:
        title = state_name

    if payload.message:
        body = (
            payload.message
            .replace("{reference}", reference)
            .replace("REFERENCE", reference)
        )
    elif is_created:
        body = f"🎉 Merci pour votre confiance ! Votre commande n°{reference} a bien été enregistrée. Notre équipe s'en occupe."
    elif payload.type == NotificationType.PAYMENT_STATUS:
        body = f"Le paiement de votre commande {reference} est mis a jour."
    else:
        body = f"Votre commande {reference} a ete mise a jour."

    row = await service.create_notification(
        customer_id=customer_id,
        type_=payload.type,
        title=title,
        body=body,
        order_id=payload.order_id,
        status_key=status_key,
        metadata={**payload.metadata, "route": f"/orders/{payload.order_id}"},
    )
    return {
        "success": True,
        "data": row.model_dump() if row else None,
        "meta": {"created": row is not None},
        "error": None,
    }


@router.post("/notifications/favorite-stock")
async def favorite_stock_event(
    payload: PrestaShopStockEventIn,
    x_heliantha_bridge_secret: str = Header(default=""),
    settings: Settings = Depends(get_settings),
    service: NotificationService = Depends(get_notification_service),
) -> dict:
    if not _valid_webhook_secret(settings, x_heliantha_bridge_secret):
        raise HTTPException(status_code=401, detail="Acces refuse.")
    created = await service.favorite_stock_changed(
        product_id=payload.product_id,
        in_stock=payload.quantity > 0,
        product_name=payload.product_name or f"Produit {payload.product_id}",
    )
    return {"success": True, "data": None, "meta": {"created": created}, "error": None}


def _valid_webhook_secret(settings: Settings, provided: str) -> bool:
    if not provided:
        return False
    valid_secrets = [
        s for s in (settings.notification_webhook_secret, settings.mobile_bridge_secret)
        if s
    ]
    return any(hmac.compare_digest(provided, secret) for secret in valid_secrets)


async def _order_state(ps: PrestaShopClient, state_id: int) -> tuple[str, bool]:
    payload = await ps.get_resource(
        "order_states",
        state_id,
        params={"display": "[id,name,paid]"},
    )
    row = payload.get("order_state") if isinstance(payload, dict) else None
    if not isinstance(row, dict):
        return "Commande mise a jour", False
    name = localized(row.get("name"), ps.settings.prestashop_language_id).strip()
    return name or "Commande mise a jour", to_bool(row.get("paid"), False)
