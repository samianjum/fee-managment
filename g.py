#!/usr/bin/env python3
"""
AXIS Student Offline Caching Patcher
------------------------------------
Modifies add_student and add_student_mobile views to redirect to the new
student's profile page. This forces the service worker to cache the profile
immediately after creation, making it available offline.
"""

import os
import re
import shutil
from pathlib import Path

VIEWS_FILE = Path("axis_saas/views_school.py")
BACKUP_SUFFIX = ".backup"

def patch_views():
    if not VIEWS_FILE.exists():
        print(f"❌ Error: {VIEWS_FILE} not found.")
        print("   Please run this script from the project root directory.")
        return False

    # Create a backup
    backup_path = VIEWS_FILE.with_suffix(VIEWS_FILE.suffix + BACKUP_SUFFIX)
    shutil.copy2(VIEWS_FILE, backup_path)
    print(f"✅ Backup created: {backup_path}")

    with open(VIEWS_FILE, "r") as f:
        content = f.read()

    # ----- Patch add_student -----
    # Find the redirect line in add_student
    pattern_add = r'(return redirect\("student_list",\s*schema_name=schema_name\))'
    replacement_add = r'return redirect("student_profile", schema_name=schema_name, student_id=student.id)'
    new_content, count_add = re.subn(pattern_add, replacement_add, content)

    if count_add == 0:
        print("⚠️  Could not find redirect('student_list') in add_student. Skipping.")
    else:
        print(f"✅ add_student: replaced redirect (found {count_add} occurrence).")

    # ----- Patch add_student_mobile -----
    pattern_mobile = r'(return redirect\("mobile_student_list",\s*schema_name=schema_name\))'
    replacement_mobile = r'return redirect("mobile_student_profile", schema_name=schema_name, student_id=student.id)'
    new_content, count_mobile = re.subn(pattern_mobile, replacement_mobile, new_content)

    if count_mobile == 0:
        print("⚠️  Could not find redirect('mobile_student_list') in add_student_mobile. Skipping.")
    else:
        print(f"✅ add_student_mobile: replaced redirect (found {count_mobile} occurrence).")

    if count_add == 0 and count_mobile == 0:
        print("❌ No changes were made. The file may already be patched or the patterns differ.")
        return False

    # Write the updated content
    with open(VIEWS_FILE, "w") as f:
        f.write(new_content)

    print(f"✅ {VIEWS_FILE} updated successfully.")
    return True

if __name__ == "__main__":
    print("🚀 AXIS Student Offline Caching Patcher")
    print("   This script modifies the views to redirect to student profile after creation.")
    success = patch_views()
    if success:
        print("\n✅ Done! Restart your server and test adding a new student.")
        print("   The new student's profile will now be cached automatically.")
    else:
        print("\n❌ Patching failed. Please check the file paths and try again.")
