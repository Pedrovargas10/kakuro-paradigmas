import json
from pathlib import Path

import pytest


@pytest.fixture
def mini_case():
    path = Path(__file__).parent / "fixtures" / "mini.json"
    return json.loads(path.read_text(encoding="utf-8"))
