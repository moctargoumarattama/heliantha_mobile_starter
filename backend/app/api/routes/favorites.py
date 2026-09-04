from fastapi import APIRouter, HTTPException

router = APIRouter(tags=["favoris et alertes"])


@router.get("/favorites")
async def favorites_info() -> dict:
    '''
    Les favoris visibles sur le site semblent dépendre d'un module.
    On ne crée pas une seconde vérité dans FastAPI.
    '''
    raise HTTPException(
        status_code=501,
        detail=(
            "Favoris à connecter au module PrestaShop existant. "
            "Le starter Flutter utilise un stockage local temporaire."
        ),
    )


@router.post("/stock-alerts/{product_id}")
async def stock_alert(product_id: int) -> dict:
    raise HTTPException(
        status_code=501,
        detail=(
            "Alertes de stock à connecter au module PrestaShop existant "
            "afin de rester synchronisées avec le site."
        ),
    )
