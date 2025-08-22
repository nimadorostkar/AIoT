import logging
import json
import threading
import time
from typing import Optional, Dict, Any

import paho.mqtt.client as mqtt

logger = logging.getLogger(__name__)


class MqttBridge:
    def __init__(self, broker_host='localhost', broker_port=1883, client_id='aiot_backend'):
        self.broker_host = broker_host
        self.broker_port = broker_port
        self.client_id = client_id
        self._client = None
        self._connected = False
        self._running = False
        self._thread = None
        
    def _on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            self._connected = True
            logger.info(f"MQTT Bridge connected to {self.broker_host}:{self.broker_port}")
            client.subscribe("devices/+/response")
            client.subscribe("devices/+/data")
            client.subscribe("devices/+/heartbeat")
            client.subscribe("gateways/+/status")
        else:
            logger.error(f"MQTT Bridge connection failed with code {rc}")
            
    def _on_disconnect(self, client, userdata, rc):
        self._connected = False
        logger.warning(f"MQTT Bridge disconnected with code {rc}")
        
    def _on_message(self, client, userdata, msg):
        try:
            topic = msg.topic
            payload = json.loads(msg.payload.decode('utf-8'))
            logger.debug(f"MQTT message received: {topic} = {payload}")
        except Exception as e:
            logger.error(f"Error processing MQTT message: {e}")
            
    def start(self):
        if self._running:
            logger.warning("MQTT Bridge is already running")
            return
            
        try:
            self._client = mqtt.Client()
            self._client._client_id = self.client_id
            self._client.on_connect = self._on_connect
            self._client.on_disconnect = self._on_disconnect
            self._client.on_message = self._on_message
            
            self._client.connect(self.broker_host, self.broker_port, 60)
            
            self._running = True
            self._thread = threading.Thread(target=self._run_loop, daemon=True)
            self._thread.start()
            
            logger.info("MQTT Bridge started")
            
        except Exception as e:
            logger.error(f"Failed to start MQTT Bridge: {e}")
            self._running = False
            
    def _run_loop(self):
        while self._running:
            try:
                self._client.loop(timeout=1.0)
            except Exception as e:
                logger.error(f"MQTT loop error: {e}")
                time.sleep(1)
                
    def stop(self):
        if not self._running:
            return
            
        self._running = False
        
        if self._client:
            self._client.disconnect()
            
        if self._thread:
            self._thread.join(timeout=5)
            
        logger.info("MQTT Bridge stopped")
        
    def publish(self, topic, payload, qos=1):
        if not self._connected or not self._client:
            logger.error("MQTT Bridge not connected - cannot publish message")
            return False
            
        try:
            message_json = json.dumps(payload)
            result = self._client.publish(topic, message_json, qos)
            
            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                logger.info(f"MQTT message published: {topic}")
                logger.debug(f"MQTT payload: {message_json}")
                return True
            else:
                logger.error(f"Failed to publish MQTT message: {result.rc}")
                return False
                
        except Exception as e:
            logger.error(f"Error publishing MQTT message: {e}")
            return False
            
    @property
    def is_connected(self):
        return self._connected


bridge = None


def start_bridge_if_enabled():
    global bridge
    
    if bridge is None:
        bridge = MqttBridge()
        bridge.start()
        time.sleep(1)
        logger.info("MQTT Bridge initialized and started")
    
    return bridge


def stop_bridge():
    global bridge
    
    if bridge:
        bridge.stop()
        bridge = None
        logger.info("MQTT Bridge stopped")