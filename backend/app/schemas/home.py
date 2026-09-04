from pydantic import BaseModel


class HomeSlideOut(BaseModel):
    id: str
    type: str
    image_url: str
    title: str | None = None
    subtitle: str | None = None
    product_id: int | None = None
    target_url: str | None = None
    position: int = 1
