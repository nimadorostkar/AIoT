from rest_framework import permissions, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils import timezone

from .models import Device, Gateway, Telemetry, DeviceModelDefinition
from .serializers import DeviceSerializer, GatewaySerializer, TelemetrySerializer, DeviceModelDefinitionSerializer
from . import mqtt_worker


class IsOwner(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        if isinstance(obj, Gateway):
            return obj.owner_id == request.user.id
        if isinstance(obj, Device):
            return obj.gateway.owner_id == request.user.id
        if isinstance(obj, Telemetry):
            return obj.device.gateway.owner_id == request.user.id
        return False


class GatewayViewSet(viewsets.ModelViewSet):
    serializer_class = GatewaySerializer
    permission_classes = [permissions.IsAuthenticated, IsOwner]

    def get_queryset(self):
        return Gateway.objects.filter(owner=self.request.user).order_by("id")

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

    @action(detail=True, methods=["get"], url_path="devices")
    def devices(self, request, pk=None):
        gateway = self.get_object()
        devices = gateway.devices.all().order_by("id")
        return Response(DeviceSerializer(devices, many=True).data)

    @action(detail=True, methods=["post"], url_path="discover")
    def discover(self, request, pk=None):
        # Hint to gateway-side agent: trigger full device announce (implementation on gateway)
        gateway = self.get_object()
        # Publish over MQTT a discovery request
        topic = f"gateways/{gateway.gateway_id}/discover"
        payload = {"action": "discover"}
        if mqtt_worker.bridge is None:
            mqtt_worker.start_bridge_if_enabled()
        if mqtt_worker.bridge:
            mqtt_worker.bridge.publish(topic, payload, qos=1)
        return Response({"status": "sent", "topic": topic})

    @action(detail=False, methods=["post"], url_path="claim")
    def claim(self, request):
        gateway_id = request.data.get("gateway_id")
        name = request.data.get("name", "")
        if not gateway_id:
            return Response({"detail": "gateway_id required"}, status=400)
        gw, created = Gateway.objects.get_or_create(
            gateway_id=gateway_id,
            defaults={"owner": request.user, "name": name},
        )
        if not created and gw.owner_id != request.user.id:
            return Response({"detail": "already claimed"}, status=409)
        if name and gw.name != name:
            gw.name = name
            gw.save(update_fields=["name"])
        return Response(GatewaySerializer(gw).data)


class DeviceViewSet(viewsets.ModelViewSet):
    serializer_class = DeviceSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwner]

    def get_queryset(self):
        return Device.objects.filter(gateway__owner=self.request.user).order_by("id")

    def create(self, request, *args, **kwargs):
        gateway_pk = request.data.get("gateway_pk")
        gateway_id = request.data.get("gateway_id")
        device_id = request.data.get("device_id")
        device_type = request.data.get("type", "sensor")
        name = request.data.get("name", "")
        model = request.data.get("model", "")

        if not device_id:
            return Response({"detail": "device_id required"}, status=400)

        gateway: Gateway | None = None
        if gateway_pk:
            gateway = Gateway.objects.filter(id=gateway_pk, owner=request.user).first()
        if not gateway and gateway_id:
            gateway = Gateway.objects.filter(gateway_id=gateway_id, owner=request.user).first()
        if not gateway:
            return Response({"detail": "gateway not found or not owned"}, status=404)

        device, created = Device.objects.get_or_create(
            gateway=gateway,
            device_id=device_id,
            defaults={"type": device_type, "name": name, "model": model},
        )
        if not created:
            # Update basic fields if provided
            updated = False
            if name and device.name != name:
                device.name = name; updated = True
            if model and device.model != model:
                device.model = model; updated = True
            if device_type and device.type != device_type:
                device.type = device_type; updated = True
            if updated:
                device.save()
        return Response(DeviceSerializer(device).data, status=201 if created else 200)

    @action(detail=True, methods=["post"], url_path="command")
    def command(self, request, pk=None):
        device = self.get_object()
        payload = request.data
        command_type = payload.get('action', 'unknown')
        
        # Enhanced command handling for different device types
        topic = f"devices/{device.device_id}/commands"
        
        # Add device type specific validation
        if device.type in ['relay', 'switch'] and command_type == 'toggle':
            if 'state' not in payload:
                return Response({"error": "State required for toggle command"}, status=400)
        
        elif device.type in ['dimmer', 'light'] and command_type == 'set_brightness':
            brightness = payload.get('brightness', 0)
            if not 0 <= brightness <= 100:
                return Response({"error": "Brightness must be between 0-100"}, status=400)
        
        elif device.type == 'camera' and command_type in ['start_recording', 'stop_recording', 'take_snapshot']:
            # Camera commands are valid
            pass
        
        # Enhanced payload with metadata
        enhanced_payload = {
            **payload,
            'device_id': device.device_id,
            'device_type': device.type,
            'gateway_id': device.gateway.gateway_id,
            'timestamp': timezone.now().isoformat(),
            'command_id': f"cmd_{device.device_id}_{int(timezone.now().timestamp())}"
        }
        
        # Publish to MQTT
        if mqtt_worker.bridge is None:
            mqtt_worker.start_bridge_if_enabled()
        
        success = False
        if mqtt_worker.bridge:
            try:
                mqtt_worker.bridge.publish(topic, enhanced_payload, qos=2)
                success = True
            except Exception as e:
                return Response({"error": f"Failed to send command: {str(e)}"}, status=500)
        
        # Log command for debugging
        import logging
        logger = logging.getLogger(__name__)
        logger.info(f"Command sent to {device.device_id}: {command_type}")
        
        return Response({
            "status": "sent" if success else "failed",
            "topic": topic,
            "command": enhanced_payload,
            "qos": 2
        })

    @action(detail=False, methods=["post"], url_path="link-model")
    def link_model(self, request):
        device_id = request.data.get("device_id")
        model_id = request.data.get("model_id")
        if not device_id or not model_id:
            return Response({"detail": "device_id and model_id required"}, status=400)
        device = Device.objects.filter(device_id=device_id, gateway__owner=request.user).first()
        if not device:
            return Response({"detail": "device not found"}, status=404)
        model_def = DeviceModelDefinition.objects.filter(model_id=model_id).first()
        if not model_def:
            return Response({"detail": "model not found"}, status=404)
        device.model_definition = model_def
        device.save(update_fields=["model_definition"])
        return Response(DeviceSerializer(device).data)



class TelemetryViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = TelemetrySerializer
    permission_classes = [permissions.IsAuthenticated, IsOwner]

    def get_queryset(self):
        queryset = Telemetry.objects.filter(device__gateway__owner=self.request.user).order_by("-timestamp")
        
        # Filter by device if specified
        device_id = self.request.query_params.get('device', None)
        if device_id:
            queryset = queryset.filter(device_id=device_id)
        
        # Limit results if specified
        limit = self.request.query_params.get('limit', None)
        if limit:
            try:
                limit_num = int(limit)
                queryset = queryset[:limit_num]
            except ValueError:
                pass
                
        return queryset


