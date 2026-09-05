"""
Protection brute force en mémoire (par processus).

Conçu pour un déploiement mono-instance léger sans dépendance externe (comme Redis).
Limite les tentatives échouées de connexion par adresse IP pour protéger les comptes.
"""

from __future__ import annotations

import logging
import threading
from dataclasses import dataclass
from time import monotonic
from typing import Dict


logger = logging.getLogger(__name__)


@dataclass
class FailedAttemptRecord:
    count: int = 0
    first_failure_time: float = 0.0
    last_failure_time: float = 0.0
    blocked_until: float = 0.0


class LoginRateLimiter:
    """
    Limiteur de tentatives de login échouées.

    Règles :
    - 5 tentatives échouées par fenêtre glissante (60 secondes par défaut).
    - Dès que le seuil de 5 échecs est atteint, l'IP est bloquée pour 60 secondes.
    - Lors du blocage, HTTP 429 Too Many Requests est renvoyé avec l'en-tête Retry-After.
    - Une connexion réussie réinitialise immédiatement le compteur pour cette IP.
    - Les requêtes réussies ne sont jamais pénalisées.
    - La mémoire est bornée (max_entries) avec un nettoyage périodique automatique.
    """

    def __init__(
        self,
        max_attempts: int = 5,
        window_seconds: float = 60.0,
        block_duration_seconds: float = 60.0,
        max_entries: int = 10000,
    ):
        self.max_attempts = max_attempts
        self.window_seconds = window_seconds
        self.block_duration_seconds = block_duration_seconds
        self.max_entries = max_entries
        self._records: Dict[str, FailedAttemptRecord] = {}
        self._lock = threading.Lock()
        self._last_cleanup = monotonic()

    def _cleanup_unlocked(self, now: float) -> None:
        """Nettoie les entrées expirées pour borner l'empreinte mémoire."""
        if len(self._records) < self.max_entries and (now - self._last_cleanup) < 60.0:
            return

        self._last_cleanup = now
        expired_keys = [
            k
            for k, rec in self._records.items()
            if now > rec.blocked_until and (now - rec.last_failure_time) > self.window_seconds
        ]
        for k in expired_keys:
            self._records.pop(k, None)

        # Si le dictionnaire dépasse toujours max_entries, éviction LRU
        if len(self._records) > self.max_entries:
            sorted_keys = sorted(
                self._records.keys(),
                key=lambda k: self._records[k].last_failure_time,
            )
            for k in sorted_keys[: len(self._records) - self.max_entries]:
                self._records.pop(k, None)

    def is_blocked(self, key: str) -> tuple[bool, int]:
        """
        Vérifie si la clé (ex: IP) est actuellement bloquée.
        Retourne (est_bloque, retry_after_secondes).
        """
        now = monotonic()
        with self._lock:
            self._cleanup_unlocked(now)
            rec = self._records.get(key)
            if not rec:
                return False, 0
            if now < rec.blocked_until:
                retry_after = max(1, int(rec.blocked_until - now) + 1)
                return True, retry_after
            return False, 0

    def record_failure(self, key: str) -> tuple[bool, int]:
        """
        Enregistre un échec d'authentification.
        Retourne (est_bloque_maintenant, retry_after_secondes).
        """
        now = monotonic()
        with self._lock:
            self._cleanup_unlocked(now)
            rec = self._records.get(key)

            if not rec or (now - rec.last_failure_time) > self.window_seconds:
                # Nouvelle fenêtre pour cette clé
                rec = FailedAttemptRecord(
                    count=1,
                    first_failure_time=now,
                    last_failure_time=now,
                    blocked_until=0.0,
                )
                self._records[key] = rec
                return False, 0

            rec.count += 1
            rec.last_failure_time = now

            if rec.count >= self.max_attempts:
                rec.blocked_until = now + self.block_duration_seconds
                retry_after = int(self.block_duration_seconds)
                logger.warning(
                    "Rate limit login déclenché pour clé=%s (%d échecs, blocage=%ds)",
                    key,
                    rec.count,
                    retry_after,
                )
                return True, retry_after

            return False, 0

    def record_success(self, key: str) -> None:
        """Réinitialise les échecs après une connexion réussie."""
        with self._lock:
            self._records.pop(key, None)

    def reset(self) -> None:
        """Réinitialise tout l'état (utile pour les tests)."""
        with self._lock:
            self._records.clear()


# Instance singleton partagée pour le processus FastAPI
login_rate_limiter = LoginRateLimiter(
    max_attempts=5,
    window_seconds=60.0,
    block_duration_seconds=60.0,
)

