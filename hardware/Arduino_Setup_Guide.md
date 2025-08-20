# راهنمای نصب کتابخانه‌های Arduino برای NodeMCU

## مرحله 1: نصب ESP8266 Board Support

### 1.1 تنظیم Board Manager
1. Arduino IDE را باز کنید
2. `File` → `Preferences` (یا `Arduino` → `Preferences` در macOS)
3. در قسمت "Additional Boards Manager URLs" این آدرس را اضافه کنید:
   ```
   http://arduino.esp8266.com/stable/package_esp8266com_index.json
   ```
4. روی OK کلیک کنید

### 1.2 نصب ESP8266 Package
1. `Tools` → `Board` → `Boards Manager...`
2. در کادر جستجو تایپ کنید: `esp8266`
3. `ESP8266 by ESP8266 Community` را پیدا کنید
4. روی `Install` کلیک کنید (ممکن است چند دقیقه طول بکشد)
5. بعد از نصب، Arduino IDE را restart کنید

## مرحله 2: نصب کتابخانه‌های مورد نیاز

### 2.1 باز کردن Library Manager
- `Sketch` → `Include Library` → `Manage Libraries...`
- یا کلید میانبر: `Ctrl+Shift+I` (Windows/Linux) یا `Cmd+Shift+I` (macOS)

### 2.2 نصب PubSubClient
1. در کادر جستجو تایپ کنید: `PubSubClient`
2. کتابخانه `PubSubClient by Nick O'Leary` را پیدا کنید
3. آخرین ورژن را انتخاب کنید (معمولاً 2.8.0 یا بالاتر)
4. روی `Install` کلیک کنید

### 2.3 نصب ArduinoJson
1. در کادر جستجو تایپ کنید: `ArduinoJson`
2. کتابخانه `ArduinoJson by Benoit Blanchon` را پیدا کنید
3. آخرین ورژن را انتخاب کنید (ورژن 6.x.x توصیه می‌شود)
4. روی `Install` کلیک کنید

## مرحله 3: تنظیم برد NodeMCU

### 3.1 انتخاب برد
1. `Tools` → `Board` → `ESP8266 Boards` → `NodeMCU 1.0 (ESP-12E Module)`

### 3.2 تنظیمات برد
- **Upload Speed**: `115200`
- **CPU Frequency**: `80 MHz`
- **Flash Size**: `4MB (FS:2MB OTA:~1019KB)`
- **Debug port**: `Disabled`
- **Debug Level**: `None`
- **lwIP Variant**: `v2 Lower Memory`
- **VTables**: `Flash`
- **Exceptions**: `Legacy (new can return nullptr)`
- **Builtin Led**: `2`
- **Erase Flash**: `Only Sketch`
- **SSL Support**: `All SSL ciphers (most compatible)`

### 3.3 انتخاب پورت
- `Tools` → `Port` → انتخاب پورت مناسب
- Windows: `COM3`, `COM4`, etc.
- macOS: `/dev/cu.usbserial-xxx` یا `/dev/cu.wchusbserial-xxx`
- Linux: `/dev/ttyUSB0`, `/dev/ttyUSB1`, etc.

## مرحله 4: تست نصب

### 4.1 ایجاد اسکچ تست
```cpp
#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

void setup() {
  Serial.begin(115200);
  Serial.println("✅ تمام کتابخانه‌ها با موفقیت لود شدند!");
}

void loop() {
  delay(1000);
}
```

### 4.2 کامپایل تست
1. کد بالا را کپی کنید
2. `Sketch` → `Verify/Compile` (یا `Ctrl+R`)
3. اگر بدون خطا کامپایل شد، همه چیز آماده است!

## عیب‌یابی مشکلات رایج

### خطای "Board not found"
```
Solution: ESP8266 board package نصب نشده
Fix: مرحله 1 را دوباره انجام دهید
```

### خطای "Port not found"  
```
Solution: درایور USB-to-Serial نصب نشده
Fix: 
- NodeMCU v3: درایور CH340G
- NodeMCU v2: درایور CP2102
- از سایت سازنده دانلود کنید
```

### خطای "Library not found"
```
Solution: کتابخانه‌ها درست نصب نشده
Fix: مرحله 2 را دوباره انجام دهید
```

### خطای "Compilation timeout"
```
Solution: حافظه سیستم کم است
Fix: 
- برنامه‌های غیرضروری را ببندید
- Arduino IDE را restart کنید
```

### خطای "Upload failed"
```
Solution: مشکل در اتصال یا تنظیمات
Fix:
- کابل USB را بررسی کنید
- پورت صحیح را انتخاب کنید  
- دکمه RESET روی NodeMCU را فشار دهید
- Upload speed را کاهش دهید (9600)
```

## آدرس‌های مفید

- **ESP8266 Board Package**: http://arduino.esp8266.com/stable/package_esp8266com_index.json
- **PubSubClient GitHub**: https://github.com/knolleary/pubsubclient
- **ArduinoJson GitHub**: https://github.com/bblanchon/ArduinoJson
- **ESP8266 Documentation**: https://arduino-esp8266.readthedocs.io/

## نکات مهم

1. **ورژن Arduino IDE**: حداقل 1.8.x استفاده کنید
2. **اتصال اینترنت**: برای دانلود کتابخانه‌ها نیاز است
3. **فضای دیسک**: حداقل 1GB فضای خالی
4. **صبر**: نصب ESP8266 package ممکن است 5-10 دقیقه طول بکشد
5. **Restart**: بعد از نصب کتابخانه‌های مهم، Arduino IDE را restart کنید

## تست نهایی

بعد از نصب موفق، این کد ساده را تست کنید:

```cpp
#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("=== NodeMCU Library Test ===");
  Serial.println("✅ ESP8266WiFi: OK");
  Serial.println("✅ PubSubClient: OK"); 
  Serial.println("✅ ArduinoJson: OK");
  Serial.println("✅ همه کتابخانه‌ها آماده!");
}

void loop() {
  delay(1000);
}
```

اگر این کد بدون خطا کامپایل و upload شد، آماده استفاده از فرمور اصلی هستید!
