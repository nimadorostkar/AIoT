# راهنمای اتصال NodeMCU به سیستم AIoT

## مقدمه
این راهنما نحوه اتصال برد NodeMCU با ماژول رله دوکاناله به سیستم AIoT موجود را توضیح می‌دهد.

## 🔧 اتصالات سخت‌افزاری

### لیست قطعات
- برد توسعه وای فای NodeMCU همراه با ماژول ESP8266-12E
- ماژول رله 5 ولت دوکاناله  
- 2 عدد LED با مقاومت 220Ω
- سیم‌های جامپر

### اتصالات

#### اتصال NodeMCU به ماژول رله:
```
NodeMCU                    ماژول رله
-------                    ----------
GND [left-down]       <->  GND [down]    
VIN [left-down]       <->  VCC [top]    
GND [right-top-7]     <->  GND [top]    
D1(GPIO5)             <->  IN1 [top]    
D2(GPIO4)             <->  IN2 [top]    
```

#### اتصال LED ها به رله:
```
منبع تغذیه              رله                LED
-----------              ----               ----
5V/3.3V             <->  COM1,COM2    
                         NO1          <->  LED1 [long/anode]
                         NO2          <->  LED2 [long/anode]
                         
LED1 [short/cathode] <-> مقاومت 220Ω <-> GND
LED2 [short/cathode] <-> مقاومت 220Ω <-> GND
```

## 📋 تنظیمات فرمور

### 1. نصب کتابخانه‌های مورد نیاز در Arduino IDE:
```
- ESP8266WiFi (درون‌ساخت ESP8266)
- ESP8266WebServer (درون‌ساخت ESP8266) 
- PubSubClient by Nick O'Leary
- ArduinoJson by Benoit Blanchon
```

### 2. تنظیمات WiFi:
در فایل `nodemcu_relay_gateway.ino` خط‌های زیر را ویرایش کنید:
```cpp
const char* ssid = "YOUR_WIFI_NAME";          // نام WiFi شما
const char* password = "YOUR_WIFI_PASSWORD";  // رمز WiFi شما
```

### 3. تنظیمات MQTT:
```cpp
const char* mqtt_server = "YOUR_SERVER_IP";   // آدرس IP سرور شما (مثل 192.168.1.100)
const int mqtt_port = 1883;                   // پورت MQTT (معمولاً 1883)
```

### 4. شناسه‌های دستگاه:
```cpp
const char* gateway_id = "NodeMCU-GW-001";    // شناسه gateway (می‌توانید تغییر دهید)
const char* device1_id = "RELAY-001";         // شناسه رله اول
const char* device2_id = "RELAY-002";         // شناسه رله دوم
```

## 🚀 راه‌اندازی گام به گام

### مرحله 1: اطمینان از عملکرد سرور
```bash
cd /Users/nima/Projects/AIoT
make dev
```

### مرحله 2: بررسی سرویس MQTT
```bash
# در ترمینال جداگانه
docker logs aiot-mosquitto

# باید پیام‌هایی مشابه زیر را ببینید:
# mosquitto version 2.x.x starting
# Opening ipv4 listen socket on port 1883
```

### مرحله 3: آپلود فرمور
1. فایل `nodemcu_relay_gateway.ino` را در Arduino IDE باز کنید
2. برد NodeMCU را به کامپیوتر متصل کنید
3. تنظیمات WiFi و MQTT را ویرایش کنید
4. برد را انتخاب کنید: `Tools > Board > NodeMCU 1.0 (ESP-12E Module)`
5. پورت صحیح را انتخاب کنید: `Tools > Port > COMx یا /dev/ttyUSBx`
6. فرمور را آپلود کنید: `Sketch > Upload`

### مرحله 4: بررسی عملکرد
1. Serial Monitor را باز کنید (`Tools > Serial Monitor`)
2. Baud Rate را روی 115200 تنظیم کنید
3. باید پیام‌هایی مشابه زیر را ببینید:

```
=== NodeMCU IoT Gateway Starting ===
Connecting to WiFi: YOUR_WIFI_NAME
...........
WiFi connected!
IP address: 192.168.1.XXX
Attempting MQTT connection... connected!
Subscribed to:
  - devices/RELAY-001/commands
  - devices/RELAY-002/commands  
  - gateways/NodeMCU-GW-001/discover
Device announced: RELAY-001
Device announced: RELAY-002
=== Setup Complete ===
```

## 🔌 اتصال به سیستم AIoT

### مرحله 1: ثبت Gateway
در مرورگر وب خود به آدرس زیر بروید:
```
http://localhost:3000/login
```

وارد سیستم شوید و سپس به بخش Devices بروید.

### مرحله 2: Claim کردن Gateway  
از API یا رابط کاربری، gateway جدید را claim کنید:

**با cURL:**
```bash
# ابتدا JWT token دریافت کنید
curl -X POST http://localhost:8000/api/token/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# Gateway را claim کنید
curl -X POST http://localhost:8000/api/devices/gateways/claim/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "NodeMCU-GW-001", 
    "name": "NodeMCU Test Gateway"
  }'
```

### مرحله 3: ثبت دستگاه‌ها
```bash
# ثبت رله اول
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "NodeMCU-GW-001",
    "device_id": "RELAY-001",
    "type": "actuator", 
    "name": "LED Channel 1",
    "model": "NodeMCU-Relay"
  }'

# ثبت رله دوم
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "NodeMCU-GW-001",
    "device_id": "RELAY-002", 
    "type": "actuator",
    "name": "LED Channel 2", 
    "model": "NodeMCU-Relay"
  }'
```

## 🎮 تست عملکرد

### تست مستقیم با HTTP:
NodeMCU یک وب سرور داخلی نیز دارد برای تست:
```
http://192.168.1.XXX/           # صفحه اصلی
http://192.168.1.XXX/relay1/on  # روشن کردن رله 1  
http://192.168.1.XXX/relay1/off # خاموش کردن رله 1
http://192.168.1.XXX/api/status # وضعیت JSON
```

### تست با رابط کاربری AIoT:
1. به صفحه Control Panel در frontend بروید
2. دستگاه‌های RELAY-001 و RELAY-002 را باید ببینید
3. دکمه‌های ON/OFF را تست کنید
4. باید LED ها روشن/خاموش شوند

### تست با MQTT مستقیم:
```bash
# نصب mosquitto clients  
sudo apt install mosquitto-clients  # Ubuntu/Debian
brew install mosquitto              # macOS

# تست toggle دستگاه
mosquitto_pub -h localhost -t "devices/RELAY-001/commands" -m '{
  "action": "toggle",
  "state": "on",
  "device_id": "RELAY-001",
  "timestamp": "2024-01-01T12:00:00Z",
  "command_id": "test_cmd_123"
}'
```

## 🔍 عیب‌یابی

### مشکلات WiFi:
- نام و رمز WiFi را بررسی کنید
- آنتن NodeMCU را بررسی کنید  
- فاصله از مودم WiFi را کاهش دهید

### مشکلات MQTT:
- آدرес IP سرور را بررسی کنید (`docker inspect aiot-mosquitto`)
- پورت 1883 را در فایروال باز کنید
- لاگ‌های mosquitto را بررسی کنید

### مشکلات رله:
- اتصالات VCC و GND را بررسی کنید
- ولتاژ تغذیه رله را بررسی کنید (5V)
- Signal های GPIO را با multimeter تست کنید

### مشکلات سیستم AIoT:
- مطمئن شوید سرویس‌های docker فعال هستند
- JWT token معتبر داشته باشید
- Gateway و Device ها صحیح ثبت شده باشند

## 📊 مانیتورینگ

### لاگ‌های NodeMCU:
```
# در Arduino IDE Serial Monitor
Heartbeat sent
MQTT Message received: devices/RELAY-001/commands = {"action":"toggle"...}
Device Command - ID: RELAY-001, Action: toggle
Relay 1 set to: on
Command response sent for RELAY-001: success
```

### لاگ‌های سرور:
```bash
# مشاهده لاگ‌های Django
docker logs aiot-backend

# مشاهده لاگ‌های MQTT
docker logs aiot-mosquitto  
```

## 🎯 ویژگی‌های پیشرفته

فرمور شامل قابلیت‌های زیر است:
- ✅ ارتباط MQTT دوطرفه
- ✅ Auto-discovery دستگاه‌ها
- ✅ Heartbeat خودکار
- ✅ تایید دستورات (Command acknowledgment)
- ✅ ارسال Telemetry real-time  
- ✅ وب سرور برای تست مستقیم
- ✅ مدیریت اتصال مجدد خودکار
- ✅ مدیریت حافظه و بهینه‌سازی

## 📈 گام‌های بعدی

بعد از موفقیت در تست:
1. **امنیت**: اضافه کردن احراز هویت MQTT
2. **SSL/TLS**: رمزنگاری ارتباطات
3. **OTA Updates**: بروزرسانی بی‌سیم فرمور
4. **سنسورها**: اضافه کردن سنسور دما/رطوبت  
5. **صرفه‌جویی انرژی**: حالت deep sleep
6. **گیتوی اختصاصی**: ساخت PCB سفارشی

---

**نکته**: این تنظیمات برای تست موقت طراحی شده است. برای استفاده تولیدی، بهتر است یک گیتوی اختصاصی کامل طراحی کنید.
