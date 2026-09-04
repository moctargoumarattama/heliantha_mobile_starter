from __future__ import annotations

from html.parser import HTMLParser
from time import monotonic
from typing import Any
from urllib.parse import urljoin

import httpx

from app.schemas.home import HomeSlideOut
from app.services.catalog import CatalogService


BANNER_CACHE_TTL_SECONDS = 300
PRODUCT_FALLBACK_CACHE_TTL_SECONDS = 60
PUBLIC_HOME_TIMEOUT_SECONDS = 1.2
PUBLIC_HOME_URL = "https://heliantha.ma/"
SLIDER_HINTS = (
    "carousel",
    "slider",
    "homeslider",
    "ps_imageslider",
    "swiper",
    "slide",
)


class HomeSlidesService:
    _banner_cache: tuple[float, list[HomeSlideOut]] | None = None
    _fallback_cache: tuple[float, list[HomeSlideOut]] | None = None

    def __init__(
        self,
        catalog: CatalogService,
    ):
        self.catalog = catalog

    async def slides(self) -> list[HomeSlideOut]:
        cached_banners = self._read_cache(self.__class__._banner_cache)

        if cached_banners:
            return cached_banners

        cached_fallback = self._read_cache(self.__class__._fallback_cache)

        if cached_fallback:
            return cached_fallback

        banners = await self._public_banners()

        if banners:
            self.__class__._banner_cache = (
                monotonic() + BANNER_CACHE_TTL_SECONDS,
                banners,
            )
            return banners

        fallback = await self._product_fallback()
        self.__class__._fallback_cache = (
            monotonic() + PRODUCT_FALLBACK_CACHE_TTL_SECONDS,
            fallback,
        )
        return fallback

    def _read_cache(
        self,
        cached: tuple[float, list[HomeSlideOut]] | None,
    ) -> list[HomeSlideOut] | None:
        if cached and cached[0] > monotonic() and cached[1]:
            return list(cached[1])

        return None

    async def _public_banners(self) -> list[HomeSlideOut]:
        try:
            async with httpx.AsyncClient(
                timeout=PUBLIC_HOME_TIMEOUT_SECONDS,
                follow_redirects=True,
            ) as client:
                response = await client.get(PUBLIC_HOME_URL)
            response.raise_for_status()
        except Exception:
            return []

        parser = PublicSliderParser(PUBLIC_HOME_URL)
        parser.feed(response.text)
        return parser.slides()

    async def _product_fallback(self) -> list[HomeSlideOut]:
        products, _ = await self.catalog.products(
            page=1,
            page_size=8,
            language_id=3,
        )

        slides: list[HomeSlideOut] = []

        for product in products:
            if not product.image_url:
                continue

            subtitle = f"{product.price:,.0f} {product.currency_symbol}"
            subtitle = subtitle.replace(",", " ")

            slides.append(
                HomeSlideOut(
                    id=f"product-{product.id}",
                    type="product",
                    image_url=product.image_url,
                    title=product.name,
                    subtitle=subtitle,
                    product_id=product.id,
                    target_url=None,
                    position=len(slides) + 1,
                )
            )

            if len(slides) >= 8:
                break

        return slides


class PublicSliderParser(HTMLParser):
    def __init__(self, base_url: str):
        super().__init__(convert_charrefs=True)
        self.base_url = base_url
        self._stack: list[bool] = []
        self._candidates: list[dict[str, Any]] = []
        self._link_stack: list[str | None] = []

    def handle_starttag(
        self,
        tag: str,
        attrs: list[tuple[str, str | None]],
    ) -> None:
        values = {
            key.lower(): value or ""
            for key, value in attrs
        }
        joined = " ".join(
            [
                values.get("class", ""),
                values.get("id", ""),
                values.get("data-swiper-slide-index", ""),
            ]
        ).lower()
        parent_slider = self._stack[-1] if self._stack else False
        current_slider = parent_slider or any(
            hint in joined
            for hint in SLIDER_HINTS
        )
        self._stack.append(current_slider)

        if tag == "a":
            href = values.get("href")
            self._link_stack.append(
                urljoin(self.base_url, href)
                if href
                else None
            )

        if tag not in {"img", "source"} or not current_slider:
            return

        image_url = self._image_url(values)

        if not image_url:
            return

        self._candidates.append(
            {
                "image_url": urljoin(self.base_url, image_url),
                "target_url": self._link_stack[-1] if self._link_stack else None,
                "title": values.get("alt") or values.get("title") or None,
            }
        )

    def handle_endtag(self, tag: str) -> None:
        if self._stack:
            self._stack.pop()
        if tag == "a" and self._link_stack:
            self._link_stack.pop()

    def _image_url(
        self,
        attrs: dict[str, str],
    ) -> str | None:
        for key in ("data-src", "data-lazy", "data-original", "src"):
            value = attrs.get(key, "").strip()
            if value and not value.startswith("data:"):
                return value

        srcset = attrs.get("srcset", "").strip()

        if srcset:
            return srcset.split(",")[0].strip().split(" ")[0]

        return None

    def slides(self) -> list[HomeSlideOut]:
        slides: list[HomeSlideOut] = []
        seen: set[str] = set()

        for candidate in self._candidates:
            image_url = candidate["image_url"]

            if image_url in seen:
                continue

            seen.add(image_url)
            slides.append(
                HomeSlideOut(
                    id=f"banner-{len(slides) + 1}",
                    type="banner",
                    image_url=image_url,
                    title=candidate["title"],
                    subtitle=None,
                    product_id=None,
                    target_url=candidate["target_url"],
                    position=len(slides) + 1,
                )
            )

        return slides
