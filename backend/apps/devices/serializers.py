"""
Serializers for the AIoT Smart System device management API.

This module contains the serializers for converting between Django model instances
and JSON representations for the REST API endpoints.
"""

from rest_framework import serializers
from django.utils import timezone
from typing import Dict, Any, Optional

from .models import Device, Gateway, Telemetry, DeviceModelDefinition


class DeviceModelDefinitionSerializer(serializers.ModelSerializer):
    """
    Serializer for device model definitions.
    
    Handles serialization of device model schemas and validation rules.
    """
    
    class Meta:
        model = DeviceModelDefinition
        fields = [
            "id", "model_id", "name", "version", "schema", 
            "created_at", "updated_at"
        ]
        read_only_fields = ["id", "created_at", "updated_at"]

    def validate_model_id(self, value: str) -> str:
        """Validate that model_id follows naming conventions."""
        if not value or len(value.strip()) == 0:
            raise serializers.ValidationError("Model ID cannot be empty")
        
        # Check for valid characters (alphanumeric, underscore, dash)
        if not all(c.isalnum() or c in ['_', '-'] for c in value):
            raise serializers.ValidationError(
                "Model ID can only contain letters, numbers, underscores, and dashes"
            )
        
        return value.strip()

    def validate_schema(self, value: Dict[str, Any]) -> Dict[str, Any]:
        """Validate that schema is a proper JSON object."""
        if not isinstance(value, dict):
            raise serializers.ValidationError("Schema must be a JSON object")
        
        return value


class GatewaySerializer(serializers.ModelSerializer):
    """
    Serializer for IoT gateways.
    
    Includes computed fields for gateway status and device counts.
    """
    
    is_online = serializers.SerializerMethodField()
    device_count = serializers.SerializerMethodField()
    online_device_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Gateway
        fields = [
            "id", "gateway_id", "name", "last_seen", "is_active",
            "created_at", "updated_at", "is_online", "device_count", 
            "online_device_count"
        ]
        read_only_fields = ["id", "created_at", "updated_at"]

    def get_is_online(self, obj: Gateway) -> bool:
        """Check if the gateway is currently online."""
        return obj.is_online

    def get_device_count(self, obj: Gateway) -> int:
        """Get the total number of devices for this gateway."""
        return obj.device_count

    def get_online_device_count(self, obj: Gateway) -> int:
        """Get the number of online devices for this gateway."""
        return obj.online_device_count

    def validate_gateway_id(self, value: str) -> str:
        """Validate gateway ID format."""
        if not value or len(value.strip()) == 0:
            raise serializers.ValidationError("Gateway ID cannot be empty")
        
        if len(value.strip()) > 64:
            raise serializers.ValidationError("Gateway ID cannot exceed 64 characters")
        
        return value.strip()

    def validate_name(self, value: str) -> str:
        """Validate gateway name."""
        if value and len(value.strip()) > 128:
            raise serializers.ValidationError("Gateway name cannot exceed 128 characters")
        
        return value.strip() if value else ""


class DeviceSerializer(serializers.ModelSerializer):
    """
    Serializer for IoT devices.
    
    Includes gateway information, model definition, and computed fields
    for device status and telemetry information.
    """
    
    gateway_id = serializers.IntegerField(source="gateway.id", read_only=True)
    gateway_name = serializers.CharField(source="gateway.name", read_only=True)
    gateway_gateway_id = serializers.CharField(source="gateway.gateway_id", read_only=True)
    model_schema = serializers.SerializerMethodField()
    model_definition = DeviceModelDefinitionSerializer(read_only=True)
    full_device_id = serializers.SerializerMethodField()
    telemetry_count = serializers.SerializerMethodField()
    last_telemetry_time = serializers.SerializerMethodField()
    can_receive_commands = serializers.SerializerMethodField()
    
    class Meta:
        model = Device
        fields = [
            "id", "device_id", "type", "model", "name", "is_online",
            "created_at", "updated_at", "last_telemetry",
            "gateway_id", "gateway_name", "gateway_gateway_id",
            "model_definition", "model_schema", "full_device_id",
            "telemetry_count", "last_telemetry_time", "can_receive_commands"
        ]
        read_only_fields = [
            "id", "is_online", "created_at", "updated_at", "last_telemetry"
        ]

    def get_model_schema(self, obj: Device) -> Optional[Dict[str, Any]]:
        """Get the model schema if a model definition is linked."""
        return getattr(getattr(obj, "model_definition", None), "schema", None)

    def get_full_device_id(self, obj: Device) -> str:
        """Get the full device identifier including gateway."""
        return obj.full_device_id

    def get_telemetry_count(self, obj: Device) -> int:
        """Get the total number of telemetry records for this device."""
        return obj.telemetry_count

    def get_last_telemetry_time(self, obj: Device) -> Optional[str]:
        """Get the timestamp of the last telemetry record."""
        latest = obj.latest_telemetry
        return latest.timestamp.isoformat() if latest else None

    def get_can_receive_commands(self, obj: Device) -> bool:
        """Check if this device can receive commands."""
        return obj.can_receive_commands()

    def validate_device_id(self, value: str) -> str:
        """Validate device ID format."""
        if not value or len(value.strip()) == 0:
            raise serializers.ValidationError("Device ID cannot be empty")
        
        if len(value.strip()) > 64:
            raise serializers.ValidationError("Device ID cannot exceed 64 characters")
        
        return value.strip()

    def validate_type(self, value: str) -> str:
        """Validate device type."""
        valid_types = [choice[0] for choice in Device.DEVICE_TYPES]
        if value not in valid_types:
            raise serializers.ValidationError(
                f"Invalid device type. Must be one of: {', '.join(valid_types)}"
            )
        
        return value

    def validate_name(self, value: str) -> str:
        """Validate device name."""
        if value and len(value.strip()) > 128:
            raise serializers.ValidationError("Device name cannot exceed 128 characters")
        
        return value.strip() if value else ""

    def validate_model(self, value: str) -> str:
        """Validate device model."""
        if value and len(value.strip()) > 128:
            raise serializers.ValidationError("Device model cannot exceed 128 characters")
        
        return value.strip() if value else ""


class TelemetrySerializer(serializers.ModelSerializer):
    """
    Serializer for device telemetry data.
    
    Includes device information and computed fields for data analysis.
    """
    
    device_name = serializers.CharField(source="device.name", read_only=True)
    device_type = serializers.CharField(source="device.type", read_only=True)
    device_id_field = serializers.CharField(source="device.device_id", read_only=True)
    gateway_id = serializers.CharField(source="device.gateway.gateway_id", read_only=True)
    age_seconds = serializers.SerializerMethodField()
    is_valid = serializers.SerializerMethodField()
    
    class Meta:
        model = Telemetry
        fields = [
            "id", "device", "timestamp", "payload", "created_at",
            "device_name", "device_type", "device_id_field", "gateway_id",
            "age_seconds", "is_valid"
        ]
        read_only_fields = ["id", "timestamp", "created_at"]

    def get_age_seconds(self, obj: Telemetry) -> float:
        """Get the age of this telemetry record in seconds."""
        return obj.age.total_seconds()

    def get_is_valid(self, obj: Telemetry) -> bool:
        """Check if this telemetry validates against the device's schema."""
        return obj.validate_against_schema()

    def validate_payload(self, value: Dict[str, Any]) -> Dict[str, Any]:
        """Validate telemetry payload."""
        if not isinstance(value, dict):
            raise serializers.ValidationError("Payload must be a JSON object")
        
        # Additional validation can be added here based on device model
        return value


class TelemetryCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating telemetry records.
    
    Simplified serializer for telemetry creation with validation.
    """
    
    class Meta:
        model = Telemetry
        fields = ["device", "payload"]

    def validate(self, attrs):
        """Validate the telemetry data against device model definition."""
        device = attrs.get('device')
        payload = attrs.get('payload')
        
        if device and device.model_definition:
            if not device.model_definition.validate_payload(payload):
                raise serializers.ValidationError(
                    "Payload does not match device model schema"
                )
        
        return attrs


