# IoT Device Testing Guide

Complete guide for testing gateways, devices, and sensors in your IoT platform.

## 🔐 Prerequisites

1. **Authentication**: Get JWT token first
```bash
# Get access token
curl -X POST http://localhost:8000/api/token/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# Save the access token for subsequent requests
export TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

2. **API Base URL**: `http://localhost:8000/api/devices/`

---

## 🌐 Gateway Management

### 1. Create/Claim a Gateway

```bash
# Claim a new gateway
curl -X POST http://localhost:8000/api/devices/gateways/claim/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "GW-HOME-001", 
    "name": "Home Main Gateway"
  }'
```

**Response:**
```json
{
  "id": 1,
  "gateway_id": "GW-HOME-001",
  "name": "Home Main Gateway",
  "last_seen": null
}
```

### 2. List Your Gateways

```bash
curl -X GET http://localhost:8000/api/devices/gateways/ \
  -H "Authorization: Bearer $TOKEN"
```

### 3. Update Gateway

```bash
curl -X PATCH http://localhost:8000/api/devices/gateways/1/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Living Room Gateway"}'
```

### 4. Trigger Device Discovery

```bash
# Send discovery command to gateway
curl -X POST http://localhost:8000/api/devices/gateways/1/discover/ \
  -H "Authorization: Bearer $TOKEN"
```

**Response:**
```json
{
  "status": "sent",
  "topic": "gateways/GW-HOME-001/discover"
}
```

---

## 📱 Device Management

### 1. Create Devices

#### Temperature Sensor
```bash
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "GW-HOME-001",
    "device_id": "TEMP-001",
    "type": "sensor",
    "name": "Living Room Temperature",
    "model": "DHT22"
  }'
```

#### Smart Switch/Relay
```bash
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "GW-HOME-001",
    "device_id": "RELAY-001",
    "type": "actuator",
    "name": "Living Room Light",
    "model": "SmartRelay-v2"
  }'
```

#### Smart Camera
```bash
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "GW-HOME-001",
    "device_id": "CAM-001",
    "type": "camera",
    "name": "Front Door Camera",
    "model": "IPCam-HD"
  }'
```

#### Motion Sensor
```bash
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "GW-HOME-001",
    "device_id": "PIR-001", 
    "type": "sensor",
    "name": "Hallway Motion Sensor",
    "model": "PIR-HC-SR501"
  }'
```

### 2. List All Devices

```bash
curl -X GET http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN"
```

### 3. Get Gateway Devices

```bash
curl -X GET http://localhost:8000/api/devices/gateways/1/devices/ \
  -H "Authorization: Bearer $TOKEN"
```

---

## 🎛️ Device Commands

### 1. Smart Switch/Relay Commands

#### Turn On/Off
```bash
# Turn ON
curl -X POST http://localhost:8000/api/devices/devices/2/command/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "toggle",
    "state": "on"
  }'

# Turn OFF
curl -X POST http://localhost:8000/api/devices/devices/2/command/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "toggle",
    "state": "off"
  }'
```

### 2. Dimmer/Light Commands

#### Set Brightness
```bash
curl -X POST http://localhost:8000/api/devices/devices/2/command/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "set_brightness",
    "brightness": 75
  }'
```

### 3. Camera Commands

#### Take Snapshot
```bash
curl -X POST http://localhost:8000/api/devices/devices/3/command/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "take_snapshot",
    "quality": "high"
  }'
```

#### Start/Stop Recording
```bash
# Start Recording
curl -X POST http://localhost:8000/api/devices/devices/3/command/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "start_recording",
    "duration": 60,
    "quality": "1080p"
  }'

# Stop Recording
curl -X POST http://localhost:8000/api/devices/devices/3/command/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "stop_recording"
  }'
```

### 4. Generic Device Commands

#### Custom Command
```bash
curl -X POST http://localhost:8000/api/devices/devices/1/command/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "custom_command",
    "parameter1": "value1",
    "parameter2": 42
  }'
```

**Command Response:**
```json
{
  "status": "sent",
  "topic": "devices/RELAY-001/commands",
  "command": {
    "action": "toggle",
    "state": "on",
    "device_id": "RELAY-001",
    "device_type": "actuator",
    "gateway_id": "GW-HOME-001",
    "timestamp": "2025-08-16T14:30:45.123456Z",
    "command_id": "cmd_RELAY-001_1755352245"
  },
  "qos": 2
}
```

---

## 📊 Telemetry & Data

### 1. Send Test Telemetry (via MQTT)

```bash
# Temperature sensor data
mosquitto_pub -h localhost -p 1883 \
  -t "devices/TEMP-001/data" \
  -m '{"temperature": 23.5, "humidity": 65.2, "timestamp": "2025-08-16T14:30:00Z"}' \
  -q 1

# Motion sensor data
mosquitto_pub -h localhost -p 1883 \
  -t "devices/PIR-001/data" \
  -m '{"motion": true, "timestamp": "2025-08-16T14:30:05Z"}' \
  -q 1

# Smart switch status
mosquitto_pub -h localhost -p 1883 \
  -t "devices/RELAY-001/data" \
  -m '{"state": "on", "power": 25.4, "timestamp": "2025-08-16T14:30:10Z"}' \
  -q 1
```

### 2. Device Heartbeat

```bash
# Send heartbeat
mosquitto_pub -h localhost -p 1883 \
  -t "devices/TEMP-001/heartbeat" \
  -m '{"status": "online", "battery": 85}' \
  -q 1
```

### 3. Get Telemetry Data

```bash
# Get all telemetry (latest first)
curl -X GET http://localhost:8000/api/devices/telemetry/ \
  -H "Authorization: Bearer $TOKEN"

# Get telemetry for specific device
curl -X GET "http://localhost:8000/api/devices/telemetry/?device=1" \
  -H "Authorization: Bearer $TOKEN"

# Limit results
curl -X GET "http://localhost:8000/api/devices/telemetry/?limit=10" \
  -H "Authorization: Bearer $TOKEN"
```

---

## 🔧 Advanced Testing

### 1. Device Model Definitions

#### Create Model Definition
```bash
curl -X POST http://localhost:8000/api/devices/device-models/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model_id": "DHT22-v1",
    "name": "DHT22 Temperature/Humidity Sensor",
    "version": "1.0",
    "schema": {
      "type": "object",
      "properties": {
        "temperature": {"type": "number", "unit": "°C"},
        "humidity": {"type": "number", "unit": "%"}
      }
    }
  }'
```

#### Link Device to Model
```bash
curl -X POST http://localhost:8000/api/devices/devices/link-model/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "TEMP-001",
    "model_id": "DHT22-v1"
  }'
```

### 2. Bulk Device Creation

```bash
# Create multiple devices
for i in {1..5}; do
  curl -X POST http://localhost:8000/api/devices/devices/ \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"gateway_id\": \"GW-HOME-001\",
      \"device_id\": \"SENSOR-$(printf "%03d" $i)\",
      \"type\": \"sensor\",
      \"name\": \"Room $i Sensor\",
      \"model\": \"Generic-v1\"
    }"
done
```

### 3. Simulate Device Activity

```bash
# Continuous temperature readings
for i in {1..10}; do
  TEMP=$(echo "20 + $RANDOM % 15" | bc)
  HUMIDITY=$(echo "40 + $RANDOM % 40" | bc)
  
  mosquitto_pub -h localhost -p 1883 \
    -t "devices/TEMP-001/data" \
    -m "{\"temperature\": $TEMP, \"humidity\": $HUMIDITY}" \
    -q 1
  
  sleep 5
done
```

---

## 🛠️ Quick Test Scripts

### Complete Test Suite
```bash
#!/bin/bash
# save as: test_iot_devices.sh

# Configuration
API_BASE="http://localhost:8000/api"
USERNAME="admin"
PASSWORD="admin123"

# Get token
echo "🔐 Getting authentication token..."
TOKEN=$(curl -s -X POST $API_BASE/token/ \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}" | \
  jq -r '.access')

if [ "$TOKEN" = "null" ]; then
  echo "❌ Failed to get token"
  exit 1
fi

echo "✅ Got token: ${TOKEN:0:20}..."

# Claim gateway
echo "🌐 Claiming gateway..."
GATEWAY=$(curl -s -X POST $API_BASE/devices/gateways/claim/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"gateway_id":"TEST-GW-001","name":"Test Gateway"}')

GATEWAY_ID=$(echo $GATEWAY | jq -r '.gateway_id')
echo "✅ Gateway claimed: $GATEWAY_ID"

# Create devices
echo "📱 Creating devices..."
DEVICES=("TEMP-001:sensor:Temperature Sensor" "RELAY-001:actuator:Smart Switch" "CAM-001:camera:Security Camera")

for device in "${DEVICES[@]}"; do
  IFS=':' read -r device_id type name <<< "$device"
  
  curl -s -X POST $API_BASE/devices/devices/ \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"gateway_id\":\"$GATEWAY_ID\",\"device_id\":\"$device_id\",\"type\":\"$type\",\"name\":\"$name\"}" > /dev/null
  
  echo "✅ Created: $name ($device_id)"
done

# Send test telemetry
echo "📊 Sending test telemetry..."
mosquitto_pub -h localhost -p 1883 -t "devices/TEMP-001/data" \
  -m '{"temperature":22.5,"humidity":60}' -q 1

mosquitto_pub -h localhost -p 1883 -t "devices/RELAY-001/data" \
  -m '{"state":"off","power":0}' -q 1

echo "✅ Test telemetry sent"

# Test device command
echo "🎛️  Testing device command..."
COMMAND_RESULT=$(curl -s -X POST $API_BASE/devices/devices/2/command/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"toggle","state":"on"}')

echo "✅ Command sent: $(echo $COMMAND_RESULT | jq -r '.status')"

echo "🎉 Test completed successfully!"
```

Make it executable and run:
```bash
chmod +x test_iot_devices.sh
./test_iot_devices.sh
```

---

## 📋 Device Types & Commands Reference

| Device Type | Commands | Example Payload |
|-------------|----------|-----------------|
| **sensor** | N/A (read-only) | `{"temperature": 25.5}` |
| **actuator/relay** | `toggle` | `{"action": "toggle", "state": "on/off"}` |
| **dimmer/light** | `set_brightness` | `{"action": "set_brightness", "brightness": 75}` |
| **camera** | `take_snapshot`, `start_recording`, `stop_recording` | `{"action": "take_snapshot", "quality": "high"}` |
| **motor** | `move`, `stop` | `{"action": "move", "direction": "clockwise", "duration": 5}` |
| **thermostat** | `set_temperature` | `{"action": "set_temperature", "target": 22.5}` |

---

## 🔍 Monitoring & Debugging

### Check MQTT Messages
```bash
# Subscribe to all device data
mosquitto_sub -h localhost -p 1883 -t "devices/+/data" -v

# Subscribe to commands
mosquitto_sub -h localhost -p 1883 -t "devices/+/commands" -v

# Subscribe to heartbeats
mosquitto_sub -h localhost -p 1883 -t "devices/+/heartbeat" -v
```

### API Endpoints Summary
- **GET** `/api/devices/gateways/` - List gateways
- **POST** `/api/devices/gateways/claim/` - Claim gateway
- **GET** `/api/devices/devices/` - List devices  
- **POST** `/api/devices/devices/` - Create device
- **POST** `/api/devices/devices/{id}/command/` - Send command
- **GET** `/api/devices/telemetry/` - Get telemetry data

This guide provides complete testing capabilities for your IoT platform! 🚀
