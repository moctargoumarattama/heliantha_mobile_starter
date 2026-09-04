from fastapi import Depends

from app.clients.bridge import PrestaShopBridgeClient
from app.clients.prestashop import PrestaShopClient
from app.core.config import Settings, get_settings
from app.services.addresses import AddressesService
from app.services.catalog import CatalogService
from app.services.checkout import CheckoutService
from app.services.home_slides import HomeSlidesService
from app.services.orders import OrdersService
from app.services.store_context import StoreContextService


def get_ps_client(
    settings: Settings = Depends(get_settings),
) -> PrestaShopClient:
    return PrestaShopClient(settings)


def get_bridge_client(
    settings: Settings = Depends(get_settings),
) -> PrestaShopBridgeClient:
    return PrestaShopBridgeClient(settings)


def get_catalog_service(
    ps: PrestaShopClient = Depends(get_ps_client),
    settings: Settings = Depends(get_settings),
) -> CatalogService:
    return CatalogService(ps, settings, StoreContextService(ps, settings))


def get_store_context_service(
    ps: PrestaShopClient = Depends(get_ps_client),
    settings: Settings = Depends(get_settings),
) -> StoreContextService:
    return StoreContextService(ps, settings)


def get_addresses_service(
    ps: PrestaShopClient = Depends(get_ps_client),
) -> AddressesService:
    return AddressesService(ps)


def get_home_slides_service(
    catalog: CatalogService = Depends(get_catalog_service),
) -> HomeSlidesService:
    return HomeSlidesService(catalog)


def get_checkout_service(
    ps: PrestaShopClient = Depends(get_ps_client),
    bridge: PrestaShopBridgeClient = Depends(get_bridge_client),
    settings: Settings = Depends(get_settings),
) -> CheckoutService:
    catalog = CatalogService(ps, settings, StoreContextService(ps, settings))
    return CheckoutService(ps, catalog, settings, bridge)


def get_orders_service(
    ps: PrestaShopClient = Depends(get_ps_client),
    bridge: PrestaShopBridgeClient = Depends(get_bridge_client),
) -> OrdersService:
    return OrdersService(ps, bridge)
