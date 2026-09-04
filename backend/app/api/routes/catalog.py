import logging
from time import monotonic

from fastapi import APIRouter, Depends, HTTPException, Query, Response

from app.api.deps import (
    get_catalog_service,
    get_home_slides_service,
    get_ps_client,
    get_store_context_service,
)
from app.clients.prestashop import PrestaShopClient, PrestaShopError
from app.services.catalog import CatalogService
from app.services.home_slides import HomeSlidesService
from app.services.store_context import StoreContextService

router = APIRouter(tags=["catalogue"])
logger = logging.getLogger("heliantha.perf")


@router.get("/home/slides", response_model=dict)
async def home_slides(
    service: HomeSlidesService = Depends(get_home_slides_service),
) -> dict:
    service.catalog.ps.reset_perf()
    start = monotonic()
    try:
        slides = await service.slides()
        _log_perf(
            "home_slides",
            start,
            service.catalog.ps,
            cache="",
        )
        return {
            "success": True,
            "data": [slide.model_dump() for slide in slides],
            "meta": {"total": len(slides)},
            "error": None,
        }
    except PrestaShopError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.get("/home")
async def home(
    catalog: CatalogService = Depends(get_catalog_service),
) -> dict:
    catalog.ps.reset_perf()
    start = monotonic()
    try:
        categories = await catalog.categories(limit=12)
        products, meta = await catalog.products(page=1, page_size=12)
        _log_perf(
            "home",
            start,
            catalog.ps,
            cache=str(meta.get("cache", "")),
        )
        return {
            "success": True,
            "data": {
                "categories": [x.model_dump() for x in categories],
                "products": [x.model_dump() for x in products],
            },
            "meta": meta,
            "error": None,
        }
    except (PrestaShopError, ValueError) as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.get("/categories", response_model=dict)
async def categories(
    language_id: int | None = Query(default=None, ge=1),
    catalog: CatalogService = Depends(get_catalog_service),
) -> dict:
    catalog.ps.reset_perf()
    start = monotonic()
    try:
        rows = await catalog.categories(language_id=language_id)
        _log_perf("categories", start, catalog.ps, cache="")
        return {
            "success": True,
            "data": [x.model_dump() for x in rows],
            "meta": {"total": len(rows)},
            "error": None,
        }
    except PrestaShopError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.get("/products", response_model=dict)
async def products(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    category: int | None = Query(default=None, ge=1),
    q: str | None = Query(default=None, max_length=120),
    language_id: int | None = Query(default=None, ge=1),
    currency_id: int | None = Query(default=None, ge=1),
    catalog: CatalogService = Depends(get_catalog_service),
) -> dict:
    catalog.ps.reset_perf()
    start = monotonic()
    try:
        rows, meta = await catalog.products(
            page=page,
            page_size=page_size,
            category_id=category,
            q=q,
            language_id=language_id,
            currency_id=currency_id,
        )
        _log_perf(
            "products",
            start,
            catalog.ps,
            cache=str(meta.get("cache", "")),
        )
        return {
            "success": True,
            "data": [x.model_dump() for x in rows],
            "meta": meta,
            "error": None,
        }
    except PrestaShopError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.get("/products/{product_id}", response_model=dict)
async def product(
    product_id: int,
    language_id: int | None = Query(default=None, ge=1),
    currency_id: int | None = Query(default=None, ge=1),
    catalog: CatalogService = Depends(get_catalog_service),
) -> dict:
    catalog.ps.reset_perf()
    start = monotonic()
    try:
        row = await catalog.product(
            product_id,
            language_id=language_id,
            currency_id=currency_id,
        )
        _log_perf("product_detail", start, catalog.ps, cache="")
        return {
            "success": True,
            "data": row.model_dump(),
            "meta": None,
            "error": None,
        }
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except PrestaShopError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.get("/store-context", response_model=dict)
async def store_context(
    service: StoreContextService = Depends(get_store_context_service),
) -> dict:
    service.ps.reset_perf()
    start = monotonic()
    try:
        context = await service.context()
        _log_perf("store_context", start, service.ps, cache="")
        return {
            "success": True,
            "data": context.model_dump(),
            "meta": None,
            "error": None,
        }
    except PrestaShopError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.get("/products/{product_id}/image")
async def product_image(
    product_id: int,
    image_id: int | None = None,
    ps: PrestaShopClient = Depends(get_ps_client),
) -> Response:
    ps.reset_perf()
    start = monotonic()
    try:
        path = (
            f"images/products/{product_id}/{image_id}"
            if image_id
            else f"images/products/{product_id}"
        )
        content, content_type = await ps.get_binary(path)
        _log_perf("product_image", start, ps, cache="")
        return Response(content=content, media_type=content_type)
    except PrestaShopError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


def _log_perf(
    name: str,
    start: float,
    ps: PrestaShopClient,
    *,
    cache: str,
) -> None:
    total_ms = (monotonic() - start) * 1000
    prestashop_ms = ps.prestashop_time_ms
    normalize_ms = max(0.0, total_ms - prestashop_ms)
    cache_part = f" cache={cache}" if cache else ""
    logger.warning(
        "PERF %s total=%dms prestashop=%dms normalize=%dms calls=%d%s",
        name,
        round(total_ms),
        round(prestashop_ms),
        round(normalize_ms),
        ps.prestashop_calls,
        cache_part,
    )
