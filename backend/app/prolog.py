"""Ponte entre a API Python (FastAPI/Pydantic) e o motor SWI-Prolog via Janus."""

from pathlib import Path
from threading import Lock
from typing import Any

import janus_swi as janus

from .schemas import BlockCell, Cell, Entry, PlayableCell, Puzzle

PROLOG_DIR = Path(__file__).resolve().parent.parent / "prolog"
KAKURO_PL = PROLOG_DIR / "kakuro.pl"

_load_lock = Lock()
_prolog_loaded = False


class PrologInputError(ValueError):
    """Erro de validação estrutural ou de entrada reportado pelo Prolog."""


def ensure_prolog_loaded() -> None:
    """Carrega o módulo Prolog `kakuro.pl` uma única vez na sessão do Janus."""
    global _prolog_loaded
    if _prolog_loaded:
        return
    with _load_lock:
        if _prolog_loaded:
            return
        if not KAKURO_PL.exists():
            raise FileNotFoundError(
                f"Arquivo Prolog não encontrado: {KAKURO_PL}"
            )
        janus.consult(str(KAKURO_PL))
        _prolog_loaded = True


def cell_to_prolog(cell: Cell) -> str | list[int]:
    """Converte uma célula Pydantic para o formato esperado por `kakuro.pl`."""
    if isinstance(cell, BlockCell):
        return "block"
    if isinstance(cell, PlayableCell):
        return "white"
    return [
        cell.across if cell.across is not None else 0,
        cell.down if cell.down is not None else 0,
    ]


def puzzle_to_prolog(puzzle: Puzzle) -> list[list[str | list[int]]]:
    """Converte um tabuleiro 6x6 para listas aninhadas compatíveis com o Janus."""
    return [[cell_to_prolog(cell) for cell in row] for row in puzzle.cells]


def entries_to_prolog(entries: list[Entry]) -> list[list[int]]:
    """Converte a lista de entradas do jogador em triplas `[Linha, Coluna, Valor]`."""
    return [[entry.row, entry.col, entry.value] for entry in entries]


def prolog_to_entries(raw_entries: list[list[int]]) -> list[Entry]:
    """Converte triplas `[Linha, Coluna, Valor]` vindas do Prolog em `Entry`."""
    return [
        Entry(row=int(row), col=int(col), value=int(value))
        for row, col, value in raw_entries
    ]


def query_prolog(goal: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
    """Executa uma consulta Janus com parâmetros vinculados e traduz erros de entrada."""
    ensure_prolog_loaded()
    try:
        return janus.query_once(goal, params or {})
    except janus.PrologError as exc:
        raise PrologInputError(
            "Tabuleiro ou entradas inválidos segundo as regras do Kakuro."
        ) from exc


def solve_puzzle(puzzle: Puzzle, entries: list[Entry]) -> list[Entry] | None:
    """Consulta `kakuro:solve/3` para obter solução compatível com `entries`.

    Retorna `None` quando o preenchimento atual não admite nenhuma solução.
    """
    result = query_prolog(
        "kakuro:solve(Puzzle, Entradas, Solucao)",
        {
            "Puzzle": puzzle_to_prolog(puzzle),
            "Entradas": entries_to_prolog(entries),
        },
    )
    if not result or not result.get("truth") or result.get("Solucao") is None:
        return None

    return prolog_to_entries(result["Solucao"])
