from importlib import import_module
from django.core.signals import request_started
from django.dispatch import receiver


@receiver(request_started)
def start_mqtt_bridge(sender, **kwargs):  # pragma: no cover
    # Lazily import to avoid migration-time side effects
    module = import_module("apps.devices.mqtt_worker")
    module.start_bridge_if_enabled()


