"""
Views for the AIoT Smart System device management API.

This module contains the REST API views for managing gateways, devices,
telemetry data, and device model definitions.
"""

import logging
from typing import Optional

from rest_framework import permissions, viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils import timezone
from django.db import transaction
from django.shortcuts import get_object_or_404

from .models import Device, Gateway, Telemetry, DeviceModelDefinition
from .serializers import DeviceSerializer, GatewaySerializer, TelemetrySerializer, DeviceModelDefinitionSerializer
from . import mqtt_worker

logger = logging.getLogger(__name__)


class IsOwner(permissions.BasePermission):
    """
    Custom permission to only allow owners of an object to access it.
    
    This permission checks ownership for Gateway, Device, and Telemetry objects
    through their ownership relationships.
    """
    
    def has_object_permission(self, request, view, obj):
        """Check if the request user owns the object."""
        if isinstance(obj, Gateway):
            return obj.owner_id == request.user.id
        elif isinstance(obj, Device):
            return obj.gateway.owner_id == request.user.id
        elif isinstance(obj, Telemetry):
            return obj.device.gateway.owner_id == request.user.id
        return False


class GatewayViewSet(viewsets.ModelViewSet):
    """
    ViewSet for managing IoT gateways.
    
    Provides CRUD operations for gateways, device discovery functionality,
    and gateway claiming for device ownership management.
    """
    
    serializer_class = GatewaySerializer
    permission_classes = [permissions.IsAuthenticated, IsOwner]
    search_fields = ['name', 'gateway_id']
    ordering_fields = ['name', 'gateway_id', 'last_seen', 'created_at']
    ordering = ['-last_seen', 'name']

    def get_queryset(self):
        """Return gateways owned by the current user."""
        return Gateway.objects.filter(owner=self.request.user).select_related('owner')

    def perform_create(self, serializer):
        """Set the current user as the owner when creating a gateway."""
        logger.info(f"Creating new gateway for user {self.request.user.id}")
        serializer.save(owner=self.request.user)

    @action(detail=True, methods=["get"], url_path="devices")
    def devices(self, request, pk=None):
        """
        Get all devices connected to a specific gateway.
        
        Returns a list of devices associated with the gateway.
        """
        try:
            gateway = self.get_object()
            devices = gateway.devices.all().select_related('model_definition').order_by("name", "device_id")
            serializer = DeviceSerializer(devices, many=True)
            
            logger.debug(f"Retrieved {len(devices)} devices for gateway {gateway.gateway_id}")
            return Response(serializer.data)
            
        except Exception as e:
            logger.error(f"Error retrieving devices for gateway {pk}: {str(e)}")
            return Response(
                {"error": "Failed to retrieve devices"}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=True, methods=["post"], url_path="discover")
    def discover(self, request, pk=None):
        """
        Trigger device discovery on a gateway.
        
        Sends an MQTT message to the gateway requesting it to announce
        all connected devices.
        """
        try:
            gateway = self.get_object()
            topic = f"gateways/{gateway.gateway_id}/discover"
            payload = {
                "action": "discover",
                "timestamp": timezone.now().isoformat(),
                "request_id": f"discover_{gateway.gateway_id}_{int(timezone.now().timestamp())}"
            }
            
            # Ensure MQTT bridge is running
            if mqtt_worker.bridge is None:
                mqtt_worker.start_bridge_if_enabled()
            
            if mqtt_worker.bridge:
                mqtt_worker.bridge.publish(topic, payload, qos=1)
                logger.info(f"Device discovery request sent to gateway {gateway.gateway_id}")
                return Response({
                    "status": "sent",
                    "topic": topic,
                    "request_id": payload["request_id"]
                })
            else:
                logger.error(f"MQTT bridge not available for discovery request to {gateway.gateway_id}")
                return Response(
                    {"error": "MQTT service unavailable"}, 
                    status=status.HTTP_503_SERVICE_UNAVAILABLE
                )
                
        except Exception as e:
            logger.error(f"Error sending discovery request to gateway {pk}: {str(e)}")
            return Response(
                {"error": "Failed to send discovery request"}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=False, methods=["post"], url_path="claim")
    def claim(self, request):
        """
        Claim ownership of a gateway.
        
        Allows a user to claim an unclaimed gateway or update the name
        of an already owned gateway.
        """
        try:
            gateway_id = request.data.get("gateway_id")
            name = request.data.get("name", "")
            
            if not gateway_id:
                return Response(
                    {"error": "gateway_id is required"}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Validate gateway_id format
            if len(gateway_id.strip()) == 0 or len(gateway_id) > 64:
                return Response(
                    {"error": "gateway_id must be 1-64 characters"}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            with transaction.atomic():
                gw, created = Gateway.objects.get_or_create(
                    gateway_id=gateway_id.strip(),
                    defaults={"owner": request.user, "name": name.strip()},
                )
                
                if not created:
                    if gw.owner_id != request.user.id:
                        logger.warning(f"User {request.user.id} attempted to claim already owned gateway {gateway_id}")
                        return Response(
                            {"error": "Gateway already claimed by another user"}, 
                            status=status.HTTP_409_CONFLICT
                        )
                    
                    # Update name if provided and different
                    if name.strip() and gw.name != name.strip():
                        gw.name = name.strip()
                        gw.save(update_fields=["name", "updated_at"])
                        logger.info(f"Updated gateway {gateway_id} name to '{name}' for user {request.user.id}")
                else:
                    logger.info(f"Gateway {gateway_id} claimed by user {request.user.id}")
                
                return Response(
                    GatewaySerializer(gw).data, 
                    status=status.HTTP_201_CREATED if created else status.HTTP_200_OK
                )
                
        except Exception as e:
            logger.error(f"Error claiming gateway: {str(e)}")
            return Response(
                {"error": "Failed to claim gateway"}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class DeviceViewSet(viewsets.ModelViewSet):
    """
    ViewSet for managing IoT devices.
    
    Provides CRUD operations for devices, command sending functionality,
    and device model linking capabilities.
    """
    
    serializer_class = DeviceSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwner]
    search_fields = ['name', 'device_id', 'type', 'model']
    ordering_fields = ['name', 'device_id', 'type', 'created_at', 'is_online']
    ordering = ['gateway__name', 'name', 'device_id']
    filterset_fields = ['type', 'is_online', 'gateway']

    def get_queryset(self):
        """Return devices owned by the current user with optional filtering."""
        queryset = Device.objects.filter(
            gateway__owner=self.request.user
        ).select_related(
            'gateway', 'model_definition'
        ).prefetch_related(
            'telemetry'
        ).order_by('gateway__name', 'name', 'device_id')
        
        # Filter by gateway if specified
        gateway_id = self.request.query_params.get('gateway', None)
        if gateway_id:
            try:
                gateway_id_int = int(gateway_id)
                queryset = queryset.filter(gateway_id=gateway_id_int)
            except ValueError:
                logger.warning(f"Invalid gateway_id filter: {gateway_id}")
                queryset = queryset.none()
        
        # Filter by device type if specified
        device_type = self.request.query_params.get('type', None)
        if device_type:
            queryset = queryset.filter(type=device_type)
        
        # Filter by online status if specified
        is_online = self.request.query_params.get('online', None)
        if is_online is not None:
            is_online_bool = is_online.lower() in ('true', '1', 'yes')
            queryset = queryset.filter(is_online=is_online_bool)
                
        return queryset

    def create(self, request, *args, **kwargs):
        """
        Create or update a device.
        
        If a device with the same gateway and device_id exists, it will be updated.
        Otherwise, a new device will be created.
        """
        try:
            gateway_pk = request.data.get("gateway_pk")
            gateway_id = request.data.get("gateway_id")
            device_id = request.data.get("device_id")
            device_type = request.data.get("type", Device.DEVICE_TYPE_SENSOR)
            name = request.data.get("name", "")
            model = request.data.get("model", "")

            # Validate required fields
            if not device_id:
                return Response(
                    {"error": "device_id is required"}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            if len(device_id.strip()) == 0 or len(device_id) > 64:
                return Response(
                    {"error": "device_id must be 1-64 characters"}, 
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Validate device type
            valid_types = [choice[0] for choice in Device.DEVICE_TYPES]
            if device_type not in valid_types:
                return Response(
                    {"error": f"Invalid device type. Must be one of: {', '.join(valid_types)}"}, 
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Find gateway
            gateway: Optional[Gateway] = None
            if gateway_pk:
                try:
                    gateway = Gateway.objects.get(id=int(gateway_pk), owner=request.user)
                except (Gateway.DoesNotExist, ValueError):
                    pass
                    
            if not gateway and gateway_id:
                try:
                    gateway = Gateway.objects.get(gateway_id=gateway_id, owner=request.user)
                except Gateway.DoesNotExist:
                    pass
                    
            if not gateway:
                return Response(
                    {"error": "Gateway not found or not owned by user"}, 
                    status=status.HTTP_404_NOT_FOUND
                )

            with transaction.atomic():
                device, created = Device.objects.get_or_create(
                    gateway=gateway,
                    device_id=device_id.strip(),
                    defaults={
                        "type": device_type, 
                        "name": name.strip(), 
                        "model": model.strip()
                    },
                )
                
                if not created:
                    # Update basic fields if provided
                    updated = False
                    if name.strip() and device.name != name.strip():
                        device.name = name.strip()
                        updated = True
                    if model.strip() and device.model != model.strip():
                        device.model = model.strip()
                        updated = True
                    if device_type and device.type != device_type:
                        device.type = device_type
                        updated = True
                    if updated:
                        device.save(update_fields=['name', 'model', 'type', 'updated_at'])
                        logger.info(f"Updated device {device.full_device_id} for user {request.user.id}")
                else:
                    logger.info(f"Created device {device.full_device_id} for user {request.user.id}")
                
                return Response(
                    DeviceSerializer(device).data, 
                    status=status.HTTP_201_CREATED if created else status.HTTP_200_OK
                )
                
        except Exception as e:
            logger.error(f"Error creating/updating device: {str(e)}")
            return Response(
                {"error": "Failed to create or update device"}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=True, methods=["post"], url_path="command")
    def command(self, request, pk=None):
        """
        Send a command to a device via MQTT.
        
        Validates the command based on device type and sends it through
        the MQTT bridge to the device.
        """
        try:
            device = self.get_object()
            payload = request.data.copy() if request.data else {}
            command_type = payload.get('action', 'unknown')
            
            # Check if device can receive commands
            if not device.can_receive_commands():
                return Response(
                    {"error": f"Device type '{device.type}' cannot receive commands"}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Validate command based on device type
            validation_error = self._validate_command(device, command_type, payload)
            if validation_error:
                return Response(validation_error, status=status.HTTP_400_BAD_REQUEST)
            
            # Build enhanced payload with metadata
            enhanced_payload = {
                **payload,
                'device_id': device.device_id,
                'device_type': device.type,
                'gateway_id': device.gateway.gateway_id,
                'timestamp': timezone.now().isoformat(),
                'command_id': f"cmd_{device.device_id}_{int(timezone.now().timestamp())}",
                'user_id': request.user.id
            }
            
            # Send command via MQTT
            topic = f"devices/{device.device_id}/commands"
            success = self._send_mqtt_command(topic, enhanced_payload)
            
            if success:
                logger.info(f"Command '{command_type}' sent to device {device.full_device_id} by user {request.user.id}")
                return Response({
                    "status": "sent",
                    "topic": topic,
                    "command_id": enhanced_payload["command_id"],
                    "timestamp": enhanced_payload["timestamp"]
                })
            else:
                logger.error(f"Failed to send command '{command_type}' to device {device.full_device_id}")
                return Response(
                    {"error": "MQTT service unavailable"}, 
                    status=status.HTTP_503_SERVICE_UNAVAILABLE
                )
                
        except Exception as e:
            logger.error(f"Error sending command to device {pk}: {str(e)}")
            return Response(
                {"error": "Failed to send command"}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    def _validate_command(self, device: Device, command_type: str, payload: dict) -> Optional[dict]:
        """Validate command payload based on device type."""
        if device.type in [Device.DEVICE_TYPE_RELAY, Device.DEVICE_TYPE_SWITCH] and command_type == 'toggle':
            if 'state' not in payload:
                return {"error": "State required for toggle command"}
            if payload['state'] not in [True, False, 'on', 'off', 1, 0]:
                return {"error": "State must be boolean or 'on'/'off'"}
        
        elif device.type in [Device.DEVICE_TYPE_DIMMER, 'light'] and command_type == 'set_brightness':
            brightness = payload.get('brightness', -1)
            try:
                brightness = float(brightness)
                if not 0 <= brightness <= 100:
                    return {"error": "Brightness must be between 0-100"}
            except (ValueError, TypeError):
                return {"error": "Brightness must be a number"}
        
        elif device.type == Device.DEVICE_TYPE_CAMERA:
            valid_camera_commands = ['start_recording', 'stop_recording', 'take_snapshot', 'set_quality']
            if command_type not in valid_camera_commands:
                return {"error": f"Invalid camera command. Valid commands: {', '.join(valid_camera_commands)}"}
            
            if command_type == 'set_quality':
                quality = payload.get('quality', '')
                if quality not in ['low', 'medium', 'high']:
                    return {"error": "Quality must be 'low', 'medium', or 'high'"}
        
        return None

    def _send_mqtt_command(self, topic: str, payload: dict) -> bool:
        """Send command via MQTT and return success status."""
        try:
            # Ensure MQTT bridge is running
            if mqtt_worker.bridge is None:
                mqtt_worker.start_bridge_if_enabled()
            
            if mqtt_worker.bridge:
                mqtt_worker.bridge.publish(topic, payload, qos=2)
                return True
            else:
                logger.warning("MQTT bridge not available for command sending")
                return False
                
        except Exception as e:
            logger.error(f"Error sending MQTT command: {str(e)}")
            return False

    @action(detail=False, methods=["post"], url_path="link-model")
    def link_model(self, request):
        """
        Link a device to a model definition for validation and schema enforcement.
        """
        try:
            device_id = request.data.get("device_id")
            model_id = request.data.get("model_id")
            
            if not device_id or not model_id:
                return Response(
                    {"error": "device_id and model_id are required"}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Find device owned by user
            try:
                device = Device.objects.select_related('gateway', 'model_definition').get(
                    device_id=device_id, 
                    gateway__owner=request.user
                )
            except Device.DoesNotExist:
                return Response(
                    {"error": "Device not found or not owned by user"}, 
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # Find model definition
            try:
                model_def = DeviceModelDefinition.objects.get(model_id=model_id)
            except DeviceModelDefinition.DoesNotExist:
                return Response(
                    {"error": "Model definition not found"}, 
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # Link device to model
            device.model_definition = model_def
            device.save(update_fields=["model_definition", "updated_at"])
            
            logger.info(f"Linked device {device.full_device_id} to model {model_id} by user {request.user.id}")
            return Response(DeviceSerializer(device).data)

        except Exception as e:
            logger.error(f"Error linking device to model: {str(e)}")
            return Response(
                {"error": "Failed to link device to model"}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class TelemetryViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet for viewing telemetry data from IoT devices.
    
    Provides read-only access to time-series data collected from devices
    with filtering and pagination capabilities.
    """
    
    serializer_class = TelemetrySerializer
    permission_classes = [permissions.IsAuthenticated, IsOwner]
    ordering_fields = ['timestamp', 'device']
    ordering = ['-timestamp']

    def get_queryset(self):
        """Return telemetry data for devices owned by the current user."""
        queryset = Telemetry.objects.filter(
            device__gateway__owner=self.request.user
        ).select_related(
            'device', 'device__gateway'
        ).order_by('-timestamp')
        
        # Filter by device if specified
        device_id = self.request.query_params.get('device', None)
        if device_id:
            try:
                device_id_int = int(device_id)
                queryset = queryset.filter(device_id=device_id_int)
            except ValueError:
                logger.warning(f"Invalid device_id filter: {device_id}")
                queryset = queryset.none()
        
        # Filter by device type if specified
        device_type = self.request.query_params.get('device_type', None)
        if device_type:
            queryset = queryset.filter(device__type=device_type)
        
        # Filter by date range if specified
        since = self.request.query_params.get('since', None)
        if since:
            try:
                from django.utils.dateparse import parse_datetime
                since_datetime = parse_datetime(since)
                if since_datetime:
                    queryset = queryset.filter(timestamp__gte=since_datetime)
            except Exception:
                logger.warning(f"Invalid since filter: {since}")
        
        until = self.request.query_params.get('until', None)
        if until:
            try:
                from django.utils.dateparse import parse_datetime
                until_datetime = parse_datetime(until)
                if until_datetime:
                    queryset = queryset.filter(timestamp__lte=until_datetime)
            except Exception:
                logger.warning(f"Invalid until filter: {until}")
        
        # Apply limit if specified (for backwards compatibility)
        limit = self.request.query_params.get('limit', None)
        if limit:
            try:
                limit_num = int(limit)
                if limit_num > 0:
                    queryset = queryset[:limit_num]
            except ValueError:
                logger.warning(f"Invalid limit filter: {limit}")
                
        return queryset


