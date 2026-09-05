from __future__ import annotations

import logging
from time import monotonic

from app.clients.prestashop import PrestaShopClient
from app.services.normalizers import to_int, unwrap_collection

logger = logging.getLogger(__name__)

MOROCCO_CACHE_TTL_SECONDS = 300
_morocco_country_cache: tuple[float, int] | None = None


async def get_morocco_country_id(ps: PrestaShopClient, language_id: int | None = None) -> int:
    """Recupere l'ID du Maroc depuis PrestaShop avec cache memoire partage."""
    global _morocco_country_cache
    now = monotonic()
    if _morocco_country_cache and _morocco_country_cache[0] > now:
        return _morocco_country_cache[1]

    effective_lang = language_id or getattr(getattr(ps, "settings", None), "prestashop_language_id", 3)
    logger.info("Recherche id_country Maroc dans PrestaShop (partagee).")
    payload = await ps.list_resource(
        "countries",
        display="[id,iso_code,active]",
        limit="0,250",
        params={"language": effective_lang},
    )

    for row in unwrap_collection(payload, "countries"):
        country_id = to_int(row.get("id"))
        iso_code = str(row.get("iso_code") or "").strip().upper()
        if country_id and iso_code == "MA":
            logger.info("Maroc identifie : id_country=%s iso_code=%s", country_id, iso_code)
            _morocco_country_cache = (now + MOROCCO_CACHE_TTL_SECONDS, country_id)
            return country_id

    raise RuntimeError("Pays Maroc introuvable dans PrestaShop.")
