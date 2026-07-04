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
                    days = (today - record.due_date).days
                    if days <= 0:
                        continue
                    # Calculate late fee for the days since due date (only new days)
                    # We track only total accrued; we could add per day, but we'll just recompute from due_date
                    # This simplistic approach adds full late fee each time; better to track last applied.
                    # Since we don't have last_applied, we'll add for all days (idempotent if we only run once)
                    # But to be safe, we'll only add if not already applied for today (we don't have field)
                    # We'll just add for all overdue days. If run daily, it will add daily penalty each day.
                    # To avoid double counting, we need a last_applied date. We'll add it in a future patch.
                    # For now, we'll compute late fee for all overdue days and set it.
                    # But that would be wrong if run multiple times.
                    # We'll set late_fee_accrued = days * record.late_fee_per_day
                    # This overwrites any previous accrued.
                    record.late_fee_accrued = Decimal(days) * record.late_fee_per_day
                    record.save(update_fields=['late_fee_accrued'])
                    total_updated += 1
        self.stdout.write(self.style.SUCCESS(f"Applied late fees to {total_updated} records."))
