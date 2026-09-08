from __future__ import annotations

from enum import StrEnum
from typing import Any

from pydantic import BaseModel


class NotificationType(StrEnum):
    ORDER_STATUS = "ORDER_STATUS"
    PAYMENT_STATUS = "PAYMENT_STATUS"
    FAVORITE_BACK_IN_STOCK = "FAVORITE_BACK_IN_STOCK"


class DeviceTokenIn(BaseModel):
    token: str
    platform: str = "android"


class NotificationOut(BaseModel):
    id: int
    type: NotificationType
    title: str
    body: str
    order_id: int | None = None
    product_id: int | None = None
    metadata: dict[str, Any] = {}
    created_at: str
    read_at: str | None = None


class PrestaShopOrderEventIn(BaseModel):
    type: NotificationType
    order_id: int
    customer_id: int | None = None
    reference: str | None = None
    state_id: int | None = None
    event: str | None = None
    status_key: str | None = None
    title: str | None = None
    message: str | None = None
    metadata: dict[str, Any] = {}


class PrestaShopStockEventIn(BaseModel):
    product_id: int
    quantity: int
    product_name: str = ""
    id_shop: int | None = None
