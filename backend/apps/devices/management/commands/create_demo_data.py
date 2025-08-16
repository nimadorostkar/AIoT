from django.core.management.base import BaseCommand
from django.utils import timezone
from apps.devices.models import Device, Gateway, Telemetry
import random
import json
from datetime import datetime


class Command(BaseCommand):
    help = 'Create demo devices with live data'

    def handle(self, *args, **options):
        self.stdout.write('Creating demo devices and data...')
        
        # Use existing gateway
        gateway = Gateway.objects.filter(gateway_id="LIVE-DEMO-GW").first()
        if not gateway:
            gateway = Gateway.objects.first()  # Use any existing gateway
        
        if gateway:
            self.stdout.write(f'Using gateway: {gateway.name} ({gateway.gateway_id})')
        else:
            self.stdout.write(self.style.ERROR('No gateways found! Create a gateway first.'))
            return
        
        # Device configurations
        devices_config = [
            {
                "device_id": "WORKING-TEMP-01",
                "type": "sensor",
                "name": "🌡️ Working Temperature",
                "model": "DHT22-Demo"
            },
            {
                "device_id": "WORKING-MOTION-01", 
                "type": "sensor",
                "name": "🚶 Working Motion",
                "model": "PIR-Demo"
            },
            {
                "device_id": "WORKING-SWITCH-01",
                "type": "actuator",
                "name": "💡 Working Switch", 
                "model": "Relay-Demo"
            }
        ]
        
        # Create devices
        for config in devices_config:
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
            
            # Ensure device is online
            device.is_online = True
            device.save(update_fields=["is_online"])
            
            if created:
                self.stdout.write(f'Created device: {config["name"]} ({config["device_id"]})')
            else:
                self.stdout.write(f'Updated device: {config["name"]} ({config["device_id"]})')
                
            # Create sample telemetry data
            self.create_sample_data(device)
        
        self.stdout.write(
            self.style.SUCCESS('✅ Demo devices created with sample data!')
        )
        self.stdout.write('💻 Check web interface: http://localhost:5173/devices')
        self.stdout.write('📊 Check API: http://localhost:8000/api/devices/telemetry/')
    
    def create_sample_data(self, device):
        """Create sample telemetry data for device"""
        device_id = device.device_id
        
        # Create 10 sample records
        for i in range(10):
            if "TEMP" in device_id:
                payload = {
                    "temperature": round(20 + random.uniform(-3, 10), 1),
                    "humidity": random.randint(40, 80),
                    "timestamp": datetime.now().isoformat(),
                    "device_type": "temperature"
                }
            elif "MOTION" in device_id:
                payload = {
                    "motion": random.choice([True, False]),
                    "confidence": random.randint(75, 100),
                    "timestamp": datetime.now().isoformat(),
                    "device_type": "motion"
                }
            elif "SWITCH" in device_id:
                state = random.choice(["on", "off"])
                payload = {
                    "state": state,
                    "power": random.randint(20, 60) if state == "on" else 0,
                    "voltage": round(220 + random.uniform(-5, 5), 1),
                    "timestamp": datetime.now().isoformat(),
                    "device_type": "switch"
                }
            else:
                payload = {
                    "value": random.randint(1, 100),
                    "timestamp": datetime.now().isoformat(),
                    "device_type": "generic"
                }
            
            Telemetry.objects.create(device=device, payload=payload)
            
        self.stdout.write(f'  📊 Created 10 telemetry records for {device_id}')
