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
    HintResponse,
    HintStatusResponse,
    HintValueResponse,
    PlayableCell,
    Puzzle,
)

PROLOG_DIR = Path(__file__).resolve().parent.parent / "prolog"
KAKURO_PL = PROLOG_DIR / "kakuro.pl"
GENERATOR_PL = PROLOG_DIR / "generator.pl"

_load_lock = Lock()
_prolog_loaded = False

_VALID_HINT_STATUSES = {"complete", "inconsistent", "no_forced_hint"}
_VALID_CHECK_STATES = {"incomplete", "inconsistent", "solved"}
GENERATION_TIMEOUT_SECONDS = 10

_INTERNAL_PROLOG_ERROR_MARKERS = (
    "existence_error",
    "undefined procedure",
    "resource_error",
    "system_error",
    "syntax_error",
    "permission_error",
    "instantiation_error",
    "out of ",
)
_VALIDATION_PROLOG_ERROR_MARKERS = (
    "invalid_",
    "validation_error",
    "kakuro_error",
    "domain_error",
    "type_error",
    "entrada",
    "tabuleiro",
    "puzzle",
    "sequencia",
    "sequence",
)


class PrologInputError(ValueError):
    """Erro de validação estrutural ou de entrada reportado pelo Prolog."""


class GenerationUnavailableError(RuntimeError):
    """O gerador não produziu um puzzle dentro do limite de tempo."""


def _is_validation_prolog_error(exc: Exception) -> bool:
    """Identifica exceções explícitas de validação do domínio vindas do Prolog."""
    message = str(exc).lower()
    if any(marker in message for marker in _INTERNAL_PROLOG_ERROR_MARKERS):
        return False
    return any(marker in message for marker in _VALIDATION_PROLOG_ERROR_MARKERS)


def ensure_prolog_loaded() -> None:
    """Carrega os módulos Prolog compartilhados uma única vez por processo."""
    global _prolog_loaded
    if _prolog_loaded:
        return
    with _load_lock:
        if _prolog_loaded:
            return
        for source in (KAKURO_PL, GENERATOR_PL):
            if not source.is_file():
                raise FileNotFoundError(f"Arquivo Prolog não encontrado: {source}")
        for source in (KAKURO_PL, GENERATOR_PL):
            janus.consult(str(source))
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


def prolog_to_cell(raw: Any) -> Cell:
    if raw == "block":
        return BlockCell()
    if raw == "white":
        return PlayableCell()
    if (
        isinstance(raw, list)
        and len(raw) == 2
        and all(type(value) is int for value in raw)
    ):
        across, down = raw
        return ClueCell(
            across=None if across == 0 else across,
            down=None if down == 0 else down,
        )
    raise RuntimeError("Célula inesperada retornada pelo motor Prolog.")


def prolog_to_puzzle(raw: Any) -> Puzzle:
    if not isinstance(raw, list) or any(not isinstance(row, list) for row in raw):
        raise RuntimeError("Tabuleiro inesperado retornado pelo motor Prolog.")
    return Puzzle(cells=[[prolog_to_cell(cell) for cell in row] for row in raw])


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
        if _is_validation_prolog_error(exc):
            raise PrologInputError(
                "Tabuleiro ou entradas inválidos segundo as regras do Kakuro."
            ) from exc
        raise


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


def _norm_str(value: Any) -> str:
    """Converte átomos/strings/bytes retornados pelo Janus para str Python."""
    if isinstance(value, bytes):
        return value.decode("utf-8")
    return str(value)


def check_puzzle(puzzle: Puzzle, entries: list[Entry]) -> str:
    result = query_prolog(
        "kakuro:check(Puzzle, Entradas, Estado)",
        {"Puzzle": puzzle_to_prolog(puzzle), "Entradas": entries_to_prolog(entries)},
    )
    if result.get("truth") is False:
        raise PrologInputError("Tabuleiro ou entradas inválidos segundo as regras do Kakuro.")
    state = _norm_str(result.get("Estado"))
    if result.get("truth") is not True or state not in _VALID_CHECK_STATES:
        raise RuntimeError("Resposta inesperada do motor Prolog ao verificar partida.")
    return state


def generate_puzzle() -> Puzzle:
    # O gerador pode falhar ao atingir seu limite ou propagar a exceção de tempo.
    result = query_prolog(
        "catch(call_with_time_limit(Seconds, generator:generate(Puzzle)), "
        "time_limit_exceeded, fail)",
        {"Seconds": GENERATION_TIMEOUT_SECONDS},
    )
    if result.get("truth") is False:
        raise GenerationUnavailableError(
            "Não foi possível gerar um puzzle no limite de 10 segundos. Tente novamente."
        )
    if result.get("truth") is not True or result.get("Puzzle") is None:
        raise RuntimeError("Resposta inesperada do motor Prolog ao gerar puzzle.")
    return prolog_to_puzzle(result["Puzzle"])


def get_hint(puzzle: Puzzle, entries: list[Entry]) -> HintResponse:
    """Consulta `kakuro:hint/3` e traduz o resultado para o contrato HTTP."""
    result = query_prolog(
        "kakuro:hint(Puzzle, Entradas, Resultado)",
        {
            "Puzzle": puzzle_to_prolog(puzzle),
            "Entradas": entries_to_prolog(entries),
        },
    )
    if not result or not result.get("truth") or result.get("Resultado") is None:
        return HintStatusResponse(kind="inconsistent")

    raw = result["Resultado"]
    if (
        isinstance(raw, (list, tuple))
        and len(raw) == 4
        and _norm_str(raw[0]) == "hint"
    ):
        return HintValueResponse(
            kind="hint",
            row=int(raw[1]),
            col=int(raw[2]),
            value=int(raw[3]),
        )

    if isinstance(raw, (str, bytes)):
        status = _norm_str(raw)
        if status in _VALID_HINT_STATUSES:
            return HintStatusResponse(kind=status)  # type: ignore[arg-type]

    raise RuntimeError("Resposta inesperada do motor Prolog ao calcular dica.")
