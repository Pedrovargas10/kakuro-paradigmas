from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app, raise_server_exceptions=False)


def test_shared_puzzle_solution_and_partial_entries(shared_case):
    puzzle, solution = shared_case["puzzle"], shared_case["solution"]
    partial = solution[::2]
    response = client.post("/api/solve", json={"puzzle": puzzle, "entries": partial})
    assert response.status_code == 200
    assert response.json() == {"solution": solution}
    for entries, state in [(partial, "incomplete"), (solution, "solved")]:
        response = client.post("/api/check", json={"puzzle": puzzle, "entries": entries})
        assert response.status_code == 200
        assert response.json() == {"state": state}


def test_shared_puzzle_hint_fills_only_missing_cell(shared_case):
    puzzle, solution = shared_case["puzzle"], shared_case["solution"]
    response = client.post("/api/hint", json={"puzzle": puzzle, "entries": solution[:-1]})
    assert response.status_code == 200
    assert response.json() == {"kind": "hint", **solution[-1]}
    response = client.post("/api/hint", json={"puzzle": puzzle, "entries": solution})
    assert response.status_code == 200
    assert response.json() == {"kind": "complete"}


def test_shared_puzzle_incompatible_value_is_rejected(shared_case):
    puzzle, solution = shared_case["puzzle"], shared_case["solution"]
    first = solution[0]
    payload = {"puzzle": puzzle, "entries": [{**first, "value": first["value"] % 9 + 1}]}
    for route, expected in [("check", {"state": "inconsistent"}),
                            ("hint", {"kind": "inconsistent"})]:
        response = client.post(f"/api/{route}", json=payload)
        assert response.status_code == 200
        assert response.json() == expected
    response = client.post("/api/solve", json=payload)
    assert response.status_code == 422
    assert isinstance(response.json()["detail"], str)
    assert response.json()["detail"].strip()
