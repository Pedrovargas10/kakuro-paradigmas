"""Solve e hint com os puzzles compartilhados de docs/fixtures (#14).

Os casos de check e generate com esses puzzles ficam com a parte do Pedro.
"""

import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app import main

FIXTURES = Path(__file__).resolve().parents[2] / "docs" / "fixtures"
CASOS = sorted(p.stem for p in FIXTURES.glob("puzzle_*.json") if not p.stem.endswith("_solution"))

pytestmark = pytest.mark.skipif(not CASOS, reason="docs/fixtures ainda não está na main (#14)")

client = TestClient(main.app, raise_server_exceptions=False)


def carregar(nome: str) -> tuple[dict, list[dict]]:
    linhas = json.loads((FIXTURES / f"{nome}.json").read_text(encoding="utf-8"))
    solucao = json.loads((FIXTURES / f"{nome}_solution.json").read_text(encoding="utf-8"))
    return {"cells": linhas}, solucao


def ordenar(entradas: list[dict]) -> list[dict]:
    return sorted(entradas, key=lambda e: (e["row"], e["col"]))


def errada(entrada: dict) -> dict:
    # Como a solução é única, trocar um valor deixa a partida sem solução.
    return {**entrada, "value": entrada["value"] % 9 + 1}


@pytest.mark.parametrize("nome", CASOS)
def test_solve_sem_entradas_devolve_a_solucao_conhecida(nome):
    puzzle, solucao = carregar(nome)
    resposta = client.post("/api/solve", json={"puzzle": puzzle, "entries": []})
    assert resposta.status_code == 200
    assert ordenar(resposta.json()["solution"]) == ordenar(solucao)


@pytest.mark.parametrize("nome", CASOS)
def test_solve_preserva_entradas_parciais(nome):
    puzzle, solucao = carregar(nome)
    parcial = solucao[: len(solucao) // 2]
    resposta = client.post("/api/solve", json={"puzzle": puzzle, "entries": parcial})
    assert resposta.status_code == 200
    resolvida = resposta.json()["solution"]
    assert all(entrada in resolvida for entrada in parcial)
    assert ordenar(resolvida) == ordenar(solucao)


@pytest.mark.parametrize("nome", CASOS)
def test_solve_sem_solucao_compativel_devolve_422(nome):
    puzzle, solucao = carregar(nome)
    resposta = client.post("/api/solve", json={"puzzle": puzzle, "entries": [errada(solucao[0])]})
    assert resposta.status_code == 422
    assert set(resposta.json()) == {"detail"}
    assert resposta.json()["detail"].strip()


@pytest.mark.parametrize("nome", CASOS)
def test_hint_revela_a_unica_casa_vazia(nome):
    puzzle, solucao = carregar(nome)
    resposta = client.post("/api/hint", json={"puzzle": puzzle, "entries": solucao[:-1]})
    assert resposta.status_code == 200
    assert resposta.json() == {"kind": "hint", **solucao[-1]}


@pytest.mark.parametrize("nome", CASOS)
def test_hint_no_tabuleiro_vazio_bate_com_a_solucao(nome):
    # Com solução única, qualquer casa vazia tem valor forçado (critério da #21).
    puzzle, solucao = carregar(nome)
    resposta = client.post("/api/hint", json={"puzzle": puzzle, "entries": []})
    assert resposta.status_code == 200
    dica = resposta.json()
    assert dica["kind"] == "hint"
    assert {"row": dica["row"], "col": dica["col"], "value": dica["value"]} in solucao


@pytest.mark.parametrize("nome", CASOS)
def test_hint_em_partida_completa(nome):
    puzzle, solucao = carregar(nome)
    resposta = client.post("/api/hint", json={"puzzle": puzzle, "entries": solucao})
    assert resposta.status_code == 200
    assert resposta.json() == {"kind": "complete"}


@pytest.mark.parametrize("nome", CASOS)
def test_hint_em_partida_inconsistente(nome):
    puzzle, solucao = carregar(nome)
    resposta = client.post("/api/hint", json={"puzzle": puzzle, "entries": [errada(solucao[0])]})
    assert resposta.status_code == 200
    assert resposta.json() == {"kind": "inconsistent"}
