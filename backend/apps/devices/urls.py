from rest_framework.routers import DefaultRouter

from .views import DeviceViewSet, GatewayViewSet, TelemetryViewSet

router = DefaultRouter()
router.register(r"gateways", GatewayViewSet, basename="gateway")
router.register(r"devices", DeviceViewSet, basename="device")
router.register(r"telemetry", TelemetryViewSet, basename="telemetry")

urlpatterns = router.urls


