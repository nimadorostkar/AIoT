# IoT Smart System (Web App + Django Backend)

End‑to‑end, production‑ready IoT platform for real‑time sensing, control, and live video. This project includes a Dockerized stack and a local dev setup (virtualenv + Vite). Architecture and protocol choices follow best practices similar to the referenced blueprint [IoT_Smart_System](https://github.com/nimadorostkar/IoT_Smart_System).

## Stack
- Backend: Django 4.2 LTS, DRF, SimpleJWT, Channels, Redis (WS), Mosquitto (MQTT)
- Frontend: React + Vite + MUI (dashboard‑style UI)
- Datastore: SQLite (local dev) / Postgres (docker compose)
- Realtime: MQTT bridge → DB + WebSocket broadcast

## Architecture (high‑level)
- Sensors → Gateway: Zigbee 3.0 (battery), LoRaWAN (long‑range), Wi‑Fi (high‑bw)
- Gateway → Cloud: MQTT/TLS (QoS1/2) with LWT presence
- Web App: REST (JWT) + WebSocket for live telemetry
- Topics:
  - `devices/{device_id}/data` (QoS1)
  - `devices/{device_id}/heartbeat`
  - `devices/{device_id}/commands` (QoS2)
  - `devices/{device_id}/response`

## Quickstart (Local, without Docker)

Prereqs: Python 3.9, Node 20, Redis, Mosquitto (via Homebrew on macOS)

1) Start services:
```bash
brew services start redis
brew services start mosquitto
```

2) Backend (Django + Channels):
```bash
cd backend
/usr/bin/python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export DJANGO_SETTINGS_MODULE=core.settings
python manage.py migrate
python manage.py ensure_superuser   # admin@example.com / admin123
daphne -b 0.0.0.0 -p 8000 core.asgi:application
```

3) Frontend (React + Vite):
```bash
cd frontend
npm install
npm run dev -- --host 0.0.0.0 --port 5173
# If 5173 is used, Vite will auto‑pick 5174
```

4) Open:
- Web app: http://localhost:5173 (or http://localhost:5174)
- API docs (Swagger): http://localhost:8000/api/docs/

5) Sign in (default):
- Username: `admin`
- Password: `admin123`

## Basic Workflow (IoT Plug and Play‑style)
1) User logs in.
2) Claim the purchased gateway by entering its `gateway_id` in the web UI (Overview page) → `POST /api/devices/gateways/claim/`.
3) Once the gateway comes online and publishes device advertisements/telemetry, devices auto‑appear and are controllable.

## API Essentials
- Auth: `POST /api/token/`, `POST /api/token/refresh/`
- Me: `GET /api/accounts/me/`
- Gateways: `GET/POST /api/devices/gateways/`, `POST /api/devices/gateways/claim/`
- Devices: `GET /api/devices/devices/`, `POST /api/devices/devices/{id}/command/`
- Telemetry: `GET /api/devices/telemetry/`
- WebSocket: `ws://localhost:8000/ws/telemetry/?token=<JWT>`

## MQTT Test (local)
Publish telemetry to Mosquitto; it will be stored and pushed over WS:
```bash
mosquitto_pub -h localhost -t devices/DEV-1/data -m '{"temperature":25.1,"humidity":44}' -q 1
```

## Docker (optional)
Docker Desktop required. From repo root:
```bash
docker compose up -d --build
```
Web: http://localhost:5173, API: http://localhost:8000.

## Docs
See `docs/`:
- `docs/IoT_System_Blueprint.md` – architecture & protocols
- `docs/software_guide/README.md` – local run, endpoints, MQTT topics
- `docs/deployment/deployment_guide.md` – docker/local deployment
- `docs/hardware_guide/firmware_guide.md` – provisioning & topics

## Notes
- Admin static 404 warnings are expected when serving via Daphne in dev; they don’t affect API/UI.
- The blueprint and choices are aligned with the public reference repo [IoT_Smart_System](https://github.com/nimadorostkar/IoT_Smart_System).
