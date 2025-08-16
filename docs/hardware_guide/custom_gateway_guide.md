# Custom IoT Gateway Development Guide

## Table of Contents
1. [Gateway Overview](#gateway-overview)
2. [Hardware Requirements](#hardware-requirements)
3. [Gateway Architecture](#gateway-architecture)
4. [Software Stack](#software-stack)
5. [Communication Protocols](#communication-protocols)
6. [Device Management](#device-management)
7. [Data Processing](#data-processing)
8. [Security Implementation](#security-implementation)
9. [Deployment Options](#deployment-options)
10. [Monitoring & Maintenance](#monitoring--maintenance)

## Gateway Overview

### What is an IoT Gateway?

An IoT Gateway serves as a bridge between IoT devices and cloud services, providing:
- **Protocol Translation**: Convert between different IoT protocols
- **Data Aggregation**: Collect and batch data from multiple devices
- **Edge Computing**: Process data locally before sending to cloud
- **Security**: Implement authentication and encryption
- **Device Management**: Monitor and control connected devices
- **Offline Capability**: Store and forward data when connectivity is lost

### Gateway Functions in Our System

```
[IoT Devices] ←→ [Gateway] ←→ [Backend API/MQTT Broker]
     │              │              │
   WiFi/BLE    Local Processing   Internet
   ZigBee      Data Caching       Cloud Services
   LoRa        Protocol Bridge    Remote Management
```

## Hardware Requirements

### Recommended Hardware Platforms

#### Option 1: Raspberry Pi 4 (Recommended)
```
Specifications:
- CPU: Quad-core ARM Cortex-A72 (1.5GHz)
- RAM: 4GB or 8GB
- Storage: 32GB+ microSD card
- Connectivity: WiFi, Ethernet, Bluetooth
- GPIO: 40 pins for sensor connections
- Power: 5V/3A USB-C

Advantages:
- Full Linux OS support
- Large community and ecosystem
- Multiple connectivity options
- Good performance for edge computing
- Easy development and debugging
```

#### Option 2: Industrial PC/Mini PC
```
Examples: Intel NUC, ASUS PN series
Specifications:
- CPU: x86-64 (Intel/AMD)
- RAM: 8GB+
- Storage: SSD 128GB+
- Connectivity: WiFi, Ethernet, multiple USB
- Operating System: Linux/Windows

Advantages:
- High performance for complex processing
- Reliable for industrial environments
- Multiple communication interfaces
- Easy integration with existing systems
```

#### Option 3: Custom ARM Board
```
Examples: BeagleBone, Orange Pi, Rock Pi
Specifications:
- ARM-based processor
- 2-4GB RAM
- Various connectivity options
- GPIO pins for custom interfaces

Advantages:
- Cost-effective
- Customizable for specific needs
- Low power consumption
- Compact form factor
```

### Essential Peripherals

#### Communication Modules
1. **WiFi Module**: ESP32 or USB WiFi adapter
2. **Cellular Module**: 4G/LTE for remote locations
3. **LoRa Module**: SX1276/SX1278 for long-range communication
4. **ZigBee Coordinator**: CC2531 or similar
5. **Bluetooth Module**: For BLE device communication

#### Storage & Processing
1. **External Storage**: USB drive or NAS for data buffering
2. **Real-time Clock**: DS3231 for timestamp accuracy
3. **Watchdog Timer**: Hardware reset capability
4. **Battery Backup**: UPS for power outages

## Gateway Architecture

### Software Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Gateway Application                   │
├─────────────────────────────────────────────────────────┤
│  Device Manager  │  Data Processor  │  Cloud Connector  │
├─────────────────────────────────────────────────────────┤
│  Protocol Stack  │  Security Layer  │  Storage Manager  │
├─────────────────────────────────────────────────────────┤
│           Operating System (Linux/Windows)              │
├─────────────────────────────────────────────────────────┤
│                    Hardware Layer                       │
└─────────────────────────────────────────────────────────┘
```

### Core Components

#### 1. Device Discovery & Management
- Automatic device detection
- Device registration and authentication
- Firmware update management
- Health monitoring and diagnostics

#### 2. Protocol Translation
- MQTT ↔ CoAP conversion
- WiFi ↔ LoRa bridging
- BLE ↔ MQTT translation
- Custom protocol support

#### 3. Data Processing
- Data validation and filtering
- Format conversion and normalization
- Aggregation and compression
- Edge analytics and ML inference

#### 4. Communication Management
- Multiple communication channels
- Failover and redundancy
- Quality of Service (QoS) management
- Offline data caching

## Software Stack

### Operating System Setup

#### Raspberry Pi OS Configuration
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y python3 python3-pip nodejs npm git vim htop

# Install Docker (optional but recommended)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Python packages
pip3 install paho-mqtt flask requests sqlite3 psutil

# Install Node.js packages
npm install -g pm2
```

#### System Services Configuration
```bash
# Enable SSH
sudo systemctl enable ssh

# Configure WiFi (if needed)
sudo nano /etc/wpa_supplicant/wpa_supplicant.conf

# Set up automatic startup
sudo systemctl enable your-gateway-service
```

### Gateway Application Development

#### Core Gateway Service (Python)

```python
#!/usr/bin/env python3
"""
IoT Gateway Service
Handles device communication, data processing, and cloud connectivity
"""

import json
import time
import sqlite3
import threading
import logging
from datetime import datetime
from typing import Dict, List, Any

import paho.mqtt.client as mqtt
import requests
from flask import Flask, request, jsonify

# Configuration
CONFIG = {
    'mqtt_broker': 'localhost',
    'mqtt_port': 1883,
    'backend_url': 'http://your-backend-server:8000',
    'database_path': '/var/lib/gateway/gateway.db',
    'log_level': 'INFO',
    'device_timeout': 300,  # 5 minutes
    'batch_size': 100,
    'sync_interval': 30,  # seconds
}

class GatewayService:
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.devices = {}
        self.data_buffer = []
        self.running = False
        
        # Setup logging
        logging.basicConfig(
            level=getattr(logging, config['log_level']),
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger('GatewayService')
        
        # Initialize database
        self.init_database()
        
        # Setup MQTT client
        self.mqtt_client = mqtt.Client()
        self.mqtt_client.on_connect = self.on_mqtt_connect
        self.mqtt_client.on_message = self.on_mqtt_message
        
        # Setup Flask API
        self.app = Flask(__name__)
        self.setup_api_routes()
        
    def init_database(self):
        """Initialize SQLite database for local storage"""
        self.conn = sqlite3.connect(self.config['database_path'], check_same_thread=False)
        self.cursor = self.conn.cursor()
        
        # Create tables
        self.cursor.execute('''
            CREATE TABLE IF NOT EXISTS devices (
                id TEXT PRIMARY KEY,
                name TEXT,
                type TEXT,
                last_seen TIMESTAMP,
                status TEXT,
                metadata TEXT
            )
        ''')
        
        self.cursor.execute('''
            CREATE TABLE IF NOT EXISTS telemetry (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_id TEXT,
                timestamp TIMESTAMP,
                data TEXT,
                synced BOOLEAN DEFAULT FALSE
            )
        ''')
        
        self.conn.commit()
        
    def setup_api_routes(self):
        """Setup Flask API routes for gateway management"""
        
        @self.app.route('/api/status', methods=['GET'])
        def get_status():
            return jsonify({
                'status': 'running' if self.running else 'stopped',
                'devices_count': len(self.devices),
                'buffer_size': len(self.data_buffer),
                'uptime': time.time() - self.start_time if hasattr(self, 'start_time') else 0
            })
        
        @self.app.route('/api/devices', methods=['GET'])
        def get_devices():
            return jsonify(list(self.devices.values()))
        
        @self.app.route('/api/devices/<device_id>/command', methods=['POST'])
        def send_command(device_id):
            command_data = request.json
            if device_id in self.devices:
                self.send_device_command(device_id, command_data)
                return jsonify({'status': 'success'})
            return jsonify({'status': 'error', 'message': 'Device not found'}), 404
    
    def on_mqtt_connect(self, client, userdata, flags, rc):
        """MQTT connection callback"""
        self.logger.info(f"Connected to MQTT broker with result code {rc}")
        
        # Subscribe to all device topics
        client.subscribe("devices/+/telemetry")
        client.subscribe("devices/+/status")
        client.subscribe("devices/+/discovery")
        
    def on_mqtt_message(self, client, userdata, msg):
        """MQTT message callback"""
        try:
            topic_parts = msg.topic.split('/')
            device_id = topic_parts[1]
            message_type = topic_parts[2]
            
            payload = json.loads(msg.payload.decode())
            
            if message_type == 'telemetry':
                self.handle_telemetry(device_id, payload)
            elif message_type == 'status':
                self.handle_device_status(device_id, payload)
            elif message_type == 'discovery':
                self.handle_device_discovery(device_id, payload)
                
        except Exception as e:
            self.logger.error(f"Error processing MQTT message: {e}")
    
    def handle_telemetry(self, device_id: str, data: Dict[str, Any]):
        """Process telemetry data from devices"""
        self.logger.debug(f"Received telemetry from {device_id}: {data}")
        
        # Update device last seen
        if device_id in self.devices:
            self.devices[device_id]['last_seen'] = datetime.now()
        
        # Validate and process data
        processed_data = self.process_telemetry(device_id, data)
        
        # Store in local database
        self.store_telemetry(device_id, processed_data)
        
        # Add to buffer for cloud sync
        self.data_buffer.append({
            'device_id': device_id,
            'timestamp': datetime.now().isoformat(),
            'data': processed_data
        })
        
        # Check if buffer needs to be flushed
        if len(self.data_buffer) >= self.config['batch_size']:
            self.sync_to_cloud()
    
    def handle_device_status(self, device_id: str, status: Dict[str, Any]):
        """Handle device status updates"""
        self.logger.info(f"Device {device_id} status: {status}")
        
        if device_id in self.devices:
            self.devices[device_id].update(status)
            self.devices[device_id]['last_seen'] = datetime.now()
        
        # Update database
        self.update_device_status(device_id, status)
    
    def handle_device_discovery(self, device_id: str, discovery_data: Dict[str, Any]):
        """Handle new device discovery"""
        self.logger.info(f"New device discovered: {device_id}")
        
        device_info = {
            'id': device_id,
            'name': discovery_data.get('name', f'Device {device_id}'),
            'type': discovery_data.get('type', 'unknown'),
            'capabilities': discovery_data.get('capabilities', []),
            'last_seen': datetime.now(),
            'status': 'online'
        }
        
        self.devices[device_id] = device_info
        self.register_device(device_info)
    
    def process_telemetry(self, device_id: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """Process and validate telemetry data"""
        processed = {
            'raw_data': data,
            'timestamp': data.get('timestamp', datetime.now().isoformat()),
            'quality_score': self.calculate_data_quality(data)
        }
        
        # Apply device-specific processing rules
        if device_id in self.devices:
            device_type = self.devices[device_id].get('type')
            processed['normalized_data'] = self.normalize_data(data, device_type)
        
        return processed
    
    def calculate_data_quality(self, data: Dict[str, Any]) -> float:
        """Calculate data quality score (0-1)"""
        score = 1.0
        
        # Check for missing fields
        required_fields = ['timestamp']
        for field in required_fields:
            if field not in data:
                score -= 0.2
        
        # Check for null values
        null_count = sum(1 for v in data.values() if v is None)
        if null_count > 0:
            score -= (null_count * 0.1)
        
        return max(0.0, score)
    
    def normalize_data(self, data: Dict[str, Any], device_type: str) -> Dict[str, Any]:
        """Normalize data based on device type"""
        normalized = {}
        
        if device_type == 'temperature_sensor':
            # Convert temperature to Celsius if needed
            temp = data.get('temperature')
            if temp is not None:
                # Assume Fahrenheit if > 50
                if temp > 50:
                    normalized['temperature_c'] = (temp - 32) * 5/9
                else:
                    normalized['temperature_c'] = temp
        
        elif device_type == 'motion_sensor':
            # Normalize motion detection
            motion = data.get('motion')
            normalized['motion_detected'] = bool(motion)
        
        return normalized
    
    def store_telemetry(self, device_id: str, data: Dict[str, Any]):
        """Store telemetry data in local database"""
        try:
            self.cursor.execute('''
                INSERT INTO telemetry (device_id, timestamp, data)
                VALUES (?, ?, ?)
            ''', (device_id, datetime.now(), json.dumps(data)))
            self.conn.commit()
        except Exception as e:
            self.logger.error(f"Error storing telemetry: {e}")
    
    def sync_to_cloud(self):
        """Synchronize buffered data to cloud backend"""
        if not self.data_buffer:
            return
        
        try:
            response = requests.post(
                f"{self.config['backend_url']}/api/gateway/telemetry/",
                json={'data': self.data_buffer},
                timeout=30
            )
            
            if response.status_code == 200:
                self.logger.info(f"Synced {len(self.data_buffer)} records to cloud")
                self.mark_data_synced()
                self.data_buffer.clear()
            else:
                self.logger.error(f"Failed to sync data: {response.status_code}")
                
        except Exception as e:
            self.logger.error(f"Error syncing to cloud: {e}")
    
    def mark_data_synced(self):
        """Mark telemetry data as synced in database"""
        try:
            self.cursor.execute('''
                UPDATE telemetry SET synced = TRUE 
                WHERE synced = FALSE
            ''')
            self.conn.commit()
        except Exception as e:
            self.logger.error(f"Error marking data as synced: {e}")
    
    def send_device_command(self, device_id: str, command: Dict[str, Any]):
        """Send command to device via MQTT"""
        topic = f"devices/{device_id}/commands"
        self.mqtt_client.publish(topic, json.dumps(command))
        self.logger.info(f"Sent command to {device_id}: {command}")
    
    def register_device(self, device_info: Dict[str, Any]):
        """Register new device with backend"""
        try:
            response = requests.post(
                f"{self.config['backend_url']}/api/devices/",
                json=device_info,
                timeout=10
            )
            
            if response.status_code == 201:
                self.logger.info(f"Device {device_info['id']} registered with backend")
            else:
                self.logger.error(f"Failed to register device: {response.status_code}")
                
        except Exception as e:
            self.logger.error(f"Error registering device: {e}")
    
    def update_device_status(self, device_id: str, status: Dict[str, Any]):
        """Update device status in database"""
        try:
            self.cursor.execute('''
                UPDATE devices SET last_seen = ?, status = ?, metadata = ?
                WHERE id = ?
            ''', (datetime.now(), status.get('status', 'unknown'), 
                  json.dumps(status), device_id))
            self.conn.commit()
        except Exception as e:
            self.logger.error(f"Error updating device status: {e}")
    
    def monitor_devices(self):
        """Monitor device health and connectivity"""
        while self.running:
            current_time = datetime.now()
            timeout_threshold = self.config['device_timeout']
            
            for device_id, device in self.devices.items():
                last_seen = device.get('last_seen')
                if last_seen:
                    time_diff = (current_time - last_seen).total_seconds()
                    if time_diff > timeout_threshold:
                        device['status'] = 'offline'
                        self.logger.warning(f"Device {device_id} marked as offline")
            
            time.sleep(60)  # Check every minute
    
    def periodic_sync(self):
        """Periodically sync data to cloud"""
        while self.running:
            time.sleep(self.config['sync_interval'])
            if self.data_buffer:
                self.sync_to_cloud()
    
    def start(self):
        """Start the gateway service"""
        self.logger.info("Starting IoT Gateway Service")
        self.running = True
        self.start_time = time.time()
        
        # Connect to MQTT broker
        self.mqtt_client.connect(self.config['mqtt_broker'], self.config['mqtt_port'], 60)
        self.mqtt_client.loop_start()
        
        # Start background threads
        threading.Thread(target=self.monitor_devices, daemon=True).start()
        threading.Thread(target=self.periodic_sync, daemon=True).start()
        
        # Start Flask API server
        self.app.run(host='0.0.0.0', port=5000, debug=False)
    
    def stop(self):
        """Stop the gateway service"""
        self.logger.info("Stopping IoT Gateway Service")
        self.running = False
        self.mqtt_client.loop_stop()
        self.mqtt_client.disconnect()
        self.conn.close()

if __name__ == "__main__":
    gateway = GatewayService(CONFIG)
    try:
        gateway.start()
    except KeyboardInterrupt:
        gateway.stop()
```

#### Gateway Configuration File

```yaml
# gateway_config.yaml
gateway:
  name: "IoT Gateway 001"
  location: "Building A, Floor 1"
  
mqtt:
  broker: "localhost"
  port: 1883
  username: ""
  password: ""
  keepalive: 60
  
backend:
  url: "http://your-backend-server:8000"
  api_key: "your-api-key"
  sync_interval: 30
  batch_size: 100
  
database:
  path: "/var/lib/gateway/gateway.db"
  backup_interval: 3600  # 1 hour
  
logging:
  level: "INFO"
  file: "/var/log/gateway/gateway.log"
  max_size: "10MB"
  backup_count: 5

devices:
  discovery:
    enabled: true
    timeout: 300  # 5 minutes
  
  protocols:
    mqtt:
      enabled: true
    coap:
      enabled: false
    lora:
      enabled: false
  
security:
  tls_enabled: false
  cert_path: "/etc/gateway/certs/"
  device_auth: true
  
monitoring:
  health_check_interval: 60
  metrics_collection: true
  alert_thresholds:
    device_offline: 300
    memory_usage: 80
    disk_usage: 90
```

## Communication Protocols

### Protocol Bridge Implementation

#### MQTT to CoAP Bridge
```python
import asyncio
import aiocoap
from aiocoap import Message, Code

class MQTTCoAPBridge:
    def __init__(self, mqtt_client, coap_context):
        self.mqtt_client = mqtt_client
        self.coap_context = coap_context
        
    async def mqtt_to_coap(self, topic, payload):
        """Forward MQTT message to CoAP"""
        # Convert MQTT topic to CoAP URI
        uri = f"coap://device-ip/{topic.replace('/', '-')}"
        
        request = Message(code=Code.PUT, uri=uri, payload=payload)
        try:
            response = await self.coap_context.request(request).response
            return response.code == Code.CHANGED
        except Exception as e:
            print(f"CoAP request failed: {e}")
            return False
    
    def coap_to_mqtt(self, uri, payload):
        """Forward CoAP message to MQTT"""
        # Convert CoAP URI to MQTT topic
        topic = uri.path.replace('-', '/')
        self.mqtt_client.publish(topic, payload)
```

#### LoRa Integration
```python
import serial
import json

class LoRaGateway:
    def __init__(self, serial_port='/dev/ttyUSB0', baudrate=9600):
        self.serial = serial.Serial(serial_port, baudrate)
        
    def send_command(self, device_addr, command):
        """Send command to LoRa device"""
        message = {
            'addr': device_addr,
            'cmd': command,
            'timestamp': time.time()
        }
        
        packet = f"AT+SEND={device_addr},{len(json.dumps(message))},{json.dumps(message)}\r\n"
        self.serial.write(packet.encode())
        
    def receive_data(self):
        """Receive data from LoRa devices"""
        while True:
            if self.serial.in_waiting:
                line = self.serial.readline().decode().strip()
                if line.startswith('+RCV='):
                    # Parse incoming data
                    parts = line.split(',')
                    addr = parts[0].split('=')[1]
                    data_len = int(parts[1])
                    rssi = int(parts[2])
                    snr = int(parts[3])
                    data = parts[4]
                    
                    yield {
                        'device_addr': addr,
                        'data': json.loads(data),
                        'rssi': rssi,
                        'snr': snr
                    }
```

## Device Management

### Device Provisioning

#### Automatic Device Discovery
```python
class DeviceDiscovery:
    def __init__(self, gateway):
        self.gateway = gateway
        self.discovery_methods = [
            self.mdns_discovery,
            self.mqtt_discovery,
            self.upnp_discovery
        ]
    
    async def discover_devices(self):
        """Run all discovery methods"""
        tasks = [method() for method in self.discovery_methods]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        devices = []
        for result in results:
            if not isinstance(result, Exception):
                devices.extend(result)
        
        return devices
    
    async def mdns_discovery(self):
        """Discover devices using mDNS/Bonjour"""
        # Implementation for mDNS discovery
        pass
    
    async def mqtt_discovery(self):
        """Discover devices using MQTT discovery protocol"""
        # Listen for discovery messages on MQTT
        pass
    
    async def upnp_discovery(self):
        """Discover devices using UPnP"""
        # Implementation for UPnP discovery
        pass
```

#### Device Authentication
```python
import hashlib
import hmac
import secrets

class DeviceAuth:
    def __init__(self, secret_key):
        self.secret_key = secret_key
        
    def generate_device_credentials(self, device_id):
        """Generate credentials for a new device"""
        device_secret = secrets.token_hex(32)
        device_hash = hmac.new(
            self.secret_key.encode(),
            device_id.encode(),
            hashlib.sha256
        ).hexdigest()
        
        return {
            'device_id': device_id,
            'device_secret': device_secret,
            'device_hash': device_hash
        }
    
    def verify_device(self, device_id, provided_hash):
        """Verify device authentication"""
        expected_hash = hmac.new(
            self.secret_key.encode(),
            device_id.encode(),
            hashlib.sha256
        ).hexdigest()
        
        return hmac.compare_digest(expected_hash, provided_hash)
```

## Data Processing

### Edge Analytics

#### Real-time Data Processing
```python
import numpy as np
from collections import deque

class EdgeAnalytics:
    def __init__(self, window_size=100):
        self.window_size = window_size
        self.data_windows = {}
        
    def process_sensor_data(self, device_id, sensor_type, value):
        """Process sensor data and detect anomalies"""
        key = f"{device_id}_{sensor_type}"
        
        if key not in self.data_windows:
            self.data_windows[key] = deque(maxlen=self.window_size)
        
        self.data_windows[key].append(value)
        
        # Calculate statistics
        data_array = np.array(self.data_windows[key])
        stats = {
            'mean': np.mean(data_array),
            'std': np.std(data_array),
            'min': np.min(data_array),
            'max': np.max(data_array),
            'current': value
        }
        
        # Anomaly detection
        if len(data_array) > 10:
            z_score = abs((value - stats['mean']) / stats['std'])
            stats['anomaly'] = z_score > 3  # 3-sigma rule
            stats['z_score'] = z_score
        
        return stats
    
    def predict_failure(self, device_id, metrics):
        """Simple failure prediction based on trends"""
        # Implement simple trend analysis
        recent_data = list(self.data_windows.get(device_id, []))[-10:]
        if len(recent_data) < 5:
            return False
        
        # Check for consistent degradation
        trend = np.polyfit(range(len(recent_data)), recent_data, 1)[0]
        return trend < -0.1  # Declining trend
```

#### Data Compression
```python
import gzip
import json

class DataCompression:
    def __init__(self, compression_level=6):
        self.compression_level = compression_level
    
    def compress_telemetry(self, telemetry_batch):
        """Compress batch of telemetry data"""
        json_data = json.dumps(telemetry_batch)
        compressed = gzip.compress(
            json_data.encode(),
            compresslevel=self.compression_level
        )
        
        compression_ratio = len(compressed) / len(json_data.encode())
        
        return {
            'data': compressed,
            'original_size': len(json_data.encode()),
            'compressed_size': len(compressed),
            'compression_ratio': compression_ratio
        }
    
    def decompress_telemetry(self, compressed_data):
        """Decompress telemetry data"""
        decompressed = gzip.decompress(compressed_data)
        return json.loads(decompressed.decode())
```

## Security Implementation

### Encryption and Authentication

#### TLS/SSL Configuration
```python
import ssl
import socket

class SecureConnection:
    def __init__(self, cert_file, key_file, ca_file=None):
        self.cert_file = cert_file
        self.key_file = key_file
        self.ca_file = ca_file
        
    def create_secure_context(self):
        """Create SSL context for secure connections"""
        context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)
        
        if self.ca_file:
            context.load_verify_locations(self.ca_file)
        
        context.load_cert_chain(self.cert_file, self.key_file)
        context.check_hostname = False
        context.verify_mode = ssl.CERT_REQUIRED
        
        return context
    
    def secure_mqtt_connection(self, mqtt_client):
        """Configure MQTT client for secure connection"""
        context = self.create_secure_context()
        mqtt_client.tls_set_context(context)
        return mqtt_client
```

#### API Key Management
```python
import secrets
import hashlib
import time

class APIKeyManager:
    def __init__(self):
        self.api_keys = {}
        
    def generate_api_key(self, device_id, expiry_hours=24):
        """Generate API key for device"""
        key = secrets.token_urlsafe(32)
        key_hash = hashlib.sha256(key.encode()).hexdigest()
        
        self.api_keys[key_hash] = {
            'device_id': device_id,
            'created': time.time(),
            'expires': time.time() + (expiry_hours * 3600)
        }
        
        return key
    
    def validate_api_key(self, key):
        """Validate API key"""
        key_hash = hashlib.sha256(key.encode()).hexdigest()
        
        if key_hash not in self.api_keys:
            return None
            
        key_info = self.api_keys[key_hash]
        
        if time.time() > key_info['expires']:
            del self.api_keys[key_hash]
            return None
            
        return key_info['device_id']
```

## Deployment Options

### Systemd Service Configuration

#### Gateway Service Unit File
```ini
# /etc/systemd/system/iot-gateway.service
[Unit]
Description=IoT Gateway Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=iot-gateway
Group=iot-gateway
WorkingDirectory=/opt/iot-gateway
ExecStart=/usr/bin/python3 /opt/iot-gateway/gateway_service.py
Restart=always
RestartSec=10
Environment=PYTHONPATH=/opt/iot-gateway

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=iot-gateway

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/gateway /var/log/gateway

[Install]
WantedBy=multi-user.target
```

#### Installation Script
```bash
#!/bin/bash
# install_gateway.sh

set -e

# Create user and directories
sudo useradd -r -s /bin/false iot-gateway
sudo mkdir -p /opt/iot-gateway
sudo mkdir -p /var/lib/gateway
sudo mkdir -p /var/log/gateway
sudo mkdir -p /etc/iot-gateway

# Set permissions
sudo chown -R iot-gateway:iot-gateway /opt/iot-gateway
sudo chown -R iot-gateway:iot-gateway /var/lib/gateway
sudo chown -R iot-gateway:iot-gateway /var/log/gateway

# Copy service files
sudo cp gateway_service.py /opt/iot-gateway/
sudo cp gateway_config.yaml /etc/iot-gateway/
sudo cp iot-gateway.service /etc/systemd/system/

# Install Python dependencies
sudo pip3 install -r requirements.txt

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable iot-gateway
sudo systemctl start iot-gateway

echo "IoT Gateway installed and started successfully"
```

### Docker Deployment

#### Dockerfile
```dockerfile
FROM python:3.9-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY gateway_service.py .
COPY config/ ./config/

# Create non-root user
RUN useradd -r -s /bin/false gateway
RUN chown -R gateway:gateway /app
USER gateway

# Expose ports
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/api/status || exit 1

# Run application
CMD ["python", "gateway_service.py"]
```

#### Docker Compose Configuration
```yaml
version: '3.8'

services:
  iot-gateway:
    build: .
    container_name: iot-gateway
    restart: unless-stopped
    ports:
      - "5000:5000"
    volumes:
      - gateway_data:/var/lib/gateway
      - gateway_logs:/var/log/gateway
      - ./config:/etc/iot-gateway:ro
    environment:
      - MQTT_BROKER=mosquitto
      - BACKEND_URL=http://backend:8000
    depends_on:
      - mosquitto
      - redis
    networks:
      - iot-network

  mosquitto:
    image: eclipse-mosquitto:2.0
    container_name: mqtt-broker
    restart: unless-stopped
    ports:
      - "1883:1883"
      - "9001:9001"
    volumes:
      - ./mosquitto/config:/mosquitto/config
      - mosquitto_data:/mosquitto/data
      - mosquitto_logs:/mosquitto/log
    networks:
      - iot-network

  redis:
    image: redis:7-alpine
    container_name: redis-cache
    restart: unless-stopped
    volumes:
      - redis_data:/data
    networks:
      - iot-network

volumes:
  gateway_data:
  gateway_logs:
  mosquitto_data:
  mosquitto_logs:
  redis_data:

networks:
  iot-network:
    driver: bridge
```

## Monitoring & Maintenance

### Health Monitoring

#### System Metrics Collection
```python
import psutil
import time

class SystemMonitor:
    def __init__(self):
        self.start_time = time.time()
        
    def get_system_metrics(self):
        """Collect system metrics"""
        return {
            'cpu_percent': psutil.cpu_percent(interval=1),
            'memory_percent': psutil.virtual_memory().percent,
            'disk_percent': psutil.disk_usage('/').percent,
            'network_io': psutil.net_io_counters()._asdict(),
            'uptime': time.time() - self.start_time,
            'load_average': psutil.getloadavg() if hasattr(psutil, 'getloadavg') else None
        }
    
    def check_health(self):
        """Check system health and return status"""
        metrics = self.get_system_metrics()
        
        health_status = {
            'status': 'healthy',
            'issues': []
        }
        
        if metrics['cpu_percent'] > 80:
            health_status['issues'].append('High CPU usage')
        
        if metrics['memory_percent'] > 80:
            health_status['issues'].append('High memory usage')
        
        if metrics['disk_percent'] > 90:
            health_status['issues'].append('Low disk space')
        
        if health_status['issues']:
            health_status['status'] = 'warning'
        
        return health_status
```

### Logging and Alerting

#### Log Management
```python
import logging
import logging.handlers

def setup_logging(log_file='/var/log/gateway/gateway.log', 
                 max_bytes=10*1024*1024, backup_count=5):
    """Setup rotating log files"""
    
    # Create formatters
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # Console handler
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(formatter)
    
    # File handler with rotation
    file_handler = logging.handlers.RotatingFileHandler(
        log_file, maxBytes=max_bytes, backupCount=backup_count
    )
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(formatter)
    
    # Configure root logger
    logging.basicConfig(
        level=logging.DEBUG,
        handlers=[console_handler, file_handler]
    )
```

### Backup and Recovery

#### Data Backup Strategy
```python
import shutil
import sqlite3
import gzip
from datetime import datetime

class BackupManager:
    def __init__(self, db_path, backup_dir):
        self.db_path = db_path
        self.backup_dir = backup_dir
        
    def backup_database(self):
        """Create compressed backup of database"""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_filename = f"gateway_backup_{timestamp}.db.gz"
        backup_path = f"{self.backup_dir}/{backup_filename}"
        
        # Create backup
        with open(self.db_path, 'rb') as f_in:
            with gzip.open(backup_path, 'wb') as f_out:
                shutil.copyfileobj(f_in, f_out)
        
        return backup_path
    
    def restore_database(self, backup_path):
        """Restore database from backup"""
        with gzip.open(backup_path, 'rb') as f_in:
            with open(self.db_path, 'wb') as f_out:
                shutil.copyfileobj(f_in, f_out)
```

This comprehensive custom gateway guide provides everything needed to develop, deploy, and maintain a robust IoT gateway solution for your system.
