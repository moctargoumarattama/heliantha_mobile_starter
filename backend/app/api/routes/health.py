from fastapi import APIRouter

router = APIRouter(tags=["system"])


@router.get("/health")
async def health() -> dict:
    return {
        "success": True,
        "data": {
            "service": "heliantha-mobile-api",
            "status": "ok",
        },
    }
