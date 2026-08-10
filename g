#!/usr/bin/env python3
"""
AXIS Fix Migration Duplicate Column
Run once to resolve migration conflicts on Railway.
"""

import os
import sys

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'axis_saas.settings')
sys.path.append(os.getcwd())

import django
django.setup()

from django.db import connection
from django_tenants.utils import schema_context
from axis_saas.models import SchoolClient
from django.db.migrations.recorder import MigrationRecorder

# List of migrations to fix (app_label, migration_name, column_name)
MIGRATIONS = [
    ('axis_saas', '0015_feerecord_due_date_offset', 'due_date_offset'),
    ('axis_saas', '0016_feerecord_late_fee_per_day', 'late_fee_per_day'),
]

def fix_schema(schema_name):
    """Apply fixes for a single schema."""
    print(f"Processing schema: {schema_name}")
    with schema_context(schema_name):
        recorder = MigrationRecorder(connection)
        with connection.cursor() as cursor:
            for app_label, migration_name, column in MIGRATIONS:
                # Check if column already exists
                cursor.execute("""
                    SELECT column_name FROM information_schema.columns
                    WHERE table_name = 'axis_saas_feerecord' AND column_name = %s
                """, [column])
                exists = cursor.fetchone() is not None

                if exists:
                    # Column already present → just mark migration as applied
                    if not recorder.migration_qs.filter(app=app_label, name=migration_name).exists():
                        recorder.record_applied(app_label, migration_name)
                        print(f"  ✅ Recorded {migration_name} as applied (column already exists)")
                    else:
                        print(f"  ℹ️ {migration_name} already recorded")
                else:
                    # Column missing → add it with default, then record
                    if column == 'due_date_offset':
                        sql = "ALTER TABLE axis_saas_feerecord ADD COLUMN due_date_offset integer DEFAULT 15 NOT NULL"
                    elif column == 'late_fee_per_day':
                        sql = "ALTER TABLE axis_saas_feerecord ADD COLUMN late_fee_per_day numeric(6,2) DEFAULT 0.00 NOT NULL"
                    else:
                        continue

                    cursor.execute(sql)
                    print(f"  ➕ Added column {column} (schema {schema_name})")

                    # Record migration as applied
                    recorder.record_applied(app_label, migration_name)
                    print(f"  ✅ Recorded {migration_name} as applied")

def main():
    print("🚀 AXIS Migration Fixer")
    print("This script will fix duplicate column issues for migrations 0015 and 0016.\n")

    # Get list of all schemas: public + all tenants
    schemas = ['public']
    try:
        tenants = SchoolClient.objects.values_list('schema_name', flat=True)
        schemas.extend(list(tenants))
    except Exception as e:
        print(f"⚠️ Could not fetch tenant list: {e}")
        print("   Will only process public schema.")

    for schema in schemas:
        try:
            fix_schema(schema)
        except Exception as e:
            print(f"❌ Error processing schema {schema}: {e}")

    print("\n✅ All fixes applied.")
    print("Now restart your server (or let Railway redeploy) and the dashboard should work.")

if __name__ == '__main__':
    main()
