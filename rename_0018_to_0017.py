#!/usr/bin/env python3
"""
Rename 0018 migration to 0017 (since 0017 was removed) and run migrate.
"""

import os
import shutil
import subprocess
import sys

MIGRATIONS_DIR = "axis_saas/migrations"
OLD_FILE = os.path.join(MIGRATIONS_DIR, "0018_add_late_fee_fields.py")
NEW_FILE = os.path.join(MIGRATIONS_DIR, "0017_add_late_fee_fields.py")

def main():
    print("🔄 Renaming 0018 to 0017...")
    if not os.path.exists(OLD_FILE):
        print("⚠️  0018 file not found. Nothing to do.")
        sys.exit(0)

    # Rename
    shutil.move(OLD_FILE, NEW_FILE)
    print(f"✅ Renamed {OLD_FILE} -> {NEW_FILE}")

    # Run migrate
    print("🔄 Running `python manage.py migrate`...")
    result = subprocess.run([sys.executable, "manage.py", "migrate"])
    if result.returncode != 0:
        print("❌ Migrate failed. Please check the error manually.")
        sys.exit(1)

    print("\n🎯 All migrations applied successfully! Ab `python manage.py runserver` chala sakte hain.")

if __name__ == "__main__":
    main()
