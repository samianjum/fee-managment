#!/usr/bin/env python3
"""
AXIS Fee Automation Scanner (Fixed)
Run: python3 g.py
"""
import os
import sys
import django
from datetime import date

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'axis_saas.settings')
django.setup()

from django_tenants.utils import schema_context
from axis_saas.models import SchoolClient, Student, FeeStructure, SchoolFeeSettings, FeeRecord
from subprocess import check_output, CalledProcessError

def check_cron_job():
    try:
        output = check_output("crontab -l", shell=True, text=True)
        if "auto_generate_fees" in output:
            print("✅ Cron job found:")
            for line in output.splitlines():
                if "auto_generate_fees" in line:
                    print(f"   {line}")
            return True
        else:
            print("❌ Cron job NOT found.")
            return False
    except CalledProcessError:
        print("❌ No crontab or error reading.")
        return False

def check_tenant(tenant):
    print(f"\n🔍 Tenant: {tenant.schema_name}")
    with schema_context(tenant.schema_name):
        settings = SchoolFeeSettings.objects.get(pk=1)
        print(f"   Automation: {'✅' if settings.automation_enabled else '❌'}")
        print(f"   Gen day: {settings.fee_generation_day}")
        print(f"   Today: {date.today().day}")
        if date.today().day == settings.fee_generation_day:
            print("   ✅ Today matches gen day.")
        else:
            print("   ❌ Today does NOT match.")

        students = Student.objects.filter(status='active')
        print(f"   Active students: {students.count()}")
        with_fee = 0
        for s in students:
            if s.custom_fee > 0:
                with_fee += 1
            else:
                fs = FeeStructure.objects.filter(grade=s.grade).first()
                if fs:
                    with_fee += 1
        print(f"   Students with fee: {with_fee}")

        today = date.today()
        existing = FeeRecord.objects.filter(month=today.month, year=today.year).count()
        print(f"   Existing fee records for {today.month}/{today.year}: {existing}")

def main():
    print("="*60)
    print("AXIS FEE AUTOMATION SCANNER")
    print("="*60)
    cron_ok = check_cron_job()

    tenants = SchoolClient.objects.filter(is_active=True).exclude(schema_name='public')
    if not tenants:
        print("❌ No tenants.")
        return
    for tenant in tenants:
        check_tenant(tenant)

    log_file = "/var/log/fee_auto.log"
    if os.path.exists(log_file):
        print(f"\n📌 Log ({log_file}):")
        with open(log_file, 'r') as f:
            for line in f.readlines()[-5:]:
                print(f"   {line.strip()}")
    else:
        print(f"\n⚠️ Log file not found yet. Cron hasn't run.")

    print("\n📌 RECOMMENDATIONS:")
    if not cron_ok:
        print("   - Add cron: crontab -e")
        print("     0 0 * * * cd /home/sami/axis_school_sys && /home/sami/axis_school_sys/venv/bin/python manage.py auto_generate_fees >> /var/log/fee_auto.log 2>&1")
    else:
        print("   ✅ Cron is set. Wait for next scheduled run (midnight).")
    print("   - To test cron: set date to 1st, restart cron, wait 1 min, check log.")
    print("   - Or just wait for real 1st July.")

if __name__ == '__main__':
    main()
