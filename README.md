# IoT Smart System (Web App + Django Backend)

End‑to‑end, production‑ready IoT platform for real‑time sensing, control, and live video. This project includes a Dockerized stack and a local dev setup (virtualenv + Vite). Architecture and protocol choices follow best practices similar to the referenced blueprint [IoT_Smart_System](https://github.com/nimadorostkar/IoT_Smart_System).

## 🗂️ Folder Structure

```
AIoT/
├── backend/                    # Django REST API & WebSocket server
│   ├── apps/                   # Django applications
│   │   ├── accounts/           # User authentication & management
│   │   └── devices/            # IoT device management & telemetry
│   ├── core/                   # Django project core settings
│   │   ├── settings.py         # Main settings file
│   │   ├── asgi.py            # ASGI configuration for WebSockets
│   │   ├── routing.py         # WebSocket routing
│   │   └── urls.py            # URL routing
│   ├── scripts/               # Database initialization scripts
│   ├── staticfiles/           # Collected static files
│   ├── templates/             # Django templates
│   ├── Dockerfile             # Backend container configuration
│   ├── manage.py              # Django management script
│   └── requirements.txt       # Python dependencies
├── frontend/                   # React TypeScript application
│   ├── src/                   # Source code
│   │   ├── api/               # API client utilities
│   │   ├── components/        # Reusable React components
│   │   ├── pages/             # Page components
│   │   ├── App.tsx            # Main application component
│   │   └── main.tsx           # Application entry point
│   ├── public/                # Static assets
│   ├── Dockerfile             # Frontend container configuration
│   ├── nginx.conf             # Nginx configuration for production
│   ├── package.json           # Node.js dependencies
│   └── vite.config.ts         # Vite build configuration
├── docker/                     # Docker configuration files
│   ├── mosquitto/             # MQTT broker configuration
│   │   └── mosquitto.conf     # Mosquitto settings
│   └── nginx/                 # Reverse proxy configuration
│       ├── nginx.conf         # Main nginx configuration
│       └── sites-available/   # Site-specific configurations
├── docs/                       # Documentation
│   ├── hardware_guide/        # Hardware setup guides
│   ├── software_guide/        # Software development guides
│   ├── deployment/            # Deployment instructions
│   └── IoT_System_Blueprint.md # Architecture overview
├── docker-compose.yml          # Development environment
├── docker-compose.prod.yml     # Production overrides
├── Makefile                    # Development shortcuts
└── README.md                   # This file
```

## ✨ Key Features

### 🏠 **Smart Home IoT Platform**
- **Multi-Protocol Support**: Zigbee 3.0, LoRaWAN, Wi-Fi device connectivity
- **Real-time Telemetry**: Live sensor data streaming via MQTT and WebSockets
- **Device Management**: Auto-discovery, remote control, and status monitoring
- **Gateway Integration**: Plug-and-play IoT gateway support

### 🔧 **Backend Capabilities**
- **Django REST Framework**: RESTful APIs with auto-generated documentation
- **WebSocket Support**: Real-time bidirectional communication using Django Channels
- **MQTT Integration**: Industrial-grade messaging with QoS levels
- **JWT Authentication**: Secure token-based authentication with refresh tokens
- **Database Flexibility**: SQLite for development, PostgreSQL for production
- **Background Tasks**: Celery integration for async processing

### 🎨 **Frontend Features**
- **Modern React UI**: TypeScript-based single-page application
- **Material-UI Design**: Professional dashboard with responsive layout
- **Real-time Updates**: Live telemetry visualization and device status
- **Device Control**: Interactive controls for IoT device management
- **Video Streaming**: Live video player integration
- **Mobile Responsive**: Optimized for desktop, tablet, and mobile devices

### 🐳 **DevOps & Deployment**
- **Docker Containerization**: Full stack containerization with multi-stage builds
- **Production Ready**: Nginx reverse proxy, health checks, and security headers
- **Development Tools**: Hot-reload development environment
- **Database Management**: Automated migrations and backups
- **Monitoring**: Health checks and logging for all services
- **Scalability**: Horizontal scaling support with load balancing

### 🔐 **Security & Performance**
- **Security Headers**: XSS protection, CSRF protection, CORS configuration
- **Rate Limiting**: API rate limiting and DDoS protection
- **SSL/TLS Ready**: HTTPS/WSS support for secure communication
- **Caching**: Redis caching for improved performance
- **Static File Optimization**: Compressed assets and CDN-ready setup

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

## 🐳 Docker Deployment (Recommended)

### Prerequisites
- Docker Desktop (v20.10+)
- Docker Compose (v2.0+)
- 4GB+ RAM available for containers

### Quick Start (Development)

1. **Clone and navigate to the project:**
```bash
git clone <repository-url>
cd AIoT
```

2. **Start all services:**
```bash
# Using Docker Compose
docker compose up -d --build

# Or using the Makefile
make up
```

3. **Access the application:**
- **Web App**: http://localhost:5173
- **API & Admin**: http://localhost:8000
- **API Documentation**: http://localhost:8000/api/docs/
- **MQTT Broker**: localhost:1883 (MQTT), localhost:9001 (WebSocket)
- **Database**: localhost:5432 (postgres/postgres)

4. **Default login credentials:**
- Username: `admin`
- Password: `admin123`

### Production Deployment

1. **Start production stack:**
```bash
# Using production configuration
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build

# Or using Makefile
make up ENV=prod
```

2. **Access the application:**
- **Web App**: http://localhost (port 80)
- **API**: http://localhost/api/

### Service Architecture

The Docker stack includes the following services:

| Service | Container | Port(s) | Description |
|---------|-----------|---------|-------------|
| **web** | iot_web | 5173 | React frontend (development) |
| **api** | iot_api | 8000 | Django REST API & WebSocket server |
| **db** | iot_db | 5432 | PostgreSQL database |
| **redis** | iot_redis | 6379 | Redis cache & session store |
| **mqtt** | iot_mqtt | 1883, 9001 | Mosquitto MQTT broker |
| **celery** | iot_celery | - | Background task worker |
| **nginx** | iot_nginx | 80, 443 | Reverse proxy (production only) |

### Docker Commands Cheat Sheet

```bash
# Build and start all services
make up

# Stop all services
make down

# View logs from all services
make logs

# View logs from specific service
docker compose logs -f api

# Access Django shell
make shell-api

# Access frontend container
make shell-web

# Run Django migrations
make migrate

# Create Django superuser
make superuser

# Check service status
make status

# Run health check
make health

# Clean up everything (⚠️ destroys data)
make clean

# Backup database
make backup-db

# Restore database
make restore-db FILE=backup.sql
```

### Development Workflow

1. **Hot-reload development:**
   - Backend: Changes in `./backend/` trigger auto-reload
   - Frontend: Changes in `./frontend/src/` trigger hot-reload

2. **Database management:**
```bash
# Create migrations after model changes
make makemigrations

# Apply migrations
make migrate

# Access database directly
docker compose exec db psql -U postgres iot
```

3. **Testing:**
```bash
# Run backend tests
make test

# Run linting
make lint
```

### Environment Variables

Key environment variables (configured in docker-compose.yml):

| Variable | Description | Default |
|----------|-------------|---------|
| `DJANGO_DEBUG` | Enable Django debug mode | `1` (dev), `0` (prod) |
| `DATABASE_URL` | PostgreSQL connection string | Auto-configured |
| `REDIS_URL` | Redis connection string | Auto-configured |
| `MQTT_BROKER_URL` | MQTT broker hostname | `mqtt` |
| `CORS_ALLOWED_ORIGINS` | Frontend URL for CORS | `http://localhost:5173` |

### Troubleshooting

**Common issues and solutions:**

1. **Port conflicts:**
```bash
# Check what's using ports
lsof -i :5173 -i :8000 -i :5432

# Stop conflicting services
brew services stop postgresql
brew services stop redis
```

2. **Container won't start:**
```bash
# Check logs
docker compose logs <service-name>

# Rebuild containers
docker compose build --no-cache
```

3. **Database connection issues:**
```bash
# Reset database
docker compose down -v
docker compose up -d
```

4. **Permission issues (Linux):**
```bash
# Fix file permissions
sudo chown -R $USER:$USER .
```

### Security Notes

- Default credentials are for development only
- In production, use environment files for secrets
- Enable SSL/TLS in production nginx configuration
- Configure firewall rules for production deployment

## Docs
See `docs/`:
- `docs/IoT_System_Blueprint.md` – architecture & protocols
- `docs/software_guide/README.md` – local run, endpoints, MQTT topics
- `docs/deployment/deployment_guide.md` – docker/local deployment
- `docs/hardware_guide/firmware_guide.md` – provisioning & topics

## Notes
- Admin static 404 warnings are expected when serving via Daphne in dev; they don’t affect API/UI.
- The blueprint and choices are aligned with the public reference repo [IoT_Smart_System](https://github.com/nimadorostkar/IoT_Smart_System).
