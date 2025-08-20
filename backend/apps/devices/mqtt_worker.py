"""
MQTT Bridge for AIoT Smart System.

This module provides MQTT communication capabilities for the IoT platform,
handling device data ingestion, command publishing, and real-time communication
between the platform and IoT gateways/devices.
"""

import json
import logging
import os
import time
from typing import Any, Dict, Optional

import paho.mqtt.client as mqtt
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.conf import settings
from django.utils import timezone
from django.db import transaction

from .models import Device, Gateway, Telemetry, DeviceModelDefinition

logger = logging.getLogger(__name__)


class MqttBridge:
    """
    MQTT Bridge class for handling IoT device communication.
    
    This class manages the MQTT connection, subscribes to device topics,
    and processes incoming messages from IoT devices and gateways.
    """
    
    def __init__(self) -> None:
        """Initialize the MQTT bridge with configuration from Django settings."""
        self.host = settings.MQTT.get("HOST", os.environ.get("MQTT_BROKER_URL", "localhost"))
        self.port = int(settings.MQTT.get("PORT", os.environ.get("MQTT_BROKER_PORT", 1883)))
        self.keepalive = settings.MQTT.get("KEEPALIVE", 60)
        self.qos = settings.MQTT.get("QOS", 1)
        
        # Create MQTT client with unique ID
        client_id = f"aiot-api-{os.getpid()}-{int(time.time())}"
        self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=client_id)
        
        # Set up callbacks
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.client.on_disconnect = self.on_disconnect
        self.client.on_log = self.on_log
        
        # Connection state
        self._connected = False
        self._connection_attempts = 0
        self._max_connection_attempts = 5
        
        logger.info(f"MQTT Bridge initialized - Host: {self.host}:{self.port}, Client ID: {client_id}")

    def start(self) -> None:
        """
        Start the MQTT bridge connection.
        
        Attempts to connect to the MQTT broker and start the message loop.
        Implements retry logic for connection failures.
        """
        while self._connection_attempts < self._max_connection_attempts:
            try:
                self._connection_attempts += 1
                logger.info(f"MQTT Bridge: Connecting to {self.host}:{self.port} (attempt {self._connection_attempts})")
                
                # Connect to MQTT broker
                self.client.connect(self.host, self.port, self.keepalive)
                
                # Start the network loop in a separate thread
                logger.info("MQTT Bridge: Starting client network loop")
            self.client.loop_start()
                
                # Wait a moment to see if connection succeeds
                time.sleep(2)
                
                if self._connected:
                    logger.info("MQTT Bridge: Successfully connected and started")
                    return
                else:
                    logger.warning(f"MQTT Bridge: Connection attempt {self._connection_attempts} failed")
                    
        except Exception as e:
                logger.error(f"MQTT Bridge: Connection attempt {self._connection_attempts} failed - {e}")
                
            # Wait before retrying
            if self._connection_attempts < self._max_connection_attempts:
                wait_time = min(5 * self._connection_attempts, 30)  # Exponential backoff, max 30s
                logger.info(f"MQTT Bridge: Retrying in {wait_time} seconds...")
                time.sleep(wait_time)
        
        logger.error(f"MQTT Bridge: Failed to connect after {self._max_connection_attempts} attempts")
            self._connected = False

    def on_log(self, client, userdata, level, buf):
        """Handle MQTT client log messages."""
        if level == mqtt.MQTT_LOG_ERR:
            logger.error(f"MQTT Client Error: {buf}")
        elif level == mqtt.MQTT_LOG_WARNING:
            logger.warning(f"MQTT Client Warning: {buf}")
        elif level == mqtt.MQTT_LOG_DEBUG:
            logger.debug(f"MQTT Client Debug: {buf}")

    def on_disconnect(self, client, userdata, reason_code):
        """Handle MQTT client disconnection."""
        logger.warning(f"MQTT Bridge: Disconnected with reason code {reason_code}")
        self._connected = False

        # Attempt to reconnect if disconnection was unexpected
        if reason_code != 0:
            logger.info("MQTT Bridge: Attempting to reconnect...")
            self._connection_attempts = 0  # Reset attempts for reconnection
    
    def stop(self) -> None:
        """Stop the MQTT bridge and disconnect from broker."""
        try:
            if self._connected:
                logger.info("MQTT Bridge: Stopping...")
                self.client.loop_stop()
                self.client.disconnect()
                self._connected = False
                logger.info("MQTT Bridge: Stopped successfully")
        except Exception as e:
            logger.error(f"MQTT Bridge: Error during stop - {e}")

    def publish(self, topic: str, payload: dict, qos: Optional[int] = None) -> bool:
        """
        Publish a message to an MQTT topic.
        
        Args:
            topic: MQTT topic to publish to
            payload: Message payload as dictionary
            qos: Quality of Service level (0, 1, or 2)
            
        Returns:
            bool: True if message was published successfully, False otherwise
        """
        if not self._connected:
            logger.error("MQTT Bridge: Cannot publish - not connected")
            return False
            
        try:
            if qos is None:
                qos = self.qos
                
            message_json = json.dumps(payload, default=str)
            result = self.client.publish(topic, message_json, qos=qos)
            
            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                logger.debug(f"MQTT Bridge: Published to {topic} with QoS {qos}")
                return True
            else:
                logger.error(f"MQTT Bridge: Failed to publish to {topic} - error code {result.rc}")
                return False
                
        except Exception as e:
            logger.error(f"MQTT Bridge: Error publishing to {topic} - {e}")
            return False

    def on_connect(self, client: mqtt.Client, userdata: Any, flags: Dict[str, Any], reason_code: int, properties=None):
        """
        Handle MQTT client connection.
        
        Sets up subscriptions to device topics and marks the bridge as connected.
        """
        if reason_code == 0:
            logger.info("MQTT Bridge: Successfully connected to broker")
            self._connected = True
            self._connection_attempts = 0  # Reset attempts on successful connection
            
            # Subscribe to device topics
            subscriptions = [
                ("devices/+/data", self.qos),
                ("devices/+/heartbeat", self.qos),
                ("gateways/+/status", self.qos),
                ("debug/test", 0),  # Debug topic for testing
            ]
            
            for topic, qos in subscriptions:
                try:
                    result, _ = client.subscribe(topic, qos)
                    if result == mqtt.MQTT_ERR_SUCCESS:
                        logger.info(f"MQTT Bridge: Subscribed to {topic} with QoS {qos}")
                    else:
                        logger.error(f"MQTT Bridge: Failed to subscribe to {topic} - error code {result}")
                except Exception as e:
                    logger.error(f"MQTT Bridge: Error subscribing to {topic} - {e}")
            
            # Publish connection announcement
            try:
                announcement = {
                    "status": "bridge_connected",
                    "timestamp": timezone.now().isoformat(),
                    "client_id": self.client._client_id.decode() if hasattr(self.client, '_client_id') else "unknown"
                }
                self.publish("system/bridge/status", announcement, qos=1)
                logger.info("MQTT Bridge: Published connection announcement")
            except Exception as e:
                logger.error(f"MQTT Bridge: Error publishing connection announcement - {e}")
                
        else:
            logger.error(f"MQTT Bridge: Failed to connect - reason code {reason_code}")
            self._connected = False

    def on_message(self, client: mqtt.Client, userdata: Any, msg: mqtt.MQTTMessage):
        """
        Handle incoming MQTT messages from devices and gateways.
        
        Processes different types of messages including device data, heartbeats,
        and status updates.
        """
        try:
            topic = msg.topic
            payload_raw = msg.payload.decode("utf-8") if msg.payload else "{}"
            
            logger.debug(f"MQTT message received: {topic} = {payload_raw[:200]}...")
            
            # Handle debug messages
            if topic.startswith("debug/"):
                logger.debug(f"Debug message: {payload_raw}")
            return
            
            # Parse topic and payload
            topic_parts = topic.split("/")
            if len(topic_parts) < 3:
                logger.warning(f"Invalid topic format: {topic}")
                return
                
            # Parse payload
            try:
                payload = json.loads(payload_raw) if payload_raw else {}
            except json.JSONDecodeError as e:
                logger.error(f"Failed to parse JSON payload: {e}")
                payload = {"raw": payload_raw}
            
            # Route message based on topic pattern
            if topic.startswith("devices/"):
                self._handle_device_message(topic_parts, payload)
            elif topic.startswith("gateways/"):
                self._handle_gateway_message(topic_parts, payload)
            else:
                logger.warning(f"Unhandled topic pattern: {topic}")
                
        except Exception as e:
            logger.error(f"Error processing MQTT message from {msg.topic}: {e}")

    def _handle_device_message(self, topic_parts: list, payload: dict) -> None:
        """Handle messages from device topics (devices/{device_id}/{event_type})."""
        if len(topic_parts) < 3:
            return
            
        _, device_id, event_type = topic_parts[:3]

        if event_type == "heartbeat":
            self._handle_device_heartbeat(device_id, payload)
        elif event_type == "data":
            self._handle_device_data(device_id, payload)
        else:
            logger.debug(f"Unhandled device event type: {event_type}")

    def _handle_gateway_message(self, topic_parts: list, payload: dict) -> None:
        """Handle messages from gateway topics (gateways/{gateway_id}/{event_type})."""
        if len(topic_parts) < 3:
            return
            
        _, gateway_id, event_type = topic_parts[:3]
        
        if event_type == "status":
            self._handle_gateway_status(gateway_id, payload)
        else:
            logger.debug(f"Unhandled gateway event type: {event_type}")

    def _handle_device_heartbeat(self, device_id: str, payload: dict) -> None:
        """Process device heartbeat messages."""
        try:
            with transaction.atomic():
            device = Device.objects.filter(device_id=device_id).select_related("gateway").first()
                
            if device:
                    device.update_online_status(True)
                    device.gateway.update_last_seen()
                    logger.debug(f"Updated heartbeat for device {device_id}")
            else:
                # Auto-create device if gateway_id provided
                    gateway_id = payload.get("gateway_id")
                    if gateway_id:
                        gateway = Gateway.objects.filter(gateway_id=gateway_id).first()
                    if gateway:
                            device = Device.objects.create(
                            gateway=gateway,
                            device_id=device_id,
                                type=payload.get("type", Device.DEVICE_TYPE_SENSOR),
                                model=payload.get("model", ""),
                                name=payload.get("name", ""),
                                is_online=True,
                            )
                            gateway.update_last_seen()
                            logger.info(f"Auto-created device {device_id} from heartbeat")
                        else:
                            logger.warning(f"Heartbeat from unknown gateway: {gateway_id}")
                    else:
                        logger.warning(f"Heartbeat without gateway_id: {device_id}")
                        
        except Exception as e:
            logger.error(f"Error processing heartbeat for {device_id}: {e}")

    def _handle_device_data(self, device_id: str, payload: dict) -> None:
        """Process device telemetry data messages."""
        try:
            with transaction.atomic():
                device = Device.objects.filter(device_id=device_id).select_related("gateway").first()
                
            if not device:
                    # Auto-create device on first telemetry if gateway_id present
                    gateway_id = payload.get("gateway_id")
                    if gateway_id:
                        gateway = Gateway.objects.filter(gateway_id=gateway_id).first()
                    if gateway:
                            device = Device.objects.create(
                            gateway=gateway,
                            device_id=device_id,
                                type=payload.get("type", Device.DEVICE_TYPE_SENSOR),
                                model=payload.get("model", ""),
                                name=payload.get("name", ""),
                                is_online=True,
                            )
                            gateway.update_last_seen()
                            logger.info(f"Auto-created device {device_id} from telemetry")
                        else:
                            logger.warning(f"Telemetry from unknown gateway: {gateway_id}")
                            return
                    else:
                        logger.warning(f"Telemetry without gateway_id: {device_id}")
                        return
                
                # Auto-link model definition if provided
                model_id = payload.get("model_id") or payload.get("model")
                if model_id and not device.model_definition:
                    try:
                        model_def = DeviceModelDefinition.objects.get(model_id=model_id)
                        device.model_definition = model_def
                        device.save(update_fields=["model_definition", "updated_at"])
                        logger.info(f"Auto-linked device {device_id} to model {model_id}")
                    except DeviceModelDefinition.DoesNotExist:
                        logger.debug(f"Model definition {model_id} not found for device {device_id}")
                
                # Create telemetry record
                telemetry = Telemetry.objects.create(device=device, payload=payload)
                device.update_online_status(True)
                
                # Send real-time update via WebSocket
                try:
                channel_layer = get_channel_layer()
                    if channel_layer:
                async_to_sync(channel_layer.group_send)(
                    "telemetry",
                            {
                                "type": "telemetry.event",
                                "data": {
                                    "device_id": device_id,
                                    "device_name": device.name,
                                    "device_type": device.type,
                                    "gateway_id": device.gateway.gateway_id,
                                    "timestamp": telemetry.timestamp.isoformat(),
                                    "payload": payload
                                }
                            },
                        )
                except Exception as e:
                    logger.error(f"Error sending WebSocket update: {e}")
                
                logger.debug(f"Processed telemetry for device {device_id}")
                
        except Exception as e:
            logger.error(f"Error processing telemetry for {device_id}: {e}")

    def _handle_gateway_status(self, gateway_id: str, payload: dict) -> None:
        """Process gateway status messages."""
        try:
            gateway = Gateway.objects.filter(gateway_id=gateway_id).first()
            if gateway:
                gateway.update_last_seen()
                logger.debug(f"Updated status for gateway {gateway_id}")
            else:
                logger.debug(f"Status from unknown gateway: {gateway_id}")
        except Exception as e:
            logger.error(f"Error processing gateway status for {gateway_id}: {e}")


# Global bridge instance
bridge: Optional[MqttBridge] = None


def start_bridge_if_enabled() -> None:
    """
    Start the MQTT bridge if enabled in settings.
    
    This function is called to initialize the MQTT connection when needed.
    It's designed to be called multiple times safely.
    """
    global bridge
    
    logger.info("MQTT Bridge: Checking if bridge should be started")
    
    if not settings.MQTT.get("ENABLE", True):
        logger.info("MQTT Bridge: MQTT is disabled in settings")
        return
    
        if bridge is None:
        logger.info("MQTT Bridge: Creating new bridge instance")
        try:
            bridge = MqttBridge()
            bridge.start()
        except Exception as e:
            logger.error(f"MQTT Bridge: Failed to create and start bridge - {e}")
            bridge = None
        else:
        logger.debug("MQTT Bridge: Bridge instance already exists")
        
        # Check if bridge is still connected
        if not bridge._connected:
            logger.warning("MQTT Bridge: Existing bridge is disconnected, attempting to reconnect")
            try:
                bridge.start()
            except Exception as e:
                logger.error(f"MQTT Bridge: Failed to reconnect - {e}")


def stop_bridge() -> None:
    """Stop the MQTT bridge if it's running."""
    global bridge
    
    if bridge is not None:
        logger.info("MQTT Bridge: Stopping bridge")
        try:
            bridge.stop()
        except Exception as e:
            logger.error(f"MQTT Bridge: Error stopping bridge - {e}")
        finally:
            bridge = None
    else:
        logger.debug("MQTT Bridge: No bridge instance to stop")


def get_bridge_status() -> dict:
    """Get the current status of the MQTT bridge."""
    global bridge
    
    if bridge is None:
        return {
            "status": "not_initialized",
            "connected": False,
            "host": None,
            "port": None
        }
    
    return {
        "status": "initialized",
        "connected": bridge._connected,
        "host": bridge.host,
        "port": bridge.port,
        "connection_attempts": bridge._connection_attempts
    }


