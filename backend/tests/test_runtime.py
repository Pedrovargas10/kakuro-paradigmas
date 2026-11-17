import pytest
from fastapi.testclient import TestClient

from app import main, prolog


def test_startup_loads_prolog_and_serves_documentation():
    with TestClient(main.app) as client:
        assert client.get("/docs").status_code == 200
        assert client.get("/openapi.json").status_code == 200
        result = prolog.janus.query_once(
            "current_predicate(kakuro:solve/3), current_predicate(generator:generate/1)"
        )
        assert result["truth"] is True


def test_modules_are_loaded_once(monkeypatch):
    loaded = []
    monkeypatch.setattr(prolog, "_prolog_loaded", False)
    monkeypatch.setattr(prolog.janus, "consult", loaded.append)
    prolog.ensure_prolog_loaded()
    prolog.ensure_prolog_loaded()
    assert loaded == [str(prolog.KAKURO_PL), str(prolog.GENERATOR_PL)]


def test_missing_module_does_not_mark_runtime_as_loaded(monkeypatch, tmp_path):
    monkeypatch.setattr(prolog, "_prolog_loaded", False)
    monkeypatch.setattr(prolog, "GENERATOR_PL", tmp_path / "missing.pl")
    with pytest.raises(FileNotFoundError):
        prolog.ensure_prolog_loaded()
    assert prolog._prolog_loaded is False


def test_consult_failure_can_be_retried(monkeypatch):
    monkeypatch.setattr(prolog, "_prolog_loaded", False)

    def fail_consult(source):
        raise RuntimeError("Falha de carregamento simulada")

    monkeypatch.setattr(prolog.janus, "consult", fail_consult)
    with pytest.raises(RuntimeError):
        prolog.ensure_prolog_loaded()
    assert prolog._prolog_loaded is False
