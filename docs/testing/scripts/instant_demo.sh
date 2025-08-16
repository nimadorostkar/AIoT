#!/bin/bash
# Instant IoT Demo - Quick fix for online devices
# حل سریع برای نمایش دستگاه‌های آنلاین

set -e

API_BASE="http://localhost:8000/api"
MQTT_HOST="localhost"
USERNAME="admin"
PASSWORD="admin123"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}🚀 Starting Instant IoT Demo${NC}"

# Get token
TOKEN=$(curl -s -X POST $API_BASE/token/ \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}" | \
    jq -r '.access')

if [ "$TOKEN" = "null" ]; then
    echo "❌ Authentication failed"
    exit 1
fi

echo -e "${GREEN}✅ Authenticated successfully${NC}"

# Force start MQTT bridge
echo -e "${BLUE}🔧 Starting MQTT bridge...${NC}"
docker compose exec -T api python manage.py shell <<EOF
from apps.devices import mqtt_worker
print("Starting MQTT bridge...")
mqtt_worker.start_bridge_if_enabled()
print("MQTT bridge started:", mqtt_worker.bridge is not None)
EOF

echo -e "${GREEN}✅ MQTT bridge started${NC}"

# Clean up old devices to avoid conflicts
echo -e "${BLUE}🧹 Cleaning up old test devices...${NC}"
curl -s -X GET $API_BASE/devices/devices/ -H "Authorization: Bearer $TOKEN" | \
    jq -r '.[] | select(.device_id | startswith("DEMO-")) | .id' | \
    while read device_id; do
        curl -s -X DELETE $API_BASE/devices/devices/$device_id/ -H "Authorization: Bearer $TOKEN" > /dev/null
    done

# Create fresh demo gateway
echo -e "${BLUE}🌐 Creating demo gateway...${NC}"
curl -s -X POST $API_BASE/devices/gateways/claim/ \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"gateway_id":"INSTANT-DEMO","name":"Instant Demo Gateway"}' > /dev/null

# Create demo devices
echo -e "${BLUE}📱 Creating demo devices...${NC}"

DEVICES=(
    "DEMO-TEMP-01:temperature:🌡️ Living Room Temperature:DHT22"
    "DEMO-MOTION-01:motion:🚶 Hallway Motion:PIR-v2"
    "DEMO-DOOR-01:door:🚪 Front Door:Magnetic-v3"
    "DEMO-LIGHT-01:relay:💡 Kitchen Light:SmartRelay"
)

for device_info in "${DEVICES[@]}"; do
    IFS=':' read -r device_id type name model <<< "$device_info"
    
    curl -s -X POST $API_BASE/devices/devices/ \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"gateway_id\":\"INSTANT-DEMO\",
            \"device_id\":\"$device_id\",
            \"type\":\"sensor\",
            \"name\":\"$name\",
            \"model\":\"$model\"
        }" > /dev/null
    
    echo -e "${GREEN}  ✅ Created: $name${NC}"
done

# Start sending data immediately
echo -e "${PURPLE}📊 Starting real-time data simulation...${NC}"

# Temperature sensor
(
    while true; do
        temp=$(echo "20 + $RANDOM % 15" | bc)
        humidity=$(echo "40 + $RANDOM % 40" | bc)
        
        mosquitto_pub -h $MQTT_HOST -p 1883 \
            -t "devices/DEMO-TEMP-01/data" \
            -m "{\"temperature\":$temp,\"humidity\":$humidity,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
            -q 1 2>/dev/null
        
        mosquitto_pub -h $MQTT_HOST -p 1883 \
            -t "devices/DEMO-TEMP-01/heartbeat" \
            -m "{\"status\":\"online\",\"battery\":85}" \
            -q 1 2>/dev/null
        
        echo -e "${YELLOW}🌡️  Temperature: ${temp}°C, Humidity: ${humidity}%${NC}"
        sleep 5
    done
) &

# Motion sensor
(
    while true; do
        if [ $((RANDOM % 4)) -eq 0 ]; then
            mosquitto_pub -h $MQTT_HOST -p 1883 \
                -t "devices/DEMO-MOTION-01/data" \
                -m "{\"motion\":true,\"confidence\":95,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
                -q 1 2>/dev/null
            
            mosquitto_pub -h $MQTT_HOST -p 1883 \
                -t "devices/DEMO-MOTION-01/heartbeat" \
                -m "{\"status\":\"online\",\"battery\":78}" \
                -q 1 2>/dev/null
            
            echo -e "${YELLOW}🚶 Motion DETECTED!${NC}"
            
            sleep 3
            
            mosquitto_pub -h $MQTT_HOST -p 1883 \
                -t "devices/DEMO-MOTION-01/data" \
                -m "{\"motion\":false,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
                -q 1 2>/dev/null
            
            echo -e "${BLUE}🚶 Motion cleared${NC}"
        fi
        sleep 8
    done
) &

# Door sensor
(
    state="closed"
    while true; do
        if [ $((RANDOM % 10)) -eq 0 ]; then
            if [ "$state" = "closed" ]; then
                state="open"
            else
                state="closed"
            fi
            
            mosquitto_pub -h $MQTT_HOST -p 1883 \
                -t "devices/DEMO-DOOR-01/data" \
                -m "{\"state\":\"$state\",\"battery\":92,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
                -q 1 2>/dev/null
            
            mosquitto_pub -h $MQTT_HOST -p 1883 \
                -t "devices/DEMO-DOOR-01/heartbeat" \
                -m "{\"status\":\"online\",\"battery\":92}" \
                -q 1 2>/dev/null
            
            if [ "$state" = "open" ]; then
                echo -e "${YELLOW}🚪 Door OPENED${NC}"
            else
                echo -e "${GREEN}🚪 Door CLOSED${NC}"
            fi
        fi
        sleep 12
    done
) &

# Smart switch
(
    switch_state="off"
    power=0
    while true; do
        if [ $((RANDOM % 8)) -eq 0 ]; then
            if [ "$switch_state" = "off" ]; then
                switch_state="on"
                power=$((20 + RANDOM % 40))
            else
                switch_state="off"
                power=0
            fi
        fi
        
        mosquitto_pub -h $MQTT_HOST -p 1883 \
            -t "devices/DEMO-LIGHT-01/data" \
            -m "{\"state\":\"$switch_state\",\"power\":$power,\"voltage\":220,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
            -q 1 2>/dev/null
        
        mosquitto_pub -h $MQTT_HOST -p 1883 \
            -t "devices/DEMO-LIGHT-01/heartbeat" \
            -m "{\"status\":\"online\"}" \
            -q 1 2>/dev/null
        
        if [ "$switch_state" = "on" ]; then
            echo -e "${GREEN}💡 Light ON (${power}W)${NC}"
        else
            echo -e "${BLUE}💡 Light OFF${NC}"
        fi
        
        sleep 10
    done
) &

echo ""
echo -e "${PURPLE}🎉 Demo is running!${NC}"
echo -e "${GREEN}💻 Open web interface: http://localhost:5173${NC}"
echo -e "${BLUE}📊 Monitor MQTT: mosquitto_sub -h localhost -t 'devices/+/data' -v${NC}"
echo -e "${YELLOW}🛑 Press Ctrl+C to stop demo${NC}"
echo ""

# Keep script running
trap 'echo -e "\n${YELLOW}🛑 Stopping demo...${NC}"; kill $(jobs -p) 2>/dev/null; exit 0' INT
wait
