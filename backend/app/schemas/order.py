from pydantic import BaseModel, EmailStr, Field


class OrderLineIn(BaseModel):
    product_id: int
    product_attribute_id: int = 0
    quantity: int = Field(ge=1)


class GuestCustomerIn(BaseModel):
    email: EmailStr
    firstname: str
    lastname: str
    phone: str | None = None


class AddressIn(BaseModel):
    address1: str
    address2: str | None = None
    postcode: str | None = None
    city: str
    country_id: int
    phone: str | None = None


class CreateOrderIn(BaseModel):
    lines: list[OrderLineIn]
    payment_method: str
    customer: GuestCustomerIn | None = None
    delivery_address: AddressIn | None = None
    note: str | None = None


class OrderOut(BaseModel):
    id: int
    reference: str
    total_paid: float = 0.0
    state_id: int | None = None
    state_name: str | None = None
    date_add: str | None = None
