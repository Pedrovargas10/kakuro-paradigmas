"""Modelos Pydantic e validações do contrato HTTP/JSON da API do Kakuro."""

from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

GRID_SIZE = 6
MIN_VALUE = 1
MAX_VALUE = 9


class BlockCell(BaseModel):
    """Casa de bloqueio (sem pista nem preenchimento)."""

    model_config = ConfigDict(extra="forbid")

    kind: Literal["block"] = "block"


class PlayableCell(BaseModel):
    """Casa branca jogável, preenchível com dígito de 1 a 9."""

    model_config = ConfigDict(extra="forbid")

    kind: Literal["playable"] = "playable"


class ClueCell(BaseModel):
    """Casa de pista com soma horizontal (`across`) e/ou vertical (`down`)."""

    model_config = ConfigDict(extra="forbid")

    kind: Literal["clue"] = "clue"
    across: int | None = None
    down: int | None = None

    @model_validator(mode="after")
    def validate_clues(self) -> "ClueCell":
        """Garante ao menos uma pista válida e valores estritamente positivos."""
        if self.across is None and self.down is None:
            raise ValueError("Casa de pista deve informar 'across' e/ou 'down'.")
        if self.across is not None and self.across <= 0:
            raise ValueError("Pista 'across' deve ser maior que zero.")
        if self.down is not None and self.down <= 0:
            raise ValueError("Pista 'down' deve ser maior que zero.")
        return self


Cell = Annotated[BlockCell | ClueCell | PlayableCell, Field(discriminator="kind")]


class Puzzle(BaseModel):
    """Tabuleiro 6x6 do Kakuro."""

    model_config = ConfigDict(extra="forbid")

    cells: list[list[Cell]]

    @field_validator("cells")
    @classmethod
    def validate_grid(cls, cells: list[list[Cell]]) -> list[list[Cell]]:
        """Valida dimensões 6x6 e presença de pelo menos uma casa jogável."""
        if len(cells) != GRID_SIZE:
            raise ValueError(f"O tabuleiro deve ter exatamente {GRID_SIZE} linhas.")

        has_playable = False
        for row_idx, row in enumerate(cells):
            if len(row) != GRID_SIZE:
                raise ValueError(
                    f"A linha {row_idx} do tabuleiro deve ter exatamente {GRID_SIZE} colunas."
                )
            if any(cell.kind == "playable" for cell in row):
                has_playable = True

        if not has_playable:
            raise ValueError("O tabuleiro deve conter ao menos uma casa jogável.")

        return cells


class Entry(BaseModel):
    """Valor preenchido pelo jogador em uma coordenada (0-based) do tabuleiro."""

    model_config = ConfigDict(extra="forbid")

    row: int = Field(..., ge=0, lt=GRID_SIZE, description="Índice da linha (0 a 5)")
    col: int = Field(..., ge=0, lt=GRID_SIZE, description="Índice da coluna (0 a 5)")
    value: int = Field(
        ..., ge=MIN_VALUE, le=MAX_VALUE, description="Dígito preenchido (1 a 9)"
    )


class PuzzleEntriesRequest(BaseModel):
    """Payload compartilhado pelas rotas que recebem tabuleiro e entradas."""

    model_config = ConfigDict(extra="forbid")

    puzzle: Puzzle
    entries: list[Entry] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_entries_on_puzzle(self) -> "PuzzleEntriesRequest":
        """Garante coordenadas únicas e restritas às casas jogáveis do tabuleiro."""
        seen: set[tuple[int, int]] = set()
        for entry in self.entries:
            coord = (entry.row, entry.col)
            if coord in seen:
                raise ValueError(
                    f"Coordenada duplicada nas entradas: ({entry.row}, {entry.col})."
                )
            seen.add(coord)

            cell = self.puzzle.cells[entry.row][entry.col]
            if cell.kind != "playable":
                raise ValueError(
                    f"A casa ({entry.row}, {entry.col}) é do tipo '{cell.kind}' e não pode receber valor."
                )
        return self


SolveRequest = PuzzleEntriesRequest


class SolveResponse(BaseModel):
    """Resposta da rota POST /api/solve."""

    solution: list[Entry]


class ErrorResponse(BaseModel):
    """Formato padronizado de erro da API."""

    detail: str
