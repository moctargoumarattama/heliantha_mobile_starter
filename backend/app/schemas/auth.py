from pydantic import BaseModel, EmailStr


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class RegisterIn(BaseModel):
    firstname: str
    lastname: str
    email: EmailStr
    password: str


class CustomerOut(BaseModel):
    id: int
    email: EmailStr
    firstname: str = ""
    lastname: str = ""


class LoginOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    customer: CustomerOut
