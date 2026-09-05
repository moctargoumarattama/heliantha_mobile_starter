from __future__ import annotations

import json
import logging
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from typing import Any, Generator

from app.core.config import Settings
from app.schemas.notification import (
    DeviceTokenIn,
    NotificationOut,
    NotificationType,
)

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
except ImportError:  # pragma: no cover
    firebase_admin = None
    credentials = None
    messaging = None


logger = logging.getLogger(__name__)


class NotificationService:
    def __init__(self, settings: Settings):
        self.settings = settings
        self.db_path = Path(settings.notification_db_path)
        if hasattr(settings, "resolved_notification_db_path"):
            self.db_path = settings.resolved_notification_db_path
        else:
            p = Path(getattr(settings, "notifications_db_path", getattr(settings, "notification_db_path", "./heliantha_notifications.sqlite3")))
            self.db_path = p.resolve()
        self._init_db()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
    @contextmanager
    def _connect(self) -> Generator[sqlite3.Connection, None, None]:
        conn = sqlite3.connect(self.db_path, timeout=10.0)
        conn.row_factory = sqlite3.Row
        return conn
        conn.execute("PRAGMA foreign_keys = ON;")
        conn.execute("PRAGMA busy_timeout = 5000;")
        try:
            conn.execute("PRAGMA journal_mode = WAL;")
        except Exception:
            pass
        try:
            with conn:
                yield conn
        finally:
            conn.close()

    def _init_db(self) -> None:
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        with self._connect() as conn:
            conn.executescript(
                """
                CREATE TABLE IF NOT EXISTS device_tokens (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    customer_id INTEGER NOT NULL,
                    token TEXT NOT NULL UNIQUE,
                    platform TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS notifications (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    customer_id INTEGER NOT NULL,
                    type TEXT NOT NULL,
                    title TEXT NOT NULL,
                    body TEXT NOT NULL,
                    order_id INTEGER,
                    product_id INTEGER,
                    status_key TEXT,
                    metadata TEXT NOT NULL DEFAULT '{}',
                    created_at TEXT NOT NULL,
                    read_at TEXT
                );
                CREATE TABLE IF NOT EXISTS favorite_watches (
                    customer_id INTEGER NOT NULL,
                    product_id INTEGER NOT NULL,
                    last_in_stock INTEGER NOT NULL DEFAULT 0,
                    notified_in_stock INTEGER NOT NULL DEFAULT 0,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    PRIMARY KEY (customer_id, product_id)
                );
                CREATE UNIQUE INDEX IF NOT EXISTS uq_notification_transition
                ON notifications(customer_id, type, COALESCE(order_id, 0),
                                 COALESCE(product_id, 0), COALESCE(status_key, ''));
                """
            )

    def register_device(self, customer_id: int, payload: DeviceTokenIn) -> None:
        now = self._now()
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO device_tokens(customer_id, token, platform, updated_at)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(token) DO UPDATE SET
                    customer_id=excluded.customer_id,
                    platform=excluded.platform,
                    updated_at=excluded.updated_at
                """,
                (customer_id, payload.token, payload.platform, now),
            )

    def delete_device(self, customer_id: int, token: str | None = None) -> None:
        with self._connect() as conn:
            if token:
                conn.execute(
                    "DELETE FROM device_tokens WHERE customer_id=? AND token=?",
                    (customer_id, token),
                )
            else:
                conn.execute(
                    "DELETE FROM device_tokens WHERE customer_id=?",
                    (customer_id,),
                )

    def list_notifications(self, customer_id: int) -> list[NotificationOut]:
        with self._connect() as conn:
            rows = conn.execute(
                """
                SELECT * FROM notifications
                WHERE customer_id=?
                ORDER BY datetime(created_at) DESC
                LIMIT 100
                """,
                (customer_id,),
            ).fetchall()
        return [self._notification_from_row(row) for row in rows]

    def unread_count(self, customer_id: int) -> int:
        with self._connect() as conn:
            row = conn.execute(
                "SELECT COUNT(*) AS total FROM notifications WHERE customer_id=? AND read_at IS NULL",
                (customer_id,),
            ).fetchone()
        return int(row["total"] if row else 0)

    def mark_read(self, customer_id: int, notification_id: int) -> bool:
        with self._connect() as conn:
            cursor = conn.execute(
                """
                UPDATE notifications
                SET read_at=COALESCE(read_at, ?)
                WHERE id=? AND customer_id=?
                """,
                (self._now(), notification_id, customer_id),
            )
        return cursor.rowcount > 0

    async def create_notification(
        self,
        *,
        customer_id: int,
        type_: NotificationType,
        title: str,
        body: str,
        order_id: int | None = None,
        product_id: int | None = None,
        status_key: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> NotificationOut | None:
        row = self._insert_notification(
            customer_id=customer_id,
            type_=type_,
            title=title,
            body=body,
            order_id=order_id,
            product_id=product_id,
            status_key=status_key,
            metadata=metadata,
        )
        if row is None:
            return None
        notification = self._notification_from_row(row)
        await self._send_fcm(customer_id, notification)
        return notification

    def watch_favorite(self, customer_id: int, product_id: int, in_stock: bool) -> None:
        now = self._now()
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO favorite_watches(customer_id, product_id, last_in_stock,
                                             notified_in_stock, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(customer_id, product_id) DO UPDATE SET
                    updated_at=excluded.updated_at
                """,
                (customer_id, product_id, int(in_stock), int(in_stock), now, now),
            )

    def unwatch_favorite(self, customer_id: int, product_id: int) -> None:
        with self._connect() as conn:
            conn.execute(
                "DELETE FROM favorite_watches WHERE customer_id=? AND product_id=?",
                (customer_id, product_id),
            )

    async def favorite_stock_changed(
        self,
        *,
        product_id: int,
        in_stock: bool,
        product_name: str,
    ) -> int:
        created = 0
        with self._connect() as conn:
            watches = conn.execute(
                "SELECT * FROM favorite_watches WHERE product_id=?",
                (product_id,),
            ).fetchall()

        for watch in watches:
            was_in_stock = bool(watch["last_in_stock"])
            if in_stock and not was_in_stock:
                row = self._insert_notification(
                    customer_id=int(watch["customer_id"]),
                    type_=NotificationType.FAVORITE_BACK_IN_STOCK,
                    title="Produit de nouveau en stock",
                    body=f"{product_name} est disponible.",
                    product_id=product_id,
                    status_key=f"stock-back-{self._now()}",
                    metadata={"route": f"/product/{product_id}"},
                )
                if row:
                    created += 1
                    await self._send_fcm(
                        int(watch["customer_id"]),
                        self._notification_from_row(row),
                    )
            with self._connect() as conn:
                conn.execute(
                    """
                    UPDATE favorite_watches
                    SET last_in_stock=?, notified_in_stock=?, updated_at=?
                    WHERE customer_id=? AND product_id=?
                    """,
                    (
                        int(in_stock),
                        int(in_stock),
                        self._now(),
                        int(watch["customer_id"]),
                        product_id,
                    ),
                )
        return created

    def _insert_notification(
        self,
        *,
        customer_id: int,
        type_: NotificationType,
        title: str,
        body: str,
        order_id: int | None = None,
        product_id: int | None = None,
        status_key: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> sqlite3.Row | None:
        now = self._now()
        with self._connect() as conn:
            try:
                cursor = conn.execute(
                    """
                    INSERT INTO notifications(customer_id, type, title, body,
                                              order_id, product_id, status_key,
                                              metadata, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        customer_id,
                        type_.value,
                        title,
                        body,
                        order_id,
                        product_id,
                        status_key,
                        json.dumps(metadata or {}, ensure_ascii=False),
                        now,
                    ),
                )
            except sqlite3.IntegrityError:
                return None
            return conn.execute(
                "SELECT * FROM notifications WHERE id=?",
                (cursor.lastrowid,),
            ).fetchone()

    async def _send_fcm(self, customer_id: int, notification: NotificationOut) -> None:
        if not self._firebase_ready():
            logger.info("FCM désactivé: Firebase Admin SDK non configuré.")
            return
        with self._connect() as conn:
            tokens = conn.execute(
                "SELECT token FROM device_tokens WHERE customer_id=?",
                (customer_id,),
            ).fetchall()
        if not tokens:
            return

        for row in tokens:
            try:
                messaging.send(
                    messaging.Message(
                        token=row["token"],
                        notification=messaging.Notification(
                            title=notification.title,
                            body=notification.body,
                        ),
                        data={
                            key: str(value)
                            for key, value in notification.metadata.items()
                            if value is not None
                        },
                    )
                )
            except Exception:
                logger.exception("Envoi FCM HTTP v1 impossible.")

    def _firebase_ready(self) -> bool:
        if firebase_admin is None or credentials is None or messaging is None:
            return False
        if firebase_admin._apps:
            return True
        credential_path = self.settings.google_application_credentials
        project_id = self.settings.firebase_project_id
        if not credential_path or not project_id:
            return False
        firebase_admin.initialize_app(
            credentials.Certificate(credential_path),
            {"projectId": project_id},
        )
        return True

    def _notification_from_row(self, row: sqlite3.Row) -> NotificationOut:
        metadata = json.loads(row["metadata"] or "{}")
        metadata.setdefault("customer_id", int(row["customer_id"]))
        return NotificationOut(
            id=int(row["id"]),
            type=NotificationType(row["type"]),
            title=str(row["title"]),
            body=str(row["body"]),
            order_id=row["order_id"],
            product_id=row["product_id"],
            metadata=metadata,
            created_at=str(row["created_at"]),
            read_at=row["read_at"],
        )

    def _now(self) -> str:
        return datetime.now(timezone.utc).isoformat()
