#!/usr/bin/env python3
"""
اسکریپت تست برای بررسی اتصال NodeMCU با سیستم AIoT
"""

import json
import time
import paho.mqtt.client as mqtt
import requests
from datetime import datetime

# تنظیمات
MQTT_BROKER = "localhost"
MQTT_PORT = 1883
API_BASE = "http://localhost:8000/api"
JWT_TOKEN = None  # باید از متغیر محیطی یا ورودی کاربر دریافت شود

# شناسه‌های NodeMCU
GATEWAY_ID = "NodeMCU-GW-001"
DEVICE1_ID = "RELAY-001"
DEVICE2_ID = "RELAY-002"

class NodeMCUTester:
    def __init__(self):
        self.mqtt_client = mqtt.Client()
        self.mqtt_client.on_connect = self.on_mqtt_connect
        self.mqtt_client.on_message = self.on_mqtt_message
        self.received_messages = []
        
    def on_mqtt_connect(self, client, userdata, flags, rc):
        print(f"✅ اتصال MQTT برقرار شد. کد: {rc}")
        
        # اشتراک در topic های مربوط به NodeMCU
        topics = [
            f"devices/{DEVICE1_ID}/data",
            f"devices/{DEVICE1_ID}/heartbeat", 
            f"devices/{DEVICE1_ID}/response",
            f"devices/{DEVICE1_ID}/discovery",
            f"devices/{DEVICE2_ID}/data",
            f"devices/{DEVICE2_ID}/heartbeat",
            f"devices/{DEVICE2_ID}/response", 
            f"devices/{DEVICE2_ID}/discovery",
            f"gateways/{GATEWAY_ID}/status"
        ]
        
        for topic in topics:
            client.subscribe(topic)
            print(f"📡 اشتراک در: {topic}")
    
    def on_mqtt_message(self, client, userdata, msg):
        topic = msg.topic
        try:
            payload = json.loads(msg.payload.decode())
        except:
            payload = msg.payload.decode()
            
        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"📨 [{timestamp}] {topic}: {payload}")
        
        self.received_messages.append({
            'topic': topic,
            'payload': payload,
            'timestamp': timestamp
        })
    
    def connect_mqtt(self):
        """اتصال به MQTT broker"""
        try:
            print(f"🔌 اتصال به MQTT broker در {MQTT_BROKER}:{MQTT_PORT}...")
            self.mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
            self.mqtt_client.loop_start()
            time.sleep(2)
            return True
        except Exception as e:
            print(f"❌ خطا در اتصال MQTT: {e}")
            return False
    
    def test_device_discovery(self):
        """تست discovery دستگاه‌ها"""
        print("\n🔍 تست Device Discovery...")
        
        discovery_payload = {
            "action": "discover",
            "timestamp": datetime.now().isoformat(),
            "request_id": f"test_discover_{int(time.time())}"
        }
        
        topic = f"gateways/{GATEWAY_ID}/discover"
        
        try:
            self.mqtt_client.publish(topic, json.dumps(discovery_payload), qos=1)
            print(f"✅ پیام discovery ارسال شد به: {topic}")
            
            # انتظار برای پاسخ
            print("⏳ انتظار برای پاسخ discovery...")
            time.sleep(5)
            
            # بررسی دریافت پیام‌های discovery
            discovery_received = any(
                'discovery' in msg['topic'] for msg in self.received_messages
            )
            
            if discovery_received:
                print("✅ پیام‌های discovery دریافت شد")
            else:
                print("⚠️ هیچ پیام discovery دریافت نشد")
                
        except Exception as e:
            print(f"❌ خطا در تست discovery: {e}")
    
    def test_relay_control(self, device_id, state):
        """تست کنترل رله"""
        print(f"\n🔄 تست کنترل {device_id} -> {state}...")
        
        command_payload = {
            "action": "toggle",
            "state": state,
            "device_id": device_id,
            "timestamp": datetime.now().isoformat(),
            "command_id": f"test_cmd_{device_id}_{int(time.time())}"
        }
        
        topic = f"devices/{device_id}/commands"
        
        try:
            self.mqtt_client.publish(topic, json.dumps(command_payload), qos=2)
            print(f"✅ دستور ارسال شد: {device_id} = {state}")
            
            # انتظار برای پاسخ
            print("⏳ انتظار برای پاسخ...")
            time.sleep(3)
            
            # بررسی دریافت پاسخ
            responses = [
                msg for msg in self.received_messages 
                if msg['topic'] == f"devices/{device_id}/response" and 
                isinstance(msg['payload'], dict) and
                msg['payload'].get('command_id') == command_payload['command_id']
            ]
            
            if responses:
                response = responses[-1]['payload']
                if response.get('status') == 'success':
                    print(f"✅ دستور موفق: {response.get('result', 'N/A')}")
                else:
                    print(f"❌ دستور ناموفق: {response}")
            else:
                print("⚠️ پاسخ دستور دریافت نشد")
                
        except Exception as e:
            print(f"❌ خطا در تست کنترل: {e}")
    
    def test_heartbeat_monitoring(self):
        """تست مانیتورینگ heartbeat"""
        print("\n💓 تست مانیتورینگ Heartbeat...")
        print("⏳ انتظار برای heartbeat (30 ثانیه)...")
        
        start_time = time.time()
        heartbeat_received = False
        
        while time.time() - start_time < 35:  # انتظار 35 ثانیه
            recent_heartbeats = [
                msg for msg in self.received_messages
                if 'heartbeat' in msg['topic'] and
                time.time() - time.mktime(time.strptime(msg['timestamp'], "%H:%M:%S")) < 60
            ]
            
            if recent_heartbeats:
                heartbeat_received = True
                print("✅ Heartbeat دریافت شد")
                break
                
            time.sleep(1)
            print(".", end="", flush=True)
        
        if not heartbeat_received:
            print("\n⚠️ هیچ heartbeat دریافت نشد")
    
    def check_api_integration(self, jwt_token):
        """بررسی یکپارچگی با API"""
        if not jwt_token:
            print("\n⚠️ JWT token در دسترس نیست - تست API رد شد")
            return
            
        print("\n🌐 تست یکپارچگی API...")
        
        headers = {
            'Authorization': f'Bearer {jwt_token}',
            'Content-Type': 'application/json'
        }
        
        try:
            # بررسی وجود gateway
            response = requests.get(f"{API_BASE}/devices/gateways/", headers=headers)
            
            if response.status_code == 200:
                gateways = response.json()
                gateway_exists = any(gw.get('gateway_id') == GATEWAY_ID for gw in gateways)
                
                if gateway_exists:
                    print(f"✅ Gateway {GATEWAY_ID} در سیستم موجود است")
                else:
                    print(f"⚠️ Gateway {GATEWAY_ID} در سیستم یافت نشد")
            else:
                print(f"❌ خطا در دریافت لیست gateway ها: {response.status_code}")
                
            # بررسی وجود دستگاه‌ها
            response = requests.get(f"{API_BASE}/devices/devices/", headers=headers)
            
            if response.status_code == 200:
                devices = response.json()
                device1_exists = any(dev.get('device_id') == DEVICE1_ID for dev in devices)
                device2_exists = any(dev.get('device_id') == DEVICE2_ID for dev in devices)
                
                if device1_exists:
                    print(f"✅ Device {DEVICE1_ID} در سیستم موجود است")
                else:
                    print(f"⚠️ Device {DEVICE1_ID} در سیستم یافت نشد")
                    
                if device2_exists:
                    print(f"✅ Device {DEVICE2_ID} در سیستم موجود است")
                else:
                    print(f"⚠️ Device {DEVICE2_ID} در سیستم یافت نشد")
            else:
                print(f"❌ خطا در دریافت لیست دستگاه‌ها: {response.status_code}")
                
        except Exception as e:
            print(f"❌ خطا در تست API: {e}")
    
    def run_full_test(self, jwt_token=None):
        """اجرای تست کامل"""
        print("🚀 شروع تست کامل NodeMCU...")
        print("=" * 50)
        
        # اتصال MQTT
        if not self.connect_mqtt():
            return False
        
        # تست discovery
        self.test_device_discovery()
        
        # تست کنترل رله‌ها
        self.test_relay_control(DEVICE1_ID, "on")
        time.sleep(2)
        self.test_relay_control(DEVICE1_ID, "off")
        time.sleep(2)
        self.test_relay_control(DEVICE2_ID, "on")
        time.sleep(2)
        self.test_relay_control(DEVICE2_ID, "off")
        
        # تست heartbeat
        self.test_heartbeat_monitoring()
        
        # تست API
        self.check_api_integration(jwt_token)
        
        print("\n" + "=" * 50)
        print("📋 خلاصه نتایج تست:")
        print(f"📨 تعداد پیام‌های دریافتی: {len(self.received_messages)}")
        
        # نمایش آخرین پیام‌ها
        if self.received_messages:
            print("\n📋 آخرین پیام‌ها:")
            for msg in self.received_messages[-5:]:  # 5 پیام آخر
                print(f"  • [{msg['timestamp']}] {msg['topic']}")
        
        print("\n✅ تست کامل شد!")
        
        # قطع اتصال
        self.mqtt_client.loop_stop()
        self.mqtt_client.disconnect()

def main():
    """تابع اصلی"""
    print("NodeMCU AIoT Integration Tester")
    print("=" * 50)
    
    # دریافت JWT token از کاربر (اختیاری)
    jwt_token = input("JWT Token را وارد کنید (Enter برای رد کردن): ").strip()
    if not jwt_token:
        jwt_token = None
        print("⚠️ تست بدون JWT token ادامه می‌یابد")
    
    print(f"🎯 تست برای Gateway: {GATEWAY_ID}")
    print(f"🎯 تست برای Devices: {DEVICE1_ID}, {DEVICE2_ID}")
    print()
    
    # اجرای تست
    tester = NodeMCUTester()
    tester.run_full_test(jwt_token)

if __name__ == "__main__":
    main()
