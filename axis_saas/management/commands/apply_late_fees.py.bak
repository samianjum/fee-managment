from django.core.management.base import BaseCommand
from django_tenants.utils import schema_context
from axis_saas.models import SchoolClient, FeeRecord
from datetime import date, timedelta
from decimal import Decimal

class Command(BaseCommand):
    help = 'Apply late fees to overdue fee records'

    def handle(self, *args, **options):
        tenants = SchoolClient.objects.filter(is_active=True).exclude(schema_name='public')
        today = date.today()
        total_updated = 0

        for tenant in tenants:
            with schema_context(tenant.schema_name):
                overdue_records = FeeRecord.objects.filter(
                    due_date__lt=today,
                    status__in=['pending', 'partial', 'overdue']
                )
                for record in overdue_records:
                    if record.last_late_fee_application == today:
                        continue
                    days = (today - record.due_date).days
                    if days <= 0:
                        continue
                    # Add late fee per day
                    record.late_fee_amount += record.late_fee_per_day * days
                    record.last_late_fee_application = today
                    record.save(update_fields=['late_fee_amount', 'last_late_fee_application'])
                    total_updated += 1
        self.stdout.write(self.style.SUCCESS(f"Applied late fees to {total_updated} records."))
