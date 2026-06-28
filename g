#!/usr/bin/env python3
"""
AXIS Auto-Fee Diagnostic Scanner
Run: python auto_fee_diagnostic.py
"""

import os
import sys
import django
from datetime import date, timedelta
from decimal import Decimal

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'axis_saas.settings')
django.setup()

from django.db import connection
from django_tenants.utils import schema_context
from axis_saas.models import SchoolClient, SchoolFeeSettings, FeeRecord, Student, FeeStructure

def run_diagnostic():
    print("=" * 80)
    print("AXIS AUTO-FEE DIAGNOSTIC SCANNER")
    print("=" * 80)

    today = date.today()
    print(f"\n📅 Server Date: {today.strftime('%A, %B %d, %Y')}")
    print(f"   Day of month: {today.day}")
    print(f"   Month: {today.month}, Year: {today.year}\n")

    # Get all active tenants (exclude public)
    tenants = SchoolClient.objects.filter(is_active=True).exclude(schema_name='public')
    if not tenants.exists():
        print("❌ No active tenants found.")
        return

    print(f"✅ Found {tenants.count()} active tenant(s).\n")

    for tenant in tenants:
        print(f"───── Tenant: {tenant.schema_name} ('{tenant.name}') ─────")
        with schema_context(tenant.schema_name):
            # 1. Fee Settings
            try:
                settings = SchoolFeeSettings.objects.get(pk=1)
                auto_enabled = settings.automation_enabled
                gen_day = settings.fee_generation_day
                offset = settings.due_date_offset
                late_fee = settings.late_fee_penalty
                extra_charges = settings.default_extra_charges or []
                total_extra = sum((ch.get('amount', 0) for ch in extra_charges), 0)
            except SchoolFeeSettings.DoesNotExist:
                print("   ❌ SchoolFeeSettings record missing! Creating default...")
                settings = SchoolFeeSettings.objects.create(pk=1)
                auto_enabled = False
                gen_day = 1
                offset = 15
                late_fee = Decimal('0')
                total_extra = Decimal('0')
                print("   ✅ Created default settings with automation disabled.")

            print(f"   ⚙️ Automation Enabled: {'✅ YES' if auto_enabled else '❌ NO'}")
            print(f"   📆 Generation Day: {gen_day}")
            print(f"   📅 Due Offset: {offset} days")
            print(f"   💰 Late Fee per day: ₹{late_fee}")
            print(f"   📦 Default Extra Charges: {len(extra_charges)} items, total ₹{total_extra}")

            # 2. Is today the generation day?
            matches = (today.day == gen_day)
            print(f"   🟢 Today matches generation day? {'✅ YES' if matches else '❌ NO'}")

            # 3. Check if any fee records already exist for this month
            existing_records = FeeRecord.objects.filter(month=today.month, year=today.year)
            existing_count = existing_records.count()
            print(f"   📋 Existing fee records for {today.month}/{today.year}: {existing_count}")

            # 4. Active students and fee structures
            active_students = Student.objects.filter(status='active')
            active_count = active_students.count()
            print(f"   👨‍🎓 Active students: {active_count}")

            if active_count > 0:
                students_with_fee = 0
                students_without_fee = 0
                for s in active_students:
                    base = s.custom_fee if s.custom_fee > 0 else 0
                    if base == 0:
                        fee_struct = FeeStructure.objects.filter(grade=s.grade).first()
                        if fee_struct:
                            base = fee_struct.monthly_fee
                    if base > 0:
                        students_with_fee += 1
                    else:
                        students_without_fee += 1
                print(f"      - With valid fee: {students_with_fee}")
                print(f"      - Without fee (will be skipped): {students_without_fee}")

            # 5. If automation is ON and today matches generation day but no records exist, we can attempt a dry-run simulation
            if auto_enabled and matches:
                if existing_count == 0:
                    print("   🚀 **Automation should run today!**")
                    print("      (But no records exist yet – cron job may not be set up)")
                else:
                    print("   ℹ️ Records already exist – automation would skip (no duplicate)")

            # 6. If automation is OFF, suggest enabling it
            if not auto_enabled:
                print("   ⚠️ Automation is DISABLED. To enable, visit Fee Settings and toggle ON.")

            # 7. Check if the management command exists (optional)
            # We'll just print a suggestion
            print("   💡 To test manually, run: python manage.py auto_generate_fees")

            # 8. Check cron (we can't check, but we'll remind)
            print("   🕒 Reminder: Ensure a cron job is set up to run the command daily.")
            print("   Example: 0 0 * * * cd /path/to/project && python manage.py auto_generate_fees >> /var/log/fee_auto.log 2>&1\n")

    # Additional summary
    print("=" * 80)
    print("🔎 DIAGNOSTIC SUMMARY:")
    print("   - If automation is ON and today matches generation day but no fees exist, the issue is most likely a missing cron job.")
    print("   - If automation is OFF, enable it and save.")
    print("   - If automation is ON but today is not generation day, wait until that day.")
    print("   - Check logs (if cron is set) for any errors.")
    print("   - You can always generate fees manually using the 'Generate All Fees' button in Fee Collection.")
    print("=" * 80)

if __name__ == "__main__":
    run_diagnostic()
