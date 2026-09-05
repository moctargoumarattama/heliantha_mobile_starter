from __future__ import annotations

import logging
from time import monotonic
from typing import Any

from app.clients.bridge import PrestaShopBridgeClient
from app.clients.prestashop import PrestaShopClient, PrestaShopError
from app.schemas.order import CreateOrderIn, OrderOut
from app.services.normalizers import localized, to_float, to_int, unwrap_collection


logger = logging.getLogger(__name__)

ORDER_LIST_DISPLAY = (
    "["
    "id,"
    "reference,"
    "id_customer,"
    "id_currency,"
    "current_state,"
    "total_paid_tax_incl,"
    "total_paid,"
    "date_add"
    "]"
)

ORDER_STATE_DISPLAY = "[id,name]"
ORDER_STATE_CACHE_TTL_SECONDS = 300


class OrdersService:
    _state_cache: dict[int, tuple[float, str]] = {}

    def __init__(
        self,
        ps: PrestaShopClient,
        bridge: PrestaShopBridgeClient,
    ):
        self.ps = ps
        self.bridge = bridge

    async def list_for_customer(self, customer_id: int) -> list[OrderOut]:
        payload = await self._orders_payload(customer_id)

        rows = unwrap_collection(payload, "orders")
        if not rows:
            return []
        rows.sort(
            key=lambda row: str(row.get("date_add") or ""),
            reverse=True,
        )

        state_ids = {
            self._state_id(row)
            for row in rows
            if self._state_id(row)
        }
        states = await self._state_names(state_ids)

        return [
            OrderOut(
                id=to_int(row.get("id")),
                reference=str(row.get("reference") or ""),
                total_paid=self._total_paid(row),
                state_id=self._state_id(row) or None,
                state_name=states.get(self._state_id(row)),
                date_add=str(row.get("date_add") or "") or None,
            )
            for row in rows
        ]

    async def get_for_customer(
        self,
        customer_id: int,
        order_id: int,
    ) -> OrderOut:
        try:
            payload = await self.ps.get_resource("orders", order_id)
        except PrestaShopError:
            logger.exception(
                "Erreur PrestaShop /orders/%s pour customer_id=%s",
                order_id,
                customer_id,
            )
            raise

        row = payload.get("order", {}) if isinstance(payload, dict) else {}
        if not row:
            rows = unwrap_collection(payload, "orders")
            row = rows[0] if rows else {}
        if not row or to_int(row.get("id_customer")) != customer_id:
            raise PermissionError("Commande introuvable.")
        state_id = self._state_id(row)
        states = await self._state_names({state_id} if state_id else set())
        return OrderOut(
            id=to_int(row.get("id")),
            reference=str(row.get("reference") or ""),
            total_paid=self._total_paid(row),
            state_id=state_id or None,
            state_name=states.get(state_id),
            date_add=str(row.get("date_add") or "") or None,
        )

    async def create(
        self,
        payload: CreateOrderIn,
        customer_id: int | None,
    ) -> dict:
        body = payload.model_dump()
        if customer_id is not None:
            body["customer_id"] = customer_id
        return await self.bridge.post("orders", body)

    async def _orders_payload(self, customer_id: int) -> dict[str, Any]:
        filters = {"id_customer": f"[{customer_id}]"}
        attempts: list[dict[str, Any]] = [
            {
                "filters": filters,
                "limit": "0,100",
                "display": ORDER_LIST_DISPLAY,
            },
            {"filters": filters, "limit": "0,100"},
            {"filters": filters},
        ]

        for index, kwargs in enumerate(attempts, start=1):
            try:
                payload = await self.ps.list_resource("orders", **kwargs)
                logger.info(
                    "PrestaShop /orders tentative=%s OK customer_id=%s",
                    index,
                    customer_id,
                )
                if isinstance(payload, dict):
                    return payload
            except PrestaShopError:
                logger.warning(
                    "PrestaShop /orders tentative=%s refusée customer_id=%s kwargs=%s",
                    index,
                    customer_id,
                    kwargs,
                )
                if index == len(attempts):
                    logger.exception(
                        "Erreur PrestaShop /orders avec filtre id_customer. "
                        "Vérifier permission GET orders et champ filtrable id_customer."
                    )
                    raise

        return {}

    async def _state_names(self, state_ids: set[int]) -> dict[int, str]:
        clean_ids = {state_id for state_id in state_ids if state_id}
        if not clean_ids:
            return {}

        now = monotonic()
        output: dict[int, str] = {}
        missing: list[int] = []
        for state_id in clean_ids:
            cached = self.__class__._state_cache.get(state_id)
            if cached and cached[0] > now:
                output[state_id] = cached[1]
            else:
                missing.append(state_id)

        if missing:
            try:
                payload = await self.ps.list_resource(
                    "order_states",
                    display=ORDER_STATE_DISPLAY,
                    filters={
                        "id": "[" + "|".join(str(state_id) for state_id in missing) + "]"
                    },
                    limit=f"0,{len(missing)}",
                    params={"language": self.ps.settings.prestashop_language_id},
                )
                rows = unwrap_collection(payload, "order_states")
                for row in rows:
                    state_id = to_int(row.get("id"))
                    name = localized(
                        row.get("name"),
                        self.ps.settings.prestashop_language_id,
                    ).strip()
                    if state_id and name:
                        output[state_id] = name
                        self.__class__._state_cache[state_id] = (
                            now + ORDER_STATE_CACHE_TTL_SECONDS,
                            name,
                        )
            except PrestaShopError:
                logger.exception(
                    "Erreur PrestaShop /order_states pour ids=%s",
                    missing,
                )

        return output

    def _state_id(self, row: dict[str, Any]) -> int:
        return to_int(
            row.get("current_state")
            or row.get("id_order_state")
            or row.get("id_current_state")
        )

    def _total_paid(self, row: dict[str, Any]) -> float:
        return to_float(
            row.get("total_paid_tax_incl")
            if row.get("total_paid_tax_incl") is not None
            else row.get("total_paid")
        )
