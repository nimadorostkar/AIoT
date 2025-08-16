# راهنمای کامل تست و شبیه‌سازی دستگاه‌های IoT

## 🚀 راه‌اندازی سریع

### 1. راه‌اندازی سیستم
```bash
# شروع تمام سرویس‌ها
docker compose up -d

# بررسی وضعیت
docker compose ps
```

### 2. اجرای محیط تعاملی (پیشنهاد شده)
```bash
cd docs/testing/scripts
./iot_playground.sh
```

## 🏠 دستورات Plug & Play

### اتصال سنسور دما
```bash
# اتصال سنسور دمای جدید
./device_manager.sh connect HOME-GW-001 TEMP-001 temperature "سنسور اتاق خواب" DHT22 8

# مشاهده در وب: http://localhost:5173
```

### اتصال سنسور حرکت
```bash
# اتصال سنسور حرکت
./device_manager.sh connect HOME-GW-001 PIR-001 motion "سنسور راهرو" PIR-v2 5
```

### اتصال کلید هوشمند
```bash
# اتصال کلید هوشمند
./device_manager.sh connect HOME-GW-001 RELAY-001 relay "چراغ آشپزخانه" SmartRelay 10
```

### قطع اتصال دستگاه
```bash
# قطع اتصال
./device_manager.sh disconnect TEMP-001
```

## 📱 انواع دستگاه‌های پشتیبانی شده

| نوع | شناسه | توضیحات | مثال |
|-----|--------|----------|-------|
| `temperature` | 🌡️ | سنسور دما و رطوبت | DHT22, BME280 |
| `motion` | 🚶 | سنسور حرکت | PIR, Microwave |
| `door` | 🚪 | سنسور درب/پنجره | Magnetic, Reed |
| `light` | 💡 | سنسور نور | BH1750, TSL2561 |
| `relay` | 🔌 | کلید/رله هوشمند | Smart Switch |
| `camera` | 📹 | دوربین امنیتی | IP Camera |
| `soil` | 🌱 | سنسور خاک | Moisture Sensor |

## 🎛️ کنترل دستگاه‌ها

### کنترل کلید هوشمند
```bash
# روشن کردن
curl -X POST http://localhost:8000/api/devices/devices/1/command/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"toggle","state":"on"}'

# خاموش کردن  
curl -X POST http://localhost:8000/api/devices/devices/1/command/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"toggle","state":"off"}'
```

### کنترل دیمر
```bash
# تنظیم روشنایی 75%
curl -X POST http://localhost:8000/api/devices/devices/2/command/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"set_brightness","brightness":75}'
```

### کنترل دوربین
```bash
# گرفتن عکس
curl -X POST http://localhost:8000/api/devices/devices/3/command/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"take_snapshot","quality":"high"}'
```

## 📊 مشاهده داده‌های Real-time

### مشاهده تمام داده‌ها
```bash
mosquitto_sub -h localhost -t "devices/+/data" -v
```

### مشاهده دستگاه خاص
```bash
mosquitto_sub -h localhost -t "devices/TEMP-001/+" -v
```

### ارسال داده تست
```bash
# ارسال داده دما
mosquitto_pub -h localhost -p 1883 \
  -t "devices/TEMP-001/data" \
  -m '{"temperature": 25.5, "humidity": 60}' -q 1
```

## 🏠 دمو خانه هوشمند

### اجرای دمو کامل
```bash
# شروع دمو با 5 دستگاه مختلف
./device_manager.sh demo
```

### دستگاه‌های دمو شامل:
- 🌡️ سنسور دمای اتاق نشیمن
- 🚶 سنسور حرکت راهرو  
- 🚪 سنسور درب ورودی
- 💡 سنسور نور بیرون
- 🔌 کلید هوشمند آشپزخانه

## 🔧 دستورات مفید

### مشاهده لیست دستگاه‌ها
```bash
./device_manager.sh list
```

### بررسی وضعیت دستگاه
```bash
./device_manager.sh status TEMP-001
```

### تست سریع سیستم
```bash
./quick_test.sh
```

### تست کامل
```bash
./test_iot_devices.sh
```

## 🌐 دستورات API

### احراز هویت
```bash
# دریافت توکن
curl -X POST http://localhost:8000/api/token/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

export TOKEN="YOUR_TOKEN_HERE"
```

### مدیریت گیتوی
```bash
# ایجاد گیتوی
curl -X POST http://localhost:8000/api/devices/gateways/claim/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"gateway_id":"HOME-GW-001","name":"گیتوی خانه"}'

# لیست گیتوی‌ها
curl -X GET http://localhost:8000/api/devices/gateways/ \
  -H "Authorization: Bearer $TOKEN"
```

### مدیریت دستگاه‌ها
```bash
# ایجاد دستگاه
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id":"HOME-GW-001",
    "device_id":"TEMP-001", 
    "type":"sensor",
    "name":"سنسور اتاق خواب",
    "model":"DHT22"
  }'

# لیست دستگاه‌ها
curl -X GET http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN"
```

### مشاهده تله‌متری
```bash
# تمام داده‌ها
curl -X GET http://localhost:8000/api/devices/telemetry/ \
  -H "Authorization: Bearer $TOKEN"

# داده‌های دستگاه خاص
curl -X GET "http://localhost:8000/api/devices/telemetry/?device=1" \
  -H "Authorization: Bearer $TOKEN"
```

## 🔍 عیب‌یابی

### بررسی وضعیت سرویس‌ها
```bash
# وضعیت کانتینرها
docker compose ps

# لاگ‌های API
docker compose logs api --tail=50

# لاگ‌های MQTT
docker compose logs mqtt --tail=50
```

### مشکلات رایج

#### 1. خطای احراز هویت
```bash
# بررسی API
curl http://localhost:8000/admin/

# تست کردن لاگین
curl -X POST http://localhost:8000/api/token/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

#### 2. مشکل MQTT
```bash
# تست اتصال MQTT
mosquitto_pub -h localhost -t test -m "hello"

# مشاهده پیام‌ها
mosquitto_sub -h localhost -t "#" -v
```

#### 3. بررسی سلامت سیستم
```bash
# اجرای تست سلامت
make health

# یا
./docker-healthcheck.sh
```

## 📈 تست عملکرد

### تست بار
```bash
# ایجاد 50 دستگاه
for i in {1..50}; do
  ./device_manager.sh connect HOME-GW-001 DEV-$i temperature "Device $i" Generic 30
done
```

### شبیه‌سازی ترافیک زیاد
```bash
# ارسال 1000 پیام
for i in {1..1000}; do
  mosquitto_pub -h localhost -p 1883 \
    -t "devices/STRESS-TEST/data" \
    -m "{\"value\":$i}" -q 1 &
done
```

## 🎯 سناریوهای واقعی

### خانه هوشمند
```bash
# اتاق نشیمن
./device_manager.sh connect HOME-GW TEMP-LIVING temperature "دمای اتاق نشیمن" DHT22
./device_manager.sh connect HOME-GW PIR-LIVING motion "حرکت اتاق نشیمن" PIR-v2
./device_manager.sh connect HOME-GW LIGHT-LIVING relay "چراغ اتاق نشیمن" SmartRelay

# آشپزخانه  
./device_manager.sh connect HOME-GW TEMP-KITCHEN temperature "دمای آشپزخانه" DHT22
./device_manager.sh connect HOME-GW GAS-KITCHEN gas "سنسور گاز" MQ-2

# حیاط
./device_manager.sh connect GARDEN-GW SOIL-01 soil "رطوبت خاک گوجه" SoilWatch
./device_manager.sh connect GARDEN-GW VALVE-01 valve "شیر آبیاری منطقه 1" SmartValve
```

### ساختمان اداری
```bash
# طبقه اول
./device_manager.sh connect OFFICE-GW HVAC-F1 hvac "تهویه طبقه 1" HVAC-Pro
./device_manager.sh connect OFFICE-GW POWER-F1 power "کنتور برق طبقه 1" PowerMeter

# امنیت
./device_manager.sh connect SECURITY-GW CAM-ENTRANCE camera "دوربین ورودی" IPCam-4K
./device_manager.sh connect SECURITY-GW DOOR-MAIN door "درب اصلی" AccessControl
```

## 🎉 نتیجه

با این ابزارها می‌توانید:

✅ **دستگاه‌های IoT را به صورت Plug & Play متصل کنید**
✅ **در real-time داده‌ها را مشاهده کنید**  
✅ **دستگاه‌ها را از راه دور کنترل کنید**
✅ **سناریوهای پیچیده را شبیه‌سازی کنید**
✅ **عملکرد سیستم را تست کنید**

🔗 **لینک‌های مفید:**
- وب اپلیکیشن: http://localhost:5173
- مستندات API: http://localhost:8000/api/docs/
- پنل مدیریت: http://localhost:8000/admin/

موفق باشید! 🚀
