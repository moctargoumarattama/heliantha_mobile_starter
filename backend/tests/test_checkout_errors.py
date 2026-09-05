from unittest.mock import AsyncMock

import httpx
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

from app.api.deps import get_bridge_client, get_checkout_service
from app.api.routes.checkout import _handle_checkout_exception
from app.clients.bridge import BridgeHTTPError, BridgeUnavailable
from app.clients.prestashop import PrestaShopError
from app.main import app


def test_handle_checkout_exception_mappings():
    # 1. Erreur métier 409 (stock, doublon, etc.)
    e_409 = BridgeHTTPError(409, "Stock insuffisant pour ce produit.", code="INSUFFICIENT_STOCK")
    res = _handle_checkout_exception(e_409, "confirm")
    assert res.status_code == 409
    assert res.detail == "Stock insuffisant pour ce produit."

    # 2. Erreur métier 422 (validation pays Maroc, etc.)
    e_422 = BridgeHTTPError(422, "Seules les adresses au Maroc sont acceptées.", code="COUNTRY_NOT_ALLOWED")
    res = _handle_checkout_exception(e_422, "confirm")
    assert res.status_code == 422
    assert res.detail == "Seules les adresses au Maroc sont acceptées."

    # 3. Erreur 500 interne PrestaShop -> mappé en 502 propre sans fuite de stack trace PHP
    e_500 = BridgeHTTPError(500, "Fatal error in prestashop.php line 42", code="PHP_FATAL_ERROR")
    res = _handle_checkout_exception(e_500, "confirm")
    assert res.status_code == 502
    assert "Fatal error" not in res.detail
    assert res.detail == "Le serveur PrestaShop a retourné une erreur interne."

    # 4. Bridge non configuré
    e_unavail = BridgeUnavailable("URL non configurée")
    res = _handle_checkout_exception(e_unavail, "preview")
    assert res.status_code == 501
    assert "nécessite le pont" in res.detail

    # 5. PrestaShopError (catalogue / webservice) -> 502 propre
    e_ps = PrestaShopError("PrestaShop 500 sur products: SQL syntax error near...")
    res = _handle_checkout_exception(e_ps, "preview")
    assert res.status_code == 502
    assert "SQL" not in res.detail
    assert res.detail == "Erreur de communication avec le catalogue PrestaShop."

    # 6. Timeout upstream -> 504 propre
    e_timeout = httpx.ConnectTimeout("Connection timed out")
    res = _handle_checkout_exception(e_timeout, "confirm")
    assert res.status_code == 504
    assert res.detail == "Délai d'attente dépassé avec PrestaShop. Veuillez réessayer."

    # 7. Erreur réseau upstream -> 503 propre
    e_connect = httpx.ConnectError("Failed to establish a new connection")
    res = _handle_checkout_exception(e_connect, "confirm")
    assert res.status_code == 503
    assert res.detail == "Impossible de joindre le serveur PrestaShop. Service temporairement indisponible."

    # 8. Erreur inattendue -> 502 sans fuite d'informations sensibles
    e_unexpected = RuntimeError("secret_key_leaked_in_traceback")
    res = _handle_checkout_exception(e_unexpected, "confirm")
    assert res.status_code == 502
    assert "secret_key" not in res.detail
    assert "Une erreur inattendue est survenue" in res.detail


def test_checkout_preview_endpoint_timeout_mapping():
    client = TestClient(app)
    mock_service = AsyncMock()
    mock_service.preview.side_effect = httpx.ReadTimeout("Read timed out")

    app.dependency_overrides[get_checkout_service] = lambda: mock_service

    try:
        response = client.post(
            "/v1/checkout/preview",
            json={
                "lines": [{"product_id": 1, "quantity": 1}],
            },
        )
        assert response.status_code == 504
        assert response.json()["detail"] == "Délai d'attente dépassé avec PrestaShop. Veuillez réessayer."
    finally:
        app.dependency_overrides.clear()


def test_checkout_confirm_endpoint_network_error_mapping():
    client = TestClient(app)
    mock_service = AsyncMock()
    mock_service._morocco_country_id.return_value = 144

    mock_bridge = AsyncMock()
    mock_bridge.post.side_effect = httpx.ConnectError("Network unreachable")

    app.dependency_overrides[get_checkout_service] = lambda: mock_service
    app.dependency_overrides[get_bridge_client] = lambda: mock_bridge

    try:
        response = client.post(
            "/v1/checkout/confirm",
            json={
                "mode": "guest",
                "idempotency_key": "test-key-safe-12345",
                "lines": [{"product_id": 1, "quantity": 1}],
            },
        )
        assert response.status_code == 503
        assert "Impossible de joindre le serveur PrestaShop" in response.json()["detail"]
    finally:
        app.dependency_overrides.clear()

