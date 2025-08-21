# راهنمای تست کامل NodeMCU با سیستم AIoT

## ✅ وضعیت سیستم - آماده تست!

همه سرویس‌ها healthy و آماده هستند:
- **Backend API**: http://localhost:8000 ✅
- **Frontend**: http://localhost:5173 ✅
- **MQTT Broker**: localhost:1883 ✅
- **Database**: کاملاً سازگار ✅

## 🔧 مرحله 1: آپلود فرمور NodeMCU

### 1.1 تنظیمات فرمور
فایل `hardware/nodemcu_relay_gateway.ino` را در Arduino IDE باز کنید و این تنظیمات را بررسی کنید:

```cpp
// WiFi تنظیمات
const char* ssid = "Nima";                    // ✅ نام WiFi شما
const char* password = "1234nima!!";          // ✅ رمز WiFi شما

// MQTT تنظیمات  
const char* mqtt_server = "192.168.1.37";    // ✅ IP سرور شما
const int mqtt_port = 1883;                  // ✅ پورت MQTT

// شناسه‌های دستگاه
const char* gateway_id = "NodeMCU-GW-001";   // ✅ ID گیتوی
const char* device1_id = "RELAY-001";        // ✅ ID رله 1
const char* device2_id = "RELAY-002";        // ✅ ID رله 2
```

### 1.2 آپلود فرمور
1. NodeMCU را به کامپیوتر وصل کنید
2. در Arduino IDE:
   - Board: `NodeMCU 1.0 (ESP-12E Module)`
   - Port: پورت صحیح NodeMCU
   - Upload Speed: `115200`
3. فرمور را آپلود کنید (`Ctrl+U`)

### 1.3 بررسی Serial Monitor
بعد از آپلود، Serial Monitor را باز کنید (115200 baud):

```
=== NodeMCU IoT Gateway Starting ===
WiFi connected!
IP address: 192.168.1.36
Attempting MQTT connection... connected!
Subscribed to:
  - devices/RELAY-001/commands
  - devices/RELAY-002/commands
  - gateways/NodeMCU-GW-001/discover
Device announced: RELAY-001
Device announced: RELAY-002
Heartbeat sent
=== Setup Complete ===
```

## 🌐 مرحله 2: ثبت در سیستم AIoT

### 2.1 دریافت JWT Token
```bash
curl -X POST http://localhost:8000/api/token/ \\
  -H "Content-Type: application/json" \\
  -d '{"username":"admin","password":"admin123"}'
```

**خروجی مثال:**
```json
{
  "access": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### 2.2 ثبت Gateway
```bash
export TOKEN="YOUR_JWT_TOKEN_HERE"

curl -X POST http://localhost:8000/api/devices/gateways/claim/ \\
  -H "Authorization: Bearer $TOKEN" \\
  -H "Content-Type: application/json" \\
  -d '{
    "gateway_id": "NodeMCU-GW-001", 
    "name": "NodeMCU Test Gateway"
  }'
```

### 2.3 ثبت رله‌ها
```bash
# رله 1
curl -X POST http://localhost:8000/api/devices/devices/ \\
  -H "Authorization: Bearer $TOKEN" \\
  -H "Content-Type: application/json" \\
  -d '{
    "gateway_id": "NodeMCU-GW-001",
    "device_id": "RELAY-001",
    "type": "actuator", 
    "name": "LED Channel 1",
    "model": "NodeMCU-Relay"
  }'

# رله 2  
curl -X POST http://localhost:8000/api/devices/devices/ \\
  -H "Authorization: Bearer $TOKEN" \\
  -H "Content-Type: application/json" \\
  -d '{
    "gateway_id": "NodeMCU-GW-001",
    "device_id": "RELAY-002",
    "type": "actuator",
    "name": "LED Channel 2", 
    "model": "NodeMCU-Relay"
  }'
```

## 🎮 مرحله 3: تست عملکرد

### 3.1 تست مستقیم NodeMCU
پیش از تست با سیستم AIoT، NodeMCU را مستقیماً تست کنید:

**صفحه اصلی NodeMCU:**
```
http://192.168.1.36
```

**تست مستقیم رله‌ها:**
```
http://192.168.1.36/relay1/on   # روشن کردن رله 1
http://192.168.1.36/relay1/off  # خاموش کردن رله 1
http://192.168.1.36/relay2/on   # روشن کردن رله 2
http://192.168.1.36/relay2/off  # خاموش کردن رله 2
```

**API Status:**
```
http://192.168.1.36/api/status
```

### 3.2 تست با Frontend AIoT
1. **وارد Frontend شوید:**
   - آدرس: http://localhost:5173
   - Username: `admin`
   - Password: `admin123`

2. **بخش Devices:**
   - باید Gateway "NodeMCU Test Gateway" را ببینید
   - باید Device های "LED Channel 1" و "LED Channel 2" را ببینید

3. **بخش Control:**
   - دکمه‌های ON/OFF برای هر رله
   - تست کنید که LED ها روشن/خاموش می‌شوند

### 3.3 تست MQTT Commands
```bash
# نصب MQTT client (اگر ندارید)
brew install mosquitto  # macOS
# یا
sudo apt install mosquitto-clients  # Ubuntu

# تست دستور رله 1
mosquitto_pub -h localhost -t "devices/RELAY-001/commands" -m '{
  "action": "toggle",
  "state": "on",
  "device_id": "RELAY-001",
  "timestamp": "2024-01-01T12:00:00Z",
  "command_id": "test_cmd_123"
}'
```

## 📊 مرحله 4: مانیتورینگ

### 4.1 لاگ‌های NodeMCU
در Serial Monitor باید ببینید:
```
MQTT Message received: devices/RELAY-001/commands = {"action":"toggle"...}
Device Command - ID: RELAY-001, Action: toggle
Relay 1 set to: on
Command response sent for RELAY-001: success
Telemetry sent for RELAY-001: state=on
```

### 4.2 لاگ‌های Backend
```bash
# مشاهده لاگ‌های API
docker logs iot_api --tail 20

# مشاهده لاگ‌های MQTT broker
docker logs iot_mqtt --tail 20
```

### 4.3 مانیتورینگ MQTT
```bash
# مشاهده تمام پیام‌های MQTT
mosquitto_sub -h localhost -t "#" -v

# مانیتورینگ دستگاه‌های خاص
mosquitto_sub -h localhost -t "devices/+/+" -v
```

## ✅ نتایج مورد انتظار

### تست موفق شامل:
1. **NodeMCU اتصال WiFi** ✅
2. **NodeMCU اتصال MQTT** ✅  
3. **Gateway ثبت در سیستم** ✅
4. **Device ها ثبت در سیستم** ✅
5. **کنترل رله از Frontend** ✅
6. **Telemetry real-time** ✅
7. **LED ها روشن/خاموش** ✅

### در صورت موفقیت:
- **Frontend**: دستگاه‌ها را نشان می‌دهد و کنترل می‌کند
- **NodeMCU**: دستورات را دریافت و اجرا می‌کند
- **LED ها**: طبق دستورات روشن/خاموش می‌شوند
- **Logs**: پیام‌های MQTT کامل دریافت می‌شوند

## ⚠️ عیب‌یابی

### اگر NodeMCU به WiFi وصل نمی‌شود:
- نام و رمز WiFi را بررسی کنید
- فاصله از router را کم کنید
- Serial Monitor را بررسی کنید

### اگر MQTT متصل نمی‌شود:
- IP آدرس سرور را بررسی کنید: `192.168.1.37`
- پورت 1883 را در فایروال باز کنید
- MQTT broker logs را بررسی کنید

### اگر رله‌ها کار نمی‌کنند:
- اتصالات سخت‌افزاری را بررسی کنید
- ولتاژ تغذیه رله (5V) را تأیید کنید
- GPIO signals را با multimeter تست کنید

### اگر Frontend دستگاه‌ها را نشان نمی‌دهد:
- Gateway و Device ها را در API ثبت کنید
- JWT token معتبر داشته باشید
- Browser cache را پاک کنید

## 🎯 مرحله بعدی

بعد از تست موفق:
1. **امنیت MQTT**: اضافه کردن authentication
2. **SSL/TLS**: رمزنگاری ارتباطات  
3. **OTA Updates**: بروزرسانی بی‌سیم
4. **گیتوی کامل**: طراحی PCB اختصاصی
5. **سنسورهای بیشتر**: دما، رطوبت، حرکت

---

**موفق باشید! 🎉**
