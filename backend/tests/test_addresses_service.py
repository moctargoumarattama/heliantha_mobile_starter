import pytest
from pydantic import ValidationError

from app.clients.bridge import BridgeHTTPError
from app.schemas.address import AddressIn
from app.services.addresses import AddressesService



pytestmark = pytest.mark.anyio


class DummySettings:
    prestashop_language_id = 3


class FakePrestaShopClient:
    def __init__(self, addresses):
        self.settings = DummySettings()
        self.addresses = addresses
        self.calls = []

    async def list_resource(
        self,
        resource,
        *,
        display=None,
        filters=None,
        limit=None,
        sort=None,
        params=None,
    ):
        self.calls.append(
            {
                "resource": resource,
                "display": display,
                "filters": filters or {},
                "limit": limit,
                "params": params or {},
            }
        )
        if resource == "addresses":
            customer_filter = (filters or {}).get("id_customer", "")
            customer_id = int(customer_filter.strip("[]"))
            return {
                "addresses": [
                    row
                    for row in self.addresses
                    if int(row["id_customer"]) == customer_id
                ]
            }
        if resource == "countries":
            return {
                "countries": [
                    {
                        "id": "143",
                        "iso_code": "MA",
                        "name": {
                            "language": [
                                {"id": "3", "value": "Maroc"},
                            ]
                        },
                    }
                ]
            }
        return {}



def clear_addresses_cache():
    AddressesService._country_cache = {}


async def test_addresses_are_filtered_for_connected_customer():
    clear_addresses_cache()
    ps = FakePrestaShopClient(
        [
            {
                "id": "15",
                "id_customer": "71",
                "alias": "Maison",
                "firstname": "Ali",
                "lastname": "Client",
                "address1": "Rue 1",
                "city": "Casablanca",
                "id_country": "143",
                "active": "1",
                "deleted": "0",
            },
            {
                "id": "16",
                "id_customer": "72",
                "alias": "Autre",
                "address1": "Rue 2",
                "city": "Rabat",
                "id_country": "143",
                "active": "1",
                "deleted": "0",
            },
            {
                "id": "17",
                "id_customer": "71",
                "alias": "Supprimée",
                "address1": "Rue 3",
                "city": "Rabat",
                "id_country": "143",
                "active": "1",
                "deleted": "1",
            },
        ]
    )

    rows = await AddressesService(ps).list_for_customer(71)

    assert [row.id for row in rows] == [15]
    assert rows[0].country == "Maroc"
    assert ps.calls[0]["resource"] == "addresses"
    assert ps.calls[0]["filters"] == {"id_customer": "[71]"}
    assert len([call for call in ps.calls if call["resource"] == "countries"]) == 1


async def test_no_addresses_returns_empty_list():
    clear_addresses_cache()
    ps = FakePrestaShopClient([])

    rows = await AddressesService(ps).list_for_customer(71)

    assert rows == []
    assert len(ps.calls) == 1


# ---------------------------------------------------------------------------
# Tests de validation tolérante : formats d'adresses marocaines réels
# ---------------------------------------------------------------------------

VALID_MOROCCAN_ADDRESSES = [
    "RTE KENITRA RESIDENCE MHADRA",
    "LOT 12 IMM B APPT 4",
    "KM 7 ROUTE DE CASA",
    "HAY ENNAHDA N° 18",
    "RUE 12 BIS",
    "DOUAR OULAD ZIANE",
    "BP 123",
    # Formats avec caractères spéciaux acceptés
    "RUE DE L'ATLAS",
    "QUARTIER AL-WAHDA",
    "N°5, RUE HASSAN II",
    "RÉSIDENCE LES ORANGERS / BLOC A",
    "IMM. SAFAE, APPT (3ÈME ÉTAGE)",
    "HAY MOHAMMADI #12",
    "2ème Rue, Cité OCP",
    "Rue Abou Bakr Saddiq — Agdal",
]


@pytest.mark.parametrize("address_value", VALID_MOROCCAN_ADDRESSES)
def test_address1_accepts_moroccan_formats(address_value: str):
    """Aucun format d'adresse marocain courant ne doit être refusé."""
    data = AddressIn(
        alias="Test",
        address1=address_value,
        city="Casablanca",
    )
    assert data.address1 == address_value.strip()


def test_address1_accepts_with_leading_trailing_spaces():
    """Les espaces début/fin doivent être nettoyés, l'adresse acceptée."""
    data = AddressIn(
        alias="Test",
        address1="  RTE KENITRA RESIDENCE MHADRA  ",
        city="Rabat",
    )
    assert data.address1 == "RTE KENITRA RESIDENCE MHADRA"


def test_address1_required_rejects_empty():
    """address1 vide doit être refusé."""
    with pytest.raises(ValidationError) as exc_info:
        AddressIn(alias="Test", address1="", city="Casablanca")
    errors = exc_info.value.errors()
    assert any("address1" in str(e["loc"]) for e in errors)


def test_address1_required_rejects_whitespace_only():
    """address1 uniquement composé d'espaces doit être refusé."""
    with pytest.raises(ValidationError):
        AddressIn(alias="Test", address1="   ", city="Casablanca")


def test_address1_rejects_too_long():
    """address1 > 128 caractères doit être refusé."""
    long_address = "A" * 129
    with pytest.raises(ValidationError) as exc_info:
        AddressIn(alias="Test", address1=long_address, city="Casablanca")
    errors = exc_info.value.errors()
    assert any("address1" in str(e["loc"]) for e in errors)


def test_address2_is_optional():
    """address2 absent ou vide doit être accepté."""
    data_none = AddressIn(alias="Test", address1="RUE 12 BIS", city="Rabat")
    assert data_none.address2 is None

    data_empty = AddressIn(
        alias="Test", address1="RUE 12 BIS", address2="", city="Rabat"
    )
    assert data_empty.address2 is None


def test_address2_accepts_complement():
    """address2 avec complément d'adresse valide doit être accepté."""
    data = AddressIn(
        alias="Test",
        address1="LOT 12 IMM B",
        address2="APPT 4 ÉTAGE 3",
        city="Casablanca",
    )
    assert data.address2 == "APPT 4 ÉTAGE 3"


def test_address2_rejects_too_long():
    """address2 > 128 caractères doit être refusé."""
    with pytest.raises(ValidationError):
        AddressIn(
            alias="Test",
            address1="RUE 12 BIS",
            address2="B" * 129,
            city="Casablanca",
        )


class FakeBridgeClient:
    def __init__(self, return_id: int = 42):
        self.calls = []
        self.return_id = return_id

    async def post(self, endpoint: str, payload: dict):
        self.calls.append({"endpoint": endpoint, "payload": payload})
        return {"success": True, "data": {"id": self.return_id}}


async def test_create_address_returns_directly_without_secondary_lookup():
    """La création réussie ne doit pas dépendre d'une relecture fragile dans /addresses."""
    clear_addresses_cache()
    ps = FakePrestaShopClient([])
    bridge = FakeBridgeClient(return_id=99)

    service = AddressesService(ps, bridge)
    payload = AddressIn(
        alias="Bureau",
        address1="KM 7 ROUTE DE CASA",
        city="Casablanca",
        phone="0611223344",
    )

    created = await service.create(71, payload)

    assert created.id == 99
    assert created.alias == "Bureau"
    assert created.address1 == "KM 7 ROUTE DE CASA"
    assert created.city == "Casablanca"
    assert created.country == "Maroc"
    assert created.country_id == 143
    assert len(bridge.calls) == 1
    # Vérifier qu'il n'y a eu que l'appel de pré-vérification anti-doublon, aucune relecture secondaire
    assert len([call for call in ps.calls if call["resource"] == "addresses"]) == 1


async def test_update_address_returns_directly_without_secondary_lookup():
    """La modification réussie ne doit pas dépendre d'une relecture fragile dans /addresses."""
    clear_addresses_cache()
    ps = FakePrestaShopClient([])
    bridge = FakeBridgeClient(return_id=99)

    service = AddressesService(ps, bridge)
    payload = AddressIn(
        alias="Maison modifiée",
        address1="LOT 12 IMM B APPT 4",
        city="Rabat",
    )

    updated = await service.update(71, 99, payload)

    assert updated.id == 99
    assert updated.alias == "Maison modifiée"
    assert updated.address1 == "LOT 12 IMM B APPT 4"
    assert updated.city == "Rabat"
    assert updated.country == "Maroc"
    assert len(bridge.calls) == 1
    assert bridge.calls[0]["endpoint"] == "addresses?action=update"
    assert not any(call["resource"] == "addresses" for call in ps.calls)


async def test_client_cannot_create_more_than_one_address():
    """
    Test complet du cycle anti-doublon :
    1. Client sans adresse -> POST -> succès -> 1 adresse
    2. Même client -> deuxième POST -> 409 (Une adresse existe déjà...) -> toujours 1 seule adresse
    3. PUT adresse existante -> succès -> toujours 1 seule adresse
    """
    clear_addresses_cache()
    ps = FakePrestaShopClient([])
    bridge = FakeBridgeClient(return_id=99)
    service = AddressesService(ps, bridge)

    payload1 = AddressIn(
        alias="Maison",
        address1="RUE 12 BIS",
        city="Casablanca",
        phone="0611223344",
    )

    # 1. Première création -> succès -> 1 adresse
    created = await service.create(71, payload1)
    assert created.id == 99
    assert created.address1 == "RUE 12 BIS"

    # Simuler la présence de cette adresse dans PrestaShop pour les prochains appels
    ps.addresses.append({
        "id": "99",
        "id_customer": "71",
        "alias": created.alias,
        "address1": created.address1,
        "city": created.city,
        "id_country": "143",
        "deleted": "0",
    })

    addresses_step1 = await service.list_for_customer(71)
    assert len(addresses_step1) == 1

    # 2. Deuxième création pour le même client -> 409 Conflict
    payload2 = AddressIn(
        alias="Deuxième adresse",
        address1="LOT 12 IMM B APPT 4",
        city="Rabat",
    )
    with pytest.raises(BridgeHTTPError) as exc_info:
        await service.create(71, payload2)

    assert exc_info.value.status_code == 409
    assert "Une adresse existe déjà. Modifiez l'adresse existante." in exc_info.value.detail

    # Vérifier qu'il y a toujours 1 seule adresse
    addresses_step2 = await service.list_for_customer(71)
    assert len(addresses_step2) == 1
    assert addresses_step2[0].id == 99

    # 3. PUT modification de l'adresse existante -> succès
    payload_update = AddressIn(
        alias="Maison Modifiée",
        address1="KM 7 ROUTE DE CASA",
        city="Casablanca",
    )
    updated = await service.update(71, 99, payload_update)
    assert updated.id == 99
    assert updated.alias == "Maison Modifiée"
    assert updated.address1 == "KM 7 ROUTE DE CASA"

    # Mettre à jour dans le mock et revérifier qu'il y a toujours 1 seule adresse
    ps.addresses[0]["alias"] = updated.alias
    ps.addresses[0]["address1"] = updated.address1
    addresses_step3 = await service.list_for_customer(71)
    assert len(addresses_step3) == 1
    assert addresses_step3[0].address1 == "KM 7 ROUTE DE CASA"



