"""Testes da API FastAPI, validações estritas de contrato e ponte Prolog (rotas solve e hint)."""

from copy import deepcopy
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app import main as main_module
from app import prolog as prolog_module
from app.schemas import (
    BlockCell,
    ClueCell,
    Entry,
    HintStatusResponse,
    HintValueResponse,
    PlayableCell,
    Puzzle,
)

client = TestClient(main_module.app, raise_server_exceptions=False)


class FakePrologError(prolog_module.janus.PrologError):
    """Simula `janus.PrologError` com mensagem arbitrária em testes unitários."""

    def __init__(self, message: str) -> None:
        Exception.__init__(self, message)
        self._message = message

    def __str__(self) -> str:
        return self._message


def make_mini_puzzle_payload() -> dict[str, Any]:
    """Retorna o tabuleiro 6x6 `puzzle_mini` no formato JSON do contrato."""
    b = {"kind": "block"}
    w = {"kind": "playable"}
    return {
        "cells": [
            [
                b,
                {"kind": "clue", "across": None, "down": 4},
                {"kind": "clue", "across": None, "down": 6},
                b,
                b,
                b,
            ],
            [{"kind": "clue", "across": 7, "down": None}, w, w, b, b, b],
            [{"kind": "clue", "across": 3, "down": None}, w, w, b, b, b],
            [b, b, b, b, b, b],
            [b, b, b, b, b, b],
            [b, b, b, b, b, b],
        ]
    }


@pytest.mark.parametrize("endpoint", ["/api/solve", "/api/hint"])
def test_validation_errors_return_422_with_string_detail(endpoint: str) -> None:
    """Rejeita entradas e tipos inválidos sem coerção silenciosa."""
    base_puzzle = make_mini_puzzle_payload()

    clue_with_str = make_mini_puzzle_payload()
    clue_with_str["cells"][1][0] = {"kind": "clue", "across": "7", "down": None}

    clue_with_bool = make_mini_puzzle_payload()
    clue_with_bool["cells"][0][1] = {"kind": "clue", "across": None, "down": True}

    invalid_payloads = [
        {"puzzle": base_puzzle, "entries": [{"row": 6, "col": 1, "value": 3}]},
        {"puzzle": base_puzzle, "entries": [{"row": -1, "col": 1, "value": 3}]},
        {"puzzle": base_puzzle, "entries": [{"row": 1, "col": 1, "value": 0}]},
        {"puzzle": base_puzzle, "entries": [{"row": 1, "col": 1, "value": 10}]},
        # Rejeição de tipos não inteiros estritos (sem coerção automática)
        {"puzzle": base_puzzle, "entries": [{"row": 1, "col": 1, "value": "7"}]},
        {"puzzle": base_puzzle, "entries": [{"row": "1", "col": 1, "value": 3}]},
        {"puzzle": base_puzzle, "entries": [{"row": 1, "col": 1, "value": True}]},
        {"puzzle": clue_with_str, "entries": []},
        {"puzzle": clue_with_bool, "entries": []},
        {
            "puzzle": base_puzzle,
            "entries": [
                {"row": 1, "col": 1, "value": 3},
                {"row": 1, "col": 1, "value": 4},
            ],
        },
        {"puzzle": base_puzzle, "entries": [{"row": 0, "col": 0, "value": 1}]},
        {"puzzle": base_puzzle, "entries": [{"row": 0, "col": 1, "value": 2}]},
        {"puzzle": {"cells": base_puzzle["cells"][:5]}, "entries": []},
    ]

    for payload in invalid_payloads:
        response = client.post(endpoint, json=payload)
        assert response.status_code == 422
        body = response.json()
        assert isinstance(body["detail"], str)
        assert len(body["detail"]) > 0


def test_clue_and_grid_structural_validation() -> None:
    """Valida pistas inválidas e tabuleiro sem casas jogáveis nos schemas."""
    with pytest.raises(ValueError):
        ClueCell(across=None, down=None)

    with pytest.raises(ValueError):
        ClueCell(across=0, down=None)

    only_blocks = [[{"kind": "block"} for _ in range(6)] for _ in range(6)]
    with pytest.raises(ValueError):
        Puzzle.model_validate({"cells": only_blocks})


def test_prolog_converters_for_solve() -> None:
    """Confere conversões de células, tabuleiro e entradas para o formato Prolog."""
    assert prolog_module.cell_to_prolog(BlockCell()) == "block"
    assert prolog_module.cell_to_prolog(PlayableCell()) == "white"
    assert prolog_module.cell_to_prolog(ClueCell(across=7, down=None)) == [7, 0]

    puzzle = Puzzle.model_validate(make_mini_puzzle_payload())
    prolog_grid = prolog_module.puzzle_to_prolog(puzzle)

    assert prolog_grid[0][0] == "block"
    assert prolog_grid[0][1] == [0, 4]
    assert prolog_grid[1][0] == [7, 0]
    assert prolog_grid[1][1] == "white"

    entries = [Entry(row=1, col=1, value=3), Entry(row=2, col=2, value=2)]
    raw_entries = prolog_module.entries_to_prolog(entries)
    assert raw_entries == [[1, 1, 3], [2, 2, 2]]
    assert prolog_module.prolog_to_entries(raw_entries) == entries


def test_solve_endpoint_unit(monkeypatch: pytest.MonkeyPatch) -> None:
    """Testa `/api/solve` em caso de sucesso e ausência de solução (422)."""
    payload = {
        "puzzle": make_mini_puzzle_payload(),
        "entries": [{"row": 1, "col": 1, "value": 3}],
    }
    expected_solution = [
        Entry(row=1, col=1, value=3),
        Entry(row=1, col=2, value=4),
        Entry(row=2, col=1, value=1),
        Entry(row=2, col=2, value=2),
    ]

    monkeypatch.setattr(
        main_module, "solve_puzzle", lambda puzzle, entries: expected_solution
    )
    ok_res = client.post("/api/solve", json=payload)
    assert ok_res.status_code == 200
    assert ok_res.json() == {
        "solution": [entry.model_dump() for entry in expected_solution]
    }

    monkeypatch.setattr(main_module, "solve_puzzle", lambda puzzle, entries: None)
    no_sol_res = client.post("/api/solve", json=payload)
    assert no_sol_res.status_code == 422
    assert isinstance(no_sol_res.json()["detail"], str)


@pytest.mark.parametrize("endpoint", ["/api/solve", "/api/hint"])
def test_differentiates_prolog_validation_error_from_internal_error(
    monkeypatch: pytest.MonkeyPatch,
    endpoint: str,
) -> None:
    """Garante 422 para erro de validação do Prolog e 500 para erro interno inesperado."""
    payload = {
        "puzzle": make_mini_puzzle_payload(),
        "entries": [{"row": 1, "col": 1, "value": 3}],
    }
    monkeypatch.setattr(prolog_module, "ensure_prolog_loaded", lambda: None)

    def raise_validation_error(*_args: Any, **_kwargs: Any) -> Any:
        raise FakePrologError("domain_error(kakuro_entry, 99)")

    monkeypatch.setattr(prolog_module.janus, "query_once", raise_validation_error)
    validation_res = client.post(endpoint, json=payload)
    assert validation_res.status_code == 422
    assert (
        validation_res.json()["detail"]
        == "Tabuleiro ou entradas inválidos segundo as regras do Kakuro."
    )

    def raise_internal_error(*_args: Any, **_kwargs: Any) -> Any:
        raise FakePrologError("existence_error(procedure, kakuro:solve/3)")

    monkeypatch.setattr(prolog_module.janus, "query_once", raise_internal_error)
    internal_res = client.post(endpoint, json=payload)
    assert internal_res.status_code == 500
    assert internal_res.json() == {
        "detail": "Erro interno ao processar a requisição."
    }


@pytest.mark.parametrize(
    ("mock_response", "expected_json"),
    [
        (
            HintValueResponse(kind="hint", row=2, col=2, value=2),
            {"kind": "hint", "row": 2, "col": 2, "value": 2},
        ),
        (HintStatusResponse(kind="complete"), {"kind": "complete"}),
        (HintStatusResponse(kind="inconsistent"), {"kind": "inconsistent"}),
        (HintStatusResponse(kind="no_forced_hint"), {"kind": "no_forced_hint"}),
    ],
)
def test_hint_endpoint_unit(
    monkeypatch: pytest.MonkeyPatch,
    mock_response: HintValueResponse | HintStatusResponse,
    expected_json: dict[str, Any],
) -> None:
    """Testa os quatro retornos possíveis de `/api/hint` conforme o contrato."""
    payload = {"puzzle": make_mini_puzzle_payload(), "entries": []}
    monkeypatch.setattr(main_module, "get_hint", lambda puzzle, entries: mock_response)

    response = client.post("/api/hint", json=payload)
    assert response.status_code == 200
    assert response.json() == expected_json


def test_solve_and_hint_integration_with_prolog() -> None:
    """Integração real com `kakuro.pl` via Janus para `/api/solve` e `/api/hint`."""
    puzzle = make_mini_puzzle_payload()

    solve_res = client.post(
        "/api/solve",
        json={"puzzle": deepcopy(puzzle), "entries": [{"row": 1, "col": 1, "value": 3}]},
    )
    assert solve_res.status_code == 200
    assert sorted(
        (item["row"], item["col"], item["value"])
        for item in solve_res.json()["solution"]
    ) == [(1, 1, 3), (1, 2, 4), (2, 1, 1), (2, 2, 2)]

    unsolvable_res = client.post(
        "/api/solve",
        json={"puzzle": deepcopy(puzzle), "entries": [{"row": 1, "col": 1, "value": 9}]},
    )
    assert unsolvable_res.status_code == 422
    assert isinstance(unsolvable_res.json()["detail"], str)

    hint_forced = client.post(
        "/api/hint",
        json={
            "puzzle": deepcopy(puzzle),
            "entries": [
                {"row": 1, "col": 1, "value": 3},
                {"row": 1, "col": 2, "value": 4},
                {"row": 2, "col": 1, "value": 1},
            ],
        },
    )
    assert hint_forced.status_code == 200
    assert hint_forced.json() == {"kind": "hint", "row": 2, "col": 2, "value": 2}

    hint_complete = client.post(
        "/api/hint",
        json={
            "puzzle": deepcopy(puzzle),
            "entries": [
                {"row": 1, "col": 1, "value": 3},
                {"row": 1, "col": 2, "value": 4},
                {"row": 2, "col": 1, "value": 1},
                {"row": 2, "col": 2, "value": 2},
            ],
        },
    )
    assert hint_complete.status_code == 200
    assert hint_complete.json() == {"kind": "complete"}

    hint_inconsistent = client.post(
        "/api/hint",
        json={"puzzle": deepcopy(puzzle), "entries": [{"row": 1, "col": 1, "value": 9}]},
    )
    assert hint_inconsistent.status_code == 200
    assert hint_inconsistent.json() == {"kind": "inconsistent"}
