#!/usr/bin/env python3
"""
Simple Working IoT Demo
This Python script ensures devices come online and send real data
"""

import json
import time
import random
import requests
import paho.mqtt.client as mqtt
from datetime import datetime
from threading import Thread

# Configuration
API_BASE = "http://localhost:8000/api"
MQTT_HOST = "localhost"
MQTT_PORT = 1883
USERNAME = "admin"
PASSWORD = "admin123"

class IoTDemo:
    def __init__(self):
        self.token = None
        self.mqtt_client = None
        self.running = True
        
    def authenticate(self):
        """Get authentication token"""
        try:
            response = requests.post(f"{API_BASE}/token/", json={
                "username": USERNAME,
                "password": PASSWORD
            })
            if response.status_code == 200:
                self.token = response.json()["access"]
                print("✅ Authentication successful")
                return True
            else:
                print("❌ Authentication failed")
                return False
        except Exception as e:
            print(f"❌ Auth error: {e}")
            return False
    
    def setup_mqtt(self):
        """Setup MQTT client"""
        self.mqtt_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
        self.mqtt_client.connect(MQTT_HOST, MQTT_PORT, 60)
        self.mqtt_client.loop_start()
        print("✅ MQTT client connected")
    
    def create_device(self, gateway_id, device_id, device_type, name, model):
        """Create a device via API"""
        try:
            response = requests.post(f"{API_BASE}/devices/devices/", 
                headers={"Authorization": f"Bearer {self.token}"},
                json={
                    "gateway_id": gateway_id,
                    "device_id": device_id,
                    "type": device_type,
                    "name": name,
                    "model": model
                }
            )
            if response.status_code in [200, 201]:
                print(f"✅ Created device: {name} ({device_id})")
                return True
            else:
                print(f"⚠️ Device {device_id} might already exist")
                return True
        except Exception as e:
            print(f"❌ Error creating device {device_id}: {e}")
            return False
    
    def send_mqtt_data(self, device_id, data):
        """Send data via MQTT"""
        if self.mqtt_client:
            topic = f"devices/{device_id}/data"
            self.mqtt_client.publish(topic, json.dumps(data), qos=1)
    
    def send_heartbeat(self, device_id, battery=85):
        """Send device heartbeat"""
        if self.mqtt_client:
            topic = f"devices/{device_id}/heartbeat"
            self.mqtt_client.publish(topic, json.dumps({
                "status": "online",
                "battery": battery,
                "timestamp": datetime.utcnow().isoformat() + "Z"
            }), qos=1)
    
    def simulate_temperature_sensor(self, device_id):
        """Simulate temperature sensor"""
        print(f"🌡️ Starting temperature sensor: {device_id}")
        while self.running:
            temp = round(20 + random.uniform(-5, 15), 1)
            humidity = random.randint(40, 80)
            
            data = {
                "temperature": temp,
                "humidity": humidity,
                "timestamp": datetime.utcnow().isoformat() + "Z"
            }
            
            self.send_mqtt_data(device_id, data)
            self.send_heartbeat(device_id, random.randint(70, 100))
            
            print(f"🌡️ {device_id}: {temp}°C, {humidity}%")
            time.sleep(8)
    
    def simulate_motion_sensor(self, device_id):
        """Simulate motion sensor"""
        print(f"🚶 Starting motion sensor: {device_id}")
        while self.running:
            if random.random() < 0.3:  # 30% chance of motion
                # Motion detected
                data = {
                    "motion": True,
                    "confidence": random.randint(80, 100),
                    "timestamp": datetime.utcnow().isoformat() + "Z"
                }
                self.send_mqtt_data(device_id, data)
                self.send_heartbeat(device_id)
                print(f"🚶 {device_id}: Motion DETECTED!")
                
                time.sleep(3)
                
                # Motion cleared
                data = {
                    "motion": False,
                    "timestamp": datetime.utcnow().isoformat() + "Z"
                }
                self.send_mqtt_data(device_id, data)
                print(f"🚶 {device_id}: Motion cleared")
            
            time.sleep(10)
    
    def simulate_smart_switch(self, device_id):
        """Simulate smart switch"""
        print(f"💡 Starting smart switch: {device_id}")
        state = "off"
        power = 0
        
        while self.running:
            if random.random() < 0.2:  # 20% chance to toggle
                state = "on" if state == "off" else "off"
                power = random.randint(20, 60) if state == "on" else 0
            
            data = {
                "state": state,
                "power": power,
                "voltage": round(220 + random.uniform(-5, 5), 1),
                "timestamp": datetime.utcnow().isoformat() + "Z"
            }
            
            self.send_mqtt_data(device_id, data)
            self.send_heartbeat(device_id)
            
            print(f"💡 {device_id}: {state.upper()} ({power}W)")
            time.sleep(12)
    
    def simulate_door_sensor(self, device_id):
        """Simulate door sensor"""
        print(f"🚪 Starting door sensor: {device_id}")
        state = "closed"
        
        while self.running:
            if random.random() < 0.15:  # 15% chance to change state
                state = "open" if state == "closed" else "closed"
                
                data = {
                    "state": state,
                    "battery": random.randint(80, 100),
                    "tamper": False,
                    "timestamp": datetime.utcnow().isoformat() + "Z"
                }
                
                self.send_mqtt_data(device_id, data)
                self.send_heartbeat(device_id)
                
                print(f"🚪 {device_id}: Door {state.upper()}")
            
            time.sleep(15)
    
    def setup_devices(self):
        """Setup all demo devices"""
        print("🔧 Setting up devices...")
        
        # Create gateway
        try:
            requests.post(f"{API_BASE}/devices/gateways/claim/",
                headers={"Authorization": f"Bearer {self.token}"},
                json={"gateway_id": "PYTHON-DEMO-GW", "name": "Python Demo Gateway"})
        except:
            pass
        
        # Device definitions
        devices = [
            ("PYTHON-TEMP-01", "sensor", "🌡️ Python Temperature", "DHT22"),
            ("PYTHON-MOTION-01", "sensor", "🚶 Python Motion", "PIR-v2"),  
            ("PYTHON-SWITCH-01", "actuator", "💡 Python Switch", "SmartRelay"),
            ("PYTHON-DOOR-01", "sensor", "🚪 Python Door", "Magnetic-v3"),
        ]
        
        for device_id, device_type, name, model in devices:
            self.create_device("PYTHON-DEMO-GW", device_id, device_type, name, model)
            time.sleep(0.5)
    
    def start_simulation(self):
        """Start all device simulations"""
        print("🚀 Starting device simulations...")
        
        # Start device threads
        threads = [
            Thread(target=self.simulate_temperature_sensor, args=("PYTHON-TEMP-01",)),
            Thread(target=self.simulate_motion_sensor, args=("PYTHON-MOTION-01",)),
            Thread(target=self.simulate_smart_switch, args=("PYTHON-SWITCH-01",)),
            Thread(target=self.simulate_door_sensor, args=("PYTHON-DOOR-01",)),
        ]
        
        for thread in threads:
            thread.daemon = True
            thread.start()
        
        return threads
    
    def run(self):
        """Main execution"""
        print("🎯 Python IoT Demo Starting...")
        print("=" * 40)
        
        # Setup
        if not self.authenticate():
            return
        
        self.setup_mqtt()
        self.setup_devices()
        
        # Force MQTT bridge start in Django
        print("🔧 Starting Django MQTT bridge...")
        try:
            requests.post(f"{API_BASE}/devices/gateways/1/discover/",
                headers={"Authorization": f"Bearer {self.token}"})
        except:
            pass
        
        time.sleep(2)
        
        # Start simulations
        threads = self.start_simulation()
        
        print("\n🎉 Demo is running!")
        print("=" * 40)
        print("💻 Web Interface: http://localhost:5173/devices")
        print("📊 MQTT Monitor: mosquitto_sub -h localhost -t 'devices/PYTHON-*/data' -v")
        print("🛑 Press Ctrl+C to stop")
        print("\nDevices:")
        print("🌡️ PYTHON-TEMP-01   - Temperature & Humidity")
        print("🚶 PYTHON-MOTION-01 - Motion Detection") 
        print("💡 PYTHON-SWITCH-01 - Smart Switch")
        print("🚪 PYTHON-DOOR-01   - Door Sensor")
        print()
        
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\n🛑 Stopping demo...")
            self.running = False
            if self.mqtt_client:
                self.mqtt_client.loop_stop()
                self.mqtt_client.disconnect()
            print("✅ Demo stopped")

if __name__ == "__main__":
    demo = IoTDemo()
    demo.run()
