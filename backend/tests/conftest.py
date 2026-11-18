import json
from pathlib import Path

import pytest


FIXTURES_DIR = Path(__file__).resolve().parents[2] / "docs" / "fixtures"


def load_shared_case(puzzle_id):
    puzzle_path = FIXTURES_DIR / f"puzzle_{puzzle_id:02d}.json"
    solution_path = FIXTURES_DIR / f"puzzle_{puzzle_id:02d}_solution.json"
    return {
        "puzzle": {"cells": json.loads(puzzle_path.read_text(encoding="utf-8"))},
        "solution": json.loads(solution_path.read_text(encoding="utf-8")),
    }


@pytest.fixture
def mini_case():
    return load_shared_case(1)


@pytest.fixture(params=[1, 2, 3], ids=["puzzle_01", "puzzle_02", "puzzle_03"])
def shared_case(request):
    return load_shared_case(request.param)
