#!/usr/bin/env python3
"""
Live Data Generator
Continuously generates live telemetry data for WORKING- devices
"""

import os
import sys
import time
import random
import requests
from datetime import datetime

# Configuration  
API_BASE = "http://localhost:8000/api"
USERNAME = "admin"
PASSWORD = "admin123"

def get_token():
    """Get authentication token"""
    try:
        response = requests.post(f"{API_BASE}/token/", json={
            "username": USERNAME,
            "password": PASSWORD
        })
        if response.status_code == 200:
            return response.json()["access"]
    except:
        pass
    return None

def create_telemetry_via_api(device_id, payload, token):
    """Create telemetry via API"""
    try:
        response = requests.post(f"{API_BASE}/devices/telemetry/", 
            headers={"Authorization": f"Bearer {token}"},
            json={
                "device_id": device_id,
                "payload": payload
            }
        )
        return response.status_code in [200, 201]
    except:
        return False

def main():
    print("🚀 Live Data Generator Starting...")
    print("=" * 40)
    
    # Get token
    token = get_token()
    if not token:
        print("❌ Authentication failed")
        return
    
    print("✅ Authentication successful")
    print("📊 Generating live data for WORKING- devices...")
    print("🛑 Press Ctrl+C to stop")
    print()
    
    devices = [
        {"id": "WORKING-TEMP-01", "type": "temperature", "emoji": "🌡️"},
        {"id": "WORKING-MOTION-01", "type": "motion", "emoji": "🚶"},
        {"id": "WORKING-SWITCH-01", "type": "switch", "emoji": "💡"}
    ]
    
    counter = 0
    
    try:
        while True:
            for device in devices:
                device_id = device["id"]
                device_type = device["type"]
                emoji = device["emoji"]
                
                # Generate data based on device type
                if device_type == "temperature":
                    temp = round(18 + random.uniform(0, 15), 1)
                    humidity = random.randint(40, 80)
                    payload = {
                        "temperature": temp,
                        "humidity": humidity,
                        "timestamp": datetime.now().isoformat(),
                        "device_type": "temperature"
                    }
                    print(f"{emoji} {device_id}: {temp}°C, {humidity}%")
                    
                elif device_type == "motion":
                    motion = random.choice([True, False])
                    confidence = random.randint(75, 100)
                    payload = {
                        "motion": motion,
                        "confidence": confidence,
                        "timestamp": datetime.now().isoformat(),
                        "device_type": "motion"
                    }
                    status = "DETECTED" if motion else "CLEAR"
                    print(f"{emoji} {device_id}: Motion {status}")
                    
                elif device_type == "switch":
                    state = random.choice(["on", "off"])
                    power = random.randint(20, 70) if state == "on" else 0
                    payload = {
                        "state": state,
                        "power": power,
                        "voltage": round(220 + random.uniform(-5, 5), 1),
                        "timestamp": datetime.now().isoformat(),
                        "device_type": "switch"
                    }
                    print(f"{emoji} {device_id}: {state.upper()} ({power}W)")
                
                # Try to create via API first, fallback to direct DB
                success = create_telemetry_via_api(device_id, payload, token)
                if not success:
                    print(f"⚠️ API failed for {device_id}, continuing...")
                
                time.sleep(2)
            
            counter += 1
            if counter % 10 == 0:
                print(f"📈 Generated {counter * len(devices)} data points...")
                # Refresh token occasionally
                new_token = get_token()
                if new_token:
                    token = new_token
            
            time.sleep(3)
            
    except KeyboardInterrupt:
        print("\n🛑 Stopping live data generator...")
        print("✅ Generator stopped")

if __name__ == "__main__":
    main()
