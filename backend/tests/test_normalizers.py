from app.services.normalizers import localized, to_bool, to_float, to_int


def test_localized_list():
    value = [
        {"id": "1", "value": "Bonjour"},
        {"id": "2", "value": "Hello"},
    ]
    assert localized(value, 1) == "Bonjour"


def test_casts():
    assert to_int("12") == 12
    assert to_float("24.5") == 24.5
    assert to_bool("1") is True
