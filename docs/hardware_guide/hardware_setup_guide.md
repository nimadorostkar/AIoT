# IoT Hardware Setup Guide

## Table of Contents
1. [Hardware Components](#hardware-components)
2. [ESP32 Setup](#esp32-setup)
3. [Sensor Integration](#sensor-integration)
4. [Camera Module Setup](#camera-module-setup)
5. [Power Management](#power-management)
6. [Enclosure Design](#enclosure-design)
7. [Device Firmware](#device-firmware)
8. [Troubleshooting](#troubleshooting)

## Hardware Components

### Microcontrollers

#### ESP32 (Recommended)
- **Model**: ESP32-WROOM-32
- **Features**: WiFi, Bluetooth, dual-core processor
- **GPIO Pins**: 30+ digital I/O pins
- **ADC**: 18 channels, 12-bit resolution
- **Power**: 3.3V operating voltage
- **Use Case**: Primary controller for IoT devices

#### ESP8266 (Alternative)
- **Model**: NodeMCU or Wemos D1 Mini
- **Features**: WiFi enabled, single-core
- **GPIO Pins**: 9-11 usable pins
- **ADC**: 1 channel, 10-bit resolution
- **Use Case**: Simple sensor nodes

### Sensors

#### Temperature & Humidity
1. **DHT22/AM2302**
   - Temperature: -40°C to 80°C (±0.5°C accuracy)
   - Humidity: 0-100% RH (±2-5% accuracy)
   - Interface: Digital, single-wire
   - Power: 3.3-6V

2. **BME280**
   - Temperature: -40°C to 85°C
   - Humidity: 0-100% RH
   - Pressure: 300-1100 hPa
   - Interface: I2C/SPI
   - Power: 3.3V

#### Motion Detection
1. **PIR Sensor (HC-SR501)**
   - Detection Range: 3-7 meters
   - Detection Angle: 110°
   - Interface: Digital output
   - Power: 5V (3.3V compatible)

2. **Microwave Sensor (RCWL-0516)**
   - Detection Range: 4-8 meters
   - Through-wall detection capability
   - Interface: Digital output
   - Power: 3.3V

#### Light & Air Quality
1. **BH1750 Light Sensor**
   - Range: 1-65535 lux
   - Interface: I2C
   - Power: 3.3V

2. **MQ-135 Air Quality Sensor**
   - Detects: CO2, ammonia, benzene, alcohol
   - Interface: Analog output
   - Power: 5V (voltage divider for ESP32)

### Camera Modules

#### ESP32-CAM
- **Sensor**: OV2640 (2MP)
- **Resolution**: Up to 1600x1200
- **Features**: Built-in WiFi, microSD slot
- **Interface**: Serial programming
- **Power**: 5V (external antenna recommended)

#### OV7670 (with ESP32)
- **Resolution**: 640x480 (VGA)
- **Interface**: Parallel/I2C
- **Power**: 3.3V
- **Use Case**: Lower resolution applications

### Actuators

#### LEDs
- **WS2812B RGB LED Strip**: Addressable RGB LEDs
- **Standard LEDs**: Status indicators
- **Power**: 3.3V-5V depending on type

#### Relays
- **5V Relay Module**: Control high-voltage devices
- **Solid State Relay**: For AC loads
- **Interface**: Digital control pin

#### Servo Motors
- **SG90 Micro Servo**: Small positioning tasks
- **MG996R**: Higher torque applications
- **Interface**: PWM control

## ESP32 Setup

### Development Environment

#### Arduino IDE Setup
1. Install Arduino IDE (latest version)
2. Add ESP32 board support:
   - File → Preferences
   - Add URL: `https://dl.espressif.com/dl/package_esp32_index.json`
   - Tools → Board → Board Manager → Search "ESP32" → Install

3. Install Required Libraries:
   ```
   - WiFi (built-in)
   - PubSubClient (MQTT)
   - ArduinoJson
   - DHT sensor library
   - ESP32Servo
   ```

#### PlatformIO Setup (Alternative)
```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
lib_deps = 
    knolleary/PubSubClient@^2.8
    bblanchon/ArduinoJson@^6.21.3
    adafruit/DHT sensor library@^1.4.4
    madhephaestus/ESP32Servo@^0.13.0
```

### Basic Pin Configuration

#### ESP32 GPIO Recommendations
```
Power:
- 3.3V: Sensor power supply
- GND: Common ground
- 5V: High-power devices (with level shifting)

Digital Pins:
- GPIO 2: Built-in LED
- GPIO 4, 5, 18, 19: General purpose I/O
- GPIO 21, 22: I2C (SDA, SCL)
- GPIO 16, 17: UART2 (RX, TX)

Analog Pins:
- GPIO 36, 39: Input only (sensor reading)
- GPIO 32, 33: ADC pins with DAC capability

PWM Pins:
- GPIO 12, 13, 14, 15: Servo control, LED dimming

Avoid:
- GPIO 0, 2: Boot mode pins
- GPIO 6-11: Flash memory pins
- GPIO 34, 35: Input only
```

## Sensor Integration

### Temperature & Humidity (DHT22)

#### Wiring
```
DHT22 Pin 1 (VCC) → ESP32 3.3V
DHT22 Pin 2 (Data) → ESP32 GPIO 4
DHT22 Pin 3 (NC) → Not connected
DHT22 Pin 4 (GND) → ESP32 GND
```

#### Code Example
```cpp
#include <DHT.h>

#define DHT_PIN 4
#define DHT_TYPE DHT22

DHT dht(DHT_PIN, DHT_TYPE);

void setup() {
  Serial.begin(115200);
  dht.begin();
}

void loop() {
  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature();
  
  if (!isnan(humidity) && !isnan(temperature)) {
    Serial.printf("Temp: %.2f°C, Humidity: %.2f%%\n", temperature, humidity);
  }
  
  delay(2000);
}
```

### Motion Detection (PIR)

#### Wiring
```
PIR VCC → ESP32 3.3V (or 5V with level shifter)
PIR OUT → ESP32 GPIO 5
PIR GND → ESP32 GND
```

#### Code Example
```cpp
#define PIR_PIN 5

void setup() {
  Serial.begin(115200);
  pinMode(PIR_PIN, INPUT);
}

void loop() {
  int motionState = digitalRead(PIR_PIN);
  if (motionState == HIGH) {
    Serial.println("Motion detected!");
  }
  delay(100);
}
```

### I2C Sensors (BME280)

#### Wiring
```
BME280 VCC → ESP32 3.3V
BME280 GND → ESP32 GND
BME280 SDA → ESP32 GPIO 21
BME280 SCL → ESP32 GPIO 22
```

#### Code Example
```cpp
#include <Wire.h>
#include <Adafruit_BME280.h>

Adafruit_BME280 bme;

void setup() {
  Serial.begin(115200);
  Wire.begin(21, 22); // SDA, SCL
  
  if (!bme.begin(0x76)) {
    Serial.println("BME280 not found!");
    return;
  }
}

void loop() {
  float temperature = bme.readTemperature();
  float humidity = bme.readHumidity();
  float pressure = bme.readPressure() / 100.0F;
  
  Serial.printf("Temp: %.2f°C, Humidity: %.2f%%, Pressure: %.2f hPa\n", 
                temperature, humidity, pressure);
  delay(1000);
}
```

## Camera Module Setup

### ESP32-CAM Configuration

#### Programming Setup
ESP32-CAM doesn't have built-in USB-to-Serial converter:

1. **Using USB-to-TTL Converter**:
   ```
   ESP32-CAM     USB-TTL
   5V         →  5V
   GND        →  GND
   U0R        →  TX
   U0T        →  RX
   IO0        →  GND (for programming mode)
   ```

2. **Programming Mode**:
   - Connect IO0 to GND
   - Press reset button
   - Upload code
   - Disconnect IO0 from GND
   - Press reset button

#### Basic Camera Code
```cpp
#include "esp_camera.h"
#include <WiFi.h>
#include <WebServer.h>

// Camera pin configuration for ESP32-CAM
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

WebServer server(80);

void setup() {
  Serial.begin(115200);
  
  // Camera configuration
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size = FRAMESIZE_VGA;
  config.jpeg_quality = 12;
  config.fb_count = 1;

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x", err);
    return;
  }

  // WiFi setup
  WiFi.begin("YOUR_SSID", "YOUR_PASSWORD");
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.println("Connecting to WiFi...");
  }
  
  Serial.println("WiFi connected");
  Serial.print("Camera Ready! Use 'http://");
  Serial.print(WiFi.localIP());
  Serial.println("' to stream");

  server.on("/", handleRoot);
  server.on("/stream", handleStream);
  server.begin();
}

void loop() {
  server.handleClient();
}

void handleRoot() {
  server.send(200, "text/html", 
    "<html><body><h1>ESP32-CAM</h1>"
    "<img src='/stream' style='width:100%;'>"
    "</body></html>");
}

void handleStream() {
  camera_fb_t* fb = esp_camera_fb_get();
  if (!fb) {
    server.send(500, "text/plain", "Camera capture failed");
    return;
  }
  
  server.sendHeader("Content-Type", "image/jpeg");
  server.sendHeader("Content-Length", String(fb->len));
  server.send_P(200, "image/jpeg", (const char*)fb->buf, fb->len);
  
  esp_camera_fb_return(fb);
}
```

## Power Management

### Power Supply Design

#### Battery Operation
1. **Li-Ion Battery (18650)**
   - Capacity: 2500-3500mAh
   - Voltage: 3.7V nominal (3.0-4.2V range)
   - Protection circuit required
   - Charging circuit: TP4056 module

2. **Power Management Circuit**
   ```
   Battery → Protection Board → Voltage Regulator → ESP32
   
   Components:
   - TP4056: Li-Ion charging
   - BMS (3S/4S): Battery protection
   - AMS1117-3.3: Voltage regulation
   - ESP32: Low power modes
   ```

#### Solar Power (Optional)
1. **Solar Panel**: 6V, 1-2W
2. **Charge Controller**: PWM or MPPT
3. **Battery Storage**: Li-Ion or LiFePO4
4. **Weather Protection**: IP65+ enclosure

### Low Power Optimization

#### ESP32 Sleep Modes
```cpp
#include "esp_sleep.h"

// Configure wake-up sources
void setupSleep() {
  // Timer wake-up (10 seconds)
  esp_sleep_enable_timer_wakeup(10 * 1000000);
  
  // External wake-up (PIR sensor on GPIO 5)
  esp_sleep_enable_ext0_wakeup(GPIO_NUM_5, 1);
  
  // Enter deep sleep
  esp_deep_sleep_start();
}

void setup() {
  Serial.begin(115200);
  
  // Check wake-up reason
  esp_sleep_wakeup_cause_t wakeup_reason = esp_sleep_get_wakeup_cause();
  
  switch(wakeup_reason) {
    case ESP_SLEEP_WAKEUP_EXT0:
      Serial.println("Wakeup by PIR sensor");
      break;
    case ESP_SLEEP_WAKEUP_TIMER:
      Serial.println("Wakeup by timer");
      break;
    default:
      Serial.println("First boot");
      break;
  }
  
  // Your main code here
  
  // Go back to sleep
  setupSleep();
}
```

## Enclosure Design

### Weatherproof Enclosures

#### Outdoor Applications
1. **IP Rating**: IP65 or higher
2. **Material**: ABS plastic or aluminum
3. **Ventilation**: Sealed with desiccant packs
4. **Cable Glands**: Waterproof cable entries
5. **Mounting**: UV-resistant materials

#### Design Considerations
- **Antenna Placement**: External WiFi antenna for better range
- **Heat Dissipation**: Ventilation slots (with filters)
- **Accessibility**: Easy access for maintenance
- **Cable Management**: Strain relief and waterproofing

### 3D Printed Enclosures

#### Design Files (for 3D printing)
```
Components to house:
- ESP32 development board
- Sensor breakout boards
- Battery pack
- Optional: Small display

Recommended dimensions:
- 100mm x 80mm x 40mm (basic sensor node)
- 150mm x 100mm x 60mm (camera module)

Features:
- Snap-fit assembly
- Cable management
- Mounting holes
- Ventilation slots
```

## Device Firmware

### Complete IoT Node Firmware

#### Main Application Code
```cpp
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include "esp_sleep.h"

// Configuration
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
const char* mqtt_server = "YOUR_MQTT_BROKER_IP";
const int mqtt_port = 1883;
const char* device_id = "esp32_001";

// Hardware pins
#define DHT_PIN 4
#define PIR_PIN 5
#define LED_PIN 2
#define DHT_TYPE DHT22

// Objects
WiFiClient espClient;
PubSubClient client(espClient);
DHT dht(DHT_PIN, DHT_TYPE);

// Variables
unsigned long lastMsg = 0;
char msg[256];
bool motionDetected = false;

void setup() {
  Serial.begin(115200);
  
  // Initialize hardware
  pinMode(PIR_PIN, INPUT);
  pinMode(LED_PIN, OUTPUT);
  dht.begin();
  
  // Connect to WiFi
  setupWiFi();
  
  // Setup MQTT
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(mqttCallback);
  
  // Configure sleep wake-up
  esp_sleep_enable_timer_wakeup(30 * 1000000); // 30 seconds
  esp_sleep_enable_ext0_wakeup(GPIO_NUM_5, 1); // PIR sensor
}

void loop() {
  if (!client.connected()) {
    reconnectMQTT();
  }
  client.loop();
  
  unsigned long now = millis();
  if (now - lastMsg > 10000) { // Send data every 10 seconds
    lastMsg = now;
    sendSensorData();
  }
  
  // Check for motion
  checkMotion();
  
  // Optional: Enter sleep mode after period of inactivity
  // esp_deep_sleep_start();
}

void setupWiFi() {
  delay(10);
  Serial.println("Connecting to WiFi...");
  WiFi.begin(ssid, password);
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println("");
  Serial.println("WiFi connected");
  Serial.println("IP address: ");
  Serial.println(WiFi.localIP());
}

void reconnectMQTT() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    if (client.connect(device_id)) {
      Serial.println("connected");
      
      // Subscribe to command topic
      String commandTopic = "devices/" + String(device_id) + "/commands";
      client.subscribe(commandTopic.c_str());
      
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      delay(5000);
    }
  }
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("] ");
  
  // Parse JSON command
  DynamicJsonDocument doc(1024);
  deserializeJson(doc, payload);
  
  String command = doc["command"];
  
  if (command == "led_on") {
    digitalWrite(LED_PIN, HIGH);
    Serial.println("LED turned ON");
  } else if (command == "led_off") {
    digitalWrite(LED_PIN, LOW);
    Serial.println("LED turned OFF");
  } else if (command == "get_status") {
    sendStatusUpdate();
  }
}

void sendSensorData() {
  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature();
  
  if (isnan(humidity) || isnan(temperature)) {
    Serial.println("Failed to read from DHT sensor!");
    return;
  }
  
  // Create JSON payload
  DynamicJsonDocument doc(1024);
  doc["device_id"] = device_id;
  doc["timestamp"] = millis();
  doc["data"]["temperature"] = temperature;
  doc["data"]["humidity"] = humidity;
  doc["data"]["motion_detected"] = motionDetected;
  doc["data"]["wifi_rssi"] = WiFi.RSSI();
  
  String output;
  serializeJson(doc, output);
  
  // Publish to MQTT
  String telemetryTopic = "devices/" + String(device_id) + "/telemetry";
  client.publish(telemetryTopic.c_str(), output.c_str());
  
  Serial.println("Sensor data sent: " + output);
  
  // Reset motion flag
  motionDetected = false;
}

void checkMotion() {
  static unsigned long lastMotionCheck = 0;
  unsigned long now = millis();
  
  if (now - lastMotionCheck > 100) { // Check every 100ms
    lastMotionCheck = now;
    
    if (digitalRead(PIR_PIN) == HIGH && !motionDetected) {
      motionDetected = true;
      Serial.println("Motion detected!");
      
      // Send immediate alert
      DynamicJsonDocument doc(512);
      doc["device_id"] = device_id;
      doc["timestamp"] = millis();
      doc["alert_type"] = "motion_detected";
      doc["data"]["motion"] = true;
      
      String output;
      serializeJson(doc, output);
      
      String alertTopic = "devices/" + String(device_id) + "/alerts";
      client.publish(alertTopic.c_str(), output.c_str());
    }
  }
}

void sendStatusUpdate() {
  DynamicJsonDocument doc(512);
  doc["device_id"] = device_id;
  doc["timestamp"] = millis();
  doc["status"]["online"] = true;
  doc["status"]["wifi_connected"] = WiFi.status() == WL_CONNECTED;
  doc["status"]["mqtt_connected"] = client.connected();
  doc["status"]["uptime"] = millis() / 1000;
  doc["status"]["free_heap"] = ESP.getFreeHeap();
  
  String output;
  serializeJson(doc, output);
  
  String statusTopic = "devices/" + String(device_id) + "/status";
  client.publish(statusTopic.c_str(), output.c_str());
}
```

## Troubleshooting

### Common Hardware Issues

#### ESP32 Won't Boot
1. **Check Power Supply**: Ensure stable 3.3V supply
2. **Boot Mode Pins**: Verify GPIO 0 and 2 are not pulled down
3. **Flash Size**: Ensure correct partition scheme
4. **Serial Connection**: Check RX/TX connections

#### Sensor Not Working
1. **Wiring**: Double-check connections and voltage levels
2. **Pull-up Resistors**: Add 4.7kΩ pull-ups for I2C
3. **Power Supply**: Verify sensor voltage requirements
4. **Library Issues**: Update to latest sensor libraries

#### WiFi Connection Problems
1. **Signal Strength**: Check WiFi signal quality
2. **Network Settings**: Verify SSID and password
3. **Channel Issues**: Try different WiFi channels
4. **Power Supply**: Ensure adequate current supply

#### MQTT Connection Issues
1. **Broker Settings**: Verify IP address and port
2. **Network Connectivity**: Test with MQTT client tools
3. **Firewall**: Check firewall settings
4. **Authentication**: Verify username/password if required

### Debugging Tools

#### Serial Monitor
```cpp
void debugPrint() {
  Serial.println("=== System Debug Info ===");
  Serial.printf("Free Heap: %d bytes\n", ESP.getFreeHeap());
  Serial.printf("WiFi Status: %s\n", WiFi.status() == WL_CONNECTED ? "Connected" : "Disconnected");
  Serial.printf("WiFi RSSI: %d dBm\n", WiFi.RSSI());
  Serial.printf("MQTT State: %d\n", client.state());
  Serial.printf("Uptime: %lu seconds\n", millis() / 1000);
  Serial.println("========================");
}
```

#### Oscilloscope/Logic Analyzer
- Use for debugging I2C/SPI communication
- Check PWM signals for servos
- Verify timing for DHT22 communication

#### Multimeter
- Verify power supply voltages
- Check continuity of connections
- Measure current consumption

### Performance Optimization

#### Memory Management
```cpp
void checkMemory() {
  Serial.printf("Free heap: %d\n", ESP.getFreeHeap());
  Serial.printf("Largest free block: %d\n", ESP.getMaxAllocHeap());
}
```

#### Task Scheduling
```cpp
// Use FreeRTOS tasks for complex applications
void sensorTask(void *parameter) {
  while(1) {
    readSensors();
    vTaskDelay(1000 / portTICK_PERIOD_MS);
  }
}

void mqttTask(void *parameter) {
  while(1) {
    if (!client.connected()) {
      reconnectMQTT();
    }
    client.loop();
    vTaskDelay(10 / portTICK_PERIOD_MS);
  }
}
```

This comprehensive hardware guide covers all aspects of setting up IoT devices with the system. Follow the specific sections relevant to your hardware configuration and use case.
