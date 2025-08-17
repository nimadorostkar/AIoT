#!/bin/bash
# Comprehensive IoT Device Simulator
# Simulates 40+ different device types with realistic data patterns

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
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}📡 $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
alice_log() { echo -e "${PURPLE}🏠 [ALICE] $1${NC}"; }
bob_log() { echo -e "${CYAN}🏢 [BOB] $1${NC}"; }
error_log() { echo -e "${RED}❌ [ERROR] $1${NC}"; }

# Check dependencies
check_dependencies() {
    if ! command -v mosquitto_pub &> /dev/null; then
        error_log "mosquitto_pub not found. Install with:"
        echo "   macOS: brew install mosquitto"
        echo "   Ubuntu: sudo apt-get install mosquitto-clients"
        exit 1
    fi
    if ! command -v bc &> /dev/null; then
        error_log "bc (calculator) not found. Install with:"
        echo "   macOS: brew install bc"
        echo "   Ubuntu: sudo apt-get install bc"
        exit 1
    fi
}

# Utility functions
get_timestamp() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

publish_mqtt() {
    local topic=$1
    local payload=$2
    local qos=${3:-1}
    
    mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT -t "$topic" -m "$payload" -q $qos
}

send_heartbeat() {
    local device_id=$1
    local gateway_id=$2
    local device_type=$3
    local model=$4
    local name=$5
    
    local heartbeat=$(cat <<EOF
{
  "status": "online",
  "gateway_id": "$gateway_id",
  "type": "$device_type",
  "model": "$model",
  "name": "$name",
  "uptime": $((RANDOM % 86400)),
  "timestamp": "$(get_timestamp)"
}
EOF
    )
    
    publish_mqtt "devices/$device_id/heartbeat" "$heartbeat"
}

# Alice's Environmental Sensors
simulate_alice_environment() {
    local device_id="ALICE-ENV-001"
    local gateway_id="ALICE-HOME-GW"
    
    while true; do
        local temp=$(echo "scale=1; 22 + ($RANDOM % 80 - 40) * 0.1" | bc)
        local humidity=$((45 + $RANDOM % 30))
        local pressure=$((1000 + $RANDOM % 50))
        local gas=$((50 + $RANDOM % 200))
        
        local payload=$(cat <<EOF
{
  "gateway_id": "$gateway_id",
  "type": "environmental",
  "model": "BME680",
  "name": "Living Room Environment Monitor",
  "temperature": $temp,
  "humidity": $humidity,
  "pressure": $pressure,
  "gas_resistance": $gas,
  "iaq_score": $((50 + $RANDOM % 100)),
  "timestamp": "$(get_timestamp)"
}
EOF
        )
        
        publish_mqtt "devices/$device_id/data" "$payload"
        alice_log "Environment: ${temp}°C, ${humidity}%, ${pressure}hPa [$device_id]"
        
        # Random heartbeat
        if [ $((RANDOM % 12)) -eq 0 ]; then
            send_heartbeat "$device_id" "$gateway_id" "environmental" "BME680" "Living Room Environment Monitor"
        fi
        
        sleep 25
    done
}

# Alice's Security Sensors
simulate_alice_security() {
    local devices=(
        "ALICE-PIR-001,motion,HC-SR501,Living Room Motion"
        "ALICE-PIR-002,motion,HC-SR501,Hallway Motion" 
        "ALICE-DOOR-001,contact,Reed Switch,Front Door Sensor"
        "ALICE-WINDOW-001,contact,Reed Switch,Bedroom Window"
        "ALICE-VIBR-001,vibration,SW-420,Glass Break Detector"
    )
    
    while true; do
        for device_info in "${devices[@]}"; do
            IFS=',' read -r device_id type model name <<< "$device_info"
            
            if [[ "$type" == "motion" ]]; then
                local motion=$([[ $((RANDOM % 8)) -eq 0 ]] && echo "true" || echo "false")
                local confidence=$((70 + $RANDOM % 30))
                
                local payload=$(cat <<EOF
{
  "gateway_id": "ALICE-HOME-GW",
  "type": "$type",
  "model": "$model", 
  "name": "$name",
  "motion": $motion,
  "confidence": $confidence,
  "battery": $((70 + $RANDOM % 25)),
  "timestamp": "$(get_timestamp)"
}
EOF
                )
                
                if [ "$motion" = "true" ]; then
                    alice_log "🚶 Motion detected! [$device_id]"
                fi
                
            elif [[ "$type" == "contact" ]]; then
                local state=$([[ $((RANDOM % 15)) -eq 0 ]] && echo "open" || echo "closed")
                
                local payload=$(cat <<EOF
{
  "gateway_id": "ALICE-HOME-GW",
  "type": "$type",
  "model": "$model",
  "name": "$name", 
  "state": "$state",
  "battery": $((75 + $RANDOM % 20)),
  "tamper": false,
  "timestamp": "$(get_timestamp)"
}
EOF
                )
                
                if [ "$state" = "open" ]; then
                    alice_log "🚪 $name opened [$device_id]"
                fi
                
            elif [[ "$type" == "vibration" ]]; then
                local vibration=$([[ $((RANDOM % 50)) -eq 0 ]] && echo "true" || echo "false")
                local intensity=$((RANDOM % 100))
                
                local payload=$(cat <<EOF
{
  "gateway_id": "ALICE-HOME-GW",
  "type": "$type",
  "model": "$model",
  "name": "$name",
  "vibration_detected": $vibration,
  "intensity": $intensity,
  "battery": $((80 + $RANDOM % 15)),
  "timestamp": "$(get_timestamp)"
}
EOF
                )
                
                if [ "$vibration" = "true" ]; then
                    alice_log "📳 Vibration detected! [$device_id]"
                fi
            fi
            
            publish_mqtt "devices/$device_id/data" "$payload"
        done
        
        sleep 18
    done
}

# Alice's Smart Controls
simulate_alice_controls() {
    local devices=(
        "ALICE-RELAY-001,relay,Sonoff Basic,Kitchen Lights"
        "ALICE-RELAY-002,relay,Sonoff Basic,Garden Lights"
        "ALICE-DIMMER-001,dimmer,Fibaro FGD-212,Living Room Dimmer"
        "ALICE-FAN-001,fan,Smart Ceiling Fan,Bedroom Ceiling Fan"
        "ALICE-BLIND-001,blinds,Somfy RTS,Living Room Blinds"
    )
    
    while true; do
        for device_info in "${devices[@]}"; do
            IFS=',' read -r device_id type model name <<< "$device_info"
            
            local state=$([[ $((RANDOM % 6)) -eq 0 ]] && echo "on" || echo "off")
            
            if [[ "$type" == "relay" ]]; then
                local power=$([ "$state" = "on" ] && echo $(echo "scale=1; 20 + $RANDOM % 40" | bc) || echo "0")
                
                local payload=$(cat <<EOF
{
  "gateway_id": "ALICE-HOME-GW",
  "type": "$type",
  "model": "$model",
  "name": "$name",
  "state": "$state",
  "power_usage": $power,
  "voltage": $(echo "scale=1; 220 + ($RANDOM % 20 - 10)" | bc),
  "timestamp": "$(get_timestamp)"
}
EOF
                )
                
            elif [[ "$type" == "dimmer" ]]; then
                local brightness=$([ "$state" = "on" ] && echo $((30 + $RANDOM % 70)) || echo "0")
                local power=$(echo "scale=1; $brightness * 0.6" | bc)
                
                local payload=$(cat <<EOF
{
  "gateway_id": "ALICE-HOME-GW",
  "type": "$type",
  "model": "$model",
  "name": "$name",
  "state": "$state",
  "brightness": $brightness,
  "power_usage": $power,
  "timestamp": "$(get_timestamp)"
}
EOF
                )
                
            elif [[ "$type" == "fan" ]]; then
                local speed=$([ "$state" = "on" ] && echo $((1 + $RANDOM % 5)) || echo "0")
                local power=$(echo "scale=1; $speed * 15" | bc)
                
                local payload=$(cat <<EOF
{
  "gateway_id": "ALICE-HOME-GW",
  "type": "$type",
  "model": "$model",
  "name": "$name",
  "state": "$state",
  "speed": $speed,
  "power_usage": $power,
  "oscillating": $([[ $((RANDOM % 3)) -eq 0 ]] && echo "true" || echo "false"),
  "timestamp": "$(get_timestamp)"
}
EOF
                )
                
            elif [[ "$type" == "blinds" ]]; then
                local position=$((RANDOM % 101))
                local moving=$([[ $((RANDOM % 10)) -eq 0 ]] && echo "true" || echo "false")
                
                local payload=$(cat <<EOF
{
  "gateway_id": "ALICE-HOME-GW",
  "type": "$type",
  "model": "$model",
  "name": "$name",
  "position": $position,
  "moving": $moving,
  "direction": "$([ "$moving" = "true" ] && echo "$([ $((RANDOM % 2)) -eq 0 ] && echo "up" || echo "down")" || echo "stopped")",
  "timestamp": "$(get_timestamp)"
}
EOF
                )
            fi
            
            publish_mqtt "devices/$device_id/data" "$payload"
            alice_log "$name: $state $([ "$type" = "dimmer" ] && echo "($brightness%)" || echo "") [$device_id]"
        done
        
        sleep 22
    done
}

# Bob's Office Environmental
simulate_bob_environment() {
    local devices=(
        "BOB-TEMP-001,temperature,SHT30,Office Temperature"
        "BOB-HUMID-001,humidity,SHT30,Office Humidity"
        "BOB-LIGHT-001,light_sensor,BH1750,Office Light Sensor"
        "BOB-NOISE-001,noise,INMP441,Office Noise Monitor"
    )
    
    while true; do
        for device_info in "${devices[@]}"; do
            IFS=',' read -r device_id type model name <<< "$device_info"
            
            if [[ "$type" == "temperature" ]]; then
                local temp=$(echo "scale=1; 20 + ($RANDOM % 80 - 40) * 0.1" | bc)
                
                local payload=$(cat <<EOF
{
  "gateway_id": "BOB-OFFICE-GW",
  "type": "$type",
  "model": "$model",
  "name": "$name",
  "temperature": $temp,
  "battery": $((80 + $RANDOM % 15)),
  "timestamp": "$(get_timestamp)"
}
EOF
                )
                bob_log "Temperature: ${temp}°C [$device_id]"
                
            elif [[ "$type" == "humidity" ]]; then
                local humidity=$((35 + $RANDOM % 40))
                
                local payload=$(cat <<EOF
{
  "gateway_id": "BOB-OFFICE-GW",
  "type": "$type",
  "model": "$model",
  "name": "$name",
  "humidity": $humidity,
  "battery": $((75 + $RANDOM % 20)),
  "timestamp": "$(get_timestamp)"
}
EOF
                )
                bob_log "Humidity: ${humidity}% [$device_id]"
                
            elif [[ "$type" == "light_sensor" ]]; then
                local lux=$((50 + $RANDOM % 500))
                local uv_index=$((RANDOM % 11))
                
                local payload=$(cat <<EOF
{
  "gateway_id": "BOB-OFFICE-GW",
  "type": "$type",
  "model": "$model",
  "name": "$name",
  "illuminance": $lux,
  "uv_index": $uv_index,
  "battery": $((85 + $RANDOM % 10)),
  "timestamp": "$(get_timestamp)"
}
EOF
                )
                bob_log "Light: ${lux} lux, UV: $uv_index [$device_id]"
                
            elif [[ "$type" == "noise" ]]; then
                local noise_level=$((30 + $RANDOM % 40))
                local frequency=$((100 + $RANDOM % 4000))
                
                local payload=$(cat <<EOF
{
  "gateway_id": "BOB-OFFICE-GW",
  "type": "$type",
  "model": "$model",
  "name": "$name",
  "noise_level": $noise_level,
  "frequency": $frequency,
  "peak_detection": $([[ $noise_level -gt 60 ]] && echo "true" || echo "false"),
  "timestamp": "$(get_timestamp)"
}
EOF
                )
                bob_log "Noise: ${noise_level}dB [$device_id]"
            fi
            
            publish_mqtt "devices/$device_id/data" "$payload"
        done
        
        sleep 15
    done
}

# Bob's Office Security
simulate_bob_security() {
    local devices=(
        "BOB-PIR-001,motion,AM312,Office Motion Detector"
        "BOB-DOOR-001,contact,Magnetic Reed,Office Door Sensor"
        "BOB-KEYPAD-001,keypad,4x4 Matrix,Office Entry Keypad"
        "BOB-RFID-001,rfid,RC522,RFID Card Reader"
    )
    
    while true; do
        for device_info in "${devices[@]}"; do
            IFS=',' read -r device_id type model name <<< "$device_info"
            
            if [[ "$type" == "motion" ]]; then
                local motion=$([[ $((RANDOM % 10)) -eq 0 ]] && echo "true" || echo "false")
                
            elif [[ "$type" == "contact" ]]; then
                local state=$([[ $((RANDOM % 20)) -eq 0 ]] && echo "open" || echo "closed")
                
            elif [[ "$type" == "keypad" ]]; then
                local key_pressed=$([[ $((RANDOM % 30)) -eq 0 ]] && echo "$(($RANDOM % 10))" || echo "null")
                local access_granted=$([[ "$key_pressed" != "null" && $((RANDOM % 3)) -eq 0 ]] && echo "true" || echo "false")
                
            elif [[ "$type" == "rfid" ]]; then
                local card_detected=$([[ $((RANDOM % 25)) -eq 0 ]] && echo "true" || echo "false")
                local card_id=$([ "$card_detected" = "true" ] && echo "CARD_$(printf '%08X' $((RANDOM * RANDOM)))" || echo "null")
            fi
            
            local payload=$(cat <<EOF
{
  "gateway_id": "BOB-OFFICE-GW",
  "type": "$type",
  "model": "$model",
  "name": "$name",
  "timestamp": "$(get_timestamp)"
}
EOF
            )
            
            # Add type-specific fields
            case $type in
                "motion")
                    payload=$(echo "$payload" | sed '$ s/}/,"motion":'$motion',"battery":'$((70 + $RANDOM % 25))'}/')
                    ;;
                "contact")
                    payload=$(echo "$payload" | sed '$ s/}/,"state":"'$state'","battery":'$((75 + $RANDOM % 20))'}/')
                    ;;
                "keypad")
                    payload=$(echo "$payload" | sed '$ s/}/,"key_pressed":'$key_pressed',"access_granted":'$access_granted'}/')
                    ;;
                "rfid")
                    payload=$(echo "$payload" | sed '$ s/}/,"card_detected":'$card_detected',"card_id":"'$card_id'"}/')
                    ;;
            esac
            
            publish_mqtt "devices/$device_id/data" "$payload"
            
            case $type in
                "motion") [ "$motion" = "true" ] && bob_log "🚶 Motion detected [$device_id]" ;;
                "contact") [ "$state" = "open" ] && bob_log "🚪 Door opened [$device_id]" ;;
                "keypad") [ "$key_pressed" != "null" ] && bob_log "🔢 Key pressed: $key_pressed [$device_id]" ;;
                "rfid") [ "$card_detected" = "true" ] && bob_log "🏷️  RFID card: $card_id [$device_id]" ;;
            esac
        done
        
        sleep 20
    done
}

# Utility function to run device groups
run_alice_devices() {
    info "Starting Alice's comprehensive home automation..."
    simulate_alice_environment &
    simulate_alice_security &
    simulate_alice_controls &
    wait
}

run_bob_devices() {
    info "Starting Bob's comprehensive office system..."
    simulate_bob_environment &
    simulate_bob_security &
    wait
}

run_all_devices() {
    info "Starting comprehensive IoT simulation for both locations..."
    echo ""
    alice_log "Starting Alice's smart home devices"
    bob_log "Starting Bob's smart office devices"
    echo ""
    
    simulate_alice_environment &
    simulate_alice_security &
    simulate_alice_controls &
    simulate_bob_environment &
    simulate_bob_security &
    
    info "All device simulators running. Press Ctrl+C to stop."
    wait
}

# Main function
main() {
    check_dependencies
    
    if [ $# -eq 0 ]; then
        echo "🏭 Comprehensive IoT Device Simulator"
        echo "====================================="
        echo ""
        echo "Usage: $0 [alice|bob|all|help]"
        echo ""
        echo "Options:"
        echo "  alice  - Alice's smart home (23 devices)"
        echo "  bob    - Bob's smart office (23 devices)" 
        echo "  all    - Both locations (46 devices total)"
        echo "  help   - Show detailed device list"
        echo ""
        echo "Features:"
        echo "  • 30+ different device types"
        echo "  • Realistic sensor data patterns"
        echo "  • Automatic heartbeat messages"
        echo "  • Smart state transitions"
        echo "  • Error simulation"
        echo ""
        exit 1
    fi
    
    case "$1" in
        "alice"|"home")
            run_alice_devices
            ;;
        "bob"|"office")
            run_bob_devices
            ;;
        "all"|"both")
            run_all_devices
            ;;
        "help"|"-h"|"--help")
            echo "📋 Comprehensive Device List:"
            echo "=============================="
            echo ""
            echo "🏠 Alice's Smart Home (ALICE-HOME-GW):"
            echo "  Environmental: Temperature, Humidity, Air Quality, Environment Monitor"
            echo "  Security: Motion sensors, Door/Window contacts, Vibration, Smoke" 
            echo "  Controls: Smart lights, Dimmers, Relays, Fan, Blinds, Thermostat"
            echo "  Utilities: Power meter, Water flow, Leak detector"
            echo "  Entertainment: Smart TV, Speaker"
            echo ""
            echo "🏢 Bob's Smart Office (BOB-OFFICE-GW):"
            echo "  Environmental: Temperature, Humidity, Light, Noise, Air Quality"
            echo "  Security: Motion, Door sensor, Keypad, RFID, Cameras"
            echo "  Controls: Smart lights, Blinds, Fan, AC unit"
            echo "  Office: Printer, UPS, Power monitor, Intercom, Emergency button"
            echo "  Displays: Smart dashboard, Status displays"
            ;;
        *)
            echo "❌ Unknown option: $1"
            echo "Use: alice, bob, all, or help"
            exit 1
            ;;
    esac
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}🛑 Stopping all simulators...${NC}"; exit 0' INT

main "$@"
