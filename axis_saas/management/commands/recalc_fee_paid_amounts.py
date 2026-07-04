from django.core.management.base import BaseCommand
from django_tenants.utils import schema_context
from axis_saas.models import SchoolClient, FeeRecord
from decimal import Decimal

class Command(BaseCommand):
    help = 'Recalculate FeeRecord.paid_amount from linked payments'

    def add_arguments(self, parser):
        parser.add_argument('--schema', type=str, help='Tenant schema name (optional, runs all if not provided)')
        parser.add_argument('--dry-run', action='store_true', help='Show changes without applying')

    def handle(self, *args, **options):
        schema = options.get('schema')
        dry_run = options.get('dry_run', False)
        tenants = SchoolClient.objects.filter(is_active=True).exclude(schema_name='public')
        if schema:
            tenants = tenants.filter(schema_name=schema)

        for tenant in tenants:
            self.stdout.write(f"Processing {tenant.schema_name}...")
            with schema_context(tenant.schema_name):
                fee_records = FeeRecord.objects.all()
                updated = 0
                for fr in fee_records:
                    total_paid = sum(p.amount for p in fr.payments.all())
                    if fr.paid_amount != total_paid:
                        if dry_run:
                            self.stdout.write(f"  Would update {fr.student.name} {fr.month}/{fr.year}: paid {fr.paid_amount} -> {total_paid}")
                        else:
                            fr.paid_amount = total_paid
                            fr.save(update_fields=['paid_amount'])
                            self.stdout.write(f"  Updated {fr.student.name} {fr.month}/{fr.year}: {fr.paid_amount}")
                        updated += 1
                self.stdout.write(self.style.SUCCESS(f"Updated {updated} fee records in {tenant.schema_name}"))
