from rest_framework import serializers

from .models import Device, Gateway, Telemetry, DeviceModelDefinition


class GatewaySerializer(serializers.ModelSerializer):
    class Meta:
        model = Gateway
        fields = ["id", "gateway_id", "name", "last_seen"]


class DeviceModelDefinitionSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeviceModelDefinition
        fields = ["id", "model_id", "name", "version", "schema"]


class DeviceSerializer(serializers.ModelSerializer):
    gateway_id = serializers.IntegerField(source="gateway.id", read_only=True)
    model_schema = serializers.SerializerMethodField()
    model_definition = DeviceModelDefinitionSerializer(read_only=True)
    class Meta:
        model = Device
        fields = [
            "id", "device_id", "type", "model", "name", "is_online", "gateway_id",
            "model_definition", "model_schema"
        ]
        read_only_fields = ["id", "is_online", "gateway_id"]

    def get_model_schema(self, obj):
        return getattr(getattr(obj, "model_definition", None), "schema", None)


class TelemetrySerializer(serializers.ModelSerializer):
    class Meta:
        model = Telemetry
        fields = ["id", "device", "timestamp", "payload"]
        read_only_fields = ["id", "timestamp"]


