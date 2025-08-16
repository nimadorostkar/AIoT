from django.core.management.base import BaseCommand
from apps.devices import mqtt_worker


class Command(BaseCommand):
    help = 'Start MQTT bridge worker'

    def handle(self, *args, **options):
        self.stdout.write('Starting MQTT bridge...')
        mqtt_worker.start_bridge_if_enabled()
        if mqtt_worker.bridge:
            self.stdout.write(
                self.style.SUCCESS('MQTT bridge started successfully')
            )
        else:
            self.stdout.write(
                self.style.ERROR('Failed to start MQTT bridge')
            )
