from pathlib import Path

from app.core.config import Settings
from app.schemas.notification import DeviceTokenIn
from app.services.notifications import NotificationService


def test_sqlite_configurable_path(tmp_path: Path):
    custom_db = tmp_path / "custom_dir" / "notifications.sqlite3"
    settings = Settings(notifications_db_path=str(custom_db))

    assert settings.resolved_notification_db_path == custom_db.resolve()

    service = NotificationService(settings)
    assert custom_db.exists()

    with service._connect() as conn:
        cursor = conn.execute("PRAGMA foreign_keys;")
        assert cursor.fetchone()[0] == 1

        cursor = conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='device_tokens';"
        )
        assert cursor.fetchone() is not None


def test_sqlite_usable_after_logical_restart(tmp_path: Path):
    custom_db = tmp_path / "persistent.sqlite3"
    settings = Settings(notifications_db_path=str(custom_db))

    # Premier démarrage
    service1 = NotificationService(settings)
    service1.register_device(
        customer_id=42,
        payload=DeviceTokenIn(token="token_abc_123", platform="android"),
    )

    # Deuxième démarrage logique sur le même fichier
    service2 = NotificationService(settings)
    with service2._connect() as conn:
        row = conn.execute(
            "SELECT token, platform FROM device_tokens WHERE customer_id=?",
            (42,),
        ).fetchone()
        assert row is not None
        assert row["token"] == "token_abc_123"
        assert row["platform"] == "android"

