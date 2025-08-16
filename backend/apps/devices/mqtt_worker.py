import json
import os
import threading
from typing import Any, Dict

import paho.mqtt.client as mqtt
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.conf import settings
from django.utils import timezone

from .models import Device, Gateway, Telemetry, DeviceModelDefinition


class MqttBridge:
    def __init__(self) -> None:
        self.host = settings.MQTT.get("HOST", os.environ.get("MQTT_BROKER_URL", "localhost"))
        self.port = int(settings.MQTT.get("PORT", os.environ.get("MQTT_BROKER_PORT", 1883)))
        self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=f"api-{os.getpid()}")
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.client.on_disconnect = self.on_disconnect
        self._connected = False
        self._thread = None

    def start(self) -> None:
        try:
            print(f"MQTT Bridge: Connecting to {self.host}:{self.port}")
            self.client.connect(self.host, self.port, 60)
            if self._thread is None or not self._thread.is_alive():
                self._thread = threading.Thread(target=self.client.loop_forever, daemon=True)
                self._thread.start()
            self._connected = True
            print("MQTT Bridge: Started successfully")
        except Exception as e:
            print(f"MQTT Bridge: Failed to start - {e}")
            self._connected = False

    def on_disconnect(self, client, userdata, reason_code):
        print(f"MQTT Bridge: Disconnected with reason code {reason_code}")
        self._connected = False

    def publish(self, topic: str, payload: dict, qos: int = 1) -> None:
        try:
            self.client.publish(topic, json.dumps(payload), qos=qos)
        except Exception:
            pass

    def on_connect(self, client: mqtt.Client, userdata: Any, flags: Dict[str, Any], reason_code: int, properties=None):
        print(f"MQTT Bridge: Connected with result code {reason_code}")
        client.subscribe("devices/+/data")
        client.subscribe("devices/+/heartbeat")
        print("MQTT Bridge: Subscribed to devices/+/data and devices/+/heartbeat")
        self._connected = True

    def on_message(self, client: mqtt.Client, userdata: Any, msg: mqtt.MQTTMessage):
        print(f"MQTT Bridge: Received message on {msg.topic}")
        topic_parts = msg.topic.split("/")
        if len(topic_parts) < 3:
            print(f"MQTT Bridge: Invalid topic format: {msg.topic}")
            return
        _, device_id, event_type = topic_parts[:3]

        try:
            payload = json.loads(msg.payload.decode("utf-8")) if msg.payload else {}
        except Exception as e:
            print(f"MQTT Bridge: Failed to parse JSON: {e}")
            payload = {"raw": msg.payload.decode("utf-8", errors="ignore")}

        if event_type == "heartbeat":
            print(f"MQTT Bridge: Processing heartbeat for {device_id}")
            device = Device.objects.filter(device_id=device_id).select_related("gateway").first()
            if device:
                device.is_online = True
                device.save(update_fields=["is_online"])
                Gateway.objects.filter(id=device.gateway_id).update(last_seen=timezone.now())
                print(f"MQTT Bridge: Device {device_id} marked as online")
            else:
                # Auto-create device if gateway_id provided
                gwid = payload.get("gateway_id")
                if gwid:
                    gateway = Gateway.objects.filter(gateway_id=gwid).first()
                    if gateway:
                        Device.objects.get_or_create(
                            gateway=gateway,
                            device_id=device_id,
                            defaults={
                                "type": payload.get("type", "sensor"),
                                "model": payload.get("model", ""),
                                "name": payload.get("name", ""),
                                "is_online": True,
                            },
                        )
                        Gateway.objects.filter(id=gateway.id).update(last_seen=timezone.now())
            return

        if event_type == "data":
            device = Device.objects.filter(device_id=device_id).first()
            if not device:
                # Auto-create on first telemetry if gateway_id present
                gwid = payload.get("gateway_id")
                if gwid:
                    gateway = Gateway.objects.filter(gateway_id=gwid).first()
                    if gateway:
                        device, _ = Device.objects.get_or_create(
                            gateway=gateway,
                            device_id=device_id,
                            defaults={
                                "type": payload.get("type", "sensor"),
                                "model": payload.get("model", ""),
                                "name": payload.get("name", ""),
                                "is_online": True,
                            },
                        )
                        Gateway.objects.filter(id=gateway.id).update(last_seen=timezone.now())
            if device:
                # Auto-link model by declared model field if present in payload
                model_id = payload.get("model_id") or payload.get("model")
                if model_id and not device.model_definition:
                    model_def = DeviceModelDefinition.objects.filter(model_id=model_id).first()
                    if model_def:
                        device.model_definition = model_def
                        device.save(update_fields=["model_definition"])
                Telemetry.objects.create(device=device, payload=payload)
                channel_layer = get_channel_layer()
                async_to_sync(channel_layer.group_send)(
                    "telemetry",
                    {"type": "telemetry.event", "data": {"device_id": device_id, "payload": payload}},
                )


try:
    from typing import Optional
except Exception:
    Optional = None  # type: ignore

bridge: 'MqttBridge | None' = None  # type: ignore


def start_bridge_if_enabled():
    global bridge
    if settings.MQTT.get("ENABLE", True):
        if bridge is None:
            bridge = MqttBridge()
            bridge.start()


