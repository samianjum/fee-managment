from django.core.management.base import BaseCommand
from axis_saas.models import SchoolClient
from django_tenants.utils import schema_context

class Command(BaseCommand):
    help = 'Add staff_management feature to all existing tenants'

    def handle(self, *args, **options):
        tenants = SchoolClient.objects.exclude(schema_name='public')
        updated = 0
        for tenant in tenants:
            with schema_context('public'):
                # Check if feature already enabled
                if 'staff_management' not in (tenant.enabled_features or []):
                    tenant.enabled_features = list(set(tenant.enabled_features or [] + ['staff_management']))
                    tenant.save(update_fields=['enabled_features'])
                    updated += 1
                    self.stdout.write(f"✅ Added staff_management to {tenant.schema_name}")
                else:
                    self.stdout.write(f"⏩ {tenant.schema_name} already has staff_management")
        self.stdout.write(self.style.SUCCESS(f"Done! Updated {updated} tenants."))
