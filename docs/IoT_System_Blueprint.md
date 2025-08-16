# IoT System Blueprint

## Layers
- Device: ESP32/LoRa/Zigbee nodes (battery‑optimized)
- Gateway: Raspberry Pi bridges (MQTT, RTSP→WebRTC)
- Cloud: Django API + MQTT broker + DBs
- App: React web dashboard

## Protocols
- Sensors→Gateway: Zigbee 3.0 (battery), LoRaWAN (long range), Wi‑Fi (high bw)
- Gateway→Cloud: MQTT/TLS (QoS1/2), LWT for presence
- Video: RTSP→WebRTC with STUN/TURN

## MQTT Topics
- devices/{id}/data (QoS1)
- devices/{id}/heartbeat
- devices/{id}/commands (QoS2)
- devices/{id}/response

## Security
- TLS 1.3, optional mTLS per device
- JWT for web app, RBAC
- Signed OTA

## Reliability
- Retained LWT, backoff, store‑and‑forward at gateway, Redis channels
