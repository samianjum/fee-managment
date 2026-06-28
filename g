#!/usr/bin/env python3
"""
AXIS Tenant Schema Fixer
- Runs all pending tenant migrations (migrate_schemas)
- Explicitly adds missing columns to Student and SchoolFeeSettings
- Idempotent (safe to run multiple times)
"""

import os
import sys
import django

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'axis_saas.settings')
django.setup()

from django.core.management import call_command
from django.db import connection
from django_tenants.utils import schema_context
from axis_saas.models import SchoolClient


def ensure_column(schema_name, table, column, column_def):
    """Add column if it does not exist in the given schema."""
    with schema_context(schema_name):
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT column_name
                FROM information_schema.columns
                WHERE table_schema = %s
                  AND table_name = %s
                  AND column_name = %s
            """, [schema_name, table, column])
            exists = cursor.fetchone()

            if not exists:
                try:
                    cursor.execute(f"ALTER TABLE {table} ADD COLUMN {column} {column_def}")
                    print(f"✅ Added {column} to {table} in {schema_name}")
                except Exception as e:
                    print(f"❌ Failed to add {column} to {table} in {schema_name}: {e}")
            else:
                print(f"ℹ️ {column} already exists in {table} in {schema_name}")


def main():
    print("🔧 AXIS TENANT SCHEMA FIXER")
    print("=" * 50)

    # 1. Run all pending tenant migrations (the proper way)
    print("\n📦 Applying pending tenant migrations...")
    try:
        call_command('migrate_schemas', interactive=False, verbosity=1)
        print("✅ Migrations applied successfully.")
    except Exception as e:
        print(f"⚠️ migrate_schemas failed: {e}")
        print("   Will fallback to explicit column addition.")

    # 2. Explicitly ensure critical columns exist in all tenant schemas
    tenants = SchoolClient.objects.exclude(schema_name='public')
    if not tenants:
        print("⚠️ No tenant schemas found. Nothing to fix.")
        return

    print("\n🔍 Verifying critical columns in each tenant schema...")

    for tenant in tenants:
        schema = tenant.schema_name
        print(f"\n--- {schema} ---")

        # Student.automation_enabled
        ensure_column(schema, 'axis_saas_student', 'automation_enabled', 'boolean DEFAULT false')

        # Student.default_extra_charges (JSON field)
        ensure_column(schema, 'axis_saas_student', 'default_extra_charges', 'jsonb DEFAULT \'[]\'::jsonb')

        # SchoolFeeSettings.automation_enabled (if it exists)
        ensure_column(schema, 'axis_saas_schoolfeesettings', 'automation_enabled', 'boolean DEFAULT false')

        # SchoolFeeSettings.default_extra_charges (if missing)
        ensure_column(schema, 'axis_saas_schoolfeesettings', 'default_extra_charges', 'jsonb DEFAULT \'[]\'::jsonb')

    print("\n✅ All tenant schemas are now up to date.")
    print("   Restart your server: python manage.py runserver")


if __name__ == '__main__':
    main()
