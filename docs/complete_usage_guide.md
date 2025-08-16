# IoT Smart System - Complete Usage Guide

## Table of Contents
1. [Project Overview](#project-overview)
2. [System Architecture](#system-architecture)
3. [Prerequisites](#prerequisites)
4. [Installation & Setup](#installation--setup)
5. [Running the Project](#running-the-project)
6. [API Documentation](#api-documentation)
7. [Frontend Features](#frontend-features)
8. [MQTT Integration](#mqtt-integration)
9. [Device Management](#device-management)
10. [Troubleshooting](#troubleshooting)

## Project Overview

The IoT Smart System is a comprehensive platform for managing IoT devices, featuring real-time data monitoring, device control, and live video streaming. The system consists of:

- **Backend**: Django REST API with WebSocket support
- **Frontend**: React TypeScript web application with Material-UI
- **MQTT Broker**: Mosquitto for device communication
- **Database**: SQLite (development) / PostgreSQL (production)

## System Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   IoT Devices   │───▶│  MQTT Broker    │───▶│   Django API    │
│                 │    │  (Mosquitto)    │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                               ┌─────────────────┐
                                               │   React Web     │
                                               │   Application   │
                                               └─────────────────┘
```

## Prerequisites

### Software Requirements
- **Python 3.9+** - Backend development
- **Node.js 18+** - Frontend development
- **npm** - Package management
- **Docker & Docker Compose** (optional) - Containerized deployment

### Hardware Requirements (for IoT devices)
- ESP32/ESP8266 microcontrollers
- Sensors (temperature, humidity, motion, etc.)
- Camera modules (for video streaming)
- Network connectivity (WiFi)

## Installation & Setup

### 1. Clone the Repository
```bash
git clone <repository-url>
cd IOT
```

### 2. Backend Setup

Navigate to the backend directory:
```bash
cd backend
```

Create a virtual environment (recommended):
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

Install dependencies:
```bash
pip install -r requirements.txt
```

Run database migrations:
```bash
python manage.py migrate
```

Create a superuser (optional):
```bash
python manage.py createsuperuser
```

### 3. Frontend Setup

Navigate to the frontend directory:
```bash
cd frontend
```

Install dependencies:
```bash
npm install
```

### 4. MQTT Broker Setup

Using Docker (recommended):
```bash
docker run -it -p 1883:1883 -p 9001:9001 eclipse-mosquitto
```

Or install Mosquitto locally and configure using the provided config:
```bash
# Copy the mosquitto config
cp docker/mosquitto/mosquitto.conf /etc/mosquitto/conf.d/
```

## Running the Project

### Development Mode

#### 1. Start the MQTT Broker
```bash
# Using Docker
docker run -it -p 1883:1883 -p 9001:9001 eclipse-mosquitto

# Or using Docker Compose
docker-compose up mosquitto
```

#### 2. Start the Backend Server
```bash
cd backend
python manage.py runserver
```
The Django API will be available at `http://localhost:8000`

#### 3. Start the Frontend Development Server
```bash
cd frontend
npm run dev
```
The React application will be available at `http://localhost:5173`

### Production Mode (Docker Compose)

```bash
# Build and start all services
docker-compose up --build

# Run in background
docker-compose up -d --build
```

## API Documentation

### Authentication Endpoints

#### Register
- **POST** `/api/auth/register/`
- **Body**: `{ "username": "user", "email": "user@example.com", "password": "password" }`

#### Login
- **POST** `/api/auth/login/`
- **Body**: `{ "username": "user", "password": "password" }`
- **Response**: `{ "access": "jwt_token", "refresh": "refresh_token" }`

### Device Endpoints

#### List Devices
- **GET** `/api/devices/`
- **Headers**: `Authorization: Bearer <jwt_token>`

#### Device Details
- **GET** `/api/devices/{id}/`

#### Device Telemetry
- **GET** `/api/devices/{id}/telemetry/`
- **Query Parameters**: `?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD`

#### Send Command
- **POST** `/api/devices/{id}/command/`
- **Body**: `{ "command": "turn_on", "parameters": {} }`

### WebSocket Endpoints

#### Real-time Device Data
- **WS** `/ws/devices/{device_id}/`
- **Authentication**: Send JWT token in connection headers

## Frontend Features

### Pages Overview

1. **Home Page** (`/`)
   - Animated intro with GIF
   - Login/Register navigation
   - System overview

2. **Login Page** (`/login`)
   - User authentication
   - JWT token management

3. **Register Page** (`/register`)
   - New user registration

4. **Overview Page** (`/overview`)
   - Dashboard with device statistics
   - Real-time telemetry charts
   - System health monitoring

5. **Devices Page** (`/devices`)
   - Device list and management
   - Add/remove devices
   - Device status monitoring

6. **Control Page** (`/control`)
   - Device control interface
   - Send commands to devices
   - Real-time feedback

7. **Video Page** (`/video`)
   - Live video streaming from cameras
   - Multiple camera support

8. **Sensor History** (`/sensor-history`)
   - Historical sensor data visualization
   - Data export functionality

### Key Components

- **DashboardLayout**: Main application layout with navigation
- **DeviceControlPanel**: Device control interface
- **LiveVideoPlayer**: Video streaming component

## MQTT Integration

### Topics Structure

```
devices/{device_id}/telemetry    # Device sensor data
devices/{device_id}/commands     # Commands to device
devices/{device_id}/status       # Device status updates
devices/{device_id}/video        # Video stream metadata
```

### Message Formats

#### Telemetry Data
```json
{
  "device_id": "esp32_001",
  "timestamp": "2024-01-15T10:30:00Z",
  "data": {
    "temperature": 25.5,
    "humidity": 60.2,
    "motion_detected": false
  }
}
```

#### Command Message
```json
{
  "command": "set_led",
  "parameters": {
    "color": "red",
    "brightness": 80
  },
  "timestamp": "2024-01-15T10:30:00Z"
}
```

## Device Management

### Adding New Devices

1. Register device in Django admin or via API
2. Configure device with MQTT broker details
3. Set up device authentication
4. Deploy firmware with proper topics

### Device Configuration

Each device needs:
- Unique device ID
- MQTT broker connection details
- WiFi credentials
- Sensor configuration
- Command handlers

### Supported Device Types

- **Temperature Sensors**: DHT22, DS18B20
- **Motion Sensors**: PIR sensors
- **Camera Modules**: ESP32-CAM
- **Actuators**: LEDs, relays, servos
- **Environmental Sensors**: Air quality, light sensors

## Troubleshooting

### Common Issues

#### Backend Issues

1. **Database Connection Error**
   ```bash
   # Reset database
   rm db.sqlite3
   python manage.py migrate
   ```

2. **MQTT Connection Failed**
   - Check if Mosquitto is running
   - Verify port 1883 is accessible
   - Check firewall settings

3. **JWT Token Expired**
   - Refresh token using `/api/auth/refresh/`
   - Re-login if refresh token expired

#### Frontend Issues

1. **Cannot Connect to Backend**
   - Verify backend is running on port 8000
   - Check CORS settings in Django
   - Verify API endpoints

2. **WebSocket Connection Failed**
   - Check if Django Channels is properly configured
   - Verify Redis is running (if using Redis channel layer)
   - Check WebSocket URL format

#### Device Issues

1. **Device Not Connecting to MQTT**
   - Verify WiFi credentials
   - Check MQTT broker IP and port
   - Verify device certificates (if using TLS)

2. **Data Not Appearing in Dashboard**
   - Check device ID matches registered device
   - Verify MQTT topic format
   - Check backend MQTT consumer logs

### Logs and Debugging

#### Backend Logs
```bash
# Django debug mode
DEBUG=True python manage.py runserver

# MQTT worker logs
python manage.py shell
>>> from apps.devices.mqtt_worker import MQTTWorker
>>> worker = MQTTWorker()
>>> worker.start()
```

#### Frontend Logs
- Open browser developer tools
- Check console for JavaScript errors
- Monitor network tab for API calls

#### MQTT Logs
```bash
# Subscribe to all topics for debugging
mosquitto_sub -h localhost -t "devices/+/+"
```

### Performance Optimization

1. **Database**
   - Add indexes for frequently queried fields
   - Use database connection pooling
   - Implement data archiving for old telemetry

2. **Frontend**
   - Implement lazy loading for components
   - Use React.memo for expensive components
   - Optimize chart rendering intervals

3. **MQTT**
   - Use persistent sessions for reliable delivery
   - Implement message compression
   - Set appropriate QoS levels

## Security Considerations

1. **Authentication**
   - Use strong passwords
   - Implement JWT token refresh
   - Set appropriate token expiration times

2. **MQTT Security**
   - Enable TLS encryption
   - Use client certificates
   - Implement access control lists

3. **Network Security**
   - Use VPN for remote access
   - Implement firewall rules
   - Regular security updates

## Support and Contributing

For issues and questions:
1. Check this documentation
2. Review existing GitHub issues
3. Create new issue with detailed description
4. Include logs and error messages

For contributing:
1. Fork the repository
2. Create feature branch
3. Submit pull request with tests
4. Follow code style guidelines

