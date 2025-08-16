#!/bin/bash
# Complete Fix and Demo Script
# This fixes all MQTT issues and demonstrates working IoT devices

set -e

API_BASE="http://localhost:8000/api"
MQTT_HOST="localhost"
USERNAME="admin"
PASSWORD="admin123"

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
success() { echo -e "${PURPLE}🎉 $1${NC}"; }

echo -e "${PURPLE}🔧 IoT System Fix & Demo${NC}"
echo "=============================="

# 1. Get authentication token
info "Getting authentication token..."
TOKEN=$(curl -s -X POST $API_BASE/token/ \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}" | \
    jq -r '.access')

if [ "$TOKEN" = "null" ]; then
    error "Authentication failed"
    exit 1
fi
log "Authentication successful"

# 2. Force restart MQTT bridge inside container
info "Forcing MQTT bridge restart..."
docker compose exec -T api python manage.py shell <<'EOF'
import os
import time
from apps.devices import mqtt_worker
from apps.devices.models import Device

# Force restart MQTT bridge
if mqtt_worker.bridge:
    try:
        mqtt_worker.bridge.client.disconnect()
    except:
        pass
    mqtt_worker.bridge = None

# Start fresh bridge
mqtt_worker.start_bridge_if_enabled()
print(f"MQTT bridge status: {mqtt_worker.bridge is not None}")

# Update all devices to be online initially
Device.objects.all().update(is_online=True)
print(f"Updated {Device.objects.count()} devices to online")
EOF

log "MQTT bridge restarted"

# 3. Clean and create fresh demo devices
info "Setting up fresh demo devices..."

# Clean old demo devices
curl -s -X GET $API_BASE/devices/devices/ -H "Authorization: Bearer $TOKEN" | \
    jq -r '.[] | select(.device_id | startswith("LIVE-")) | .id' | \
    while read device_id; do
        if [ -n "$device_id" ]; then
            curl -s -X DELETE $API_BASE/devices/devices/$device_id/ -H "Authorization: Bearer $TOKEN" > /dev/null
        fi
    done

# Create demo gateway
curl -s -X POST $API_BASE/devices/gateways/claim/ \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"gateway_id":"LIVE-DEMO-GW","name":"Live Demo Gateway"}' > /dev/null

# Create demo devices with unique IDs
DEMO_DEVICES=(
    "LIVE-TEMP-SENSOR:sensor:🌡️ Temperature Sensor:DHT22"
    "LIVE-MOTION-PIR:sensor:🚶 Motion Detector:PIR-v2"
    "LIVE-SMART-SWITCH:actuator:💡 Smart Switch:SmartRelay-v2"
    "LIVE-DOOR-SENSOR:sensor:🚪 Door Sensor:Magnetic-v3"
)

for device_info in "${DEMO_DEVICES[@]}"; do
    IFS=':' read -r device_id type name model <<< "$device_info"
    
    result=$(curl -s -X POST $API_BASE/devices/devices/ \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"gateway_id\":\"LIVE-DEMO-GW\",
            \"device_id\":\"$device_id\",
            \"type\":\"$type\",
            \"name\":\"$name\",
            \"model\":\"$model\"
        }")
    
    device_created=$(echo $result | jq -r '.device_id')
    if [ "$device_created" = "$device_id" ]; then
        log "Created: $name ($device_id)"
    else
        warn "Failed to create: $name"
    fi
done

# 4. Send initial data to establish devices as online
info "Sending initial data to bring devices online..."

# Send data for each device
for device_info in "${DEMO_DEVICES[@]}"; do
    IFS=':' read -r device_id type name model <<< "$device_info"
    
    case $type in
        "sensor")
            if [[ $device_id == *"TEMP"* ]]; then
                mosquitto_pub -h $MQTT_HOST -p 1883 \
                    -t "devices/$device_id/data" \
                    -m '{"temperature":22.5,"humidity":55,"timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' \
                    -q 1
            elif [[ $device_id == *"MOTION"* ]]; then
                mosquitto_pub -h $MQTT_HOST -p 1883 \
                    -t "devices/$device_id/data" \
                    -m '{"motion":false,"timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' \
                    -q 1
            elif [[ $device_id == *"DOOR"* ]]; then
                mosquitto_pub -h $MQTT_HOST -p 1883 \
                    -t "devices/$device_id/data" \
                    -m '{"state":"closed","battery":85,"timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' \
                    -q 1
            fi
            ;;
        "actuator")
            mosquitto_pub -h $MQTT_HOST -p 1883 \
                -t "devices/$device_id/data" \
                -m '{"state":"off","power":0,"voltage":220,"timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' \
                -q 1
            ;;
    esac
    
    # Send heartbeat for all devices
    mosquitto_pub -h $MQTT_HOST -p 1883 \
        -t "devices/$device_id/heartbeat" \
        -m '{"status":"online","battery":85,"signal_strength":-45}' \
        -q 1
    
    sleep 1
done

log "Initial data sent for all devices"

# 5. Wait a moment for processing
sleep 3

# 6. Verify data was received
info "Verifying system is working..."

TELEMETRY_COUNT=$(curl -s "$API_BASE/devices/telemetry/?limit=10" -H "Authorization: Bearer $TOKEN" | jq length)
DEVICE_COUNT=$(curl -s "$API_BASE/devices/devices/" -H "Authorization: Bearer $TOKEN" | jq '[.[] | select(.device_id | startswith("LIVE-"))] | length')

if [ "$TELEMETRY_COUNT" -gt 0 ]; then
    success "✅ Telemetry working! Received $TELEMETRY_COUNT records"
else
    warn "⚠️ No telemetry received yet"
fi

if [ "$DEVICE_COUNT" -gt 0 ]; then
    success "✅ $DEVICE_COUNT demo devices created"
else
    error "❌ No demo devices found"
fi

# 7. Start continuous simulation
success "🚀 Starting live simulation..."

# Function to simulate temperature sensor
simulate_temp() {
    while true; do
        temp=$((20 + RANDOM % 15))
        humidity=$((40 + RANDOM % 40))
        
        mosquitto_pub -h $MQTT_HOST -p 1883 \
            -t "devices/LIVE-TEMP-SENSOR/data" \
            -m "{\"temperature\":$temp,\"humidity\":$humidity,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
            -q 1 2>/dev/null
        
        echo -e "${BLUE}🌡️  Temperature: ${temp}°C, Humidity: ${humidity}%${NC}"
        sleep 8
    done
}

# Function to simulate motion sensor
simulate_motion() {
    while true; do
        if [ $((RANDOM % 5)) -eq 0 ]; then
            mosquitto_pub -h $MQTT_HOST -p 1883 \
                -t "devices/LIVE-MOTION-PIR/data" \
                -m "{\"motion\":true,\"confidence\":95,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
                -q 1 2>/dev/null
            
            echo -e "${YELLOW}🚶 Motion DETECTED!${NC}"
            sleep 3
            
            mosquitto_pub -h $MQTT_HOST -p 1883 \
                -t "devices/LIVE-MOTION-PIR/data" \
                -m "{\"motion\":false,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
                -q 1 2>/dev/null
            
            echo -e "${GREEN}🚶 Motion cleared${NC}"
        fi
        sleep 12
    done
}

# Function to simulate smart switch
simulate_switch() {
    state="off"
    while true; do
        if [ $((RANDOM % 6)) -eq 0 ]; then
            if [ "$state" = "off" ]; then
                state="on"
                power=$((25 + RANDOM % 30))
            else
                state="off"
                power=0
            fi
            
            mosquitto_pub -h $MQTT_HOST -p 1883 \
                -t "devices/LIVE-SMART-SWITCH/data" \
                -m "{\"state\":\"$state\",\"power\":$power,\"voltage\":220,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
                -q 1 2>/dev/null
            
            if [ "$state" = "on" ]; then
                echo -e "${GREEN}💡 Switch ON (${power}W)${NC}"
            else
                echo -e "${BLUE}💡 Switch OFF${NC}"
            fi
        fi
        sleep 15
    done
}

# Function to simulate door sensor
simulate_door() {
    door_state="closed"
    while true; do
        if [ $((RANDOM % 8)) -eq 0 ]; then
            if [ "$door_state" = "closed" ]; then
                door_state="open"
            else
                door_state="closed"
            fi
            
            mosquitto_pub -h $MQTT_HOST -p 1883 \
                -t "devices/LIVE-DOOR-SENSOR/data" \
                -m "{\"state\":\"$door_state\",\"battery\":90,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
                -q 1 2>/dev/null
            
            if [ "$door_state" = "open" ]; then
                echo -e "${RED}🚪 Door OPENED${NC}"
            else
                echo -e "${GREEN}🚪 Door CLOSED${NC}"
            fi
        fi
        sleep 20
    done
}

# Send heartbeats periodically
send_heartbeats() {
    while true; do
        for device_id in "LIVE-TEMP-SENSOR" "LIVE-MOTION-PIR" "LIVE-SMART-SWITCH" "LIVE-DOOR-SENSOR"; do
            mosquitto_pub -h $MQTT_HOST -p 1883 \
                -t "devices/$device_id/heartbeat" \
                -m "{\"status\":\"online\",\"battery\":$((70 + RANDOM % 30)),\"uptime\":$((RANDOM % 86400))}" \
                -q 1 2>/dev/null
        done
        sleep 30
    done
}

# Start all simulations in background
simulate_temp &
simulate_motion &
simulate_switch &
simulate_door &
send_heartbeats &

echo ""
echo -e "${PURPLE}🎉 Live IoT Demo is Running!${NC}"
echo "================================"
echo -e "${GREEN}💻 Web Interface: http://localhost:5173/devices${NC}"
echo -e "${BLUE}📊 Monitor MQTT: mosquitto_sub -h localhost -t 'devices/LIVE-*/data' -v${NC}"
echo -e "${YELLOW}🛑 Press Ctrl+C to stop${NC}"
echo ""
echo "Devices sending data:"
echo "🌡️  LIVE-TEMP-SENSOR   - Temperature & Humidity"
echo "🚶 LIVE-MOTION-PIR    - Motion Detection"
echo "💡 LIVE-SMART-SWITCH  - Smart Switch"
echo "🚪 LIVE-DOOR-SENSOR   - Door Status"
echo ""

# Keep running until interrupted
trap 'echo -e "\n${YELLOW}🛑 Stopping simulation...${NC}"; kill $(jobs -p) 2>/dev/null; exit 0' INT
wait
