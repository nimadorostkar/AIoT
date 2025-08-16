from django.core.management.base import BaseCommand

from apps.devices.models import Device, Gateway


class Command(BaseCommand):
    help = "Seed a sample gateway and device for local testing"

    def handle(self, *args, **options):
        gw, _ = Gateway.objects.get_or_create(gateway_id="GW-LOCAL-1", defaults={"owner_id": 1, "name": "Local Gateway"})
        dev, _ = Device.objects.get_or_create(gateway=gw, device_id="DEV-1", defaults={"type": "sensor", "model": "demo", "name": "Demo Sensor"})
        self.stdout.write(self.style.SUCCESS(f"Seeded gateway {gw.gateway_id} and device {dev.device_id}"))


