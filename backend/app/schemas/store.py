from pydantic import BaseModel


class LanguageOut(BaseModel):
    id: int
    name: str
    iso_code: str | None = None
    locale: str | None = None
    language_code: str | None = None
    active: bool = True
    is_rtl: bool = False


class CurrencyOut(BaseModel):
    id: int
    name: str
    iso_code: str
    symbol: str
    precision: int = 2
    conversion_rate: float = 1.0
    active: bool = True


class StoreContextOut(BaseModel):
    language: dict
    currency: dict
