#!/usr/bin/env python3
"""
AXIS School System – Tenant Schema Patcher
Fixes missing columns in all tenant schemas to match the current models.
Run this once after pulling new migrations.
"""

import os
import sys
import django

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'axis_saas.settings')
django.setup()

from django.db import connection
from django_tenants.utils import schema_context
from axis_saas.models import SchoolClient

# List of columns to check and add if missing
# Format: (table_name, column_name, data_type, default_value, nullable)
COLUMNS_TO_ADD = [
    # Student table
    ('axis_saas_student', 'automation_enabled', 'boolean', 'False', False),
    ('axis_saas_student', 'default_extra_charges', 'jsonb', '[]', True),

    # FeeRecord table
    ('axis_saas_feerecord', 'extra_charges', 'jsonb', '[]', True),
    ('axis_saas_feerecord', 'due_date_offset', 'integer', '15', False),
    ('axis_saas_feerecord', 'late_fee_per_day', 'numeric(6,2)', '0.00', False),

    # SchoolFeeSettings table (only one row per schema)
    ('axis_saas_schoolfeesettings', 'default_extra_charges', 'jsonb', '[]', True),
    ('axis_saas_schoolfeesettings', 'automation_enabled', 'boolean', 'False', False),
]

def column_exists(schema, table, column):
    """Check if a column exists in the given schema and table."""
    with connection.cursor() as cursor:
        cursor.execute("""
            SELECT COUNT(*)
            FROM information_schema.columns
            WHERE table_schema = %s
              AND table_name = %s
              AND column_name = %s
        """, [schema, table, column])
        return cursor.fetchone()[0] > 0

def add_column(schema, table, column, data_type, default, nullable):
    """Add a column to the given table in the specified schema."""
    with connection.cursor() as cursor:
        # Build ALTER TABLE statement
        sql = f'ALTER TABLE "{table}" ADD COLUMN "{column}" {data_type}'
        if default is not None:
            # Handle special default values for JSON and boolean
            if data_type == 'jsonb':
                sql += f" DEFAULT '{default}'::jsonb"
            elif data_type == 'boolean':
                sql += f" DEFAULT {default}"
            elif data_type.startswith('numeric'):
                sql += f" DEFAULT {default}"
            else:
                sql += f" DEFAULT {default}"
        if not nullable:
            sql += " NOT NULL"
        cursor.execute(sql)
        print(f"  ✅ Added column '{column}' to {schema}.{table}")

def patch_schema(schema_name):
    """Apply all missing columns for a single schema."""
    print(f"\n🔧 Processing schema: {schema_name}")
    with schema_context(schema_name):
        # Check and add each column
        for table, column, dtype, default, nullable in COLUMNS_TO_ADD:
            if not column_exists(schema_name, table, column):
                add_column(schema_name, table, column, dtype, default, nullable)
            else:
                print(f"  ✓ Column '{column}' already exists in {table}")

def main():
    print("=" * 60)
    print("AXIS SCHOOL SYSTEM – TENANT SCHEMA PATCHER")
    print("=" * 60)

    # Get all active tenants (exclude public)
    tenants = SchoolClient.objects.exclude(schema_name='public')
    if not tenants.exists():
        print("⚠️  No tenant schemas found. Nothing to patch.")
        return

    print(f"Found {tenants.count()} tenant(s).")
    for tenant in tenants:
        patch_schema(tenant.schema_name)

    print("\n" + "=" * 60)
    print("✅ Patching complete. All tenant schemas are now up-to-date.")
    print("   You can now restart the server and access the portal.")
    print("=" * 60)

if __name__ == "__main__":
    main()
