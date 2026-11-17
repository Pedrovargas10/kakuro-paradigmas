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

RUN_PGROUP := python3 -c 'import os,sys; os.setpgid(0,0); os.execvp(sys.argv[1],sys.argv[1:])'

install:
	cd backend && uv sync
	cd frontend && npm install

dev:
	@backend_pid=""; \
	frontend_pid=""; \
	backend_done=0; \
	frontend_done=0; \
	status=0; \
	group_alive() { \
	  ps -A -o pgid= -o stat= | awk -v g="$$1" '$$1 == g && $$2 !~ /^Z/ { found = 1 } END { exit !found }'; \
	}; \
	cleanup() { \
	  trap "" INT TERM; \
	  for pid in "$$backend_pid" "$$frontend_pid"; do \
	    if [ -n "$$pid" ]; then \
	      kill -TERM -"$$pid" 2>/dev/null || true; \
	    fi; \
	  done; \
	  tries=0; \
	  while [ "$$tries" -lt 20 ]; do \
	    alive=0; \
	    for pid in "$$backend_pid" "$$frontend_pid"; do \
	      if [ -n "$$pid" ] && group_alive "$$pid"; then \
	        alive=1; \
	      fi; \
	    done; \
	    if [ "$$alive" -eq 0 ]; then \
	      break; \
	    fi; \
	    sleep 0.1; \
	    tries=$$((tries + 1)); \
	  done; \
	  for pid in "$$backend_pid" "$$frontend_pid"; do \
	    if [ -n "$$pid" ] && group_alive "$$pid"; then \
	      kill -KILL -"$$pid" 2>/dev/null || true; \
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
	(cd backend && exec $(RUN_PGROUP) uv run fastapi dev app/main.py --port 8000) & \
	backend_pid=$$!; \
	(cd frontend && exec $(RUN_PGROUP) npm run dev -- --port 5173) & \
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
	@test -s scripts/validar_entrega.py || { echo "Validador oficial ausente ou vazio: obter o arquivo do professor conforme issue #9." >&2; exit 1; }
	uv run scripts/validar_entrega.py
