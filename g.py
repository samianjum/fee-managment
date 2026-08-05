#!/usr/bin/env python3
"""
AXIS – Restore Redirect to Student List After Adding Student
-----------------------------------------------------------
Changes redirect from profile to list so that the pre‑caching
script runs and automatically caches the new student's profile.
"""

import os
import re
import shutil
from pathlib import Path

VIEWS_FILE = Path("axis_saas/views_school.py")
BACKUP_SUFFIX = ".redirect_backup"

def patch_redirects():
    if not VIEWS_FILE.exists():
        print(f"❌ Error: {VIEWS_FILE} not found.")
        print("   Run this script from the project root.")
        return False

    # Backup
    backup_path = VIEWS_FILE.with_suffix(VIEWS_FILE.suffix + BACKUP_SUFFIX)
    shutil.copy2(VIEWS_FILE, backup_path)
    print(f"✅ Backup created: {backup_path}")

    with open(VIEWS_FILE, "r") as f:
        content = f.read()

    # ---- Replace add_student redirect ----
    pattern_add = r'(return redirect\("student_profile",\s*schema_name=schema_name,\s*student_id=student\.id\))'
    replacement_add = r'return redirect("student_list", schema_name=schema_name)'
    new_content, count_add = re.subn(pattern_add, replacement_add, content)

    if count_add == 0:
        print("⚠️  Could not find redirect to student_profile in add_student. Already patched or different?")
    else:
        print(f"✅ add_student: replaced redirect (found {count_add} occurrence).")

    # ---- Replace add_student_mobile redirect ----
    pattern_mobile = r'(return redirect\("mobile_student_profile",\s*schema_name=schema_name,\s*student_id=student\.id\))'
    replacement_mobile = r'return redirect("mobile_student_list", schema_name=schema_name)'
    new_content, count_mobile = re.subn(pattern_mobile, replacement_mobile, new_content)

    if count_mobile == 0:
        print("⚠️  Could not find redirect to mobile_student_profile in add_student_mobile.")
    else:
        print(f"✅ add_student_mobile: replaced redirect (found {count_mobile} occurrence).")

    if count_add == 0 and count_mobile == 0:
        print("❌ No changes were made. The file may already be patched.")
        return False

    # Write updated content
    with open(VIEWS_FILE, "w") as f:
        f.write(new_content)

    print(f"✅ {VIEWS_FILE} updated successfully.")
    return True

if __name__ == "__main__":
    print("🚀 AXIS – Redirect to Student List Patcher")
    print("   This script restores the redirect to student list after adding a student.")
    success = patch_redirects()
    if success:
        print("\n✅ Done! Restart your server and clear browser cache.")
        print("   Now, after adding a student, you'll be redirected to the student list.")
        print("   The pre‑caching script will run and cache the new student's profile automatically.")
        print("   No manual visits are required – all profiles are cached in the background.")
    else:
        print("\n❌ Patching failed. Check the file paths and try again.")
