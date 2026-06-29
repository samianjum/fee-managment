#!/usr/bin/env python3
import os
import re
import sys

MIGRATION_FILE = "axis_saas/migrations/0017_feerecord_due_date_offset_feerecord_late_fee_per_day_and_more.py"

def patch_migration():
    if not os.path.exists(MIGRATION_FILE):
        print(f"❌ Migration file not found: {MIGRATION_FILE}")
        sys.exit(1)

    with open(MIGRATION_FILE, "r") as f:
        content = f.read()

    # Check if already patched (look for RunSQL)
    if "RunSQL" in content and "ADD COLUMN IF NOT EXISTS" in content:
        print("✅ Migration already patched. Skipping.")
        return True

    # Replace AddField operations with RunSQL
    # We'll define a replacement pattern for AddField for SchoolFeeSettings and Student
    new_ops = """
    operations = [
        migrations.RunSQL(
            sql="ALTER TABLE axis_saas_schoolfeesettings ADD COLUMN IF NOT EXISTS automation_enabled boolean DEFAULT false NOT NULL;",
            reverse_sql="ALTER TABLE axis_saas_schoolfeesettings DROP COLUMN IF EXISTS automation_enabled;"
        ),
        migrations.RunSQL(
            sql="ALTER TABLE axis_saas_student ADD COLUMN IF NOT EXISTS automation_enabled boolean DEFAULT false NOT NULL;",
            reverse_sql="ALTER TABLE axis_saas_student DROP COLUMN IF EXISTS automation_enabled;"
        ),
    ]
    """

    # Find the operations list and replace it
    # We'll use regex to locate the operations assignment
    pattern = r"operations\s*=\s*\[[\s\S]*?\]"
    match = re.search(pattern, content)
    if not match:
        print("❌ Could not find 'operations = [...]' in migration file.")
        sys.exit(1)

    new_content = content[:match.start()] + new_ops + content[match.end():]

    with open(MIGRATION_FILE, "w") as f:
        f.write(new_content)

    print(f"✅ Patched {MIGRATION_FILE} to use IF NOT EXISTS.")
    return True

def main():
    print("🔄 Patching migration to handle duplicate column error...")
    if patch_migration():
        print("\n🔄 Running migrate to apply to all tenants...")
        exit_code = os.system("python3 manage.py migrate")
        if exit_code != 0:
            print("❌ Migration failed. Please check the error output above.")
            sys.exit(1)
        print("✅ Migration completed successfully.")
        print("\n🎉 You can now run: python3 manage.py runserver")
    else:
        print("❌ Patching failed.")
        sys.exit(1)

if __name__ == "__main__":
    main()
