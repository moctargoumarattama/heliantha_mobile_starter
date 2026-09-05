import pytest

from app.core.config import Settings


def test_jwt_secret_required_in_production():
    with pytest.raises(ValueError, match="JWT_SECRET est obligatoire"):
        Settings(app_env="production", jwt_secret="")


def test_jwt_secret_rejects_placeholder_in_production():
    with pytest.raises(ValueError, match="ne peut pas être une valeur par défaut ou un placeholder"):
        Settings(
            app_env="production",
            jwt_secret="CHANGE_ME_WITH_A_LONG_RANDOM_SECRET",
        )

    with pytest.raises(ValueError, match="ne peut pas être une valeur par défaut ou un placeholder"):
        Settings(
            app_env="production",
            jwt_secret="CHANGE_ME",
        )


def test_jwt_secret_rejects_weak_secret_in_production():
    with pytest.raises(ValueError, match="trop faible"):
        Settings(
            app_env="production",
            jwt_secret="too_short_secret_under_32_chr",
        )


def test_jwt_secret_accepts_strong_secret_in_production():
    strong_secret = "a" * 64
    settings = Settings(
        app_env="production",
        jwt_secret=strong_secret,
    )
    assert settings.jwt_secret == strong_secret


def test_development_allows_placeholder():
    settings = Settings(
        app_env="development",
        jwt_secret="CHANGE_ME_WITH_A_LONG_RANDOM_SECRET",
    )
    assert settings.jwt_secret == "CHANGE_ME_WITH_A_LONG_RANDOM_SECRET"

