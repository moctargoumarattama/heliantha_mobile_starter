import asyncio
import logging
from typing import Any

import httpx

from app.core.config import Settings


logger = logging.getLogger(__name__)


class BridgeUnavailable(RuntimeError):
    pass


class BridgeHTTPError(RuntimeError):
    def __init__(
        self,
        status_code: int,
        detail: str,
        body: str | None = None,
        code: str | None = None,
    ):
        super().__init__(detail)
        self.status_code = status_code
        self.detail = detail
        self.body = body
        self.code = code


class PrestaShopBridgeClient:
    """
    Pont privé optionnel entre FastAPI et PrestaShop.

    Sert pour les opérations que le Webservice historique ne fournit pas
    proprement comme un login client ou un checkout dépendant de modules.
    """

    _client: httpx.AsyncClient | None = None
    _client_loop: asyncio.AbstractEventLoop | None = None

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

    def _shared_client(self) -> httpx.AsyncClient:
        self._check()
        try:
            current_loop = asyncio.get_running_loop()
        except RuntimeError:
            current_loop = None

        if (
            self.__class__._client is None
            or self.__class__._client.is_closed
            or (current_loop is not None and self.__class__._client_loop != current_loop)
        ):
            self.__class__._client = httpx.AsyncClient(
                timeout=httpx.Timeout(
                    self.settings.prestashop_timeout_seconds,
                    connect=5.0,
                    read=self.settings.prestashop_timeout_seconds,
                    write=10.0,
                    pool=5.0,
                ),
                follow_redirects=True,
                limits=httpx.Limits(
                    max_connections=20,
                    max_keepalive_connections=10,
                    keepalive_expiry=30.0,
                ),
            )
            self.__class__._client_loop = current_loop
        return self.__class__._client

    @classmethod
    async def close_shared_client(cls) -> None:
        if cls._client is not None and not cls._client.is_closed:
            await cls._client.aclose()
        cls._client = None
        cls._client_loop = None

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
        client = self._shared_client()
        try:
            logger.info("Bridge request method=POST url=%s", url)
            response = await client.post(url, json=payload, headers=headers)
        except httpx.TimeoutException as exc:
            logger.warning(
                "Bridge timeout method=POST url=%s type=%s",
                url,
                type(exc).__name__,
            )
            raise
        except httpx.RequestError as exc:
            logger.warning(
                "Bridge request error method=POST url=%s type=%s",
                url,
                type(exc).__name__,
            )
            raise
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
            error_code = "BRIDGE_ERROR"
            clean_message = f"Erreur PrestaShop (HTTP {response.status_code})"
            try:
                data = response.json()
                if isinstance(data, dict) and "error" in data:
                    err = data["error"]
                    if isinstance(err, dict):
                        error_code = str(err.get("code") or error_code)
                        clean_message = str(err.get("message") or clean_message)
                    elif isinstance(err, str):
                        clean_message = err
                elif isinstance(data, dict) and "message" in data:
                    clean_message = str(data["message"])
            except Exception:
                clean_message = "Erreur serveur PrestaShop temporaire."

            raise BridgeHTTPError(
                status_code=response.status_code,
                detail=clean_message,
                body=response.text[:2000],
                code=error_code,
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
                status_code=response.status_code,
                detail="Réponse JSON invalide du serveur PrestaShop.",
                body=response.text[:2000],
                code="INVALID_JSON",
            ) from exc
