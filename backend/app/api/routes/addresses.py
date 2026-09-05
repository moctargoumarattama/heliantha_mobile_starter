import logging

from fastapi import APIRouter, Depends, HTTPException

from app.api.deps import get_addresses_service
from app.clients.bridge import BridgeHTTPError, BridgeUnavailable
from app.core.security import get_current_identity
from app.schemas.address import AddressIn
from app.services.addresses import AddressesService


logger = logging.getLogger(__name__)
router = APIRouter(tags=["adresses"])


@router.get("/addresses", response_model=dict)
async def list_addresses(
    identity: dict = Depends(get_current_identity),
    service: AddressesService = Depends(get_addresses_service),
) -> dict:
    customer_id = int(identity["sub"])
    try:
        rows = await service.list_for_customer(customer_id)
        return {
            "success": True,
            "data": [row.model_dump() for row in rows],
            "meta": {"total": len(rows)},
            "error": None,
        }
    except Exception as exc:
        logger.exception(
            "Erreur chargement adresses pour customer_id=%s",
            customer_id,
        )
        raise HTTPException(
            status_code=502,
            detail="Impossible de charger les adresses PrestaShop.",
        ) from exc


@router.get("/addresses/countries", response_model=dict)
async def list_address_countries(
    identity: dict = Depends(get_current_identity),
    service: AddressesService = Depends(get_addresses_service),
) -> dict:
    try:
        rows = await service.countries()
        return {
            "success": True,
            "data": [row.model_dump() for row in rows],
            "meta": {"total": len(rows)},
            "error": None,
        }
    except Exception as exc:
        logger.exception(
            "Erreur chargement pays adresses pour customer_id=%s",
            identity.get("sub"),
        )
        raise HTTPException(
            status_code=502,
            detail="Impossible de charger les pays PrestaShop.",
        ) from exc


@router.post("/addresses", response_model=dict)
async def create_address(
    payload: AddressIn,
    identity: dict = Depends(get_current_identity),
    service: AddressesService = Depends(get_addresses_service),
) -> dict:
    customer_id = int(identity["sub"])
    try:
        row = await service.create(customer_id, payload)
        return {
            "success": True,
            "data": row.model_dump(),
            "meta": None,
            "error": None,
        }
    except BridgeUnavailable as exc:
        raise HTTPException(status_code=501, detail=str(exc)) from exc
    except BridgeHTTPError as exc:
        # Transmettre le message PrestaShop tel quel (jamais de stack trace)
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    except Exception as exc:
        logger.exception(
            "Erreur création adresse pour customer_id=%s",
            customer_id,
        )
        raise HTTPException(
            status_code=502,
            detail="Impossible de créer l'adresse. Réessayez ou contactez le support.",
        ) from exc


@router.put("/addresses/{address_id}", response_model=dict)
async def update_address(
    address_id: int,
    payload: AddressIn,
    identity: dict = Depends(get_current_identity),
    service: AddressesService = Depends(get_addresses_service),
) -> dict:
    customer_id = int(identity["sub"])
    try:
        row = await service.update(customer_id, address_id, payload)
        return {
            "success": True,
            "data": row.model_dump(),
            "meta": None,
            "error": None,
        }
    except BridgeUnavailable as exc:
        raise HTTPException(status_code=501, detail=str(exc)) from exc
    except BridgeHTTPError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    except Exception as exc:
        logger.exception(
            "Erreur modification adresse id=%s pour customer_id=%s",
            address_id,
            customer_id,
        )
        raise HTTPException(
            status_code=502,
            detail="Impossible de modifier l’adresse PrestaShop.",
        ) from exc
