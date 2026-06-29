#!/usr/bin/env python3
"""
Zero‑change migration scanner – reports current migration files and applied state.
Run: python3 migration_scanner.py
"""

import os
import re
import sys
import django
from django.db import connection
from django_tenants.utils import schema_context
from axis_saas.models import SchoolClient

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'axis_saas.settings')
django.setup()

MIGRATIONS_DIR = "axis_saas/migrations"
IGNORE_FILES = {'__init__.py', '__pycache__'}

def get_migration_files():
    """Return list of migration filenames (without .py)."""
    files = []
    for f in os.listdir(MIGRATIONS_DIR):
        if f.endswith('.py') and f not in IGNORE_FILES:
            files.append(f[:-3])  # remove .py
    return sorted(files)

def parse_dependencies(migration_file):
    """Parse the dependencies list from a migration file."""
    path = os.path.join(MIGRATIONS_DIR, migration_file + '.py')
    with open(path, 'r') as f:
        content = f.read()
    # Find dependencies = [ ... ]
    match = re.search(r'dependencies\s*=\s*\[(.*?)\]', content, re.DOTALL)
    if not match:
        return []
    deps_block = match.group(1)
    # Extract tuples like ('axis_saas', '0016')
    deps = re.findall(r"\(\s*['\"]([^'\"]+)['\"]\s*,\s*['\"]([^'\"]+)['\"]\s*\)", deps_block)
    return deps

def get_applied_migrations(schema_name='public'):
    """Get list of applied migration names for a schema."""
    with schema_context(schema_name):
        with connection.cursor() as cur:
            cur.execute("SELECT app, name FROM django_migrations WHERE app='axis_saas'")
            rows = cur.fetchall()
            return [row[1] for row in rows]

def get_all_tenant_schemas():
    """Return list of all tenant schema names (non‑public, non‑system)."""
    with schema_context('public'):
        tenants = SchoolClient.objects.exclude(schema_name='public').values_list('schema_name', flat=True)
        return list(tenants)

def main():
    print("=" * 70)
    print("AXIS MIGRATION SCANNER – Zero changes, only diagnostic")
    print("=" * 70)

    # 1. List migration files
    files = get_migration_files()
    print(f"\n📁 Migration files in {MIGRATIONS_DIR}:")
    for f in files:
        print(f"   - {f}")

    # 2. Parse dependencies for each file
    print("\n🔗 Dependencies per file:")
    for f in files:
        deps = parse_dependencies(f)
        if deps:
            dep_str = ", ".join([f"('{app}', '{name}')" for app, name in deps])
            print(f"   {f} -> [{dep_str}]")
        else:
            print(f"   {f} -> (no dependencies)")

    # 3. Check applied migrations in public schema
    applied_public = get_applied_migrations('public')
    print(f"\n✅ Applied migrations in public schema: {len(applied_public)}")
    for m in applied_public:
        print(f"   - {m}")

    # 4. Which files are not applied in public?
    missing_in_public = [f for f in files if f not in applied_public]
    if missing_in_public:
        print(f"\n⚠️  Not applied in public schema: {missing_in_public}")
    else:
        print("\n✅ All migration files are applied in public schema.")

    # 5. Check tenant schemas (first 5 only to avoid spam)
    tenants = get_all_tenant_schemas()
    print(f"\n🏫 Tenant schemas found: {len(tenants)}")
    if tenants:
        for schema in tenants[:5]:
            applied = get_applied_migrations(schema)
            missing = [f for f in files if f not in applied]
            print(f"   Schema '{schema}': {len(applied)} applied, missing: {missing if missing else 'none'}")
        if len(tenants) > 5:
            print(f"   ... and {len(tenants)-5} more (use full scan if needed)")

    # 6. Consistency check: for each migration file, ensure its dependencies exist in files
    print("\n🧩 Dependency existence check (file‑level):")
    all_files_set = set(files)
    for f in files:
        deps = parse_dependencies(f)
        for app, name in deps:
            if app != 'axis_saas':
                continue  # ignore cross‑app deps (like admin, auth)
            if name not in all_files_set:
                print(f"   ❌ {f} depends on {name} but file {name}.py is missing!")
            else:
                print(f"   ✅ {f} -> {name} exists")

    # 7. Check if any applied migration is not in files (orphan)
    orphan_public = [m for m in applied_public if m not in all_files_set]
    if orphan_public:
        print(f"\n⚠️  Orphan migrations in public schema (applied but file missing): {orphan_public}")
    else:
        print("\n✅ No orphan migrations in public schema.")

    print("\n" + "=" * 70)
    print("Scan complete. No changes were made.")
    print("If you see missing dependencies, you may need to adjust migration files or fake migrations.")
    print("=" * 70)

if __name__ == "__main__":
    main()
