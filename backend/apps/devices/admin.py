from django.contrib import admin
from django.utils.html import format_html
from django.utils.safestring import mark_safe
from .models import Gateway, Device, Telemetry, DeviceModelDefinition
import json


@admin.register(Gateway)
class GatewayAdmin(admin.ModelAdmin):
    list_display = ['gateway_id', 'name', 'owner', 'status_indicator', 'last_seen', 'device_count']
    list_filter = ['last_seen', 'owner']
    search_fields = ['gateway_id', 'name', 'owner__username']
    
    def status_indicator(self, obj):
        if obj.last_seen:
            # If last seen within 5 minutes, consider online
            from django.utils import timezone
            from datetime import timedelta
            is_online = obj.last_seen > timezone.now() - timedelta(minutes=5)
            color = 'green' if is_online else 'orange'
            status = 'Online' if is_online else 'Offline'
            return format_html(
                '<span style="color: {}; font-weight: bold;">● {}</span>',
                color, status
            )
        return format_html('<span style="color: red; font-weight: bold;">● Never Connected</span>')
    status_indicator.short_description = 'Status'
    
    def device_count(self, obj):
        count = obj.devices.count()
        return format_html('<strong>{}</strong>', count)
    device_count.short_description = 'Devices'


@admin.register(Device)
class DeviceAdmin(admin.ModelAdmin):
    list_display = ['device_id', 'name', 'type', 'model', 'gateway_link', 'status_indicator', 'last_telemetry']
    list_filter = ['type', 'model', 'is_online', 'gateway']
    search_fields = ['device_id', 'name', 'type', 'model', 'gateway__gateway_id']
    
    def gateway_link(self, obj):
        if obj.gateway:
            return format_html(
                '<a href="/admin/devices/gateway/{}/change/">{}</a>',
                obj.gateway.id, obj.gateway.name or obj.gateway.gateway_id
            )
        return '-'
    gateway_link.short_description = 'Gateway'
    
    def status_indicator(self, obj):
        color = 'green' if obj.is_online else 'red'
        status = 'Online' if obj.is_online else 'Offline'
        return format_html(
            '<span style="color: {}; font-weight: bold;">● {}</span>',
            color, status
        )
    status_indicator.short_description = 'Status'
    
    def last_telemetry(self, obj):
        telemetry = obj.telemetry.order_by('-timestamp').first()
        if telemetry:
            return telemetry.timestamp.strftime('%Y-%m-%d %H:%M:%S')
        return 'No data'
    last_telemetry.short_description = 'Last Data'


@admin.register(Telemetry)
class TelemetryAdmin(admin.ModelAdmin):
    list_display = ['device_link', 'timestamp', 'payload_summary', 'gateway_info']
    list_filter = ['timestamp', 'device__type', 'device__gateway']
    search_fields = ['device__device_id', 'device__name', 'device__gateway__gateway_id']
    readonly_fields = ['timestamp', 'formatted_payload']
    date_hierarchy = 'timestamp'
    
    def device_link(self, obj):
        return format_html(
            '<a href="/admin/devices/device/{}/change/">{}</a>',
            obj.device.id, obj.device.name or obj.device.device_id
        )
    device_link.short_description = 'Device'
    
    def payload_summary(self, obj):
        if obj.payload:
            summary = []
            for key, value in obj.payload.items():
                if key != 'gateway_id':
                    if isinstance(value, (int, float)):
                        summary.append(f"{key}: {value}")
                    else:
                        summary.append(f"{key}: {str(value)[:20]}")
            return ', '.join(summary[:3])  # Show first 3 items
        return 'Empty'
    payload_summary.short_description = 'Data Summary'
    
    def gateway_info(self, obj):
        if obj.device.gateway:
            return obj.device.gateway.name or obj.device.gateway.gateway_id
        return '-'
    gateway_info.short_description = 'Gateway'
    
    def formatted_payload(self, obj):
        if obj.payload:
            formatted = json.dumps(obj.payload, indent=2)
            return format_html('<pre>{}</pre>', formatted)
        return 'No payload data'
    formatted_payload.short_description = 'Full Payload'


@admin.register(DeviceModelDefinition)
class DeviceModelDefinitionAdmin(admin.ModelAdmin):
    list_display = ['model_id', 'name', 'version', 'device_count']
    search_fields = ['model_id', 'name']
    readonly_fields = ['formatted_schema']
    
    def device_count(self, obj):
        count = obj.devices.count()
        return format_html('<strong>{}</strong>', count)
    device_count.short_description = 'Devices Using'
    
    def formatted_schema(self, obj):
        if obj.model_schema:
            formatted = json.dumps(obj.model_schema, indent=2)
            return format_html('<pre>{}</pre>', formatted)
        return 'No schema defined'
    formatted_schema.short_description = 'Model Schema'


# Custom admin site configuration
admin.site.site_header = "IoT Smart System Administration"
admin.site.site_title = "IoT Admin"
admin.site.index_title = "IoT Smart System Dashboard"
