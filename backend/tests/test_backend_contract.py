import pytest
from fastapi.testclient import TestClient

from app import main, prolog
from app.schemas import Puzzle

client = TestClient(main.app, raise_server_exceptions=False)


def test_fixed_fixture_check_solve_and_hint(mini_case):
    puzzle = mini_case["puzzle"]
    solution = mini_case["solution"]
    entries = solution[:1]
    solved = client.post("/api/solve", json={"puzzle": puzzle, "entries": entries})
    assert solved.status_code == 200
    assert solved.json() == {"solution": solution}
    for values, expected in [(entries, "incomplete"), (solution, "solved"),
                             ([{"row": 1, "col": 1, "value": 1}], "inconsistent")]:
        response = client.post("/api/check", json={"puzzle": puzzle, "entries": values})
        assert response.status_code == 200
        assert response.json() == {"state": expected}
    hinted = client.post("/api/hint", json={"puzzle": puzzle, "entries": solution[:-1]})
    assert hinted.status_code == 200
    assert hinted.json() == {"kind": "hint", **solution[-1]}


@pytest.mark.parametrize("endpoint", ["check", "solve", "hint"])
@pytest.mark.parametrize("changes", [
    {"entries": None},
    {"entries": [{"row": 1, "col": 1, "value": False}]},
    {"entries": [{"row": 1, "col": 1, "value": "3"}]},
    {"entries": [{"row": 1, "col": 1}]},
    {"unexpected": "field"},
])
def test_shared_contract_rejects_invalid_payloads(endpoint, changes, mini_case):
    response = client.post(f"/api/{endpoint}", json={"puzzle": mini_case["puzzle"], **changes})
    assert response.status_code == 422
    assert set(response.json()) == {"detail"}
    assert isinstance(response.json()["detail"], str)


@pytest.mark.parametrize(
    ("endpoint", "error", "expected_status"),
    [
        ("check", "domain_error(kakuro_entry, 99)", 422),
        ("check", "existence_error(procedure, missing/3)", 500),
        ("generate", "domain_error(kakuro_entry, 99)", 500),
        ("generate", "resource_error(memory)", 500),
    ],
)
def test_real_prolog_errors_have_controlled_http_responses(
    monkeypatch, mini_case, endpoint, error, expected_status
):
    prolog.ensure_prolog_loaded()
    query_once = prolog.janus.query_once

    def raise_prolog_error(goal, params):
        return query_once(f"throw(error({error}, _))")

    monkeypatch.setattr(prolog.janus, "query_once", raise_prolog_error)
    payload = {} if endpoint == "generate" else {"puzzle": mini_case["puzzle"]}
    response = client.post(f"/api/{endpoint}", json=payload)
    assert response.status_code == expected_status
    assert isinstance(response.json()["detail"], str)
    assert error not in response.json()["detail"]
    if expected_status == 500:
        assert response.json() == {"detail": "Erro interno ao processar a requisição."}


def test_real_prolog_time_limit_becomes_http_503(monkeypatch):
    prolog.ensure_prolog_loaded()
    query_once = prolog.janus.query_once

    def slow_generator(goal, params):
        assert "generator:generate(Puzzle)" in goal
        assert params == {"Seconds": 10}
        return query_once(
            "catch(call_with_time_limit(Seconds, (repeat, fail)), time_limit_exceeded, fail)",
            {"Seconds": 0.01},
        )

    monkeypatch.setattr(prolog.janus, "query_once", slow_generator)
    response = client.post("/api/generate", json={})
    assert response.status_code == 503
    assert "10 segundos" in response.json()["detail"]


def test_real_generator_returns_unique_solvable_puzzle():
    response = client.post("/api/generate", json={})
    assert response.status_code == 200
    puzzle = Puzzle.model_validate(response.json()["puzzle"])
    raw = prolog.puzzle_to_prolog(puzzle)
    count = prolog.query_prolog(
        "kakuro:solution_count(Puzzle, Entradas, Count)", {"Puzzle": raw, "Entradas": []}
    )
    assert count["truth"] is True
    assert count["Count"] == 1
    solved = client.post("/api/solve", json={"puzzle": puzzle.model_dump(), "entries": []})
    assert solved.status_code == 200
    solution = solved.json()["solution"]
    playable = {(row, col) for row, cells in enumerate(puzzle.cells)
                for col, cell in enumerate(cells) if cell.kind == "playable"}
    assert {(entry["row"], entry["col"]) for entry in solution} == playable
    checked = client.post("/api/check", json={"puzzle": puzzle.model_dump(), "entries": solution})
    assert checked.status_code == 200
    assert checked.json() == {"state": "solved"}
