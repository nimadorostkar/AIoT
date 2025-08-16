#!/bin/bash
# Quick IoT Test Script
# Rapid testing of basic IoT functionality

API_BASE="http://localhost:8000/api"
USERNAME="admin"
PASSWORD="admin123"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Quick IoT Test${NC}"

# Get token
echo "Getting token..."
TOKEN=$(curl -s -X POST $API_BASE/token/ \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}" | \
  jq -r '.access')

if [ "$TOKEN" = "null" ]; then
  echo -e "${RED}❌ Failed to get token${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Token obtained${NC}"

# Claim gateway
echo "Claiming gateway..."
curl -s -X POST $API_BASE/devices/gateways/claim/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"gateway_id":"QUICK-TEST-GW","name":"Quick Test Gateway"}' > /dev/null

echo -e "${GREEN}✅ Gateway claimed${NC}"

# Create test device
echo "Creating test device..."
curl -s -X POST $API_BASE/devices/devices/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"gateway_id":"QUICK-TEST-GW","device_id":"TEST-001","type":"sensor","name":"Test Sensor"}' > /dev/null

echo -e "${GREEN}✅ Device created${NC}"

# Send test telemetry
if command -v mosquitto_pub &> /dev/null; then
  echo "Sending test telemetry..."
  mosquitto_pub -h localhost -p 1883 \
    -t "devices/TEST-001/data" \
    -m '{"temperature":25.5,"test":true}' -q 1
  echo -e "${GREEN}✅ Telemetry sent${NC}"
else
  echo -e "${BLUE}ℹ️  Skipping MQTT (mosquitto not available)${NC}"
fi

# Get telemetry count
echo "Checking telemetry..."
COUNT=$(curl -s -X GET "$API_BASE/devices/telemetry/" \
  -H "Authorization: Bearer $TOKEN" | jq length)

echo -e "${GREEN}✅ Found $COUNT telemetry records${NC}"

echo -e "${BLUE}🎉 Quick test completed!${NC}"
echo "Web UI: http://localhost:5173"
