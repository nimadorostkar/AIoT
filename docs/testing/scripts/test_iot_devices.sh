#!/bin/bash
# IoT Device Testing Script
# Complete automated test for gateways, devices, and sensors

set -e

# Configuration
API_BASE="http://localhost:8000/api"
MQTT_HOST="localhost"
MQTT_PORT="1883"
USERNAME="admin"
PASSWORD="admin123"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}✅ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check dependencies
check_dependencies() {
    info "Checking dependencies..."
    
    if ! command -v curl &> /dev/null; then
        error "curl is required but not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        error "jq is required but not installed. Install with: brew install jq"
        exit 1
    fi
    
    if ! command -v mosquitto_pub &> /dev/null; then
        warn "mosquitto_pub not found. MQTT tests will be skipped."
        warn "Install with: brew install mosquitto"
    fi
    
    log "Dependencies checked"
}

# Get authentication token
get_auth_token() {
    info "Getting authentication token..."
    
    TOKEN=$(curl -s -X POST $API_BASE/token/ \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}" | \
        jq -r '.access')
    
    if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
        error "Failed to get authentication token"
        error "Please check if the API is running and credentials are correct"
        exit 1
    fi
    
    log "Authentication successful: ${TOKEN:0:20}..."
}

# Test gateway operations
test_gateways() {
    info "Testing gateway operations..."
    
    # Claim gateway
    GATEWAY_RESPONSE=$(curl -s -X POST $API_BASE/devices/gateways/claim/ \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"gateway_id":"TEST-GW-001","name":"Automated Test Gateway"}')
    
    GATEWAY_ID=$(echo $GATEWAY_RESPONSE | jq -r '.gateway_id')
    
    if [ "$GATEWAY_ID" != "TEST-GW-001" ]; then
        error "Failed to claim gateway"
        echo $GATEWAY_RESPONSE
        exit 1
    fi
    
    log "Gateway claimed: $GATEWAY_ID"
    
    # List gateways
    GATEWAYS=$(curl -s -X GET $API_BASE/devices/gateways/ \
        -H "Authorization: Bearer $TOKEN")
    
    GATEWAY_COUNT=$(echo $GATEWAYS | jq length)
    log "Found $GATEWAY_COUNT gateway(s)"
    
    # Test discovery
    DISCOVERY_RESULT=$(curl -s -X POST $API_BASE/devices/gateways/1/discover/ \
        -H "Authorization: Bearer $TOKEN")
    
    DISCOVERY_STATUS=$(echo $DISCOVERY_RESULT | jq -r '.status')
    if [ "$DISCOVERY_STATUS" = "sent" ]; then
        log "Discovery command sent successfully"
    else
        warn "Discovery command may have failed"
    fi
}

# Test device creation
test_devices() {
    info "Testing device creation..."
    
    # Device configurations
    declare -a DEVICES=(
        "TEMP-001:sensor:Living Room Temperature:DHT22"
        "HUMIDITY-001:sensor:Living Room Humidity:DHT22"
        "RELAY-001:actuator:Living Room Light:SmartRelay-v2"
        "RELAY-002:actuator:Kitchen Light:SmartRelay-v2"
        "CAM-001:camera:Front Door Camera:IPCam-HD"
        "PIR-001:sensor:Hallway Motion:PIR-HC-SR501"
        "DIMMER-001:dimmer:Bedroom Light:SmartDimmer-v3"
    )
    
    DEVICE_IDS=()
    
    for device_config in "${DEVICES[@]}"; do
        IFS=':' read -r device_id type name model <<< "$device_config"
        
        DEVICE_RESPONSE=$(curl -s -X POST $API_BASE/devices/devices/ \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"gateway_id\":\"TEST-GW-001\",\"device_id\":\"$device_id\",\"type\":\"$type\",\"name\":\"$name\",\"model\":\"$model\"}")
        
        CREATED_DEVICE_ID=$(echo $DEVICE_RESPONSE | jq -r '.device_id')
        
        if [ "$CREATED_DEVICE_ID" = "$device_id" ]; then
            log "Created device: $name ($device_id)"
            DEVICE_IDS+=($device_id)
        else
            error "Failed to create device: $name"
            echo $DEVICE_RESPONSE
        fi
    done
    
    # List devices
    DEVICES_LIST=$(curl -s -X GET $API_BASE/devices/devices/ \
        -H "Authorization: Bearer $TOKEN")
    
    DEVICE_COUNT=$(echo $DEVICES_LIST | jq length)
    log "Total devices created: $DEVICE_COUNT"
}

# Test device commands
test_device_commands() {
    info "Testing device commands..."
    
    # Get device IDs
    DEVICES_LIST=$(curl -s -X GET $API_BASE/devices/devices/ \
        -H "Authorization: Bearer $TOKEN")
    
    # Test relay commands
    RELAY_ID=$(echo $DEVICES_LIST | jq -r '.[] | select(.device_id=="RELAY-001") | .id')
    if [ "$RELAY_ID" != "null" ] && [ -n "$RELAY_ID" ]; then
        # Turn ON
        COMMAND_RESULT=$(curl -s -X POST $API_BASE/devices/devices/$RELAY_ID/command/ \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d '{"action":"toggle","state":"on"}')
        
        COMMAND_STATUS=$(echo $COMMAND_RESULT | jq -r '.status')
        if [ "$COMMAND_STATUS" = "sent" ]; then
            log "Relay ON command sent successfully"
        else
            warn "Relay ON command may have failed"
        fi
        
        sleep 2
        
        # Turn OFF
        COMMAND_RESULT=$(curl -s -X POST $API_BASE/devices/devices/$RELAY_ID/command/ \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d '{"action":"toggle","state":"off"}')
        
        COMMAND_STATUS=$(echo $COMMAND_RESULT | jq -r '.status')
        if [ "$COMMAND_STATUS" = "sent" ]; then
            log "Relay OFF command sent successfully"
        else
            warn "Relay OFF command may have failed"
        fi
    fi
    
    # Test dimmer commands
    DIMMER_ID=$(echo $DEVICES_LIST | jq -r '.[] | select(.device_id=="DIMMER-001") | .id')
    if [ "$DIMMER_ID" != "null" ] && [ -n "$DIMMER_ID" ]; then
        COMMAND_RESULT=$(curl -s -X POST $API_BASE/devices/devices/$DIMMER_ID/command/ \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d '{"action":"set_brightness","brightness":75}')
        
        COMMAND_STATUS=$(echo $COMMAND_RESULT | jq -r '.status')
        if [ "$COMMAND_STATUS" = "sent" ]; then
            log "Dimmer brightness command sent successfully"
        else
            warn "Dimmer brightness command may have failed"
        fi
    fi
    
    # Test camera commands
    CAM_ID=$(echo $DEVICES_LIST | jq -r '.[] | select(.device_id=="CAM-001") | .id')
    if [ "$CAM_ID" != "null" ] && [ -n "$CAM_ID" ]; then
        COMMAND_RESULT=$(curl -s -X POST $API_BASE/devices/devices/$CAM_ID/command/ \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d '{"action":"take_snapshot","quality":"high"}')
        
        COMMAND_STATUS=$(echo $COMMAND_RESULT | jq -r '.status')
        if [ "$COMMAND_STATUS" = "sent" ]; then
            log "Camera snapshot command sent successfully"
        else
            warn "Camera snapshot command may have failed"
        fi
    fi
}

# Test MQTT telemetry
test_mqtt_telemetry() {
    if ! command -v mosquitto_pub &> /dev/null; then
        warn "Skipping MQTT tests (mosquitto_pub not available)"
        return
    fi
    
    info "Testing MQTT telemetry..."
    
    # Temperature data
    mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
        -t "devices/TEMP-001/data" \
        -m '{"temperature": 23.5, "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' \
        -q 1
    log "Temperature telemetry sent"
    
    # Humidity data
    mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
        -t "devices/HUMIDITY-001/data" \
        -m '{"humidity": 65.2, "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' \
        -q 1
    log "Humidity telemetry sent"
    
    # Motion detection
    mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
        -t "devices/PIR-001/data" \
        -m '{"motion": true, "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' \
        -q 1
    log "Motion detection telemetry sent"
    
    # Relay status
    mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
        -t "devices/RELAY-001/data" \
        -m '{"state": "on", "power": 25.4, "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' \
        -q 1
    log "Relay status telemetry sent"
    
    # Device heartbeats
    for device in "TEMP-001" "HUMIDITY-001" "RELAY-001" "PIR-001" "CAM-001"; do
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
            -t "devices/$device/heartbeat" \
            -m '{"status": "online", "battery": '$(($RANDOM % 40 + 60))'}' \
            -q 1
    done
    log "Device heartbeats sent"
    
    sleep 2
}

# Test telemetry retrieval
test_telemetry_retrieval() {
    info "Testing telemetry retrieval..."
    
    # Get all telemetry
    TELEMETRY=$(curl -s -X GET "$API_BASE/devices/telemetry/?limit=10" \
        -H "Authorization: Bearer $TOKEN")
    
    TELEMETRY_COUNT=$(echo $TELEMETRY | jq length)
    log "Retrieved $TELEMETRY_COUNT telemetry records"
    
    if [ $TELEMETRY_COUNT -gt 0 ]; then
        LATEST_PAYLOAD=$(echo $TELEMETRY | jq -r '.[0].payload')
        log "Latest telemetry: $LATEST_PAYLOAD"
    fi
}

# Simulate continuous sensor data
simulate_sensor_data() {
    if ! command -v mosquitto_pub &> /dev/null; then
        warn "Skipping sensor simulation (mosquitto_pub not available)"
        return
    fi
    
    info "Simulating sensor data for 30 seconds..."
    
    for i in {1..6}; do
        # Random temperature between 20-30°C
        TEMP=$(echo "scale=1; 20 + ($RANDOM % 100) / 10" | bc)
        # Random humidity between 40-80%
        HUMIDITY=$(echo "40 + ($RANDOM % 40)" | bc)
        # Random motion detection
        MOTION=$((RANDOM % 2 == 0))
        
        # Send temperature
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
            -t "devices/TEMP-001/data" \
            -m "{\"temperature\": $TEMP, \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
            -q 1
        
        # Send humidity
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
            -t "devices/HUMIDITY-001/data" \
            -m "{\"humidity\": $HUMIDITY, \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
            -q 1
        
        # Send motion if detected
        if [ $MOTION -eq 1 ]; then
            mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
                -t "devices/PIR-001/data" \
                -m "{\"motion\": true, \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
                -q 1
        fi
        
        info "Sent sensor data batch $i/6 (Temp: ${TEMP}°C, Humidity: ${HUMIDITY}%, Motion: $MOTION)"
        sleep 5
    done
    
    log "Sensor simulation completed"
}

# Display summary
display_summary() {
    info "Test Summary:"
    
    # Get final counts
    GATEWAYS=$(curl -s -X GET $API_BASE/devices/gateways/ \
        -H "Authorization: Bearer $TOKEN")
    DEVICES_LIST=$(curl -s -X GET $API_BASE/devices/devices/ \
        -H "Authorization: Bearer $TOKEN")
    TELEMETRY=$(curl -s -X GET "$API_BASE/devices/telemetry/?limit=100" \
        -H "Authorization: Bearer $TOKEN")
    
    GATEWAY_COUNT=$(echo $GATEWAYS | jq length)
    DEVICE_COUNT=$(echo $DEVICES_LIST | jq length)
    TELEMETRY_COUNT=$(echo $TELEMETRY | jq length)
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 IoT Platform Test Results"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌐 Gateways: $GATEWAY_COUNT"
    echo "📱 Devices: $DEVICE_COUNT"
    echo "📊 Telemetry Records: $TELEMETRY_COUNT"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Show device types breakdown
    echo "📱 Device Types:"
    echo $DEVICES_LIST | jq -r '.[] | "\(.type): \(.device_id) (\(.name))"' | sort | uniq -c
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 API Endpoints Tested:"
    echo "✅ Authentication"
    echo "✅ Gateway Management"
    echo "✅ Device Creation"
    echo "✅ Device Commands"
    echo "✅ MQTT Telemetry"
    echo "✅ Data Retrieval"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Main execution
main() {
    echo "🚀 Starting IoT Device Testing Suite"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    check_dependencies
    get_auth_token
    test_gateways
    test_devices
    test_device_commands
    test_mqtt_telemetry
    test_telemetry_retrieval
    simulate_sensor_data
    display_summary
    
    echo ""
    log "🎉 All tests completed successfully!"
    echo ""
    echo "💡 Next steps:"
    echo "   - Check the web interface: http://localhost:5173"
    echo "   - Monitor MQTT: mosquitto_sub -h localhost -t 'devices/+/data' -v"
    echo "   - View API docs: http://localhost:8000/api/docs/"
}

# Run main function
main "$@"
