from fastapi import APIRouter, Depends, HTTPException, Request

from app.api.deps import get_bridge_client
from app.clients.bridge import (
    BridgeHTTPError,
    BridgeUnavailable,
    PrestaShopBridgeClient,
)
from app.core.config import Settings, get_settings
from app.core.rate_limit import login_rate_limiter
from app.core.security import create_access_token, get_current_identity
from app.schemas.auth import CustomerOut, LoginIn, LoginOut, RegisterIn

router = APIRouter(tags=["authentification"])


@router.post("/auth/login", response_model=dict)
async def login(
    request: Request,
    payload: LoginIn,
    bridge: PrestaShopBridgeClient = Depends(get_bridge_client),
    settings: Settings = Depends(get_settings),
) -> dict:
    forwarded = request.headers.get("x-forwarded-for")
    client_ip = (
        forwarded.split(",")[0].strip()
        if forwarded
        else (request.client.host if request.client else "unknown")
    )

    is_blocked, retry_after = login_rate_limiter.is_blocked(client_ip)
    if is_blocked:
        raise HTTPException(
            status_code=429,
            detail=f"Trop de tentatives de connexion échouées. Réessayez dans {retry_after} secondes.",
            headers={"Retry-After": str(retry_after)},
        )

    def _record_failure_and_raise(detail: str = "Email ou mot de passe incorrect.") -> None:
        blocked, retry = login_rate_limiter.record_failure(client_ip)
        if blocked:
            raise HTTPException(
                status_code=429,
                detail=f"Trop de tentatives de connexion échouées. Réessayez dans {retry} secondes.",
                headers={"Retry-After": str(retry)},
            )
        raise HTTPException(status_code=401, detail=detail)

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
            _record_failure_and_raise()
        raise HTTPException(status_code=502, detail=exc.detail) from exc

    data = result.get("data", result)
    if not data or not data.get("id"):
        _record_failure_and_raise()

    login_rate_limiter.record_success(client_ip)

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


@router.post("/auth/register", response_model=dict)
async def register(
    payload: RegisterIn,
    bridge: PrestaShopBridgeClient = Depends(get_bridge_client),
    settings: Settings = Depends(get_settings),
) -> dict:
    try:
        result = await bridge.post(
            "auth?action=register",
            {
                "firstname": payload.firstname.strip(),
                "lastname": payload.lastname.strip(),
                "email": str(payload.email),
                "password": payload.password,
            },
        )
    except BridgeUnavailable as exc:
        raise HTTPException(
            status_code=501,
            detail=(
                "La création de compte PrestaShop nécessite le pont serveur. "
                f"{exc}"
            ),
        ) from exc
    except BridgeHTTPError as exc:
        if exc.status_code in {400, 401, 409, 422}:
            raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
        raise HTTPException(status_code=502, detail=exc.detail) from exc

    data = result.get("data", result)
    if not data or not data.get("id"):
        raise HTTPException(status_code=502, detail="Compte PrestaShop non créé.")

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
