import pytest

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
