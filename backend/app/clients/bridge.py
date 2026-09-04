from __future__ import annotations

import logging
from typing import Any

import httpx

from app.core.config import Settings


logger = logging.getLogger(__name__)


class BridgeUnavailable(RuntimeError):
    pass


class BridgeHTTPError(RuntimeError):
    def __init__(self, status_code: int, detail: str, body: str | None = None):
        super().__init__(detail)
        self.status_code = status_code
        self.detail = detail
        self.body = body


class PrestaShopBridgeClient:
    '''
    Pont privé optionnel entre FastAPI et PrestaShop.

    Sert pour les opérations que le Webservice historique ne fournit pas
    proprement comme un login client ou un checkout dépendant de modules.
    '''

    def __init__(self, settings: Settings):
        self.settings = settings

    def _check(self) -> None:
        if not self.settings.mobile_bridge_url:
            raise BridgeUnavailable(
                "MOBILE_BRIDGE_URL n'est pas configuré."
            )
        if not self.settings.mobile_bridge_secret:
            raise BridgeUnavailable(
                "MOBILE_BRIDGE_SECRET n'est pas configuré."
            )

    async def post(self, endpoint: str, payload: dict[str, Any]) -> Any:
        self._check()
        url = (
            self.settings.mobile_bridge_url.rstrip("/")
            + "/"
            + endpoint.lstrip("/")
        )
        headers = {
            "X-Heliantha-Bridge-Secret": self.settings.mobile_bridge_secret,
            "Accept": "application/json",
        }
        async with httpx.AsyncClient(
            timeout=self.settings.prestashop_timeout_seconds,
            follow_redirects=True,
        ) as client:
            try:
                logger.info("Bridge request method=POST url=%s", url)
                response = await client.post(url, json=payload, headers=headers)
            except Exception as exc:
                logger.exception(
                    "Bridge exception method=POST url=%s type=%s",
                    url,
                    type(exc).__name__,
                )
                raise

        logger.info(
            "Bridge response method=POST url=%s status=%s body=%s",
            url,
            response.status_code,
            response.text[:2000],
        )
        if response.status_code >= 400:
            try:
                detail = response.json()
            except Exception:
                detail = response.text[:500]
            raise BridgeHTTPError(
                response.status_code,
                f"Pont PrestaShop: HTTP {response.status_code} - {detail}",
                response.text[:2000],
            )
        try:
            return response.json()
        except Exception as exc:
            logger.exception(
                "Bridge invalid JSON method=POST url=%s status=%s body=%s",
                url,
                response.status_code,
                response.text[:2000],
            )
            raise BridgeHTTPError(
                response.status_code,
                f"Pont PrestaShop: JSON invalide - {type(exc).__name__}",
                response.text[:2000],
            ) from exc
