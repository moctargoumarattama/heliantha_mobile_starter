from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient

from app.api.deps import get_bridge_client
from app.clients.bridge import BridgeHTTPError
from app.core.rate_limit import LoginRateLimiter, login_rate_limiter
from app.main import app


def test_login_rate_limiter_unit():
    limiter = LoginRateLimiter(
        max_attempts=3,
        window_seconds=10.0,
        block_duration_seconds=5.0,
    )
    ip_key = "test_ip_1"

    assert limiter.is_blocked(ip_key) == (False, 0)

    # 1er et 2ème échecs : non bloqué
    assert limiter.record_failure(ip_key) == (False, 0)
    assert limiter.record_failure(ip_key) == (False, 0)
    assert limiter.is_blocked(ip_key) == (False, 0)

    # 3ème échec : seuil atteint -> bloqué
    blocked, retry_after = limiter.record_failure(ip_key)
    assert blocked is True
    assert retry_after > 0

    is_blocked, remaining = limiter.is_blocked(ip_key)
    assert is_blocked is True
    assert remaining > 0

    # Succès -> réinitialisation
    limiter.record_success(ip_key)
    assert limiter.is_blocked(ip_key) == (False, 0)


def test_login_endpoint_rate_limiting_and_no_email_leak():
    login_rate_limiter.reset()
    client = TestClient(app)

    # Simuler un pont PrestaShop qui retourne 401 identifiants invalides
    mock_bridge = AsyncMock()
    mock_bridge.post.side_effect = BridgeHTTPError(
        status_code=401,
        detail="Email ou mot de passe incorrect.",
    )

    app.dependency_overrides[get_bridge_client] = lambda: mock_bridge

    try:
        # 4 premiers échecs avec différents emails (existant ou inexistant)
        for i in range(4):
            response = client.post(
                "/v1/auth/login",
                json={"email": f"user_{i}@example.com", "password": "wrong_password"},
                headers={"X-Forwarded-For": "198.51.100.1"},
            )
            assert response.status_code == 401
            assert response.json()["detail"] == "Email ou mot de passe incorrect."

        # 5ème échec -> doit déclencher HTTP 429
        fifth_response = client.post(
            "/v1/auth/login",
            json={"email": "victim@example.com", "password": "wrong_password"},
            headers={"X-Forwarded-For": "198.51.100.1"},
        )
        assert fifth_response.status_code == 429
        assert "Retry-After" in fifth_response.headers
        assert "Trop de tentatives" in fifth_response.json()["detail"]

        # Tentative subséquente pendant le blocage -> immédiatement 429
        sixth_response = client.post(
            "/v1/auth/login",
            json={"email": "victim@example.com", "password": "any_password"},
            headers={"X-Forwarded-For": "198.51.100.1"},
        )
        assert sixth_response.status_code == 429
        assert "Retry-After" in sixth_response.headers

        # Une autre IP n'est pas bloquée
        other_ip_response = client.post(
            "/v1/auth/login",
            json={"email": "other@example.com", "password": "wrong_password"},
            headers={"X-Forwarded-For": "198.51.100.2"},
        )
        assert other_ip_response.status_code == 401

    finally:
        app.dependency_overrides.clear()
        login_rate_limiter.reset()

