from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ('devices', '0002_rename_devices_tel_timesta_123abc_devices_tel_timesta_bd8d1b_idx'),
    ]

    operations = [
        migrations.CreateModel(
            name='DeviceModelDefinition',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('model_id', models.CharField(max_length=128, unique=True)),
                ('name', models.CharField(max_length=128)),
                ('version', models.CharField(blank=True, max_length=32)),
                ('schema', models.JSONField(default=dict)),
            ],
        ),
        migrations.AddField(
            model_name='device',
            name='model_definition',
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, to='devices.devicemodeldefinition'),
        ),
    ]


