from django.urls import path

from apps.devices import consumers as device_consumers

websocket_urlpatterns = [
    path("ws/telemetry/", device_consumers.TelemetryConsumer.as_asgi()),
]


