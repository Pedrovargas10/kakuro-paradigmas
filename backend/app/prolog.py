"""Ponte entre a API Python (FastAPI/Pydantic) e o motor SWI-Prolog via Janus."""

from pathlib import Path
from threading import Lock
from typing import Any

import janus_swi as janus

from .schemas import (
    BlockCell,
    Cell,
    ClueCell,
    Entry,
    PlayableCell,
    Puzzle,
)

PROLOG_DIR = Path(__file__).resolve().parent.parent / "prolog"
KAKURO_PL = PROLOG_DIR / "kakuro.pl"
GENERATOR_PL = PROLOG_DIR / "generator.pl"

_load_lock = Lock()
_prolog_loaded = False


class PrologInputError(ValueError):
    """Erro de validação estrutural ou de entrada reportado pelo Prolog."""


def ensure_prolog_loaded() -> None:
    """Carrega os módulos Prolog principais uma única vez na sessão do Janus."""
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
        if GENERATOR_PL.exists() and GENERATOR_PL.stat().st_size > 0:
            janus.consult(str(GENERATOR_PL))
        _prolog_loaded = True


def _norm_str(value: Any) -> str:
    """Converte átomos/strings/bytes retornados pelo Janus para str Python."""
    if isinstance(value, bytes):
        return value.decode("utf-8")
    return str(value)


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


def prolog_to_cell(raw_cell: Any) -> Cell:
    """Converte uma célula vinda do Prolog para o modelo Pydantic correspondente.

    Aceita tanto o formato usado por `kakuro.pl` (`"block"`, `"white"`, `[A, D]`)
    quanto a tripla numérica `[Tipo, Across, Down]` descrita no plano de execução.
    """
    if isinstance(raw_cell, (str, bytes)):
        label = _norm_str(raw_cell)
        if label == "block":
            return BlockCell()
        if label in {"white", "playable"}:
            return PlayableCell()
        raise ValueError(f"Célula textual inválida vinda do Prolog: {label!r}")

    if isinstance(raw_cell, (list, tuple)):
        if len(raw_cell) == 2:
            across_raw, down_raw = int(raw_cell[0]), int(raw_cell[1])
            return ClueCell(
                across=across_raw if across_raw > 0 else None,
                down=down_raw if down_raw > 0 else None,
            )
        if len(raw_cell) == 3:
            kind_code, across_raw, down_raw = (
                int(raw_cell[0]),
                int(raw_cell[1]),
                int(raw_cell[2]),
            )
            if kind_code == 0:
                return BlockCell()
            if kind_code == 1:
                return ClueCell(
                    across=across_raw if across_raw > 0 else None,
                    down=down_raw if down_raw > 0 else None,
                )
            if kind_code == 2:
                return PlayableCell()

    raise ValueError(f"Formato de célula Prolog inválido: {raw_cell!r}")


def prolog_to_puzzle(raw_grid: list[list[Any]]) -> Puzzle:
    """Converte uma matriz 6x6 retornada pelo Prolog em um `Puzzle` validado."""
    return Puzzle(
        cells=[[prolog_to_cell(cell) for cell in row] for row in raw_grid]
    )


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
