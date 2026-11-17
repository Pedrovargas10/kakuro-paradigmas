.PHONY: install install-backend dev dev-backend test test-prolog test-backend test-integration validar
.DEFAULT_GOAL := install

API_URL ?= http://127.0.0.1:8000
PARTIDAS ?= 10

install-backend:
	cd backend && uv sync --locked

dev-backend:
	cd backend && uv run --locked fastapi dev app/main.py --port 8000

# Requer backend já iniciado; não depende da disponibilidade do frontend.
test-integration:
	cd backend && uv run --locked python scripts/verificar_api.py --base-url "$(API_URL)" --partidas "$(PARTIDAS)"

install:
	cd backend && uv sync
	cd frontend && npm install

dev:
	@backend_pid=""; \
	frontend_pid=""; \
	backend_done=0; \
	frontend_done=0; \
	status=0; \
	cleanup() { \
	  trap "" INT TERM; \
	  for pid in "$$backend_pid" "$$frontend_pid"; do \
	    if [ -n "$$pid" ] && kill -0 "$$pid" 2>/dev/null; then \
	      kill -TERM "$$pid" 2>/dev/null || true; \
	    fi; \
	  done; \
	  if [ "$$backend_done" -eq 0 ] && [ -n "$$backend_pid" ]; then \
	    wait "$$backend_pid" 2>/dev/null || true; \
	    backend_done=1; \
	  fi; \
	  if [ "$$frontend_done" -eq 0 ] && [ -n "$$frontend_pid" ]; then \
	    wait "$$frontend_pid" 2>/dev/null || true; \
	    frontend_done=1; \
	  fi; \
	}; \
	trap 'cleanup; exit 130' INT; \
	trap 'cleanup; exit 143' TERM; \
	(cd backend && exec uv run fastapi dev app/main.py --port 8000) & \
	backend_pid=$$!; \
	(cd frontend && exec npm run dev -- --port 5173) & \
	frontend_pid=$$!; \
	while [ "$$backend_done" -eq 0 ] || [ "$$frontend_done" -eq 0 ]; do \
	  if [ "$$backend_done" -eq 0 ] && ! kill -0 "$$backend_pid" 2>/dev/null; then \
	    rc=0; \
	    wait "$$backend_pid" || rc=$$?; \
	    backend_done=1; \
	    if [ "$$rc" -ne 0 ]; then \
	      status=$$rc; \
	      break; \
	    fi; \
	  fi; \
	  if [ "$$frontend_done" -eq 0 ] && ! kill -0 "$$frontend_pid" 2>/dev/null; then \
	    rc=0; \
	    wait "$$frontend_pid" || rc=$$?; \
	    frontend_done=1; \
	    if [ "$$rc" -ne 0 ]; then \
	      status=$$rc; \
	      break; \
	    fi; \
	  fi; \
	  if [ "$$backend_done" -eq 0 ] || [ "$$frontend_done" -eq 0 ]; then \
	    sleep 0.1; \
	  fi; \
	done; \
	cleanup; \
	exit "$$status"

test-prolog:
	swipl -g run_tests -t halt backend/prolog/test_kakuro.pl

test-backend:
	cd backend && uv run pytest

test: test-prolog test-backend

validar:
	uv run scripts/validar_entrega.py
