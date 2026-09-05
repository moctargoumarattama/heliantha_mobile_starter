# Longueur max PrestaShop pour les champs adresse (128 caractères).
# Pas de regex : on laisse PrestaShop faire sa propre validation de format.
_ADDRESS_MAX_LEN = 128
_ADDRESS_MIN_LEN = 3

from typing import Annotated

from pydantic import BaseModel, field_validator


def _validate_address_field(value: str, field_name: str = "Adresse") -> str:
    """Validation tolérante : trim + longueur min/max uniquement."""
    cleaned = value.strip()
    if not cleaned:
        raise ValueError(f"{field_name} obligatoire.")
    if len(cleaned) < _ADDRESS_MIN_LEN:
        raise ValueError(
            f"{field_name} trop courte (minimum {_ADDRESS_MIN_LEN} caractères)."
        )
    if len(cleaned) > _ADDRESS_MAX_LEN:
        raise ValueError(
            f"{field_name} trop longue (maximum {_ADDRESS_MAX_LEN} caractères)."
        )
    return cleaned


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


class AddressIn(BaseModel):
    alias: str
    firstname: str | None = None
    lastname: str | None = None
    company: str | None = None
    address1: str
    address2: str | None = None
    postcode: str | None = None
    city: str
    country_id: int | None = None
    state_id: int | None = None
    phone: str | None = None
    phone_mobile: str | None = None

    @field_validator("address1", mode="before")
    @classmethod
    def validate_address1(cls, v: object) -> str:
        return _validate_address_field(str(v or ""), "Adresse (ligne 1)")

    @field_validator("address2", mode="before")
    @classmethod
    def validate_address2(cls, v: object) -> str | None:
        if v is None:
            return None
        cleaned = str(v).strip()
        if not cleaned:
            return None
        if len(cleaned) > _ADDRESS_MAX_LEN:
            raise ValueError(
                f"Complément d'adresse trop long (maximum {_ADDRESS_MAX_LEN} caractères)."
            )
        return cleaned


class CountryOut(BaseModel):
    id: int
    name: str
