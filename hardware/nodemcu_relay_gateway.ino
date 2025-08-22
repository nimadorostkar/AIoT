#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

// ========================================
// تنظیمات WiFi و MQTT
// ========================================
const char* ssid = "Nima";
const char* password = "1234nima!!";

// تنظیمات MQTT - باید با سرور AIoT شما مطابقت داشته باشد
const char* mqtt_server = "192.168.1.38";  // آدرس IP سرور شما
const int mqtt_port = 1883;
const char* mqtt_client_id = "NodeMCU-Gateway-001";

// شناسه‌های سیستم AIoT
const char* gateway_id = "NodeMCU-GW-001";
const char* device1_id = "RELAY-001";
const char* device2_id = "RELAY-002";

// ========================================
// تنظیمات سخت‌افزاری
// ========================================
// GPIO pins for relays
const int relay1 = D1; // GPIO5
const int relay2 = D2; // GPIO4

// LED وضعیت (بورد داخلی)
const int status_led = LED_BUILTIN;

// ========================================
// متغیرها
// ========================================
ESP8266WebServer server(80);
WiFiClient espClient;
PubSubClient mqtt_client(espClient);

// وضعیت رله‌ها
bool relay1_state = false;
bool relay2_state = false;

// زمان‌بندی برای heartbeat
unsigned long last_heartbeat = 0;
const unsigned long heartbeat_interval = 30000; // 30 ثانیه

// بافر JSON
StaticJsonDocument<512> json_buffer;

// ========================================
// تابع اتصال به WiFi
// ========================================
void setup_wifi() {
  delay(10);
  Serial.println();
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);

  WiFi.begin(ssid, password);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
    
    // چشمک زدن LED در حین اتصال
    digitalWrite(status_led, !digitalRead(status_led));
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println();
    Serial.println("WiFi connected!");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
    
    // روشن کردن LED برای نشان دادن اتصال موفق
    digitalWrite(status_led, LOW); // LOW = ON برای ESP8266
  } else {
    Serial.println();
    Serial.println("Failed to connect to WiFi.");
  }
}

// ========================================
// تابع پردازش پیام‌های MQTT
// ========================================
void mqtt_callback(char* topic, byte* payload, unsigned int length) {
  // تبدیل payload به string
  char message[length + 1];
  for (int i = 0; i < length; i++) {
    message[i] = (char)payload[i];
  }
  message[length] = '\0';
  
  Serial.printf("MQTT Message received: %s = %s\n", topic, message);
  
  // پارس کردن JSON
  DeserializationError error = deserializeJson(json_buffer, message);
  if (error) {
    Serial.print("JSON parse failed: ");
    Serial.println(error.c_str());
    return;
  }
  
  // بررسی topic و پردازش دستور
  String topic_str = String(topic);
  
  // دستورات دستگاه‌ها: devices/{device_id}/commands
  if (topic_str.startsWith("devices/") && topic_str.endsWith("/commands")) {
    handle_device_command(json_buffer);
  }
  // درخواست discovery: gateways/{gateway_id}/discover
  else if (topic_str.endsWith("/discover")) {
    handle_discovery_request(json_buffer);
  }
}

// ========================================
// پردازش دستورات دستگاه
// ========================================
void handle_device_command(JsonDocument& doc) {
  String device_id = doc["device_id"];
  String action = doc["action"];
  String command_id = doc["command_id"];
  
  Serial.printf("Device Command - ID: %s, Action: %s\n", device_id.c_str(), action.c_str());
  
  bool success = false;
  String result_state = "";
  
  if (action == "toggle") {
    String state = doc["state"];
    bool target_state = (state == "on" || state == "1" || state == "true");
    
    if (device_id == device1_id) {
      relay1_state = target_state;
      digitalWrite(relay1, relay1_state ? LOW : HIGH); // رله فعال کم
      success = true;
      result_state = relay1_state ? "on" : "off";
      Serial.printf("Relay 1 set to: %s\n", result_state.c_str());
    }
    else if (device_id == device2_id) {
      relay2_state = target_state;
      digitalWrite(relay2, relay2_state ? LOW : HIGH); // رله فعال کم
      success = true;
      result_state = relay2_state ? "on" : "off";
      Serial.printf("Relay 2 set to: %s\n", result_state.c_str());
    }
  }
  
  // ارسال پاسخ دستور
  if (success) {
    send_command_response(device_id, command_id, "success", result_state);
    // ارسال telemetry جدید
    send_device_telemetry(device_id, result_state);
  } else {
    send_command_response(device_id, command_id, "error", "Unknown device or command");
  }
}

// ========================================
// پردازش درخواست discovery
// ========================================
void handle_discovery_request(JsonDocument& doc) {
  Serial.println("Discovery request received - announcing devices");
  
  // اعلام دستگاه‌های متصل
  announce_device(device1_id, "actuator", "NodeMCU-Relay", "Relay Channel 1");
  delay(100);
  announce_device(device2_id, "actuator", "NodeMCU-Relay", "Relay Channel 2");
  
  // ارسال وضعیت فعلی دستگاه‌ها
  send_device_telemetry(device1_id, relay1_state ? "on" : "off");
  delay(100);
  send_device_telemetry(device2_id, relay2_state ? "on" : "off");
}

// ========================================
// اعلام دستگاه جدید
// ========================================
void announce_device(String device_id, String type, String model, String name) {
  json_buffer.clear();
  json_buffer["device_id"] = device_id;
  json_buffer["gateway_id"] = gateway_id;
  json_buffer["type"] = type;
  json_buffer["model"] = model;
  json_buffer["name"] = name;
  json_buffer["timestamp"] = millis();
  json_buffer["capabilities"] = JsonArray();
  json_buffer["capabilities"].add("toggle");
  
  String topic = "devices/" + device_id + "/discovery";
  String payload;
  serializeJson(json_buffer, payload);
  
  mqtt_client.publish(topic.c_str(), payload.c_str(), true); // retained message
  Serial.printf("Device announced: %s\n", device_id.c_str());
}

// ========================================
// ارسال پاسخ دستور
// ========================================
void send_command_response(String device_id, String command_id, String status, String result) {
  json_buffer.clear();
  json_buffer["command_id"] = command_id;
  json_buffer["device_id"] = device_id;
  json_buffer["status"] = status;
  json_buffer["result"] = result;
  json_buffer["timestamp"] = millis();
  
  String topic = "devices/" + device_id + "/response";
  String payload;
  serializeJson(json_buffer, payload);
  
  mqtt_client.publish(topic.c_str(), payload.c_str());
  Serial.printf("Command response sent for %s: %s\n", device_id.c_str(), status.c_str());
}

// ========================================
// ارسال telemetry دستگاه
// ========================================
void send_device_telemetry(String device_id, String state) {
  json_buffer.clear();
  json_buffer["device_id"] = device_id;
  json_buffer["gateway_id"] = gateway_id;
  json_buffer["state"] = state;
  json_buffer["timestamp"] = millis();
  json_buffer["voltage"] = 3.3;
  json_buffer["signal_strength"] = WiFi.RSSI();
  
  String topic = "devices/" + device_id + "/data";
  String payload;
  serializeJson(json_buffer, payload);
  
  mqtt_client.publish(topic.c_str(), payload.c_str());
  Serial.printf("Telemetry sent for %s: state=%s\n", device_id.c_str(), state.c_str());
}

// ========================================
// ارسال heartbeat
// ========================================
void send_heartbeat() {
  // Heartbeat برای gateway
  json_buffer.clear();
  json_buffer["gateway_id"] = gateway_id;
  json_buffer["status"] = "online";
  json_buffer["timestamp"] = millis();
  json_buffer["devices_count"] = 2;
  json_buffer["wifi_signal"] = WiFi.RSSI();
  json_buffer["free_heap"] = ESP.getFreeHeap();
  
  String topic = "gateways/" + String(gateway_id) + "/status";
  String payload;
  serializeJson(json_buffer, payload);
  
  mqtt_client.publish(topic.c_str(), payload.c_str());
  
  // Heartbeat برای دستگاه‌ها
  send_device_heartbeat(device1_id);
  delay(50);
  send_device_heartbeat(device2_id);
  
  Serial.println("Heartbeat sent");
}

void send_device_heartbeat(String device_id) {
  json_buffer.clear();
  json_buffer["device_id"] = device_id;
  json_buffer["gateway_id"] = gateway_id;
  json_buffer["status"] = "online";
  json_buffer["timestamp"] = millis();
  
  String topic = "devices/" + device_id + "/heartbeat";
  String payload;
  serializeJson(json_buffer, payload);
  
  mqtt_client.publish(topic.c_str(), payload.c_str());
}

// ========================================
// اتصال مجدد MQTT
// ========================================
void reconnect_mqtt() {
  while (!mqtt_client.connected()) {
    Serial.print("Attempting MQTT connection...");
    
    if (mqtt_client.connect(mqtt_client_id)) {
      Serial.println(" connected!");
      
      // اشتراک در topic های مورد نیاز
      String device1_cmd_topic = "devices/" + String(device1_id) + "/commands";
      String device2_cmd_topic = "devices/" + String(device2_id) + "/commands";
      String discovery_topic = "gateways/" + String(gateway_id) + "/discover";
      
      mqtt_client.subscribe(device1_cmd_topic.c_str());
      mqtt_client.subscribe(device2_cmd_topic.c_str());
      mqtt_client.subscribe(discovery_topic.c_str());
      
      Serial.printf("Subscribed to:\n");
      Serial.printf("  - %s\n", device1_cmd_topic.c_str());
      Serial.printf("  - %s\n", device2_cmd_topic.c_str());
      Serial.printf("  - %s\n", discovery_topic.c_str());
      
      // اعلام devices بعد از اتصال
      delay(1000);
      announce_device(device1_id, "actuator", "NodeMCU-Relay", "Relay Channel 1");
      delay(100);
      announce_device(device2_id, "actuator", "NodeMCU-Relay", "Relay Channel 2");
      
      // ارسال heartbeat اولیه
      send_heartbeat();
      
    } else {
      Serial.print(" failed, rc=");
      Serial.print(mqtt_client.state());
      Serial.println(" trying again in 5 seconds");
      delay(5000);
    }
  }
}

// ========================================
// تنظیم route های HTTP (اختیاری - برای تست مستقیم)
// ========================================
void setup_http_routes() {
  // صفحه اصلی
  server.on("/", []() {
    String html = "<!DOCTYPE html><html>";
    html += "<head><meta charset='UTF-8'><title>NodeMCU IoT Gateway</title></head>";
    html += "<body style='font-family: Arial'>";
    html += "<h1>NodeMCU IoT Gateway</h1>";
    html += "<p><strong>Gateway ID:</strong> " + String(gateway_id) + "</p>";
    html += "<p><strong>WiFi Signal:</strong> " + String(WiFi.RSSI()) + " dBm</p>";
    html += "<p><strong>Free Heap:</strong> " + String(ESP.getFreeHeap()) + " bytes</p>";
    html += "<h2>Relay Status</h2>";
    html += "<p>Relay 1 (" + String(device1_id) + "): " + (relay1_state ? "ON" : "OFF") + "</p>";
    html += "<p>Relay 2 (" + String(device2_id) + "): " + (relay2_state ? "ON" : "OFF") + "</p>";
    html += "<h2>Direct Control (برای تست)</h2>";
    html += "<a href='/relay1/on'><button>Relay 1 ON</button></a> ";
    html += "<a href='/relay1/off'><button>Relay 1 OFF</button></a><br><br>";
    html += "<a href='/relay2/on'><button>Relay 2 ON</button></a> ";
    html += "<a href='/relay2/off'><button>Relay 2 OFF</button></a>";
    html += "</body></html>";
    
    server.send(200, "text/html", html);
  });

  // کنترل مستقیم رله 1
  server.on("/relay1/on", []() {
    relay1_state = true;
    digitalWrite(relay1, LOW);
    send_device_telemetry(device1_id, "on");
    server.send(200, "text/plain", "Relay 1 ON");
    Serial.println("HTTP: Relay 1 ON");
  });

  server.on("/relay1/off", []() {
    relay1_state = false;
    digitalWrite(relay1, HIGH);
    send_device_telemetry(device1_id, "off");
    server.send(200, "text/plain", "Relay 1 OFF");
    Serial.println("HTTP: Relay 1 OFF");
  });

  // کنترل مستقیم رله 2
  server.on("/relay2/on", []() {
    relay2_state = true;
    digitalWrite(relay2, LOW);
    send_device_telemetry(device2_id, "on");
    server.send(200, "text/plain", "Relay 2 ON");
    Serial.println("HTTP: Relay 2 ON");
  });

  server.on("/relay2/off", []() {
    relay2_state = false;
    digitalWrite(relay2, HIGH);
    send_device_telemetry(device2_id, "off");
    server.send(200, "text/plain", "Relay 2 OFF");
    Serial.println("HTTP: Relay 2 OFF");
  });

  // API endpoint برای status
  server.on("/api/status", []() {
    json_buffer.clear();
    json_buffer["gateway_id"] = gateway_id;
    json_buffer["wifi_connected"] = WiFi.status() == WL_CONNECTED;
    json_buffer["mqtt_connected"] = mqtt_client.connected();
    json_buffer["wifi_signal"] = WiFi.RSSI();
    json_buffer["free_heap"] = ESP.getFreeHeap();
    json_buffer["uptime"] = millis();
    json_buffer["devices"][device1_id] = relay1_state ? "on" : "off";
    json_buffer["devices"][device2_id] = relay2_state ? "on" : "off";
    
    String response;
    serializeJson(json_buffer, response);
    server.send(200, "application/json", response);
  });
}

// ========================================
// SETUP
// ========================================
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n=== NodeMCU IoT Gateway Starting ===");

  // تنظیم GPIO
  pinMode(relay1, OUTPUT);
  pinMode(relay2, OUTPUT);
  pinMode(status_led, OUTPUT);
  
  // حالت اولیه رله‌ها (خاموش)
  digitalWrite(relay1, HIGH);  // HIGH = OFF برای رله
  digitalWrite(relay2, HIGH);  // HIGH = OFF برای رله
  digitalWrite(status_led, HIGH); // HIGH = OFF برای LED داخلی
  
  relay1_state = false;
  relay2_state = false;

  // اتصال به WiFi
  setup_wifi();

  // تنظیم MQTT
  mqtt_client.setServer(mqtt_server, mqtt_port);
  mqtt_client.setCallback(mqtt_callback);
  mqtt_client.setBufferSize(1024); // افزایش بافر برای JSON های بزرگ

  // تنظیم HTTP server
  setup_http_routes();
  server.begin();
  Serial.println("HTTP server started on port 80");

  // اتصال اولیه MQTT
  if (WiFi.status() == WL_CONNECTED) {
    reconnect_mqtt();
  }

  Serial.println("=== Setup Complete ===");
  Serial.printf("Gateway ID: %s\n", gateway_id);
  Serial.printf("Device 1 ID: %s\n", device1_id);
  Serial.printf("Device 2 ID: %s\n", device2_id);
  Serial.printf("IP Address: %s\n", WiFi.localIP().toString().c_str());
}

// ========================================
// MAIN LOOP
// ========================================
void loop() {
  // بررسی اتصال WiFi
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected! Attempting to reconnect...");
    setup_wifi();
  }

  // بررسی اتصال MQTT
  if (WiFi.status() == WL_CONNECTED && !mqtt_client.connected()) {
    reconnect_mqtt();
  }

  // پردازش MQTT
  if (mqtt_client.connected()) {
    mqtt_client.loop();
  }

  // پردازش HTTP requests
  server.handleClient();

  // ارسال heartbeat دوره‌ای
  unsigned long now = millis();
  if (now - last_heartbeat > heartbeat_interval) {
    if (mqtt_client.connected()) {
      send_heartbeat();
    }
    last_heartbeat = now;
  }

  // تاخیر کوتاه
  delay(10);
}
