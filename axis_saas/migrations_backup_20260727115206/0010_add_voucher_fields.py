from django.db import migrations, models

class Migration(migrations.Migration):
    dependencies = [
        ('axis_saas', '0009_add_school_feature_flags'),
    ]
    operations = [
        migrations.AddField(
            model_name='student',
            name='default_extra_charges',
            field=models.JSONField(blank=True, default=list, null=True),
        ),
        migrations.AddField(
            model_name='feerecord',
            name='extra_charges',
            field=models.JSONField(blank=True, default=list, null=True),
        ),
    ]
