"""Aplicação FastAPI do Kakuro com rotas de resolução, dica e tratamento de erros."""

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .prolog import PrologInputError, get_hint, solve_puzzle
from .schemas import (
    ErrorResponse,
    HintRequest,
    HintResponse,
    SolveRequest,
    SolveResponse,
)

app = FastAPI(title="Kakuro API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


def _format_validation_errors(exc: RequestValidationError) -> str:
    """Converte erros estruturados do Pydantic em mensagem legível para o cliente."""
    messages: list[str] = []
    for err in exc.errors():
        msg = str(err.get("msg", "Valor inválido")).removeprefix("Value error, ")
        loc_parts = [
            str(part)
            for part in err.get("loc", ())
            if part not in {"body", "__root__"}
        ]
        formatted = f"{'.'.join(loc_parts)}: {msg}" if loc_parts else msg
        if formatted not in messages:
            messages.append(formatted)

    return "; ".join(messages) if messages else "Dados de entrada inválidos."


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    """Retorna erro 422 no formato `{ "detail": "mensagem legível" }`."""
    return JSONResponse(
        status_code=422,
        content={"detail": _format_validation_errors(exc)},
    )


@app.exception_handler(PrologInputError)
async def prolog_input_exception_handler(
    request: Request, exc: PrologInputError
) -> JSONResponse:
    """Converte rejeições estruturais do Prolog em erro 422 legível."""
    return JSONResponse(
        status_code=422,
        content={"detail": str(exc)},
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(
    request: Request, exc: Exception
) -> JSONResponse:
    """Evita vazamento de stack traces ou detalhes internos para o frontend."""
    return JSONResponse(
        status_code=500,
        content={"detail": "Erro interno ao processar a requisição."},
    )


@app.post(
    "/api/solve",
    response_model=SolveResponse,
    responses={422: {"model": ErrorResponse}},
)
def solve_endpoint(payload: SolveRequest) -> SolveResponse:
    """Resolve o tabuleiro respeitando as entradas já preenchidas pelo jogador."""
    solution = solve_puzzle(payload.puzzle, payload.entries)
    if solution is None:
        raise HTTPException(
            status_code=422,
            detail="Não existe solução compatível com o preenchimento atual.",
        )
    return SolveResponse(solution=solution)


@app.post(
    "/api/hint",
    response_model=HintResponse,
    response_model_exclude_none=True,
    responses={422: {"model": ErrorResponse}},
)
def hint_endpoint(payload: HintRequest) -> HintResponse:
    """Retorna uma dica logicamente forçada ou o estado da partida."""
    return get_hint(payload.puzzle, payload.entries)
