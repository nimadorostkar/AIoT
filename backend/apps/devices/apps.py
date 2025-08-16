from django.apps import AppConfig


class DevicesConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.devices"
    label = "devices"

    def ready(self):  # pragma: no cover
        from . import signals  # noqa: F401


