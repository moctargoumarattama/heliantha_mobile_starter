import pytest

from app.schemas.product import ProductOut
from app.services.home_slides import HomeSlidesService, PublicSliderParser

pytestmark = pytest.mark.anyio


def test_public_slider_parser_detects_real_slider_images():
    html = """
    <div class="homeslider swiper">
      <a href="/promo"><img data-src="/img/banner.jpg" alt="Promo solaire"></a>
      <div class="slide"><img srcset="/img/banner-2.jpg 800w" title="Batteries"></div>
    </div>
    """

    parser = PublicSliderParser("https://heliantha.ma/")
    parser.feed(html)
    slides = parser.slides()

    assert len(slides) == 2
    assert slides[0].type == "banner"
    assert slides[0].image_url == "https://heliantha.ma/img/banner.jpg"
    assert slides[0].target_url == "https://heliantha.ma/promo"
    assert slides[1].image_url == "https://heliantha.ma/img/banner-2.jpg"


class FakeCatalog:
    async def products(self, *, page, page_size, language_id):
        return [
            ProductOut(
                id=339,
                name="Panneau Solaire JA Solar 715W",
                price=1200,
                currency="MAD",
                currency_symbol="MAD",
                currency_id=2,
                available=True,
                image_url="/v1/products/339/image?image_id=1",
            ),
            ProductOut(
                id=340,
                name="Batterie solaire",
                price=11500,
                currency="MAD",
                currency_symbol="MAD",
                currency_id=2,
                available=True,
                image_url="/v1/products/340/image?image_id=2",
            ),
        ], {"returned": 2}


async def test_product_fallback_builds_product_slides():
    HomeSlidesService._fallback_cache = None
    service = HomeSlidesService(FakeCatalog())

    slides = await service._product_fallback()

    assert len(slides) == 2
    assert slides[0].id == "product-339"
    assert slides[0].type == "product"
    assert slides[0].product_id == 339
    assert slides[0].subtitle == "1 200 MAD"


async def test_slides_falls_back_to_products_when_public_banners_fail():
    HomeSlidesService._banner_cache = None
    HomeSlidesService._fallback_cache = None

    class FailingBannerService(HomeSlidesService):
        async def _public_banners(self):
            return []

    service = FailingBannerService(FakeCatalog())

    slides = await service.slides()

    assert len(slides) == 2
    assert all(slide.type == "product" for slide in slides)
