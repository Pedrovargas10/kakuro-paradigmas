.PHONY: install dev test test-prolog test-backend validar

install:
	cd backend && uv sync
	cd frontend && npm install

dev:
	@trap 'kill 0' INT TERM; \
	(cd backend && uv run fastapi dev app/main.py --port 8000) & \
	(cd frontend && npm run dev -- --port 5173) & \
	wait

test-prolog:
	swipl -g run_tests -t halt backend/prolog/test_kakuro.pl

test-backend:
	cd backend && uv run pytest

test: test-prolog test-backend

validar:
	uv run scripts/validar_entrega.py
