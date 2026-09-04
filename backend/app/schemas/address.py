from pydantic import BaseModel


class AddressOut(BaseModel):
    id: int
    alias: str | None = None
    firstname: str | None = None
    lastname: str | None = None
    company: str | None = None
    address1: str
    address2: str | None = None
    postcode: str | None = None
    city: str
    country: str | None = None
    country_id: int | None = None
    state_id: int | None = None
    phone: str | None = None
    phone_mobile: str | None = None
