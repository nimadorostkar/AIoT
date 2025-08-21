#!/bin/bash

# NodeMCU Quick Setup Script for AIoT System
# این اسکریپت به شما کمک می‌کند تا سریعاً NodeMCU را در سیستم ثبت کنید

echo "🚀 NodeMCU AIoT Setup Script"
echo "=============================="

# بررسی سرویس‌ها
echo "📋 بررسی وضعیت سرویس‌ها..."
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/admin/)
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5173/)

if [ "$API_STATUS" != "302" ]; then
    echo "❌ Backend API در دسترس نیست (http://localhost:8000)"
    echo "لطفاً دستور 'make dev' را اجرا کنید"
    exit 1
fi

if [ "$FRONTEND_STATUS" != "200" ]; then
    echo "❌ Frontend در دسترس نیست (http://localhost:5173)"
    echo "لطفاً دستور 'make dev' را اجرا کنید"
    exit 1
fi

echo "✅ Backend API: آماده"
echo "✅ Frontend: آماده"

# دریافت JWT Token
echo ""
echo "🔐 دریافت JWT Token..."
echo "Username: admin"
echo "Password: admin123"

JWT_RESPONSE=$(curl -s -X POST http://localhost:8000/api/token/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}')

if [ $? -ne 0 ]; then
    echo "❌ خطا در دریافت JWT Token"
    exit 1
fi

JWT_TOKEN=$(echo "$JWT_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['access'])" 2>/dev/null)

if [ -z "$JWT_TOKEN" ]; then
    echo "❌ JWT Token دریافت نشد. لطفاً username/password را بررسی کنید"
    echo "Response: $JWT_RESPONSE"
    exit 1
fi

echo "✅ JWT Token دریافت شد"

# ثبت Gateway
echo ""
echo "🌐 ثبت Gateway..."
GATEWAY_RESPONSE=$(curl -s -X POST http://localhost:8000/api/devices/gateways/claim/ \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "NodeMCU-GW-001", 
    "name": "NodeMCU Test Gateway"
  }')

if echo "$GATEWAY_RESPONSE" | grep -q "error"; then
    echo "⚠️  Gateway قبلاً ثبت شده یا خطا رخ داد"
    echo "Response: $GATEWAY_RESPONSE"
else
    echo "✅ Gateway 'NodeMCU-GW-001' ثبت شد"
fi

# ثبت Device 1
echo ""
echo "🔌 ثبت Device 1 (RELAY-001)..."
DEVICE1_RESPONSE=$(curl -s -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "NodeMCU-GW-001",
    "device_id": "RELAY-001",
    "type": "actuator", 
    "name": "LED Channel 1",
    "model": "NodeMCU-Relay"
  }')

if echo "$DEVICE1_RESPONSE" | grep -q "error"; then
    echo "⚠️  Device RELAY-001 قبلاً ثبت شده یا خطا رخ داد"
else
    echo "✅ Device 'RELAY-001' ثبت شد"
fi

# ثبت Device 2
echo ""
echo "🔌 ثبت Device 2 (RELAY-002)..."
DEVICE2_RESPONSE=$(curl -s -X POST http://localhost:8000/api/devices/devices/ \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_id": "NodeMCU-GW-001",
    "device_id": "RELAY-002",
    "type": "actuator",
    "name": "LED Channel 2", 
    "model": "NodeMCU-Relay"
  }')

if echo "$DEVICE2_RESPONSE" | grep -q "error"; then
    echo "⚠️  Device RELAY-002 قبلاً ثبت شده یا خطا رخ داد"
else
    echo "✅ Device 'RELAY-002' ثبت شد"
fi

# نمایش خلاصه
echo ""
echo "🎯 خلاصه تنظیمات:"
echo "=================="
echo "Gateway ID: NodeMCU-GW-001"
echo "Device 1: RELAY-001 (LED Channel 1)"
echo "Device 2: RELAY-002 (LED Channel 2)"
echo ""
echo "🌐 لینک‌های مفید:"
echo "Frontend: http://localhost:5173"
echo "Admin Panel: http://localhost:8000/admin"
echo "NodeMCU Direct: http://192.168.1.36 (IP NodeMCU شما)"
echo ""
echo "📖 راهنمای کامل: NodeMCU_Testing_Guide.md"
echo ""
echo "✅ NodeMCU آماده تست است!"
echo "حالا فرمور hardware/nodemcu_relay_gateway.ino را آپلود کنید"
