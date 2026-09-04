from pydantic import BaseModel, Field


class CategoryOut(BaseModel):
    id: int
    name: str
    active: bool = True


class ProductFeatureOut(BaseModel):
    name: str
    value: str


class ProductOut(BaseModel):
    id: int
    name: str
    reference: str | None = None
    price: float = 0.0
    currency: str = "MAD"
    currency_symbol: str = "MAD"
    currency_id: int | None = None
    available: bool = True
    quantity: int | None = None
    description_short: str | None = None
    description: str | None = None
    category_id: int | None = None
    image_url: str | None = None
    features: list[ProductFeatureOut] = Field(default_factory=list)
