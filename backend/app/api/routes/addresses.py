import logging

from fastapi import APIRouter, Depends, HTTPException

from app.api.deps import get_addresses_service
from app.core.security import get_current_identity
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
