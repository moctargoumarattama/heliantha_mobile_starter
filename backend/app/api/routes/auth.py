from fastapi import APIRouter, Depends, HTTPException

from app.api.deps import get_bridge_client
from app.clients.bridge import (
    BridgeHTTPError,
    BridgeUnavailable,
    PrestaShopBridgeClient,
)
from app.core.config import Settings, get_settings
from app.core.security import create_access_token, get_current_identity
from app.schemas.auth import CustomerOut, LoginIn, LoginOut

router = APIRouter(tags=["authentification"])


@router.post("/auth/login", response_model=dict)
async def login(
    payload: LoginIn,
    bridge: PrestaShopBridgeClient = Depends(get_bridge_client),
    settings: Settings = Depends(get_settings),
) -> dict:
    try:
        result = await bridge.post(
            "auth",
            {
                "email": str(payload.email),
                "password": payload.password,
            },
        )
    except BridgeUnavailable as exc:
        raise HTTPException(
            status_code=501,
            detail=(
                "Le login PrestaShop nécessite le pont serveur. "
                f"{exc}"
            ),
        ) from exc
    except BridgeHTTPError as exc:
        if exc.status_code in {400, 401, 422}:
            raise HTTPException(
                status_code=401,
                detail="Email ou mot de passe incorrect.",
            ) from exc
        raise HTTPException(status_code=502, detail=exc.detail) from exc

    data = result.get("data", result)
    if not data or not data.get("id"):
        raise HTTPException(
            status_code=401,
            detail="Email ou mot de passe incorrect.",
        )

    customer = CustomerOut(
        id=int(data["id"]),
        email=data["email"],
        firstname=data.get("firstname", ""),
        lastname=data.get("lastname", ""),
    )
    token = create_access_token(
        customer_id=customer.id,
        email=str(customer.email),
        settings=settings,
    )
    out = LoginOut(
        access_token=token,
        customer=customer,
    )
    return {
        "success": True,
        "data": out.model_dump(),
        "meta": None,
        "error": None,
    }


@router.get("/me", response_model=dict)
async def me(
    identity: dict = Depends(get_current_identity),
) -> dict:
    return {
        "success": True,
        "data": {
            "id": int(identity["sub"]),
            "email": identity.get("email"),
        },
        "meta": None,
        "error": None,
    }
