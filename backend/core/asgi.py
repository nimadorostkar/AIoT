import os

from channels.auth import AuthMiddlewareStack
from channels.routing import ProtocolTypeRouter, URLRouter
from django.core.asgi import get_asgi_application
from django.contrib.staticfiles.handlers import ASGIStaticFilesHandler

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "core.settings")

django_asgi_app = ASGIStaticFilesHandler(get_asgi_application())

try:
    from . import routing as core_routing
except Exception:  # pragma: no cover
    core_routing = None

# Import JWT middleware after Django apps are loaded
from .auth import JWTAuthMiddlewareStack  # noqa: E402

application = ProtocolTypeRouter({
    "http": django_asgi_app,
    "websocket": JWTAuthMiddlewareStack(
        AuthMiddlewareStack(
            URLRouter(core_routing.websocket_urlpatterns if core_routing else [])
        )
    ),
})


# Start MQTT bridge on ASGI import (idempotent)
try:  # pragma: no cover
    from apps.devices.mqtt_worker import start_bridge_if_enabled  # type: ignore
    start_bridge_if_enabled()
except Exception:
    pass


