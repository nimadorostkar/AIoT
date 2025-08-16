from django.contrib.auth import get_user_model
from django.db import models


User = get_user_model()


class DeviceModelDefinition(models.Model):
    model_id = models.CharField(max_length=128, unique=True)
    name = models.CharField(max_length=128)
    version = models.CharField(max_length=32, blank=True)
    schema = models.JSONField(default=dict)

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.model_id}"


class Gateway(models.Model):
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name="gateways")
    gateway_id = models.CharField(max_length=64, unique=True)
    name = models.CharField(max_length=128, blank=True)
    last_seen = models.DateTimeField(null=True, blank=True)

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.gateway_id}"


class Device(models.Model):
    gateway = models.ForeignKey(Gateway, on_delete=models.CASCADE, related_name="devices")
    device_id = models.CharField(max_length=64)
    type = models.CharField(max_length=64, help_text="sensor|actuator|camera")
    model = models.CharField(max_length=128, blank=True)
    model_definition = models.ForeignKey(DeviceModelDefinition, null=True, blank=True, on_delete=models.SET_NULL)
    name = models.CharField(max_length=128, blank=True)
    is_online = models.BooleanField(default=False)

    class Meta:
        unique_together = ("gateway", "device_id")

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.gateway.gateway_id}:{self.device_id}"


class Telemetry(models.Model):
    device = models.ForeignKey(Device, on_delete=models.CASCADE, related_name="telemetry")
    timestamp = models.DateTimeField(auto_now_add=True)
    payload = models.JSONField()

    class Meta:
        indexes = [models.Index(fields=["timestamp"])]


