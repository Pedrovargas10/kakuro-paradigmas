.PHONY: install dev

install:
	cd backend && uv sync
	cd frontend && npm install

dev:
	@trap 'kill 0' INT TERM; \
	(cd backend && uv run fastapi dev app/main.py --port 8000) & \
	(cd frontend && npm run dev -- --port 5173) & \
	wait
