from django.shortcuts import render
from django.contrib.admin.views.decorators import staff_member_required
from django.utils import timezone
from django.db.models import Count, Q
from datetime import timedelta
from .models import Gateway, Device, Telemetry


@staff_member_required
def iot_dashboard(request):
    """Custom IoT dashboard with statistics and charts"""
    now = timezone.now()
    
    # Gateway statistics
    total_gateways = Gateway.objects.count()
    online_gateways = Gateway.objects.filter(
        last_seen__gte=now - timedelta(minutes=5)
    ).count()
    
    # Device statistics
    total_devices = Device.objects.count()
    online_devices = Device.objects.filter(is_online=True).count()
    devices_by_type = Device.objects.values('type').annotate(count=Count('id'))
    
    # Telemetry statistics
    recent_telemetry = Telemetry.objects.filter(
        timestamp__gte=now - timedelta(hours=24)
    ).count()
    
    # Recent activity  
    recent_devices = Device.objects.order_by('-id')[:5]
    recent_telemetry_data = Telemetry.objects.select_related('device', 'device__gateway').order_by('-timestamp')[:10]
    
    # Gateway with device counts
    gateways_with_counts = Gateway.objects.annotate(
        device_count=Count('devices')
    ).order_by('-device_count')
    
    context = {
        'title': 'IoT Dashboard',
        'total_gateways': total_gateways,
        'online_gateways': online_gateways,
        'offline_gateways': total_gateways - online_gateways,
        'total_devices': total_devices,
        'online_devices': online_devices,
        'offline_devices': total_devices - online_devices,
        'devices_by_type': devices_by_type,
        'recent_telemetry_count': recent_telemetry,
        'recent_devices': recent_devices,
        'recent_telemetry_data': recent_telemetry_data,
        'gateways_with_counts': gateways_with_counts,
    }
    
    return render(request, 'admin/iot_dashboard.html', context)
