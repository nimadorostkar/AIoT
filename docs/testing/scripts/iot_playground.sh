#!/bin/bash
# IoT Playground - Interactive Device Manager
# محیط تعاملی برای مدیریت دستگاه‌های IoT

set -e

# Configuration
API_BASE="http://localhost:8000/api"
MQTT_HOST="localhost"
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

TOKEN=""

# Utility functions
log() { echo -e "${GREEN}✅ $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
success() { echo -e "${PURPLE}🎉 $1${NC}"; }

# Get authentication token
get_auth_token() {
    if [ -z "$TOKEN" ]; then
        TOKEN=$(curl -s -X POST $API_BASE/token/ \
            -H "Content-Type: application/json" \
            -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}" | \
            jq -r '.access')
        
        if [ "$TOKEN" = "null" ]; then
            error "خطا در احراز هویت - لطفاً بررسی کنید که API در حال اجرا باشد"
            exit 1
        fi
    fi
}

# Show main menu
show_menu() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                    🏠 IoT Playground                       ║"
    echo "║                  محیط تعاملی IoT                          ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${YELLOW}انتخاب کنید:${NC}"
    echo ""
    echo "1️⃣  اتصال سنسور جدید (Connect New Device)"
    echo "2️⃣  مشاهده دستگاه‌های متصل (List Connected Devices)"
    echo "3️⃣  قطع اتصال دستگاه (Disconnect Device)"
    echo "4️⃣  کنترل دستگاه (Control Device)"
    echo "5️⃣  مشاهده داده‌های real-time (Live Telemetry)"
    echo "6️⃣  دمو خانه هوشمند (Smart Home Demo)"
    echo "7️⃣  ایجاد گیتوی جدید (Create Gateway)"
    echo "8️⃣  مشاهده گیتوی‌ها (List Gateways)"
    echo "9️⃣  خروج (Exit)"
    echo ""
    echo -e "${CYAN}💻 وب اپلیکیشن: http://localhost:5173${NC}"
    echo ""
}

# Device type selection
select_device_type() {
    echo -e "${YELLOW}نوع دستگاه را انتخاب کنید:${NC}"
    echo ""
    echo "1. 🌡️  سنسور دما و رطوبت (Temperature/Humidity)"
    echo "2. 🚶 سنسور حرکت (Motion Sensor)"
    echo "3. 🚪 سنسور درب/پنجره (Door/Window Sensor)"
    echo "4. 💡 سنسور نور (Light Sensor)"
    echo "5. 🔌 کلید هوشمند (Smart Switch)"
    echo "6. 📹 دوربین امنیتی (Security Camera)"
    echo "7. 🌱 سنسور خاک (Soil Sensor)"
    echo "8. 🔧 سنسور عمومی (Generic Sensor)"
    echo ""
    read -p "انتخاب شما (1-8): " choice
    
    case $choice in
        1) echo "temperature";;
        2) echo "motion";;
        3) echo "door";;
        4) echo "light";;
        5) echo "relay";;
        6) echo "camera";;
        7) echo "soil";;
        8) echo "generic";;
        *) echo "temperature";;
    esac
}

# Connect new device
connect_new_device() {
    clear
    echo -e "${BLUE}🔗 اتصال دستگاه جدید${NC}"
    echo ""
    
    # Get gateways list
    local gateways=$(curl -s -X GET $API_BASE/devices/gateways/ \
        -H "Authorization: Bearer $TOKEN")
    
    local gateway_count=$(echo $gateways | jq length)
    
    if [ "$gateway_count" -eq 0 ]; then
        warn "هیچ گیتوی‌ای یافت نشد. ابتدا یک گیتوی ایجاد کنید."
        read -p "Enter برای ادامه..."
        return
    fi
    
    echo -e "${YELLOW}گیتوی‌های موجود:${NC}"
    echo $gateways | jq -r '.[] | "\(.id). \(.gateway_id) - \(.name)"'
    echo ""
    
    read -p "شناسه گیتوی (Gateway ID): " gateway_id
    read -p "شناسه دستگاه (Device ID) [مثال: TEMP-001]: " device_id
    
    if [ -z "$gateway_id" ] || [ -z "$device_id" ]; then
        error "شناسه گیتوی و دستگاه الزامی است"
        read -p "Enter برای ادامه..."
        return
    fi
    
    device_type=$(select_device_type)
    echo ""
    read -p "نام دستگاه [مثال: سنسور اتاق خواب]: " device_name
    read -p "مدل دستگاه [مثال: DHT22]: " device_model
    read -p "فاصله ارسال داده (ثانیه) [پیش‌فرض: 10]: " interval
    
    device_name=${device_name:-"$device_type Sensor"}
    device_model=${device_model:-"Generic-v1"}
    interval=${interval:-10}
    
    echo ""
    info "در حال اتصال دستگاه..."
    
    # Add device
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
        success "دستگاه '$device_id' با موفقیت متصل شد!"
        echo ""
        info "آیا می‌خواهید شبیه‌سازی داده را شروع کنید؟ (y/n)"
        read -p "پاسخ: " start_sim
        
        if [ "$start_sim" = "y" ] || [ "$start_sim" = "Y" ]; then
            echo ""
            success "شبیه‌سازی شروع شد! داده‌ها هر $interval ثانیه ارسال می‌شوند."
            info "برای توقف Ctrl+C بزنید"
            echo ""
            
            # Start simulation in background
            ./device_manager.sh connect "$gateway_id" "$device_id" "$device_type" "$device_name" "$device_model" "$interval" &
            
            info "دستگاه در پس‌زمینه در حال ارسال داده است"
        fi
    else
        error "خطا در اتصال دستگاه"
        echo $result | jq .
    fi
    
    echo ""
    read -p "Enter برای ادامه..."
}

# List connected devices
list_devices() {
    clear
    echo -e "${BLUE}📱 دستگاه‌های متصل${NC}"
    echo ""
    
    local devices=$(curl -s -X GET $API_BASE/devices/devices/ \
        -H "Authorization: Bearer $TOKEN")
    
    local device_count=$(echo $devices | jq length)
    
    if [ "$device_count" -eq 0 ]; then
        warn "هیچ دستگاهی متصل نیست"
    else
        echo -e "${GREEN}تعداد دستگاه‌های متصل: $device_count${NC}"
        echo ""
        echo -e "${CYAN}┌─────────────────┬──────────────┬─────────────────────┬─────────────┬──────────┐${NC}"
        echo -e "${CYAN}│ شناسه دستگاه    │ نوع          │ نام                 │ مدل         │ وضعیت    │${NC}"
        echo -e "${CYAN}├─────────────────┼──────────────┼─────────────────────┼─────────────┼──────────┤${NC}"
        
        echo $devices | jq -r '.[] | 
            "│ \(.device_id | .[0:15]) │ \(.type | .[0:12]) │ \(.name | .[0:19]) │ \(.model | .[0:11]) │ \(if .is_online then "🟢 آنلاین" else "🔴 آفلاین" end) │"'
        
        echo -e "${CYAN}└─────────────────┴──────────────┴─────────────────────┴─────────────┴──────────┘${NC}"
    fi
    
    echo ""
    read -p "Enter برای ادامه..."
}

# Disconnect device
disconnect_device() {
    clear
    echo -e "${BLUE}🔌 قطع اتصال دستگاه${NC}"
    echo ""
    
    local devices=$(curl -s -X GET $API_BASE/devices/devices/ \
        -H "Authorization: Bearer $TOKEN")
    
    local device_count=$(echo $devices | jq length)
    
    if [ "$device_count" -eq 0 ]; then
        warn "هیچ دستگاهی برای قطع اتصال یافت نشد"
        read -p "Enter برای ادامه..."
        return
    fi
    
    echo -e "${YELLOW}دستگاه‌های متصل:${NC}"
    echo $devices | jq -r '.[] | "\(.id). \(.device_id) - \(.name)"'
    echo ""
    
    read -p "شناسه دستگاه برای قطع اتصال: " device_id
    
    if [ -z "$device_id" ]; then
        error "شناسه دستگاه الزامی است"
        read -p "Enter برای ادامه..."
        return
    fi
    
    # Get device info
    local device_pk=$(echo $devices | jq -r ".[] | select(.device_id==\"$device_id\") | .id")
    
    if [ "$device_pk" != "null" ] && [ -n "$device_pk" ]; then
        curl -s -X DELETE $API_BASE/devices/devices/$device_pk/ \
            -H "Authorization: Bearer $TOKEN" > /dev/null
        success "دستگاه '$device_id' قطع شد"
    else
        error "دستگاه '$device_id' یافت نشد"
    fi
    
    echo ""
    read -p "Enter برای ادامه..."
}

# Control device
control_device() {
    clear
    echo -e "${BLUE}🎛️  کنترل دستگاه${NC}"
    echo ""
    
    local devices=$(curl -s -X GET $API_BASE/devices/devices/ \
        -H "Authorization: Bearer $TOKEN")
    
    local device_count=$(echo $devices | jq length)
    
    if [ "$device_count" -eq 0 ]; then
        warn "هیچ دستگاهی برای کنترل یافت نشد"
        read -p "Enter برای ادامه..."
        return
    fi
    
    echo -e "${YELLOW}دستگاه‌های قابل کنترل:${NC}"
    echo $devices | jq -r '.[] | select(.type == "relay" or .type == "actuator" or .type == "dimmer" or .type == "camera") | "\(.id). \(.device_id) - \(.name) (\(.type))"'
    echo ""
    
    read -p "شماره ID دستگاه: " device_pk
    
    if [ -z "$device_pk" ]; then
        error "شماره دستگاه الزامی است"
        read -p "Enter برای ادامه..."
        return
    fi
    
    local device=$(echo $devices | jq -r ".[] | select(.id==$device_pk)")
    local device_type=$(echo $device | jq -r '.type')
    local device_id=$(echo $device | jq -r '.device_id')
    
    if [ "$device_type" = "null" ]; then
        error "دستگاه یافت نشد"
        read -p "Enter برای ادامه..."
        return
    fi
    
    echo ""
    echo -e "${CYAN}کنترل دستگاه: $device_id ($device_type)${NC}"
    echo ""
    
    case $device_type in
        "relay"|"actuator")
            echo "1. روشن کردن (Turn ON)"
            echo "2. خاموش کردن (Turn OFF)"
            read -p "انتخاب: " action
            
            if [ "$action" = "1" ]; then
                command_data='{"action":"toggle","state":"on"}'
            elif [ "$action" = "2" ]; then
                command_data='{"action":"toggle","state":"off"}'
            else
                error "انتخاب نامعتبر"
                read -p "Enter برای ادامه..."
                return
            fi
            ;;
        "dimmer")
            read -p "درصد روشنایی (0-100): " brightness
            command_data="{\"action\":\"set_brightness\",\"brightness\":$brightness}"
            ;;
        "camera")
            echo "1. گرفتن عکس (Take Snapshot)"
            echo "2. شروع ضبط (Start Recording)"
            echo "3. توقف ضبط (Stop Recording)"
            read -p "انتخاب: " action
            
            case $action in
                1) command_data='{"action":"take_snapshot","quality":"high"}';;
                2) command_data='{"action":"start_recording","duration":300}';;
                3) command_data='{"action":"stop_recording"}';;
                *) error "انتخاب نامعتبر"; read -p "Enter برای ادامه..."; return;;
            esac
            ;;
        *)
            error "این نوع دستگاه قابل کنترل نیست"
            read -p "Enter برای ادامه..."
            return
            ;;
    esac
    
    # Send command
    local result=$(curl -s -X POST $API_BASE/devices/devices/$device_pk/command/ \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$command_data")
    
    local status=$(echo $result | jq -r '.status')
    if [ "$status" = "sent" ]; then
        success "دستور با موفقیت ارسال شد!"
        echo ""
        echo -e "${CYAN}جزئیات دستور:${NC}"
        echo $result | jq .
    else
        error "خطا در ارسال دستور"
        echo $result | jq .
    fi
    
    echo ""
    read -p "Enter برای ادامه..."
}

# Live telemetry monitoring
live_telemetry() {
    clear
    echo -e "${BLUE}📊 مشاهده داده‌های real-time${NC}"
    echo ""
    
    if ! command -v mosquitto_sub &> /dev/null; then
        error "mosquitto_sub یافت نشد. نصب کنید: brew install mosquitto"
        read -p "Enter برای ادامه..."
        return
    fi
    
    info "در حال مشاهده تمام داده‌های دستگاه‌ها..."
    info "برای توقف Ctrl+C بزنید"
    echo ""
    
    mosquitto_sub -h $MQTT_HOST -t "devices/+/data" -v | while read line; do
        topic=$(echo $line | cut -d' ' -f1)
        data=$(echo $line | cut -d' ' -f2-)
        device_id=$(echo $topic | cut -d'/' -f2)
        
        echo -e "${CYAN}[$(date '+%H:%M:%S')] 📱 $device_id:${NC} $data"
    done
}

# Smart home demo
smart_home_demo() {
    clear
    echo -e "${BLUE}🏠 دمو خانه هوشمند${NC}"
    echo ""
    
    info "در حال راه‌اندازی خانه هوشمند نمونه..."
    echo ""
    
    # Run demo in background
    ./device_manager.sh demo &
    local demo_pid=$!
    
    success "خانه هوشمند نمونه راه‌اندازی شد!"
    echo ""
    echo -e "${YELLOW}دستگاه‌های متصل:${NC}"
    echo "🌡️  سنسور دمای اتاق نشیمن"
    echo "🚶 سنسور حرکت راهرو"
    echo "🚪 سنسور درب ورودی"
    echo "💡 سنسور نور بیرون"
    echo "🔌 کلید هوشمند آشپزخانه"
    echo ""
    info "💻 مشاهده در وب: http://localhost:5173"
    echo ""
    
    read -p "Enter برای توقف دمو..."
    kill $demo_pid 2>/dev/null || true
    
    warn "دمو متوقف شد"
    read -p "Enter برای ادامه..."
}

# Create gateway
create_gateway() {
    clear
    echo -e "${BLUE}🌐 ایجاد گیتوی جدید${NC}"
    echo ""
    
    read -p "شناسه گیتوی [مثال: HOME-GW-001]: " gateway_id
    read -p "نام گیتوی [مثال: گیتوی خانه]: " gateway_name
    
    if [ -z "$gateway_id" ]; then
        error "شناسه گیتوی الزامی است"
        read -p "Enter برای ادامه..."
        return
    fi
    
    gateway_name=${gateway_name:-"Gateway $gateway_id"}
    
    local result=$(curl -s -X POST $API_BASE/devices/gateways/claim/ \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"gateway_id\":\"$gateway_id\",\"name\":\"$gateway_name\"}")
    
    local created_id=$(echo $result | jq -r '.gateway_id')
    if [ "$created_id" = "$gateway_id" ]; then
        success "گیتوی '$gateway_id' با موفقیت ایجاد شد!"
    else
        error "خطا در ایجاد گیتوی"
        echo $result | jq .
    fi
    
    echo ""
    read -p "Enter برای ادامه..."
}

# List gateways
list_gateways() {
    clear
    echo -e "${BLUE}🌐 گیتوی‌های موجود${NC}"
    echo ""
    
    local gateways=$(curl -s -X GET $API_BASE/devices/gateways/ \
        -H "Authorization: Bearer $TOKEN")
    
    local gateway_count=$(echo $gateways | jq length)
    
    if [ "$gateway_count" -eq 0 ]; then
        warn "هیچ گیتوی‌ای یافت نشد"
    else
        echo -e "${GREEN}تعداد گیتوی‌ها: $gateway_count${NC}"
        echo ""
        echo $gateways | jq -r '.[] | "🌐 \(.gateway_id) - \(.name) | آخرین بازدید: \(.last_seen // "هرگز")"'
    fi
    
    echo ""
    read -p "Enter برای ادامه..."
}

# Main loop
main_loop() {
    while true; do
        show_menu
        read -p "انتخاب شما (1-9): " choice
        
        case $choice in
            1) connect_new_device ;;
            2) list_devices ;;
            3) disconnect_device ;;
            4) control_device ;;
            5) live_telemetry ;;
            6) smart_home_demo ;;
            7) create_gateway ;;
            8) list_gateways ;;
            9) 
                echo ""
                success "خروج از IoT Playground"
                exit 0
                ;;
            *)
                error "انتخاب نامعتبر. لطفاً عددی بین 1 تا 9 وارد کنید."
                sleep 2
                ;;
        esac
    done
}

# Check dependencies and start
check_dependencies() {
    if ! command -v curl &> /dev/null; then
        error "curl required but not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        error "jq required. Install with: brew install jq"
        exit 1
    fi
    
    # Get auth token
    get_auth_token
    log "اتصال به API موفق بود"
    sleep 1
}

# Start the playground
echo -e "${PURPLE}🚀 در حال راه‌اندازی IoT Playground...${NC}"
check_dependencies
main_loop
