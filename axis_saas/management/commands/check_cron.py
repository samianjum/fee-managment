from django.core.management.base import BaseCommand
from django_tenants.utils import schema_context
from axis_saas.models import SchoolClient, SchoolFeeSettings
from datetime import date

class Command(BaseCommand):
    help = 'Check the status of fee automation cron job'

    def handle(self, *args, **options):
        tenants = SchoolClient.objects.filter(is_active=True).exclude(schema_name='public')
        today = date.today()
        self.stdout.write(f"Today: {today.isoformat()}")
        self.stdout.write("=" * 50)
        found_enabled = False

        for tenant in tenants:
            with schema_context(tenant.schema_name):
                settings, _ = SchoolFeeSettings.objects.get_or_create(pk=1)
                enabled = settings.automation_enabled
                gen_day = settings.fee_generation_day
                status = "✅" if enabled else "❌"
                matches = "✅" if enabled and today.day == gen_day else " "
                self.stdout.write(
                    f"{status} {tenant.schema_name:20} | Automation: {'ON' if enabled else 'OFF':4} | "
                    f"Gen day: {gen_day:2} | Today matches: {matches}"
                )
                if enabled:
                    found_enabled = True

        if not found_enabled:
            self.stdout.write(self.style.WARNING("No tenant has automation enabled."))
        else:
            self.stdout.write(self.style.SUCCESS("Automation is enabled for at least one tenant."))
            self.stdout.write("To test actual generation, run: python manage.py auto_generate_fees")
