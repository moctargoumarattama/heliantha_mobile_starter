from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


BACKEND_DIR = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    app_name: str = "Heliantha Mobile API"
    app_env: str = "development"
    api_prefix: str = "/v1"






    prestashop_base_url: str = "https://heliantha.ma"
    prestashop_webservice_key: str = ""
    prestashop_language_id: int = 3
    prestashop_timeout_seconds: float = 20.0

    jwt_secret: str = "CHANGE_ME"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 720

    mobile_bridge_url: str = ""
    mobile_bridge_secret: str = ""
    checkout_write_enabled: bool = False

    cors_origins: str = "http://localhost:3000,http://127.0.0.1:3000"

    model_config = SettingsConfigDict(
        env_file=BACKEND_DIR / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @property
    def cors_origin_list(self) -> list[str]:
        return [x.strip() for x in self.cors_origins.split(",") if x.strip()]



@lru_cache
def get_settings() -> Settings:
    return Settings()
