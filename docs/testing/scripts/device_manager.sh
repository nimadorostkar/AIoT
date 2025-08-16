#!/bin/bash
# IoT Device Plug & Play Manager
# شبیه‌سازی اتصال و قطع اتصال دستگاه‌ها به صورت real-time

set -e

# Configuration
API_BASE="http://localhost:8000/api"
MQTT_HOST="localhost"
MQTT_PORT="1883"
USERNAME="admin"
PASSWORD="admin123"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Global variables
TOKEN=""
DEVICE_PIDS=()

log() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

success() {
    echo -e "${PURPLE}🎉 $1${NC}"
}

device_info() {
    echo -e "${CYAN}📱 $1${NC}"
}

# Get authentication token
get_auth_token() {
    TOKEN=$(curl -s -X POST $API_BASE/token/ \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}" | \
        jq -r '.access')
    
    if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
        error "Failed to authenticate. Check if API is running."
        exit 1
    fi
}

# Check if gateway exists, create if not
ensure_gateway() {
    local gateway_id=$1
    local gateway_name=$2
    
    # Try to claim the gateway
    local result=$(curl -s -X POST $API_BASE/devices/gateways/claim/ \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"gateway_id\":\"$gateway_id\",\"name\":\"$gateway_name\"}")
    
    local created_id=$(echo $result | jq -r '.gateway_id')
    if [ "$created_id" = "$gateway_id" ]; then
        log "Gateway '$gateway_id' is ready"
    else
        error "Failed to setup gateway '$gateway_id'"
        echo $result
        exit 1
    fi
}

# Add device to system
add_device() {
    local gateway_id=$1
    local device_id=$2
    local device_type=$3
    local device_name=$4
    local device_model=$5
    
    local result=$(curl -s -X POST $API_BASE/devices/devices/ \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"gateway_id\":\"$gateway_id\",
            \"device_id\":\"$device_id\",
            \"type\":\"$device_type\",
            \"name\":\"$device_name\",
            \"model\":\"$device_model\"
        }")
    
    local created_id=$(echo $result | jq -r '.device_id')
    if [ "$created_id" = "$device_id" ]; then
        success "Device '$device_id' connected to gateway '$gateway_id'"
        device_info "📋 Name: $device_name | Type: $device_type | Model: $device_model"
    else
        error "Failed to connect device '$device_id'"
        echo $result
        return 1
    fi
}

# Remove device from system
remove_device() {
    local device_id=$1
    
    # Get device info first
    local devices=$(curl -s -X GET $API_BASE/devices/devices/ \
        -H "Authorization: Bearer $TOKEN")
    
    local device_pk=$(echo $devices | jq -r ".[] | select(.device_id==\"$device_id\") | .id")
    
    if [ "$device_pk" != "null" ] && [ -n "$device_pk" ]; then
        curl -s -X DELETE $API_BASE/devices/devices/$device_pk/ \
            -H "Authorization: Bearer $TOKEN" > /dev/null
        warn "Device '$device_id' disconnected and removed"
    else
        error "Device '$device_id' not found"
    fi
}

# Start device telemetry simulation
start_device_telemetry() {
    local device_id=$1
    local device_type=$2
    local interval=${3:-10}
    
    case $device_type in
        "temperature")
            start_temperature_sensor $device_id $interval &
            ;;
        "motion")
            start_motion_sensor $device_id $interval &
            ;;
        "door")
            start_door_sensor $device_id $interval &
            ;;
        "light")
            start_light_sensor $device_id $interval &
            ;;
        "relay"|"switch")
            start_smart_switch $device_id $interval &
            ;;
        "camera")
            start_camera $device_id $interval &
            ;;
        *)
            start_generic_sensor $device_id $interval &
            ;;
    esac
    
    DEVICE_PIDS+=($!)
    info "Started telemetry for $device_id (PID: $!)"
}

# Temperature sensor simulation
start_temperature_sensor() {
    local device_id=$1
    local interval=$2
    
    info "🌡️  Temperature sensor '$device_id' started (every ${interval}s)"
    
    while true; do
        local temp=$(echo "scale=1; 18 + ($RANDOM % 20)" | bc)
        local humidity=$(echo "40 + ($RANDOM % 40)" | bc)
        local battery=$(echo "60 + ($RANDOM % 40)" | bc)
        
        local payload=$(cat <<EOF
{
  "temperature": $temp,
  "humidity": $humidity,
  "battery": $battery,
  "signal_strength": $((-30 - $RANDOM % 30)),
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
        )
        
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
            -t "devices/$device_id/data" \
            -m "$payload" -q 1 2>/dev/null
        
        echo -e "${CYAN}🌡️  [$device_id] Temperature: ${temp}°C, Humidity: ${humidity}%${NC}"
        
        # Send heartbeat occasionally
        if [ $((RANDOM % 5)) -eq 0 ]; then
            mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
                -t "devices/$device_id/heartbeat" \
                -m "{\"status\":\"online\",\"battery\":$battery}" -q 1 2>/dev/null
        fi
        
        sleep $interval
    done
}

# Motion sensor simulation
start_motion_sensor() {
    local device_id=$1
    local interval=$2
    
    info "🚶 Motion sensor '$device_id' started (every ${interval}s)"
    
    while true; do
        # Random motion detection (30% chance)
        if [ $((RANDOM % 10)) -lt 3 ]; then
            local payload=$(cat <<EOF
{
  "motion": true,
  "confidence": $((70 + $RANDOM % 30)),
  "battery": $((70 + $RANDOM % 30)),
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
            )
            
            mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
                -t "devices/$device_id/data" \
                -m "$payload" -q 1 2>/dev/null
            
            echo -e "${YELLOW}🚶 [$device_id] Motion DETECTED!${NC}"
            
            # Motion cleared after few seconds
            sleep 3
            
            mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
                -t "devices/$device_id/data" \
                -m "{\"motion\":false,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" -q 1 2>/dev/null
            
            echo -e "${BLUE}🚶 [$device_id] Motion cleared${NC}"
        fi
        
        sleep $interval
    done
}

# Door sensor simulation
start_door_sensor() {
    local device_id=$1
    local interval=$2
    local state="closed"
    
    info "🚪 Door sensor '$device_id' started (every ${interval}s)"
    
    while true; do
        # Random door state change (20% chance)
        if [ $((RANDOM % 5)) -eq 0 ]; then
            if [ "$state" = "closed" ]; then
                state="open"
            else
                state="closed"
            fi
            
            local payload=$(cat <<EOF
{
  "state": "$state",
  "battery": $((80 + $RANDOM % 20)),
  "tamper": false,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
            )
            
            mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
                -t "devices/$device_id/data" \
                -m "$payload" -q 1 2>/dev/null
            
            if [ "$state" = "open" ]; then
                echo -e "${RED}🚪 [$device_id] Door OPENED${NC}"
            else
                echo -e "${GREEN}🚪 [$device_id] Door CLOSED${NC}"
            fi
        fi
        
        sleep $interval
    done
}

# Light sensor simulation
start_light_sensor() {
    local device_id=$1
    local interval=$2
    
    info "💡 Light sensor '$device_id' started (every ${interval}s)"
    
    while true; do
        local hour=$(date +%H)
        local lux
        
        # Simulate day/night cycle
        if [ $hour -ge 6 ] && [ $hour -le 18 ]; then
            lux=$((200 + RANDOM % 800))  # Daytime
        else
            lux=$((0 + RANDOM % 100))    # Nighttime
        fi
        
        local payload=$(cat <<EOF
{
  "illuminance": $lux,
  "uv_index": $((RANDOM % 12)),
  "battery": $((70 + $RANDOM % 30)),
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
        )
        
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
            -t "devices/$device_id/data" \
            -m "$payload" -q 1 2>/dev/null
        
        echo -e "${YELLOW}💡 [$device_id] Light: ${lux} lux${NC}"
        
        sleep $interval
    done
}

# Smart switch simulation
start_smart_switch() {
    local device_id=$1
    local interval=$2
    local state="off"
    local power=0
    
    info "🔌 Smart switch '$device_id' started (every ${interval}s)"
    
    while true; do
        # Random state change (15% chance)
        if [ $((RANDOM % 7)) -eq 0 ]; then
            if [ "$state" = "off" ]; then
                state="on"
                power=$(echo "scale=1; 20 + ($RANDOM % 50)" | bc)
            else
                state="off"
                power=0
            fi
        fi
        
        local payload=$(cat <<EOF
{
  "state": "$state",
  "power": $power,
  "voltage": $(echo "scale=1; 220 + ($RANDOM % 20 - 10)" | bc),
  "energy_total": $((RANDOM % 1000)),
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
        )
        
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
            -t "devices/$device_id/data" \
            -m "$payload" -q 1 2>/dev/null
        
        if [ "$state" = "on" ]; then
            echo -e "${GREEN}🔌 [$device_id] Switch ON (${power}W)${NC}"
        else
            echo -e "${BLUE}🔌 [$device_id] Switch OFF${NC}"
        fi
        
        sleep $interval
    done
}

# Camera simulation
start_camera() {
    local device_id=$1
    local interval=$2
    
    info "📹 Camera '$device_id' started (every ${interval}s)"
    
    while true; do
        local recording=$([[ $((RANDOM % 4)) -eq 0 ]] && echo "true" || echo "false")
        local motion=$([[ $((RANDOM % 6)) -eq 0 ]] && echo "true" || echo "false")
        
        local payload=$(cat <<EOF
{
  "status": "online",
  "recording": $recording,
  "motion_detected": $motion,
  "resolution": "1080p",
  "storage_used": $((20 + RANDOM % 60)),
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
        )
        
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
            -t "devices/$device_id/data" \
            -m "$payload" -q 1 2>/dev/null
        
        local status_text="Online"
        [ "$recording" = "true" ] && status_text="Recording"
        [ "$motion" = "true" ] && status_text="$status_text + Motion"
        
        echo -e "${PURPLE}📹 [$device_id] $status_text${NC}"
        
        sleep $interval
    done
}

# Generic sensor simulation
start_generic_sensor() {
    local device_id=$1
    local interval=$2
    
    info "📊 Generic sensor '$device_id' started (every ${interval}s)"
    
    while true; do
        local value=$(echo "scale=2; ($RANDOM % 1000) / 10" | bc)
        
        local payload=$(cat <<EOF
{
  "value": $value,
  "unit": "units",
  "battery": $((60 + $RANDOM % 40)),
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
        )
        
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
            -t "devices/$device_id/data" \
            -m "$payload" -q 1 2>/dev/null
        
        echo -e "${CYAN}📊 [$device_id] Value: $value${NC}"
        
        sleep $interval
    done
}

# Stop all device processes
stop_all_devices() {
    if [ ${#DEVICE_PIDS[@]} -gt 0 ]; then
        warn "Stopping all device simulations..."
        for pid in "${DEVICE_PIDS[@]}"; do
            kill $pid 2>/dev/null || true
        done
        DEVICE_PIDS=()
        log "All devices stopped"
    fi
}

# Show help
show_help() {
    echo -e "${BLUE}🏠 IoT Device Plug & Play Manager${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "  $0 connect <gateway_id> <device_id> <type> [name] [model] [interval]"
    echo "  $0 disconnect <device_id>"
    echo "  $0 list"
    echo "  $0 status <device_id>"
    echo "  $0 demo"
    echo ""
    echo -e "${YELLOW}Device Types:${NC}"
    echo "  temperature  - Temperature/humidity sensor"
    echo "  motion       - PIR motion detector"
    echo "  door         - Door/window sensor"
    echo "  light        - Light/illuminance sensor"
    echo "  relay        - Smart switch/relay"
    echo "  camera       - Security camera"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 connect HOME-GW-001 TEMP-001 temperature"
    echo "  $0 connect HOME-GW-001 PIR-001 motion \"Hallway Motion\" PIR-v2 5"
    echo "  $0 disconnect TEMP-001"
    echo "  $0 demo"
}

# Connect device
connect_device() {
    local gateway_id=$1
    local device_id=$2
    local device_type=$3
    local device_name=${4:-"$device_type Sensor"}
    local device_model=${5:-"Generic-v1"}
    local interval=${6:-10}
    
    if [ -z "$gateway_id" ] || [ -z "$device_id" ] || [ -z "$device_type" ]; then
        error "Missing required parameters"
        show_help
        exit 1
    fi
    
    info "🔗 Connecting device '$device_id' to gateway '$gateway_id'..."
    
    get_auth_token
    ensure_gateway "$gateway_id" "Auto Gateway"
    
    if add_device "$gateway_id" "$device_id" "$device_type" "$device_name" "$device_model"; then
        start_device_telemetry "$device_id" "$device_type" "$interval"
        success "Device '$device_id' is now ONLINE and sending data!"
        info "💻 Check web interface: http://localhost:5173"
        info "🛑 Press Ctrl+C to disconnect device"
        
        # Keep running until interrupted
        trap 'stop_all_devices; warn "Device $device_id disconnected"; exit 0' INT
        wait
    fi
}

# Disconnect device
disconnect_device() {
    local device_id=$1
    
    if [ -z "$device_id" ]; then
        error "Device ID required"
        exit 1
    fi
    
    get_auth_token
    remove_device "$device_id"
}

# List devices
list_devices() {
    get_auth_token
    
    info "📋 Listing all devices..."
    
    local devices=$(curl -s -X GET $API_BASE/devices/devices/ \
        -H "Authorization: Bearer $TOKEN")
    
    echo $devices | jq -r '.[] | "📱 \(.device_id) | \(.type) | \(.name) | Gateway: \(.gateway_id) | Online: \(.is_online)"'
}

# Show device status
device_status() {
    local device_id=$1
    
    if [ -z "$device_id" ]; then
        error "Device ID required"
        exit 1
    fi
    
    get_auth_token
    
    local devices=$(curl -s -X GET $API_BASE/devices/devices/ \
        -H "Authorization: Bearer $TOKEN")
    
    local device=$(echo $devices | jq -r ".[] | select(.device_id==\"$device_id\")")
    
    if [ "$device" != "" ]; then
        echo -e "${CYAN}📱 Device Status: $device_id${NC}"
        echo $device | jq .
    else
        error "Device '$device_id' not found"
    fi
}

# Demo mode - connect multiple devices
demo_mode() {
    info "🎬 Starting demo mode..."
    
    get_auth_token
    ensure_gateway "DEMO-GW-001" "Demo Gateway"
    
    # Demo devices
    declare -a DEMO_DEVICES=(
        "DEMO-GW-001:TEMP-LIVING:temperature:Living Room Temperature:DHT22:8"
        "DEMO-GW-001:PIR-HALL:motion:Hallway Motion Sensor:PIR-v2:12"
        "DEMO-GW-001:DOOR-FRONT:door:Front Door Sensor:Magnetic-v3:15"
        "DEMO-GW-001:LIGHT-OUT:light:Outdoor Light Sensor:BH1750:20"
        "DEMO-GW-001:RELAY-KITCHEN:relay:Kitchen Light Switch:SmartRelay:10"
    )
    
    success "🏠 Connecting demo smart home devices..."
    
    for device_config in "${DEMO_DEVICES[@]}"; do
        IFS=':' read -r gateway_id device_id device_type device_name device_model interval <<< "$device_config"
        
        if add_device "$gateway_id" "$device_id" "$device_type" "$device_name" "$device_model"; then
            start_device_telemetry "$device_id" "$device_type" "$interval"
            sleep 1
        fi
    done
    
    success "🎉 Demo devices are now ONLINE!"
    info "💻 Open web interface: http://localhost:5173"
    info "📊 Watch telemetry: mosquitto_sub -h localhost -t 'devices/+/data' -v"
    info "🛑 Press Ctrl+C to stop demo"
    
    trap 'stop_all_devices; warn "Demo stopped"; exit 0' INT
    wait
}

# Main function
main() {
    # Check dependencies
    if ! command -v mosquitto_pub &> /dev/null; then
        error "mosquitto_pub not found. Install with: brew install mosquitto"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        error "jq not found. Install with: brew install jq"
        exit 1
    fi
    
    case "${1:-help}" in
        "connect")
            connect_device "$2" "$3" "$4" "$5" "$6" "$7"
            ;;
        "disconnect")
            disconnect_device "$2"
            ;;
        "list")
            list_devices
            ;;
        "status")
            device_status "$2"
            ;;
        "demo")
            demo_mode
            ;;
        *)
            show_help
            ;;
    esac
}

main "$@"
