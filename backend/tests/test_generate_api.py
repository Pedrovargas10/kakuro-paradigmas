import pytest
from fastapi.testclient import TestClient

from app import main, prolog
from app.schemas import Puzzle

client = TestClient(main.app, raise_server_exceptions=False)


def test_generate_with_real_prolog_excludes_solution():
    response = client.post("/api/generate", json={})
    assert response.status_code == 200
    body = response.json()
    assert set(body) == {"puzzle"}
    puzzle = Puzzle.model_validate(body["puzzle"])
    assert len(puzzle.cells) == 6
    for row in body["puzzle"]["cells"]:
        assert len(row) == 6
        for cell in row:
            expected = {"kind", "across", "down"} if cell["kind"] == "clue" else {"kind"}
            assert set(cell) == expected


def test_generate_failure_returns_503(monkeypatch):
    monkeypatch.setattr(prolog, "query_prolog", lambda *args: {"truth": False, "Puzzle": None})
    response = client.post("/api/generate", json={})
    assert response.status_code == 503
    assert "10 segundos" in response.json()["detail"]


@pytest.mark.parametrize("payload", [{"seed": 1}, {"solution": []}, [], "puzzle", 1])
def test_generate_rejects_invalid_payload_before_engine(monkeypatch, payload):
    def unexpected_call():
        pytest.fail("Payload inválido chegou ao gerador")

    monkeypatch.setattr(main, "generate_puzzle", unexpected_call)
    response = client.post("/api/generate", json=payload)
    assert response.status_code == 422
    assert isinstance(response.json()["detail"], str)


def test_generate_requires_json_object():
    for options in [{}, {"content": "null", "headers": {"content-type": "application/json"}},
                    {"content": "{", "headers": {"content-type": "application/json"}}]:
        response = client.post("/api/generate", **options)
        assert response.status_code == 422
        assert isinstance(response.json()["detail"], str)


def test_generate_internal_error_does_not_leak_details(monkeypatch):
    def fail():
        raise RuntimeError("private stack trace /srv/secret.pl")

    monkeypatch.setattr(main, "generate_puzzle", fail)
    response = client.post("/api/generate", json={})
    assert response.status_code == 500
    assert response.json() == {"detail": "Erro interno ao processar a requisição."}


def test_invalid_engine_response_is_500_not_422(monkeypatch):
    monkeypatch.setattr(prolog, "query_prolog", lambda *args: {"truth": True, "Puzzle": [["white"]]})
    response = client.post("/api/generate", json={})
    assert response.status_code == 500
    assert response.json() == {"detail": "Erro interno ao processar a requisição."}


def test_generate_openapi_includes_payload_and_errors():
    operation = client.get("/openapi.json").json()["paths"]["/api/generate"]["post"]
    assert operation["requestBody"]["required"] is True
    assert {"200", "422", "503", "500"} <= operation["responses"].keys()
