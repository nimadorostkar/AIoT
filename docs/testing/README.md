# IoT Testing Documentation

Complete testing suite for your IoT platform with devices, sensors, and gateways.

## 📁 Files Overview

| File | Description |
|------|-------------|
| `device_testing_guide.md` | Complete API testing guide with curl commands |
| `device_examples.md` | Real-world device examples and configurations |
| `scripts/test_iot_devices.sh` | Comprehensive automated testing script |
| `scripts/mqtt_simulator.sh` | Multi-device MQTT simulator |
| `scripts/quick_test.sh` | Quick functionality test |

## 🚀 Quick Start

### 1. Run Quick Test
```bash
cd docs/testing/scripts
./quick_test.sh
```

### 2. Full Device Testing
```bash
cd docs/testing/scripts
./test_iot_devices.sh
```

### 3. Simulate IoT Devices
```bash
cd docs/testing/scripts

# Simulate single device type
./mqtt_simulator.sh temperature
./mqtt_simulator.sh motion
./mqtt_simulator.sh switch

# Simulate all devices
./mqtt_simulator.sh all
```

## 📋 Prerequisites

- **jq**: JSON processor
  ```bash
  # macOS
  brew install jq
  
  # Ubuntu
  sudo apt-get install jq
  ```

- **mosquitto-clients**: MQTT tools (optional)
  ```bash
  # macOS
  brew install mosquitto
  
  # Ubuntu
  sudo apt-get install mosquitto-clients
  ```

## 🎯 Testing Scenarios

### Basic Functionality
- ✅ Authentication
- ✅ Gateway management
- ✅ Device creation
- ✅ Device commands
- ✅ Telemetry data

### Advanced Testing
- ✅ Multiple device types
- ✅ Real-time data simulation
- ✅ Command responses
- ✅ Error handling
- ✅ Bulk operations

### Device Types Covered
- 🌡️ Temperature/Humidity sensors
- 🚶 Motion sensors (PIR)
- 💡 Smart switches/relays
- 🎚️ Dimmers
- 📹 Security cameras
- 🚪 Door/window sensors
- 🌱 Environmental sensors
- 🏠 Smart home appliances

## 📊 Monitoring Commands

### Watch MQTT Traffic
```bash
# All device data
mosquitto_sub -h localhost -t "devices/+/data" -v

# All commands
mosquitto_sub -h localhost -t "devices/+/commands" -v

# Specific device
mosquitto_sub -h localhost -t "devices/TEMP-001/+" -v
```

### API Health Check
```bash
curl http://localhost:8000/api/devices/gateways/ \
  -H "Authorization: Bearer $TOKEN"
```

## 🔧 Troubleshooting

### Common Issues

1. **Authentication Failed**
   - Check Docker containers are running: `docker compose ps`
   - Verify credentials: `admin` / `admin123`

2. **MQTT Connection Failed**
   - Check MQTT broker: `docker compose logs mqtt`
   - Test connection: `mosquitto_pub -h localhost -t test -m "hello"`

3. **No Telemetry Data**
   - Check device creation was successful
   - Verify MQTT topics match device IDs
   - Check API logs: `docker compose logs api`

### Debug Commands
```bash
# Check all services
docker compose ps

# View API logs
docker compose logs api --tail=50

# View MQTT logs
docker compose logs mqtt --tail=50

# Test authentication
curl -X POST http://localhost:8000/api/token/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

## 📈 Performance Testing

### Load Testing
```bash
# Create 100 devices quickly
for i in {1..100}; do
  curl -s -X POST http://localhost:8000/api/devices/devices/ \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"gateway_id\":\"TEST-GW\",\"device_id\":\"DEV-$i\",\"type\":\"sensor\",\"name\":\"Device $i\"}" &
done
wait
```

### Stress Testing MQTT
```bash
# Send rapid telemetry data
for i in {1..1000}; do
  mosquitto_pub -h localhost -p 1883 \
    -t "devices/STRESS-TEST/data" \
    -m "{\"value\":$i,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" -q 1 &
done
```

## 🎉 Success Indicators

After running tests, you should see:

- ✅ Gateways listed in API response
- ✅ Devices visible in web interface
- ✅ Telemetry data in database
- ✅ Commands sent via MQTT
- ✅ Real-time updates in UI

## 🔗 Related Documentation

- [Main README](../../README.md) - Project overview and setup
- [API Documentation](http://localhost:8000/api/docs/) - Interactive API docs
- [Hardware Guide](../hardware_guide/) - Physical device setup
- [Deployment Guide](../deployment/) - Production deployment

Happy testing! 🚀
