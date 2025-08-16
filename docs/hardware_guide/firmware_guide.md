# Firmware Guide (ESP32/Zigbee/LoRa)

## Provisioning
- Zigbee: permit join via gateway, bind clusters
- Wi‑Fi: BLE-based provisioning or pre-config
- LoRa: provision DevEUI/AppKey in LNS

## Telemetry
- Publish JSON to `devices/{device_id}/data`
- Send heartbeat to `devices/{device_id}/heartbeat`

## Commands
- Subscribe to `devices/{device_id}/commands`
- Publish result to `devices/{device_id}/response`
