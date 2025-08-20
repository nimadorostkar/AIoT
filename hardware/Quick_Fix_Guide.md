# راهنمای سریع حل مشکل MQTT Connection

## ✅ مشکل شناسایی شد
NodeMCU موفقیت آمیز آپلود شد و به WiFi متصل شده است. مشکل در اتصال MQTT بود.

## 🔧 حل مشکل

### مرحله 1: تنظیم آدرس MQTT صحیح
آدرس IP سرور شما: `192.168.1.37`

در فایل `nodemcu_relay_gateway.ino` خط 13 را به شکل زیر تغییر دهید:
```cpp
const char* mqtt_server = "192.168.1.37";  // آدرس IP سرور شما
```

### مرحله 2: آپلود مجدد فرمور
1. فایل `nodemcu_relay_gateway.ino` را در Arduino IDE باز کنید
2. مطمئن شوید که تغییر آدرس IP انجام شده است
3. فرمور را دوباره آپلود کنید (`Ctrl+U` یا `Upload`)

### مرحله 3: بررسی نتیجه
بعد از آپلود موفق، در Serial Monitor باید چیزی شبیه زیر ببینید:

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

## 🎯 مراحل بعدی (بعد از حل مشکل MQTT)

### 1. ثبت Gateway در سیستم
```bash
# دریافت JWT Token
curl -X POST http://localhost:8000/api/token/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# Claim Gateway
curl -X POST http://localhost:8000/api/devices/gateways/claim/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "NodeMCU-GW-001", 
    "name": "NodeMCU Test Gateway"
  }'
```

### 2. ثبت دستگاه‌ها
```bash
# رله 1
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

# رله 2
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

### 3. تست عملکرد
- **وب رابط NodeMCU**: http://192.168.1.36
- **تست مستقیم**: http://192.168.1.36/relay1/on
- **رابط کاربری AIoT**: http://localhost:3000

## 🚨 اگر همچنان مشکل داشتید

### بررسی لاگ‌های سیستم:
```bash
# لاگ MQTT broker
docker logs iot_mqtt

# لاگ backend
docker logs iot_api
```

### تست MQTT مستقیم:
```bash
# نصب mosquitto client (اگر نیست)
brew install mosquitto  # macOS

# تست subscribe
mosquitto_sub -h 192.168.1.37 -t "devices/+/+"

# تست publish
mosquitto_pub -h 192.168.1.37 -t "test/topic" -m "hello"
```

### علل احتمالی مشکل:
1. **Firewall**: پورت 1883 بسته باشد
2. **Docker network**: تنظیمات شبکه اشتباه
3. **IP تغییر کرده**: سیستم IP جدید گرفته باشد

### پیدا کردن IP جدید:
```bash
# روش 1
ifconfig | grep "inet " | grep -v 127.0.0.1

# روش 2  
ip route get 8.8.8.8 | awk '{print $7}'
```

## ✅ نکات مهم

1. **IP ثابت**: بهتر است IP سیستم را ثابت کنید تا دوباره این مشکل پیش نیاید
2. **WiFi network**: NodeMCU و سرور باید در همان شبکه باشند
3. **Port forwarding**: اگر از VPN استفاده می‌کنید، ممکن است مشکل ایجاد شود

## 🎉 بعد از موفقیت

وقتی همه چیز کار کرد:
- LEDها با رابط وب کنترل می‌شوند
- دستگاه‌ها در dashboard ظاهر می‌شوند  
- Real-time telemetry دریافت می‌شود
- آماده ساخت گیتوی کامل هستید!
