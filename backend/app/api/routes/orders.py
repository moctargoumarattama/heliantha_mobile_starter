from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.api.deps import get_orders_service
from app.clients.bridge import BridgeUnavailable
from app.core.config import Settings, get_settings
from app.core.security import decode_access_token, get_current_identity
from app.schemas.order import CreateOrderIn
from app.services.orders import OrdersService

router = APIRouter(tags=["commandes"])
optional_bearer = HTTPBearer(auto_error=False)


@router.get("/orders", response_model=dict)
async def list_orders(
    identity: dict = Depends(get_current_identity),
    service: OrdersService = Depends(get_orders_service),
) -> dict:
    try:
        rows = await service.list_for_customer(int(identity["sub"]))
        return {
            "success": True,
            "data": [x.model_dump() for x in rows],
            "meta": {"total": len(rows)},
            "error": None,
        }
    except Exception as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.get("/orders/{order_id}", response_model=dict)
async def get_order(
    order_id: int,
    identity: dict = Depends(get_current_identity),
    service: OrdersService = Depends(get_orders_service),
) -> dict:
    try:
        row = await service.get_for_customer(
            int(identity["sub"]),
            order_id,
        )
        return {
            "success": True,
            "data": row.model_dump(),
            "meta": None,
            "error": None,
        }
    except PermissionError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.post("/orders", response_model=dict)
async def create_order(
    payload: CreateOrderIn,
    credentials: HTTPAuthorizationCredentials | None = Depends(optional_bearer),
    settings: Settings = Depends(get_settings),
    service: OrdersService = Depends(get_orders_service),
) -> dict:
    customer_id: int | None = None
    if credentials:
        identity = decode_access_token(credentials.credentials, settings)
        customer_id = int(identity["sub"])

    try:
        result = await service.create(payload, customer_id)
        return {
            "success": True,
            "data": result.get("data", result),
            "meta": None,
            "error": None,
        }
    except BridgeUnavailable as exc:
        raise HTTPException(
            status_code=501,
            detail=(
                "Le checkout réel dépend des règles de la boutique "
                "PrestaShop et doit passer par le pont serveur. "
                f"{exc}"
            ),
        ) from exc
