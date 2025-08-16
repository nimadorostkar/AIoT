# IoT Device Examples & Commands

Real-world examples for testing different types of IoT devices in your platform.

## 🏠 Smart Home Device Examples

### 1. Temperature & Humidity Sensors

#### DHT22 Sensor
```bash
# Create device
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "HOME-GW-001",
    "device_id": "DHT22-LIVING",
    "type": "sensor",
    "name": "Living Room Climate",
    "model": "DHT22"
  }'

# Send telemetry
mosquitto_pub -h localhost -p 1883 \
  -t "devices/DHT22-LIVING/data" \
  -m '{
    "temperature": 23.5,
    "humidity": 62.3,
    "heat_index": 24.1,
    "timestamp": "2025-08-16T15:30:00Z"
  }' -q 1
```

#### BME280 Environmental Sensor
```bash
# Create device
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "HOME-GW-001",
    "device_id": "BME280-OUTDOOR",
    "type": "sensor", 
    "name": "Outdoor Weather Station",
    "model": "BME280"
  }'

# Send comprehensive weather data
mosquitto_pub -h localhost -p 1883 \
  -t "devices/BME280-OUTDOOR/data" \
  -m '{
    "temperature": 18.7,
    "humidity": 75.2,
    "pressure": 1013.25,
    "altitude": 120.5,
    "dew_point": 14.3,
    "timestamp": "2025-08-16T15:30:00Z"
  }' -q 1
```

### 2. Smart Switches & Relays

#### Smart Light Switch
```bash
# Create device
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "HOME-GW-001",
    "device_id": "SWITCH-KITCHEN",
    "type": "actuator",
    "name": "Kitchen Light Switch",
    "model": "SmartSwitch-v2"
  }'

# Turn ON
curl -X POST http://localhost:8000/api/devices/devices/1/command/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "toggle",
    "state": "on"
  }'

# Status feedback
mosquitto_pub -h localhost -p 1883 \
  -t "devices/SWITCH-KITCHEN/data" \
  -m '{
    "state": "on",
    "power": 60.5,
    "voltage": 220.3,
    "current": 0.27,
    "energy_today": 2.45,
    "timestamp": "2025-08-16T15:30:00Z"
  }' -q 1
```

#### Smart Dimmer
```bash
# Create device
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "HOME-GW-001",
    "device_id": "DIMMER-BEDROOM",
    "type": "dimmer",
    "name": "Bedroom Dimmer",
    "model": "SmartDimmer-Pro"
  }'

# Set brightness to 75%
curl -X POST http://localhost:8000/api/devices/devices/2/command/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "set_brightness",
    "brightness": 75
  }'

# Status feedback
mosquitto_pub -h localhost -p 1883 \
  -t "devices/DIMMER-BEDROOM/data" \
  -m '{
    "state": "on",
    "brightness": 75,
    "power": 45.3,
    "color_temp": 3000,
    "timestamp": "2025-08-16T15:30:00Z"
  }' -q 1
```

### 3. Security Devices

#### Motion Sensor (PIR)
```bash
# Create device
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "HOME-GW-001",
    "device_id": "PIR-HALLWAY",
    "type": "sensor",
    "name": "Hallway Motion Sensor",
    "model": "PIR-HC-SR501"
  }'

# Motion detected
mosquitto_pub -h localhost -p 1883 \
  -t "devices/PIR-HALLWAY/data" \
  -m '{
    "motion": true,
    "confidence": 95,
    "lux": 45,
    "temperature": 22.1,
    "timestamp": "2025-08-16T15:30:00Z"
  }' -q 1

# Motion cleared (after 30 seconds)
mosquitto_pub -h localhost -p 1883 \
  -t "devices/PIR-HALLWAY/data" \
  -m '{
    "motion": false,
    "timestamp": "2025-08-16T15:30:30Z"
  }' -q 1
```

#### Door/Window Sensor
```bash
# Create device
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "HOME-GW-001",
    "device_id": "DOOR-FRONT",
    "type": "sensor",
    "name": "Front Door Sensor",
    "model": "MagneticSensor-v3"
  }'

# Door opened
mosquitto_pub -h localhost -p 1883 \
  -t "devices/DOOR-FRONT/data" \
  -m '{
    "state": "open",
    "battery": 89,
    "signal_strength": -45,
    "tamper": false,
    "timestamp": "2025-08-16T15:30:00Z"
  }' -q 1

# Door closed
mosquitto_pub -h localhost -p 1883 \
  -t "devices/DOOR-FRONT/data" \
  -m '{
    "state": "closed",
    "timestamp": "2025-08-16T15:35:00Z"
  }' -q 1
```

#### Security Camera
```bash
# Create device
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "HOME-GW-001",
    "device_id": "CAM-FRONT-DOOR",
    "type": "camera",
    "name": "Front Door Camera",
    "model": "IPCam-4K-Pro"
  }'

# Take snapshot
curl -X POST http://localhost:8000/api/devices/devices/3/command/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "take_snapshot",
    "quality": "high",
    "resolution": "4K"
  }'

# Start recording
curl -X POST http://localhost:8000/api/devices/devices/3/command/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "start_recording",
    "duration": 300,
    "quality": "1080p",
    "motion_triggered": true
  }'

# Camera status
mosquitto_pub -h localhost -p 1883 \
  -t "devices/CAM-FRONT-DOOR/data" \
  -m '{
    "status": "online",
    "recording": true,
    "motion_detected": true,
    "resolution": "1080p",
    "fps": 30,
    "storage_used": 67,
    "night_vision": false,
    "timestamp": "2025-08-16T15:30:00Z"
  }' -q 1
```

### 4. Environmental Sensors

#### Air Quality Sensor
```bash
# Create device
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "HOME-GW-001",
    "device_id": "AQS-LIVING",
    "type": "sensor",
    "name": "Living Room Air Quality",
    "model": "AQS-Pro-v2"
  }'

# Air quality data
mosquitto_pub -h localhost -p 1883 \
  -t "devices/AQS-LIVING/data" \
  -m '{
    "pm25": 12.5,
    "pm10": 18.3,
    "co2": 420,
    "co": 0.5,
    "no2": 15.2,
    "o3": 25.8,
    "aqi": 45,
    "quality": "good",
    "temperature": 23.1,
    "humidity": 58.2,
    "timestamp": "2025-08-16T15:30:00Z"
  }' -q 1
```

#### Light Sensor
```bash
# Create device
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "HOME-GW-001",
    "device_id": "LUX-OUTDOOR",
    "type": "sensor",
    "name": "Outdoor Light Sensor",
    "model": "BH1750-v2"
  }'

# Light level data
mosquitto_pub -h localhost -p 1883 \
  -t "devices/LUX-OUTDOOR/data" \
  -m '{
    "illuminance": 15000,
    "lux_level": "daylight",
    "uv_index": 6,
    "color_temp": 5500,
    "ir_level": 234,
    "timestamp": "2025-08-16T15:30:00Z"
  }' -q 1
```

### 5. Smart Appliances

#### Smart Thermostat
```bash
# Create device
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "HOME-GW-001",
    "device_id": "THERMO-MAIN",
    "type": "thermostat",
    "name": "Main Thermostat",
    "model": "SmartThermo-Pro"
  }'

# Set temperature
curl -X POST http://localhost:8000/api/devices/devices/4/command/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "set_temperature",
    "target": 22.5,
    "mode": "heat"
  }'

# Thermostat status
mosquitto_pub -h localhost -p 1883 \
  -t "devices/THERMO-MAIN/data" \
  -m '{
    "current_temp": 21.8,
    "target_temp": 22.5,
    "mode": "heat",
    "heating": true,
    "fan": "auto",
    "humidity": 45,
    "energy_usage": 850,
    "schedule_active": true,
    "timestamp": "2025-08-16T15:30:00Z"
  }' -q 1
```

#### Smart Plug
```bash
# Create device
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "HOME-GW-001",
    "device_id": "PLUG-TV",
    "type": "actuator",
    "name": "TV Smart Plug",
    "model": "SmartPlug-Energy"
  }'

# Control plug
curl -X POST http://localhost:8000/api/devices/devices/5/command/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "toggle",
    "state": "on"
  }'

# Plug status with energy monitoring
mosquitto_pub -h localhost -p 1883 \
  -t "devices/PLUG-TV/data" \
  -m '{
    "state": "on",
    "power": 145.7,
    "voltage": 220.1,
    "current": 0.66,
    "energy_today": 3.2,
    "energy_total": 156.8,
    "cost_today": 0.48,
    "temperature": 28.5,
    "timestamp": "2025-08-16T15:30:00Z"
  }' -q 1
```

### 6. Garden & Outdoor Devices

#### Soil Moisture Sensor
```bash
# Create device
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "GARDEN-GW-001",
    "device_id": "SOIL-TOMATOES",
    "type": "sensor",
    "name": "Tomato Bed Soil Sensor",
    "model": "SoilWatch-Pro"
  }'

# Soil data
mosquitto_pub -h localhost -p 1883 \
  -t "devices/SOIL-TOMATOES/data" \
  -m '{
    "moisture": 65,
    "temperature": 19.5,
    "ph": 6.8,
    "conductivity": 1250,
    "nitrogen": 45,
    "phosphorus": 23,
    "potassium": 167,
    "light": 8500,
    "battery": 78,
    "timestamp": "2025-08-16T15:30:00Z"
  }' -q 1
```

#### Smart Irrigation Valve
```bash
# Create device
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "GARDEN-GW-001",
    "device_id": "VALVE-ZONE1",
    "type": "actuator",
    "name": "Garden Zone 1 Valve",
    "model": "SmartValve-24V"
  }'

# Start watering for 30 minutes
curl -X POST http://localhost:8000/api/devices/devices/6/command/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "start_watering",
    "duration": 1800,
    "pressure": "medium"
  }'

# Valve status
mosquitto_pub -h localhost -p 1883 \
  -t "devices/VALVE-ZONE1/data" \
  -m '{
    "state": "open",
    "flow_rate": 12.5,
    "pressure": 2.3,
    "water_used": 45.2,
    "remaining_time": 1650,
    "battery": 92,
    "timestamp": "2025-08-16T15:30:00Z"
  }' -q 1
```

## 🏭 Industrial/Commercial Examples

### 1. Energy Monitoring

#### 3-Phase Power Meter
```bash
# Create device
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "INDUSTRIAL-GW-001",
    "device_id": "POWER-MAIN",
    "type": "sensor",
    "name": "Main Power Meter",
    "model": "PM-3Phase-Pro"
  }'

# Power consumption data
mosquitto_pub -h localhost -p 1883 \
  -t "devices/POWER-MAIN/data" \
  -m '{
    "total_power": 15750,
    "l1_voltage": 230.2,
    "l2_voltage": 229.8,
    "l3_voltage": 230.5,
    "l1_current": 22.5,
    "l2_current": 23.1,
    "l3_current": 22.8,
    "l1_power": 5175,
    "l2_power": 5291,
    "l3_power": 5284,
    "frequency": 50.01,
    "power_factor": 0.95,
    "energy_total": 12567.8,
    "cost_total": 1884.2,
    "timestamp": "2025-08-16T15:30:00Z"
  }' -q 1
```

### 2. HVAC Monitoring

#### Air Handler Unit
```bash
# Create device
curl -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "BUILDING-GW-001",
    "device_id": "AHU-FLOOR2",
    "type": "sensor",
    "name": "Floor 2 Air Handler",
    "model": "AHU-Monitor-Pro"
  }'

# HVAC system data
mosquitto_pub -h localhost -p 1883 \
  -t "devices/AHU-FLOOR2/data" \
  -m '{
    "supply_temp": 16.5,
    "return_temp": 22.8,
    "outside_temp": 28.3,
    "supply_humidity": 55,
    "return_humidity": 48,
    "fan_speed": 75,
    "damper_position": 65,
    "filter_pressure": 125,
    "compressor_status": "running",
    "energy_usage": 4250,
    "airflow": 2500,
    "co2_level": 450,
    "timestamp": "2025-08-16T15:30:00Z"
  }' -q 1
```

## 🔄 Device State Management

### Device Heartbeats
```bash
# Send heartbeat for any device
mosquitto_pub -h localhost -p 1883 \
  -t "devices/DEVICE-ID/heartbeat" \
  -m '{
    "status": "online",
    "uptime": 86400,
    "memory_free": 45,
    "cpu_usage": 12,
    "battery": 85,
    "signal_strength": -42,
    "firmware_version": "1.2.3",
    "last_reboot": "2025-08-15T09:15:00Z"
  }' -q 1
```

### Device Error Reporting
```bash
# Report device error
mosquitto_pub -h localhost -p 1883 \
  -t "devices/DEVICE-ID/error" \
  -m '{
    "error_code": "SENSOR_FAULT",
    "error_message": "Temperature sensor not responding",
    "severity": "warning",
    "timestamp": "2025-08-16T15:30:00Z",
    "recovery_action": "restart_required"
  }' -q 1
```

### Firmware Update Status
```bash
# Firmware update progress
mosquitto_pub -h localhost -p 1883 \
  -t "devices/DEVICE-ID/firmware" \
  -m '{
    "status": "updating",
    "current_version": "1.2.3",
    "target_version": "1.3.0",
    "progress": 65,
    "estimated_time": 120,
    "timestamp": "2025-08-16T15:30:00Z"
  }' -q 1
```

## 📊 Bulk Testing Scripts

### Create Multiple Temperature Sensors
```bash
#!/bin/bash
for i in {1..5}; do
  ROOM=("Living Room" "Kitchen" "Bedroom" "Office" "Garage")
  curl -X POST http://localhost:8000/api/devices/devices/ \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"gateway_id\": \"HOME-GW-001\",
      \"device_id\": \"TEMP-$(printf %03d $i)\",
      \"type\": \"sensor\",
      \"name\": \"${ROOM[$((i-1))]} Temperature\",
      \"model\": \"DHT22\"
    }"
done
```

### Simulate Daily Temperature Cycle
```bash
#!/bin/bash
for hour in {0..23}; do
  # Simulate daily temperature variation
  base_temp=20
  variation=$(echo "scale=1; 5 * sin($hour * 3.14159 / 12)" | bc -l)
  temp=$(echo "scale=1; $base_temp + $variation + ($RANDOM % 20 - 10) / 10" | bc)
  
  mosquitto_pub -h localhost -p 1883 \
    -t "devices/TEMP-001/data" \
    -m "{\"temperature\": $temp, \"hour\": $hour}" -q 1
  
  echo "Hour $hour: ${temp}°C"
done
```

This comprehensive guide provides real-world examples for testing all types of IoT devices in your platform! 🚀
