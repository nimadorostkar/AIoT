#!/bin/bash
# Health check script for Docker services

set -e

echo "🔍 Checking Docker services health..."

# Function to check service health
check_service() {
    local service=$1
    
    local state=$(docker compose ps --format "{{.Service}}" --filter status=running | grep "^${service}$" || echo "")
    
    if [ "$state" = "$service" ]; then
        echo "✅ $service: Running"
        return 0
    else
        echo "❌ $service: Not running"
        return 1
    fi
}

# Function to check endpoint health
check_endpoint() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [ "$response" = "$expected_code" ]; then
        echo "✅ $name ($url): HTTP $response"
        return 0
    else
        echo "❌ $name ($url): HTTP $response (expected $expected_code)"
        return 1
    fi
}

# Check Docker services
echo ""
echo "📦 Docker Services:"
check_service "db"
check_service "redis"
check_service "mqtt"
check_service "api"
check_service "web"
check_service "celery"

# Check endpoints
echo ""
echo "🌐 Endpoint Health:"
check_endpoint "Frontend" "http://localhost:5173"
check_endpoint "Admin Panel" "http://localhost:8000/admin/" 302  # 302 is expected (redirect to login)
check_endpoint "API Docs" "http://localhost:8000/api/docs/"

# Check MQTT
echo ""
echo "📡 MQTT Broker:"
if command -v mosquitto_pub >/dev/null 2>&1; then
    if mosquitto_pub -h localhost -p 1883 -t "health/check" -m "test" -q 1 >/dev/null 2>&1; then
        echo "✅ MQTT Broker (localhost:1883): Connected"
    else
        echo "❌ MQTT Broker (localhost:1883): Connection failed"
    fi
else
    echo "⚠️  MQTT Broker: mosquitto_pub not available for testing"
fi

echo ""
echo "🏁 Health check complete!"
