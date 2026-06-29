from django.core.management.base import BaseCommand
from django_tenants.utils import schema_context
from axis_saas.models import SchoolClient, SchoolFeeSettings, Student, FeeRecord, FeeStructure
from datetime import date, timedelta
from decimal import Decimal

class Command(BaseCommand):
    help = 'Automatically generate monthly fees for tenants with automation enabled'

    def handle(self, *args, **options):
        tenants = SchoolClient.objects.filter(is_active=True).exclude(schema_name='public')
        today = date.today()
        generated_total = 0

        for tenant in tenants:
            with schema_context(tenant.schema_name):
                settings, _ = SchoolFeeSettings.objects.get_or_create(pk=1)

                if not settings.automation_enabled:
                    continue

                if today.day != settings.fee_generation_day:
                    continue

                month, year = today.month, today.year
                due_date = today + timedelta(days=settings.due_date_offset)
                students = Student.objects.filter(status='active')
                created = 0
                skipped_existing = 0
                skipped_no_fee = 0

                # Convert extra charges to Decimal safely
                extra_charges = settings.default_extra_charges or []
                total_extra = sum(
                    (Decimal(str(ch.get('amount', 0))) for ch in extra_charges),
                    Decimal('0')
                )

                for s in students:
                    if FeeRecord.objects.filter(student=s, month=month, year=year).exists():
                        skipped_existing += 1
                        continue

                    base_fee = s.custom_fee if s.custom_fee > 0 else Decimal('0')
                    if base_fee == 0:
                        fee_struct = FeeStructure.objects.filter(grade=s.grade).first()
                        if fee_struct:
                            base_fee = fee_struct.monthly_fee
                            s.custom_fee = base_fee
                            s.save(update_fields=['custom_fee'])

                    if base_fee > 0:
                        total_fee = base_fee  # extra charges stored separately in extra_charges field
                        FeeRecord.objects.create(
                            student=s,
                            month=month,
                            year=year,
                            amount=total_fee,
                            due_date=due_date,
                            status='pending',
                            extra_charges=extra_charges,
                            due_date_offset=settings.due_date_offset,
                            late_fee_per_day=settings.late_fee_penalty
                        )
                        created += 1
                    else:
                        skipped_no_fee += 1

                if created > 0 or skipped_existing > 0 or skipped_no_fee > 0:
                    self.stdout.write(
                        f"{tenant.schema_name}: generated {created}, "
                        f"already had fee: {skipped_existing}, "
                        f"skipped (no fee structure): {skipped_no_fee} for {month}/{year}"
                    )

                generated_total += created

        self.stdout.write(self.style.SUCCESS(f"Total fees generated: {generated_total}"))
