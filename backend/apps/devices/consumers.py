import json

from channels.generic.websocket import AsyncJsonWebsocketConsumer


class TelemetryConsumer(AsyncJsonWebsocketConsumer):
    async def connect(self):
        if self.scope.get("user") and self.scope["user"].is_authenticated:
            await self.channel_layer.group_add("telemetry", self.channel_name)
            await self.accept()
        else:
            await self.close()

    async def receive(self, text_data=None, bytes_data=None):
        try:
            message = json.loads(text_data or "{}")
        except Exception:
            message = {"type": "ping"}
        await self.send_json({"echo": message})

    async def telemetry_event(self, event):
        await self.send_json(event.get("data", {}))


