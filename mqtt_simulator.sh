#!/bin/bash
# MQTT Device Simulator
# Simulates various IoT devices sending telemetry data

set -e

# Configuration
MQTT_HOST="localhost"
MQTT_PORT="1883"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}📡 $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if mosquitto is available
check_mosquitto() {
    if ! command -v mosquitto_pub &> /dev/null; then
        echo "❌ mosquitto_pub not found. Install with:"
        echo "   macOS: brew install mosquitto"
        echo "   Ubuntu: sudo apt-get install mosquitto-clients"
        exit 1
    fi
}

# Smart Home Temperature Sensor
simulate_temperature_sensor() {
    local device_id="TEMP-001"
    local gateway_id="GATEWAY-001"
    local location="Living Room"
    
    while true; do
        # Generate realistic temperature (18-28°C with some randomness)
        local base_temp=23
        local variation=$(($RANDOM % 10 - 5))  # -5 to +5
        local temp=$(echo "scale=1; $base_temp + $variation * 0.1" | bc)
        
        # Generate humidity (40-80%)
        local humidity=$((40 + $RANDOM % 40))
        
        local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        
        local payload=$(cat <<EOF
{
  "gateway_id": "$gateway_id",
  "type": "temperature",
  "model": "DHT22",
  "name": "Living Room Temperature",
  "temperature": $temp,
  "humidity": $humidity,
  "location": "$location",
  "timestamp": "$timestamp",
  "battery": $((80 + $RANDOM % 20)),
  "signal_strength": $((-30 - $RANDOM % 30))
}
EOF
        )
        
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
            -t "devices/$device_id/data" \
            -m "$payload" -q 1
        
        log "Temperature: ${temp}°C, Humidity: ${humidity}% [$device_id]"
        
        # Send heartbeat occasionally
        if [ $((RANDOM % 10)) -eq 0 ]; then
            local heartbeat_payload=$(cat <<EOF
{
  "status": "online",
  "gateway_id": "$gateway_id",
  "type": "temperature",
  "model": "DHT22",
  "name": "Living Room Temperature",
  "uptime": $((RANDOM % 86400))
}
EOF
            )
            mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
                -t "devices/$device_id/heartbeat" \
                -m "$heartbeat_payload" -q 1
        fi
        
        sleep 10
    done
}

# Motion Sensor
simulate_motion_sensor() {
    local device_id="PIR-001"
    local gateway_id="GATEWAY-001"
    local location="Hallway"
    
    while true; do
        # Random motion detection (20% chance)
        if [ $((RANDOM % 5)) -eq 0 ]; then
            local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
            
            local payload=$(cat <<EOF
{
  "gateway_id": "$gateway_id",
  "type": "motion",
  "model": "PIR-HC-SR501",
  "name": "Hallway Motion Sensor",
  "motion": true,
  "location": "$location",
  "timestamp": "$timestamp",
  "confidence": $((70 + $RANDOM % 30)),
  "battery": $((60 + $RANDOM % 40))
}
EOF
            )
            
            mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
                -t "devices/$device_id/data" \
                -m "$payload" -q 1
            
            log "Motion detected! [$device_id]"
            
            # Motion cleared after 5 seconds
            sleep 5
            
            local clear_payload=$(cat <<EOF
{
  "gateway_id": "$gateway_id",
  "type": "motion",
  "model": "PIR-HC-SR501",
  "name": "Hallway Motion Sensor",
  "motion": false,
  "location": "$location",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
            )
            
            mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
                -t "devices/$device_id/data" \
                -m "$clear_payload" -q 1
            
            log "Motion cleared [$device_id]"
        fi
        
        # Send heartbeat occasionally
        if [ $((RANDOM % 15)) -eq 0 ]; then
            local heartbeat_payload=$(cat <<EOF
{
  "status": "online",
  "gateway_id": "$gateway_id",
  "type": "motion",
  "model": "PIR-HC-SR501",
  "name": "Hallway Motion Sensor",
  "uptime": $((RANDOM % 86400))
}
EOF
            )
            mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
                -t "devices/$device_id/heartbeat" \
                -m "$heartbeat_payload" -q 1
        fi
        
        sleep 8
    done
}

# Smart Switch Status
simulate_smart_switch() {
    local device_id="RELAY-001"
    local state="off"
    local power=0
    
    while true; do
        # Random state changes (10% chance)
        if [ $((RANDOM % 10)) -eq 0 ]; then
            if [ "$state" = "off" ]; then
                state="on"
                power=$(echo "scale=1; 15 + ($RANDOM % 20)" | bc)
            else
                state="off"
                power=0
            fi
        fi
        
        local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        
        local payload=$(cat <<EOF
{
  "state": "$state",
  "power": $power,
  "voltage": $(echo "scale=1; 220 + ($RANDOM % 20 - 10)" | bc),
  "current": $(echo "scale=2; $power / 220" | bc),
  "timestamp": "$timestamp",
  "total_energy": $((RANDOM % 1000)),
  "wifi_signal": $((-40 - $RANDOM % 30))
}
EOF
        )
        
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
            -t "devices/$device_id/data" \
            -m "$payload" -q 1
        
        log "Switch: $state, Power: ${power}W [$device_id]"
        
        sleep 15
    done
}

# Door/Window Sensor
simulate_door_sensor() {
    local device_id="DOOR-001"
    local state="closed"
    
    while true; do
        # Random door open/close (5% chance)
        if [ $((RANDOM % 20)) -eq 0 ]; then
            if [ "$state" = "closed" ]; then
                state="open"
            else
                state="closed"
            fi
            
            local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
            
            local payload=$(cat <<EOF
{
  "state": "$state",
  "timestamp": "$timestamp",
  "battery": $((70 + $RANDOM % 30)),
  "tamper": false,
  "signal_strength": $((-35 - $RANDOM % 25))
}
EOF
            )
            
            mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
                -t "devices/$device_id/data" \
                -m "$payload" -q 1
            
            log "Door $state [$device_id]"
        fi
        
        sleep 12
    done
}

# Security Camera Status
simulate_camera() {
    local device_id="CAM-001"
    
    while true; do
        local recording=$([[ $((RANDOM % 4)) -eq 0 ]] && echo "true" || echo "false")
        local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        
        local payload=$(cat <<EOF
{
  "status": "online",
  "recording": $recording,
  "resolution": "1080p",
  "fps": 30,
  "storage_used": $((RANDOM % 80 + 10)),
  "motion_detected": $([[ $((RANDOM % 8)) -eq 0 ]] && echo "true" || echo "false"),
  "timestamp": "$timestamp",
  "uptime": $((RANDOM % 86400))
}
EOF
        )
        
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
            -t "devices/$device_id/data" \
            -m "$payload" -q 1
        
        log "Camera status: $([ "$recording" = "true" ] && echo "Recording" || echo "Standby") [$device_id]"
        
        sleep 20
    done
}

# Light Sensor
simulate_light_sensor() {
    local device_id="LIGHT-001"
    
    while true; do
        # Simulate day/night cycle
        local hour=$(date +%H)
        local base_lux=50
        
        if [ $hour -ge 6 ] && [ $hour -le 18 ]; then
            # Daytime: 100-1000 lux
            base_lux=$((100 + RANDOM % 900))
        else
            # Nighttime: 0-50 lux
            base_lux=$((RANDOM % 50))
        fi
        
        local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        
        local payload=$(cat <<EOF
{
  "illuminance": $base_lux,
  "uv_index": $((RANDOM % 11)),
  "timestamp": "$timestamp",
  "battery": $((75 + $RANDOM % 25))
}
EOF
        )
        
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
            -t "devices/$device_id/data" \
            -m "$payload" -q 1
        
        log "Light: ${base_lux} lux [$device_id]"
        
        sleep 30
    done
}

# Smart Thermostat
simulate_thermostat() {
    local device_id="THERMO-001"
    local target_temp=22
    local current_temp=$target_temp
    local heating=false
    
    while true; do
        # Simple heating logic
        if [ $(echo "$current_temp < $target_temp - 1" | bc) -eq 1 ]; then
            heating=true
        elif [ $(echo "$current_temp > $target_temp + 1" | bc) -eq 1 ]; then
            heating=false
        fi
        
        # Adjust temperature based on heating
        if [ "$heating" = "true" ]; then
            current_temp=$(echo "scale=1; $current_temp + 0.2" | bc)
        else
            current_temp=$(echo "scale=1; $current_temp - 0.1" | bc)
        fi
        
        # Random target temp changes
        if [ $((RANDOM % 50)) -eq 0 ]; then
            target_temp=$((18 + RANDOM % 8))
        fi
        
        local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        
        local payload=$(cat <<EOF
{
  "current_temperature": $current_temp,
  "target_temperature": $target_temp,
  "heating": $heating,
  "mode": "auto",
  "timestamp": "$timestamp",
  "humidity": $((40 + RANDOM % 40)),
  "energy_usage": $([ "$heating" = "true" ] && echo $((800 + RANDOM % 400)) || echo $((20 + RANDOM % 30)))
}
EOF
        )
        
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
            -t "devices/$device_id/data" \
            -m "$payload" -q 1
        
        log "Thermostat: ${current_temp}°C → ${target_temp}°C ($([ "$heating" = "true" ] && echo "Heating" || echo "Idle")) [$device_id]"
        
        sleep 25
    done
}

# Run specific device type
run_device() {
    local device_type=$1
    
    case $device_type in
        "temperature")
            simulate_temperature_sensor
            ;;
        "motion")
            simulate_motion_sensor
            ;;
        "switch")
            simulate_smart_switch
            ;;
        "door")
            simulate_door_sensor
            ;;
        "camera")
            simulate_camera
            ;;
        "light")
            simulate_light_sensor
            ;;
        "thermostat")
            simulate_thermostat
            ;;
        *)
            echo "❌ Unknown device type: $device_type"
            echo "Available types: temperature, motion, switch, door, camera, light, thermostat"
            exit 1
            ;;
    esac
}

# Run all devices in parallel
run_all_devices() {
    info "Starting all device simulators..."
    
    simulate_temperature_sensor &
    simulate_motion_sensor &
    simulate_smart_switch &
    simulate_door_sensor &
    simulate_camera &
    simulate_light_sensor &
    simulate_thermostat &
    
    info "All simulators started. Press Ctrl+C to stop."
    wait
}

# Main function
main() {
    check_mosquitto
    
    if [ $# -eq 0 ]; then
        echo "🏠 IoT Device Simulator"
        echo "Usage: $0 [device_type|all]"
        echo ""
        echo "Available device types:"
        echo "  temperature  - Temperature/humidity sensor"
        echo "  motion       - PIR motion sensor"
        echo "  switch       - Smart switch/relay"
        echo "  door         - Door/window sensor"
        echo "  camera       - Security camera"
        echo "  light        - Light sensor"
        echo "  thermostat   - Smart thermostat"
        echo "  all          - Run all devices"
        echo ""
        echo "Examples:"
        echo "  $0 temperature"
        echo "  $0 all"
        exit 1
    fi
    
    if [ "$1" = "all" ]; then
        run_all_devices
    else
        run_device "$1"
    fi
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}🛑 Stopping simulators...${NC}"; exit 0' INT

main "$@"
