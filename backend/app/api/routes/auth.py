from fastapi import APIRouter, Depends, HTTPException
from fastapi import APIRouter, Depends, HTTPException, Request, status

from app.api.deps import get_bridge_client
from app.clients.bridge import (
    BridgeHTTPError,
    BridgeUnavailable,
    PrestaShopBridgeClient,
)
from app.core.config import Settings, get_settings
from app.core.rate_limit import login_rate_limiter
from app.core.security import create_access_token, get_current_identity
from app.schemas.auth import CustomerOut, LoginIn, LoginOut

router = APIRouter(tags=["authentification"])


def _get_client_ip(request: Request) -> str:
    """Extrait l'adresse IP du client en tenant compte d'un éventuel proxy."""
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    if request.client and request.client.host:
        return request.client.host
    return "127.0.0.1"


@router.post("/auth/login", response_model=dict)
async def login(
    payload: LoginIn,
    request: Request,
    bridge: PrestaShopBridgeClient = Depends(get_bridge_client),
    settings: Settings = Depends(get_settings),
) -> dict:
    client_ip = _get_client_ip(request)
    rate_key = f"ip:{client_ip}"

    # Vérifier si l'IP est temporairement bloquée suite à trop d'échecs
    blocked, retry_after = login_rate_limiter.is_blocked(rate_key)
    if blocked:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Trop de tentatives de connexion échouées. Veuillez réessayer plus tard.",
            headers={"Retry-After": str(retry_after)},
        )

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
            is_now_blocked, wait_seconds = login_rate_limiter.record_failure(rate_key)
            if is_now_blocked:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Trop de tentatives de connexion échouées. Veuillez réessayer plus tard.",
                    headers={"Retry-After": str(wait_seconds)},
                ) from exc
            raise HTTPException(
                status_code=401,
                detail="Email ou mot de passe incorrect.",
            ) from exc
        raise HTTPException(status_code=502, detail=exc.detail) from exc

    data = result.get("data", result)
    if not data or not data.get("id"):
        is_now_blocked, wait_seconds = login_rate_limiter.record_failure(rate_key)
        if is_now_blocked:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Trop de tentatives de connexion échouées. Veuillez réessayer plus tard.",
                headers={"Retry-After": str(wait_seconds)},
            )
        raise HTTPException(
            status_code=401,
            detail="Email ou mot de passe incorrect.",
        )

    # Réinitialisation du compteur pour cette IP en cas de succès
    login_rate_limiter.record_success(rate_key)

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
