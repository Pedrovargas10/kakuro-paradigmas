import pytest
from fastapi.testclient import TestClient

from app import main, prolog
from test_api import make_mini_puzzle_payload

client = TestClient(main.app, raise_server_exceptions=False)


@pytest.mark.parametrize(
    ("entries", "expected"),
    [
        ([], "incomplete"),
        ([{"row": 1, "col": 1, "value": 3}], "incomplete"),
        ([{"row": 1, "col": 1, "value": 9}], "inconsistent"),
        ([
            {"row": 1, "col": 1, "value": 3},
            {"row": 1, "col": 2, "value": 4},
            {"row": 2, "col": 1, "value": 1},
            {"row": 2, "col": 2, "value": 2},
        ], "solved"),
    ],
)
def test_check_real_prolog(entries, expected):
    response = client.post(
        "/api/check", json={"puzzle": make_mini_puzzle_payload(), "entries": entries}
    )
    assert response.status_code == 200
    assert response.json() == {"state": expected}


@pytest.mark.parametrize("entry", [
    {"row": 0, "col": 0, "value": 1},
    {"row": 0, "col": 1, "value": 1},
    {"row": 6, "col": 1, "value": 1},
    {"row": 1, "col": -1, "value": 1},
    {"row": True, "col": 1, "value": 3},
    {"row": 1, "col": "1", "value": 3},
    {"row": 1, "col": 1, "value": 3.0},
    {"row": 1, "col": 1, "value": 0},
    {"row": 1, "col": 1, "value": 10},
])
def test_invalid_entries_do_not_reach_engine(monkeypatch, entry):
    def unexpected_call(*args):
        pytest.fail("Entrada inválida chegou ao motor Prolog")

    monkeypatch.setattr(main, "check_puzzle", unexpected_call)
    response = client.post(
        "/api/check", json={"puzzle": make_mini_puzzle_payload(), "entries": [entry]}
    )
    assert response.status_code == 422
    assert isinstance(response.json()["detail"], str)


def test_duplicate_entries_are_rejected():
    entry = {"row": 1, "col": 1, "value": 3}
    response = client.post(
        "/api/check", json={"puzzle": make_mini_puzzle_payload(), "entries": [entry, entry]}
    )
    assert response.status_code == 422
    assert "duplicada" in response.json()["detail"]


def test_unexpected_engine_state_is_controlled(monkeypatch):
    monkeypatch.setattr(prolog, "query_prolog", lambda *args: {"truth": True, "Estado": "private"})
    response = client.post("/api/check", json={"puzzle": make_mini_puzzle_payload()})
    assert response.status_code == 500
    assert response.json() == {"detail": "Erro interno ao processar a requisição."}


def test_check_is_documented_in_openapi():
    schema = client.get("/openapi.json").json()
    operation = schema["paths"]["/api/check"]["post"]
    assert {"200", "422", "500"} <= operation["responses"].keys()
