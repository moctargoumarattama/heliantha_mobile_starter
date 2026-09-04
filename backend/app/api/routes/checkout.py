import logging

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.api.deps import get_bridge_client, get_checkout_service
from app.clients.bridge import BridgeHTTPError, BridgeUnavailable, PrestaShopBridgeClient
from app.core.config import Settings, get_settings
from app.core.security import decode_access_token
from app.schemas.checkout import CheckoutConfirmIn, CheckoutPreviewIn
from app.services.checkout import CheckoutService

router = APIRouter(tags=["checkout"])
optional_bearer = HTTPBearer(auto_error=False)
logger = logging.getLogger(__name__)


def _safe_confirm_log(body: dict) -> dict:
    return {
        "line_count": len(body.get("lines") or []),
        "lines": [
            {
                "product_id": line.get("product_id"),
                "product_attribute_id": line.get("product_attribute_id"),
                "quantity": line.get("quantity"),
            }
            for line in (body.get("lines") or [])
            if isinstance(line, dict)
        ],
        "mode": body.get("mode"),
        "customer_id": body.get("customer_id"),
        "address_id": body.get("address_id"),
        "has_address": isinstance(body.get("address"), dict),
        "carrier_id": body.get("carrier_id"),
        "payment_module": body.get("payment_module"),
        "has_idempotency_key": bool(body.get("idempotency_key")),
    }


@router.post("/checkout/preview", response_model=dict)
async def checkout_preview(
    payload: CheckoutPreviewIn,
    service: CheckoutService = Depends(get_checkout_service),
    credentials: HTTPAuthorizationCredentials | None = Depends(optional_bearer),
    settings: Settings = Depends(get_settings),
) -> dict:
    try:
        customer_id: int | None = None
        if credentials:
            identity = decode_access_token(credentials.credentials, settings)
            customer_id = int(identity["sub"])
        preview = await service.preview(payload, customer_id=customer_id)
        return {
            "success": True,
            "data": preview.model_dump(),
            "meta": None,
            "error": None,
        }
    except Exception as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.post("/checkout/confirm", response_model=dict)
async def checkout_confirm(
    payload: CheckoutConfirmIn,
    settings: Settings = Depends(get_settings),
    service: CheckoutService = Depends(get_checkout_service),
    bridge: PrestaShopBridgeClient = Depends(get_bridge_client),
    credentials: HTTPAuthorizationCredentials | None = Depends(optional_bearer),
) -> dict:
    if not settings.checkout_write_enabled:
        raise HTTPException(
            status_code=423,
            detail=(
                "CHECKOUT_WRITE_ENABLED=false : la création réelle de "
                "commande PrestaShop est désactivée."
            ),
    )

    try:
        body = payload.model_dump(mode="json")
        if credentials:
            identity = decode_access_token(credentials.credentials, settings)
            body["customer_id"] = int(identity["sub"])
        logger.info(
            "Checkout confirm payload sanitized=%s write_enabled=%s",
            _safe_confirm_log(body),
            settings.checkout_write_enabled,
        )
        result = await bridge.post(
            "checkout?action=confirm",
            body,
        )
    except BridgeUnavailable as exc:
        raise HTTPException(status_code=501, detail=str(exc)) from exc
    except BridgeHTTPError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc

    return {
        "success": True,
        "data": result.get("data", result),
        "meta": None,
        "error": None,
    }
