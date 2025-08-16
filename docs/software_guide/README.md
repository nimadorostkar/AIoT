# Software Guide

## Local Run (no Docker)
- Requirements: Python 3.9, Redis, Mosquitto, Node 20
- Backend:
  - `cd backend && /usr/bin/python3 -m venv .venv && source .venv/bin/activate`
  - `pip install -r requirements.txt`
  - `export DJANGO_SETTINGS_MODULE=core.settings`
  - `python manage.py migrate && python manage.py ensure_superuser`
  - `daphne -b 0.0.0.0 -p 8000 core.asgi:application`
- Frontend:
  - `cd frontend && npm install && npm run dev`

## API Endpoints
- Auth: `POST /api/token/`, `POST /api/token/refresh/`
- Me: `GET /api/accounts/me/`
- Gateways: `GET/POST /api/devices/gateways/`, `POST /api/devices/gateways/claim/`
- Devices: `GET /api/devices/devices/`, `POST /api/devices/devices/{id}/command/`
- Telemetry: `GET /api/devices/telemetry/`
- Docs: `/api/docs/`

## MQTT Topics
- Telemetry: `devices/{id}/data`
- Heartbeat: `devices/{id}/heartbeat`
- Commands: `devices/{id}/commands`
- Responses: `devices/{id}/response`
