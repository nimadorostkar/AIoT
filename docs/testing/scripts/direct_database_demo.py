#!/usr/bin/env python3
"""
Direct Database IoT Demo
Bypasses MQTT and directly creates data in the database
This guarantees working devices and real-time data
"""

import os
import sys
import django
import json
import time
import random
import requests
from datetime import datetime, timezone
from threading import Thread

# Setup Django
sys.path.append('/app')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
django.setup()

from apps.devices.models import Device, Gateway, Telemetry

# Configuration
API_BASE = "http://localhost:8000/api"
USERNAME = "admin"
PASSWORD = "admin123"

class DirectIoTDemo:
    def __init__(self):
        self.token = None
        self.running = True
        self.devices = []
        
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
    
    def setup_devices(self):
        """Setup devices directly in database"""
        print("🔧 Setting up devices directly in database...")
        
        # Create or get gateway
        gateway, created = Gateway.objects.get_or_create(
            gateway_id="DIRECT-DEMO-GW",
            defaults={
                "name": "Direct Demo Gateway",
                "user_id": 1  # admin user
            }
        )
        
        if created:
            print(f"✅ Created gateway: {gateway.name}")
        else:
            print(f"✅ Using existing gateway: {gateway.name}")
        
        # Device definitions
        device_configs = [
            {
                "device_id": "DIRECT-TEMP-01",
                "type": "sensor", 
                "name": "🌡️ Direct Temperature",
                "model": "DHT22-Direct"
            },
            {
                "device_id": "DIRECT-MOTION-01", 
                "type": "sensor",
                "name": "🚶 Direct Motion",
                "model": "PIR-Direct"
            },
            {
                "device_id": "DIRECT-SWITCH-01",
                "type": "actuator", 
                "name": "💡 Direct Switch",
                "model": "Relay-Direct"
            },
            {
                "device_id": "DIRECT-DOOR-01",
                "type": "sensor",
                "name": "🚪 Direct Door",
                "model": "Magnetic-Direct"
            }
        ]
        
        for config in device_configs:
            device, created = Device.objects.get_or_create(
                gateway=gateway,
                device_id=config["device_id"],
                defaults={
                    "type": config["type"],
                    "name": config["name"], 
                    "model": config["model"],
                    "is_online": True
                }
            )
            
            if created:
                print(f"✅ Created device: {config['name']} ({config['device_id']})")
            else:
                device.is_online = True
                device.save(update_fields=["is_online"])
                print(f"✅ Updated device: {config['name']} ({config['device_id']})")
                
            self.devices.append(device)
    
    def create_telemetry(self, device, data):
        """Create telemetry record directly in database"""
        Telemetry.objects.create(device=device, payload=data)
    
    def simulate_temperature_sensor(self, device):
        """Simulate temperature sensor with direct DB writes"""
        print(f"🌡️ Starting temperature simulation: {device.device_id}")
        while self.running:
            temp = round(18 + random.uniform(0, 20), 1)
            humidity = random.randint(35, 85)
            
            data = {
                "temperature": temp,
                "humidity": humidity,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "device_type": "temperature"
            }
            
            self.create_telemetry(device, data)
            print(f"🌡️ {device.device_id}: {temp}°C, {humidity}%")
            time.sleep(6)
    
    def simulate_motion_sensor(self, device):
        """Simulate motion sensor with direct DB writes"""
        print(f"🚶 Starting motion simulation: {device.device_id}")
        motion_state = False
        
        while self.running:
            # Random motion events
            if random.random() < 0.25:  # 25% chance
                motion_state = not motion_state
                
                data = {
                    "motion": motion_state,
                    "confidence": random.randint(75, 100),
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "device_type": "motion"
                }
                
                self.create_telemetry(device, data)
                status = "DETECTED" if motion_state else "CLEARED"
                print(f"🚶 {device.device_id}: Motion {status}")
            
            time.sleep(8)
    
    def simulate_smart_switch(self, device):
        """Simulate smart switch with direct DB writes"""
        print(f"💡 Starting switch simulation: {device.device_id}")
        state = "off"
        power = 0
        
        while self.running:
            # Random state changes
            if random.random() < 0.2:  # 20% chance
                state = "on" if state == "off" else "off"
                power = random.randint(15, 75) if state == "on" else 0
            
            data = {
                "state": state,
                "power": power,
                "voltage": round(220 + random.uniform(-8, 8), 1),
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "device_type": "switch"
            }
            
            self.create_telemetry(device, data)
            print(f"💡 {device.device_id}: {state.upper()} ({power}W)")
            time.sleep(10)
    
    def simulate_door_sensor(self, device):
        """Simulate door sensor with direct DB writes"""
        print(f"🚪 Starting door simulation: {device.device_id}")
        door_state = "closed"
        
        while self.running:
            # Random door events
            if random.random() < 0.15:  # 15% chance
                door_state = "open" if door_state == "closed" else "closed"
                
                data = {
                    "state": door_state,
                    "battery": random.randint(70, 100),
                    "tamper": False,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "device_type": "door"
                }
                
                self.create_telemetry(device, data)
                print(f"🚪 {device.device_id}: Door {door_state.upper()}")
            
            time.sleep(12)
    
    def keep_devices_online(self):
        """Periodically update device online status"""
        while self.running:
            Device.objects.filter(
                device_id__startswith="DIRECT-"
            ).update(is_online=True)
            time.sleep(30)
    
    def run(self):
        """Main execution"""
        print("🎯 Direct Database IoT Demo Starting...")
        print("=" * 50)
        
        if not self.authenticate():
            return
        
        self.setup_devices()
        
        # Find our devices
        temp_device = next((d for d in self.devices if "TEMP" in d.device_id), None)
        motion_device = next((d for d in self.devices if "MOTION" in d.device_id), None) 
        switch_device = next((d for d in self.devices if "SWITCH" in d.device_id), None)
        door_device = next((d for d in self.devices if "DOOR" in d.device_id), None)
        
        # Start simulation threads
        threads = []
        if temp_device:
            threads.append(Thread(target=self.simulate_temperature_sensor, args=(temp_device,)))
        if motion_device:
            threads.append(Thread(target=self.simulate_motion_sensor, args=(motion_device,)))
        if switch_device:
            threads.append(Thread(target=self.simulate_smart_switch, args=(switch_device,)))
        if door_device:
            threads.append(Thread(target=self.simulate_door_sensor, args=(door_device,)))
        
        # Online status thread
        threads.append(Thread(target=self.keep_devices_online))
        
        for thread in threads:
            thread.daemon = True
            thread.start()
        
        print("\n🎉 Direct Database Demo is Running!")
        print("=" * 50)
        print("💻 Web Interface: http://localhost:5173/devices")
        print("📊 API Telemetry: http://localhost:8000/api/devices/telemetry/")
        print("🛑 Press Ctrl+C to stop")
        print("\nDevices (Direct Database):")
        print("🌡️ DIRECT-TEMP-01   - Temperature & Humidity")
        print("🚶 DIRECT-MOTION-01 - Motion Detection")
        print("💡 DIRECT-SWITCH-01 - Smart Switch")
        print("🚪 DIRECT-DOOR-01   - Door Sensor")
        print("\n🔧 Data is written directly to database, bypassing MQTT")
        print()
        
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\n🛑 Stopping demo...")
            self.running = False
            print("✅ Demo stopped")

if __name__ == "__main__":
    demo = DirectIoTDemo()
    demo.run()
