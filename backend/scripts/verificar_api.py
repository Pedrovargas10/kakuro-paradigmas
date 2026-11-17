"""Verifica o fluxo HTTP usando exclusivamente as decisões do motor Prolog."""

import argparse
import json
from time import monotonic

import httpx


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def post(client: httpx.Client, route: str, payload: dict) -> dict:
    response = client.post(route, json=payload)
    if response.status_code != 200:
        raise RuntimeError(f"{route}: HTTP {response.status_code}: {response.text}")
    body = response.json()
    require(isinstance(body, dict), f"{route}: resposta deve ser um objeto JSON.")
    return body


def verify_game(client: httpx.Client) -> float:
    start = monotonic()
    generated = post(client, "/api/generate", {})
    elapsed = monotonic() - start
    require(set(generated) == {"puzzle"}, "Geração expôs campos além do puzzle.")
    puzzle = generated["puzzle"]
    cells = puzzle["cells"]
    require(len(cells) == 6 and all(len(row) == 6 for row in cells), "Puzzle não é 6x6.")
    require(all("value" not in cell for row in cells for cell in row), "Geração expôs dígitos.")

    checked = post(client, "/api/check", {"puzzle": puzzle, "entries": []})
    require(checked == {"state": "incomplete"}, "Puzzle vazio não é incompleto consistente.")
    solved = post(client, "/api/solve", {"puzzle": puzzle, "entries": []})
    solution = solved["solution"]
    require(bool(solution), "Solução vazia.")
    partial = solution[:-1]
    hinted = post(client, "/api/hint", {"puzzle": puzzle, "entries": partial})
    require(hinted == {"kind": "hint", **solution[-1]}, "Dica não preenche a única casa vazia.")
    preserved = post(client, "/api/solve", {"puzzle": puzzle, "entries": solution[:1]})
    require(solution[0] in preserved["solution"], "Resolver alterou a entrada do jogador.")
    complete = {"puzzle": puzzle, "entries": solution}
    require(post(client, "/api/check", complete) == {"state": "solved"}, "Solução foi rejeitada.")
    require(post(client, "/api/hint", complete) == {"kind": "complete"}, "Partida não foi concluída.")
    return elapsed


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    parser.add_argument("--partidas", type=int, default=1)
    args = parser.parse_args()
    if args.partidas < 1:
        parser.error("--partidas deve ser maior que zero")
    try:
        with httpx.Client(base_url=args.base_url, timeout=15) as client:
            durations = [verify_game(client) for _ in range(args.partidas)]
    except (httpx.HTTPError, RuntimeError, KeyError, TypeError, ValueError) as exc:
        parser.exit(1, f"Falha na verificação: {exc}\n")
    print(json.dumps({
        "partidas_verificadas": len(durations),
        "geracao_max_segundos": round(max(durations), 3),
        "geracao_media_segundos": round(sum(durations) / len(durations), 3),
    }))


if __name__ == "__main__":
    main()
