#!/bin/bash
# Multi-Gateway IoT Device Simulator
# Simulates devices from different gateways for testing multi-user scenarios

set -e

# Configuration
MQTT_HOST="localhost"
MQTT_PORT="1883"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

alice_log() {
    echo -e "${PURPLE}🏠 [ALICE] $1${NC}"
}

bob_log() {
    echo -e "${CYAN}🏢 [BOB] $1${NC}"
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

# Alice's Home Devices
simulate_alice_temperature() {
    local device_id="ALICE-TEMP-001"
    local gateway_id="ALICE-HOME-GW"
    
    while true; do
        local temp=$(echo "scale=1; 22 + ($RANDOM % 60 - 30) * 0.1" | bc)
        local humidity=$((45 + $RANDOM % 30))
        local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        
        local payload=$(cat <<EOF
{
  "gateway_id": "$gateway_id",
  "type": "temperature",
  "model": "DHT22",
  "name": "Alice Living Room Temp",
  "temperature": $temp,
  "humidity": $humidity,
  "timestamp": "$timestamp",
  "battery": $((80 + $RANDOM % 20)),
  "signal_strength": $((-25 - $RANDOM % 20))
}
EOF
        )
        
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
            -t "devices/$device_id/data" \
            -m "$payload" -q 1
        
        alice_log "Temp: ${temp}°C, Humidity: ${humidity}% [$device_id]"
        
        # Heartbeat occasionally
        if [ $((RANDOM % 8)) -eq 0 ]; then
            local heartbeat=$(cat <<EOF
{
  "status": "online",
  "gateway_id": "$gateway_id",
  "type": "temperature",
  "model": "DHT22",
  "name": "Alice Living Room Temp",
  "uptime": $((RANDOM % 86400))
}
EOF
            )
            mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
                -t "devices/$device_id/heartbeat" \
                -m "$heartbeat" -q 1
        fi
        
        sleep 12
    done
}

simulate_alice_smart_lock() {
    local device_id="ALICE-LOCK-001"
    local gateway_id="ALICE-HOME-GW"
    local state="locked"
    
    while true; do
        # Random lock/unlock (5% chance)
        if [ $((RANDOM % 20)) -eq 0 ]; then
            if [ "$state" = "locked" ]; then
                state="unlocked"
            else
                state="locked"
            fi
            
            local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
            
            local payload=$(cat <<EOF
{
  "gateway_id": "$gateway_id",
  "type": "lock",
  "model": "August Smart Lock",
  "name": "Alice Front Door Lock",
  "state": "$state",
  "timestamp": "$timestamp",
  "battery": $((60 + $RANDOM % 35)),
  "last_user": "alice",
  "access_method": "app"
}
EOF
            )
            
            mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
                -t "devices/$device_id/data" \
                -m "$payload" -q 1
            
            alice_log "Door ${state} [$device_id]"
        fi
        
        sleep 15
    done
}

simulate_alice_lights() {
    local device_id="ALICE-LIGHT-001"
    local gateway_id="ALICE-HOME-GW"
    local state="off"
    local brightness=0
    
    while true; do
        # Random state changes (8% chance)
        if [ $((RANDOM % 12)) -eq 0 ]; then
            if [ "$state" = "off" ]; then
                state="on"
                brightness=$((30 + $RANDOM % 70))
            else
                state="off"
                brightness=0
            fi
        fi
        
        local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        
        local payload=$(cat <<EOF
{
  "gateway_id": "$gateway_id",
  "type": "light",
  "model": "Philips Hue",
  "name": "Alice Bedroom Light",
  "state": "$state",
  "brightness": $brightness,
  "color": {"r": 255, "g": 255, "b": 255},
  "timestamp": "$timestamp",
  "power_usage": $([ "$state" = "on" ] && echo $(echo "scale=1; $brightness * 0.12" | bc) || echo "0")
}
EOF
        )
        
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
            -t "devices/$device_id/data" \
            -m "$payload" -q 1
        
        alice_log "Light: $state (${brightness}%) [$device_id]"
        
        sleep 18
    done
}

# Bob's Office Devices
simulate_bob_air_quality() {
    local device_id="BOB-AIR-001"
    local gateway_id="BOB-OFFICE-GW"
    
    while true; do
        local co2=$((400 + $RANDOM % 800))
        local pm25=$(echo "scale=1; 10 + ($RANDOM % 50)" | bc)
        local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        
        local payload=$(cat <<EOF
{
  "gateway_id": "$gateway_id",
  "type": "air_quality",
  "model": "Sensirion SPS30",
  "name": "Bob Office Air Monitor",
  "co2": $co2,
  "pm2_5": $pm25,
  "temperature": $(echo "scale=1; 20 + ($RANDOM % 80 - 40) * 0.1" | bc),
  "humidity": $((35 + $RANDOM % 40)),
  "timestamp": "$timestamp",
  "battery": $((70 + $RANDOM % 30))
}
EOF
        )
        
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
            -t "devices/$device_id/data" \
            -m "$payload" -q 1
        
        bob_log "CO2: ${co2}ppm, PM2.5: ${pm25}μg/m³ [$device_id]"
        
        # Heartbeat occasionally
        if [ $((RANDOM % 10)) -eq 0 ]; then
            local heartbeat=$(cat <<EOF
{
  "status": "online",
  "gateway_id": "$gateway_id",
  "type": "air_quality",
  "model": "Sensirion SPS30",
  "name": "Bob Office Air Monitor",
  "uptime": $((RANDOM % 86400))
}
EOF
            )
            mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
                -t "devices/$device_id/heartbeat" \
                -m "$heartbeat" -q 1
        fi
        
        sleep 20
    done
}

simulate_bob_security_camera() {
    local device_id="BOB-CAM-001"
    local gateway_id="BOB-OFFICE-GW"
    
    while true; do
        local recording=$([[ $((RANDOM % 6)) -eq 0 ]] && echo "true" || echo "false")
        local motion=$([[ $((RANDOM % 8)) -eq 0 ]] && echo "true" || echo "false")
        local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        
        local payload=$(cat <<EOF
{
  "gateway_id": "$gateway_id",
  "type": "camera",
  "model": "Hikvision DS-2CD2143G0-I",
  "name": "Bob Office Security Cam",
  "status": "online",
  "recording": $recording,
  "motion_detected": $motion,
  "resolution": "1080p",
  "fps": 30,
  "storage_used": $((RANDOM % 80 + 10)),
  "timestamp": "$timestamp",
  "night_vision": $([[ $(date +%H) -lt 7 || $(date +%H) -gt 19 ]] && echo "true" || echo "false")
}
EOF
        )
        
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
            -t "devices/$device_id/data" \
            -m "$payload" -q 1
        
        local status_msg="Camera: Online"
        [ "$recording" = "true" ] && status_msg="$status_msg, Recording"
        [ "$motion" = "true" ] && status_msg="$status_msg, Motion!"
        bob_log "$status_msg [$device_id]"
        
        sleep 25
    done
}

simulate_bob_smart_ac() {
    local device_id="BOB-AC-001"
    local gateway_id="BOB-OFFICE-GW"
    local target_temp=23
    local current_temp=$target_temp
    local mode="auto"
    local running=false
    
    while true; do
        # Simple AC logic
        if [ $(echo "$current_temp > $target_temp + 1" | bc) -eq 1 ]; then
            running=true
            mode="cooling"
        elif [ $(echo "$current_temp < $target_temp - 1" | bc) -eq 1 ]; then
            running=true
            mode="heating"
        else
            running=false
            mode="auto"
        fi
        
        # Adjust temperature based on AC
        if [ "$running" = "true" ]; then
            if [ "$mode" = "cooling" ]; then
                current_temp=$(echo "scale=1; $current_temp - 0.3" | bc)
            else
                current_temp=$(echo "scale=1; $current_temp + 0.3" | bc)
            fi
        else
            # Drift toward room temperature (25°C)
            current_temp=$(echo "scale=1; $current_temp + (25 - $current_temp) * 0.1" | bc)
        fi
        
        # Random target temp changes
        if [ $((RANDOM % 40)) -eq 0 ]; then
            target_temp=$((20 + RANDOM % 8))
        fi
        
        local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        
        local payload=$(cat <<EOF
{
  "gateway_id": "$gateway_id",
  "type": "hvac",
  "model": "Daikin FTX35KV1B",
  "name": "Bob Office AC Unit",
  "current_temperature": $current_temp,
  "target_temperature": $target_temp,
  "mode": "$mode",
  "running": $running,
  "fan_speed": $([ "$running" = "true" ] && echo $((2 + RANDOM % 3)) || echo "0"),
  "power_usage": $([ "$running" = "true" ] && echo $((1200 + RANDOM % 800)) || echo "15"),
  "timestamp": "$timestamp"
}
EOF
        )
        
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
            -t "devices/$device_id/data" \
            -m "$payload" -q 1
        
        bob_log "AC: ${current_temp}°C → ${target_temp}°C ($mode, $([ "$running" = "true" ] && echo "ON" || echo "OFF")) [$device_id]"
        
        sleep 30
    done
}

# Run specific gateway devices
run_alice_devices() {
    info "Starting Alice's home devices..."
    simulate_alice_temperature &
    simulate_alice_smart_lock &
    simulate_alice_lights &
    wait
}

run_bob_devices() {
    info "Starting Bob's office devices..."
    simulate_bob_air_quality &
    simulate_bob_security_camera &
    simulate_bob_smart_ac &
    wait
}

# Run all devices
run_all_devices() {
    info "Starting multi-gateway simulation..."
    echo ""
    alice_log "Starting Alice's home devices (ALICE-HOME-GW)"
    bob_log "Starting Bob's office devices (BOB-OFFICE-GW)"
    echo ""
    
    simulate_alice_temperature &
    simulate_alice_smart_lock &
    simulate_alice_lights &
    simulate_bob_air_quality &
    simulate_bob_security_camera &
    simulate_bob_smart_ac &
    
    info "All devices started. Press Ctrl+C to stop."
    wait
}

# Main function
main() {
    check_mosquitto
    
    if [ $# -eq 0 ]; then
        echo "🏠🏢 Multi-Gateway IoT Device Simulator"
        echo "Usage: $0 [alice|bob|all]"
        echo ""
        echo "Available options:"
        echo "  alice  - Simulate Alice's home devices (ALICE-HOME-GW)"
        echo "  bob    - Simulate Bob's office devices (BOB-OFFICE-GW)"
        echo "  all    - Simulate all devices from both gateways"
        echo ""
        echo "Devices simulated:"
        echo "  Alice's Home:"
        echo "    - Temperature sensor (ALICE-TEMP-001)"
        echo "    - Smart door lock (ALICE-LOCK-001)"
        echo "    - Smart lights (ALICE-LIGHT-001)"
        echo ""
        echo "  Bob's Office:"
        echo "    - Air quality monitor (BOB-AIR-001)"
        echo "    - Security camera (BOB-CAM-001)"
        echo "    - Smart AC unit (BOB-AC-001)"
        echo ""
        echo "Examples:"
        echo "  $0 alice"
        echo "  $0 bob"
        echo "  $0 all"
        exit 1
    fi
    
    case "$1" in
        "alice")
            run_alice_devices
            ;;
        "bob")
            run_bob_devices
            ;;
        "all")
            run_all_devices
            ;;
        *)
            echo "❌ Unknown option: $1"
            echo "Use: alice, bob, or all"
            exit 1
            ;;
    esac
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}🛑 Stopping all simulators...${NC}"; exit 0' INT

main "$@"
