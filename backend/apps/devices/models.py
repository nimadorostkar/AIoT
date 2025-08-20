"""
Device models for the AIoT Smart System.

This module contains the data models for managing IoT devices, gateways, 
telemetry data, and device model definitions within the system.
"""

from django.contrib.auth import get_user_model
from django.db import models
from django.utils import timezone
from datetime import timedelta
from typing import Dict, Any, Optional


User = get_user_model()


class DeviceModelDefinition(models.Model):
    """
    Device model definition that describes the schema and capabilities of a device type.
    
    This model stores the technical specifications and data schema for different
    types of IoT devices, enabling dynamic device registration and validation.
    """
    
    model_id = models.CharField(
        max_length=128, 
        unique=True,
        help_text="Unique identifier for the device model (e.g., 'sensor_temp_v1')"
    )
    name = models.CharField(
        max_length=128,
        help_text="Human-readable name for the device model"
    )
    version = models.CharField(
        max_length=32, 
        blank=True,
        help_text="Version of the device model (e.g., '1.0.0')"
    )
    schema = models.JSONField(
        default=dict,
        help_text="JSON schema defining the structure of telemetry data"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Device Model Definition"
        verbose_name_plural = "Device Model Definitions"
        ordering = ['name', 'version']

    def __str__(self) -> str:
        return f"{self.name} ({self.model_id})"

    def validate_payload(self, payload: Dict[str, Any]) -> bool:
        """
        Validate a telemetry payload against this model's schema.
        
        Args:
            payload: The telemetry data to validate
            
        Returns:
            bool: True if payload is valid, False otherwise
        """
        # Basic validation - can be extended with jsonschema
        if not self.schema:
            return True
            
        required_fields = self.schema.get('required', [])
        return all(field in payload for field in required_fields)


class Gateway(models.Model):
    """
    Gateway represents a physical IoT gateway device that manages multiple sensors/actuators.
    
    Gateways act as intermediaries between IoT devices and the cloud platform,
    handling local device communication and data aggregation.
    """
    
    owner = models.ForeignKey(
        User, 
        on_delete=models.CASCADE, 
        related_name="gateways",
        help_text="User who owns this gateway"
    )
    gateway_id = models.CharField(
        max_length=64, 
        unique=True,
        help_text="Unique identifier for the gateway (usually MAC address or serial number)"
    )
    name = models.CharField(
        max_length=128, 
        blank=True,
        help_text="Human-readable name for the gateway"
    )
    last_seen = models.DateTimeField(
        null=True, 
        blank=True,
        help_text="Last time this gateway was seen online"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_active = models.BooleanField(
        default=True,
        help_text="Whether this gateway is active and should receive commands"
    )

    class Meta:
        verbose_name = "Gateway"
        verbose_name_plural = "Gateways"
        ordering = ['-last_seen', 'name']

    def __str__(self) -> str:
        return f"{self.name or self.gateway_id}"

    @property
    def is_online(self) -> bool:
        """Check if the gateway is considered online (seen within last 5 minutes)."""
        if not self.last_seen:
            return False
        return timezone.now() - self.last_seen < timedelta(minutes=5)

    @property
    def device_count(self) -> int:
        """Return the number of devices connected to this gateway."""
        return self.devices.count()

    @property
    def online_device_count(self) -> int:
        """Return the number of online devices connected to this gateway."""
        return self.devices.filter(is_online=True).count()

    def update_last_seen(self) -> None:
        """Update the last_seen timestamp to now."""
        self.last_seen = timezone.now()
        self.save(update_fields=['last_seen'])


class Device(models.Model):
    """
    Device represents an individual IoT device connected through a gateway.
    
    Devices can be sensors (collecting data), actuators (performing actions),
    or cameras (streaming video/taking photos).
    """
    
    # Device types
    DEVICE_TYPE_SENSOR = 'sensor'
    DEVICE_TYPE_ACTUATOR = 'actuator'
    DEVICE_TYPE_CAMERA = 'camera'
    DEVICE_TYPE_RELAY = 'relay'
    DEVICE_TYPE_DIMMER = 'dimmer'
    DEVICE_TYPE_SWITCH = 'switch'
    
    DEVICE_TYPES = [
        (DEVICE_TYPE_SENSOR, 'Sensor'),
        (DEVICE_TYPE_ACTUATOR, 'Actuator'),
        (DEVICE_TYPE_CAMERA, 'Camera'),
        (DEVICE_TYPE_RELAY, 'Relay'),
        (DEVICE_TYPE_DIMMER, 'Dimmer'),
        (DEVICE_TYPE_SWITCH, 'Switch'),
    ]
    
    gateway = models.ForeignKey(
        Gateway, 
        on_delete=models.CASCADE, 
        related_name="devices",
        help_text="Gateway that manages this device"
    )
    device_id = models.CharField(
        max_length=64,
        help_text="Unique identifier for the device within its gateway"
    )
    type = models.CharField(
        max_length=64, 
        choices=DEVICE_TYPES,
        default=DEVICE_TYPE_SENSOR,
        help_text="Type of device (sensor, actuator, camera, etc.)"
    )
    model = models.CharField(
        max_length=128, 
        blank=True,
        help_text="Device model/part number"
    )
    model_definition = models.ForeignKey(
        DeviceModelDefinition, 
        null=True, 
        blank=True, 
        on_delete=models.SET_NULL,
        help_text="Reference to device model definition for validation"
    )
    name = models.CharField(
        max_length=128, 
        blank=True,
        help_text="Human-readable name for the device"
    )
    is_online = models.BooleanField(
        default=False,
        help_text="Whether the device is currently online"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    last_telemetry = models.DateTimeField(
        null=True, 
        blank=True,
        help_text="Timestamp of last received telemetry data"
    )

    class Meta:
        unique_together = ("gateway", "device_id")
        verbose_name = "Device"
        verbose_name_plural = "Devices"
        ordering = ['gateway__name', 'name', 'device_id']

    def __str__(self) -> str:
        return f"{self.name or self.device_id} ({self.gateway.name or self.gateway.gateway_id})"

    @property
    def full_device_id(self) -> str:
        """Return the full device identifier including gateway."""
        return f"{self.gateway.gateway_id}:{self.device_id}"

    @property
    def telemetry_count(self) -> int:
        """Return the total number of telemetry records for this device."""
        return self.telemetry.count()

    @property
    def latest_telemetry(self) -> Optional['Telemetry']:
        """Return the most recent telemetry record for this device."""
        return self.telemetry.first()

    def get_telemetry_since(self, since: timezone.datetime) -> models.QuerySet:
        """Get telemetry data since a specific timestamp."""
        return self.telemetry.filter(timestamp__gte=since)

    def update_online_status(self, is_online: bool) -> None:
        """Update the online status of the device."""
        self.is_online = is_online
        if is_online:
            self.last_telemetry = timezone.now()
        self.save(update_fields=['is_online', 'last_telemetry'])

    def can_receive_commands(self) -> bool:
        """Check if this device can receive commands (actuators, cameras, etc.)."""
        return self.type in [
            self.DEVICE_TYPE_ACTUATOR,
            self.DEVICE_TYPE_CAMERA,
            self.DEVICE_TYPE_RELAY,
            self.DEVICE_TYPE_DIMMER,
            self.DEVICE_TYPE_SWITCH,
        ]


class Telemetry(models.Model):
    """
    Telemetry represents sensor data or status updates from IoT devices.
    
    This model stores time-series data from devices, including sensor readings,
    status updates, and other device-generated information.
    """
    
    device = models.ForeignKey(
        Device, 
        on_delete=models.CASCADE, 
        related_name="telemetry",
        help_text="Device that generated this telemetry data"
    )
    timestamp = models.DateTimeField(
        auto_now_add=True,
        help_text="When this telemetry data was received"
    )
    payload = models.JSONField(
        help_text="The actual telemetry data as JSON"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Telemetry"
        verbose_name_plural = "Telemetry"
        ordering = ['-timestamp']
        indexes = [
            models.Index(fields=["timestamp"]),
            models.Index(fields=["device", "-timestamp"]),
        ]

    def __str__(self) -> str:
        return f"{self.device.name or self.device.device_id} @ {self.timestamp}"

    @property
    def age(self) -> timedelta:
        """Return how old this telemetry data is."""
        return timezone.now() - self.timestamp

    def validate_against_schema(self) -> bool:
        """Validate this telemetry against the device's model definition schema."""
        if not self.device.model_definition:
            return True
        return self.device.model_definition.validate_payload(self.payload)

    def get_value(self, key: str, default: Any = None) -> Any:
        """Get a specific value from the payload."""
        return self.payload.get(key, default)

    def has_key(self, key: str) -> bool:
        """Check if a key exists in the payload."""
        return key in self.payload


