from django.db import migrations, models
import django.db.models.deletion
from django.conf import settings


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='Gateway',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('gateway_id', models.CharField(max_length=64, unique=True)),
                ('name', models.CharField(blank=True, max_length=128)),
                ('last_seen', models.DateTimeField(blank=True, null=True)),
                ('owner', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='gateways', to=settings.AUTH_USER_MODEL)),
            ],
        ),
        migrations.CreateModel(
            name='Device',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('device_id', models.CharField(max_length=64)),
                ('type', models.CharField(help_text='sensor|actuator|camera', max_length=64)),
                ('model', models.CharField(blank=True, max_length=128)),
                ('name', models.CharField(blank=True, max_length=128)),
                ('is_online', models.BooleanField(default=False)),
                ('gateway', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='devices', to='devices.gateway')),
            ],
            options={
                'unique_together': {('gateway', 'device_id')},
            },
        ),
        migrations.CreateModel(
            name='Telemetry',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('timestamp', models.DateTimeField(auto_now_add=True)),
                ('payload', models.JSONField()),
                ('device', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='telemetry', to='devices.device')),
            ],
        ),
        migrations.AddIndex(
            model_name='telemetry',
            index=models.Index(fields=['timestamp'], name='devices_tel_timesta_123abc'),
        ),
    ]


