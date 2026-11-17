import pytest

from app import prolog
from app.schemas import Entry, Puzzle
from test_api import make_mini_puzzle_payload


def test_puzzle_round_trip():
    puzzle = Puzzle.model_validate(make_mini_puzzle_payload())
    assert prolog.prolog_to_puzzle(prolog.puzzle_to_prolog(puzzle)) == puzzle


@pytest.mark.parametrize("cell", [None, "playable", [0, 0], [1], [True, 3], [1.0, 0], [-1, 0]])
def test_invalid_engine_cells_are_rejected(cell):
    with pytest.raises((RuntimeError, ValueError)):
        prolog.prolog_to_cell(cell)


def test_check_uses_bound_parameters(monkeypatch):
    seen = []

    def query(goal, params):
        seen.append((goal, params))
        return {"truth": True, "Estado": "incomplete"}

    monkeypatch.setattr(prolog, "query_prolog", query)
    puzzle = Puzzle.model_validate(make_mini_puzzle_payload())
    entries = [Entry(row=1, col=1, value=3)]
    assert prolog.check_puzzle(puzzle, entries) == "incomplete"
    assert seen == [(
        "kakuro:check(Puzzle, Entradas, Estado)",
        {"Puzzle": prolog.puzzle_to_prolog(puzzle), "Entradas": [[1, 1, 3]]},
    )]


@pytest.mark.parametrize("state", ["incomplete", "inconsistent", "solved"])
def test_check_translates_all_states(monkeypatch, state):
    monkeypatch.setattr(prolog, "query_prolog", lambda *args: {"truth": True, "Estado": state})
    assert prolog.check_puzzle(Puzzle.model_validate(make_mini_puzzle_payload()), []) == state


def test_check_rejects_unexpected_engine_state(monkeypatch):
    monkeypatch.setattr(prolog, "query_prolog", lambda *args: {"truth": True, "Estado": "private"})
    with pytest.raises(RuntimeError):
        prolog.check_puzzle(Puzzle.model_validate(make_mini_puzzle_payload()), [])


def test_generation_failure_is_explicit(monkeypatch):
    monkeypatch.setattr(prolog, "query_prolog", lambda *args: {"truth": False, "Puzzle": None})
    with pytest.raises(prolog.GenerationUnavailableError):
        prolog.generate_puzzle()


def test_generation_uses_bound_time_limit(monkeypatch):
    puzzle = Puzzle.model_validate(make_mini_puzzle_payload())
    seen = []

    def query(goal, params):
        seen.append((goal, params))
        return {"truth": True, "Puzzle": prolog.puzzle_to_prolog(puzzle)}

    monkeypatch.setattr(prolog, "query_prolog", query)
    assert prolog.generate_puzzle() == puzzle
    assert seen == [(
        "catch(call_with_time_limit(Seconds, generator:generate(Puzzle)), time_limit_exceeded, fail)",
        {"Seconds": 10},
    )]


def test_check_integration_with_real_prolog():
    puzzle = Puzzle.model_validate(make_mini_puzzle_payload())
    assert prolog.check_puzzle(puzzle, []) == "incomplete"
    assert prolog.check_puzzle(puzzle, [Entry(row=1, col=1, value=9)]) == "inconsistent"


def test_generate_integration_with_real_prolog():
    puzzle = prolog.generate_puzzle()
    assert len(puzzle.cells) == 6
    assert prolog.check_puzzle(puzzle, []) == "incomplete"
