#!/usr/bin/env python3
"""
AXIS Patcher – Remove orphaned late_fee_accrued field from FeeRecord model.
This fixes the "column does not exist" error.
"""

import os
import re
import sys

MODELS_PATH = "axis_saas/models.py"

def patch():
    if not os.path.exists(MODELS_PATH):
        print(f"❌ {MODELS_PATH} not found. Are you in the project root?")
        sys.exit(1)

    with open(MODELS_PATH, "r") as f:
        content = f.read()

    # Look for the line that defines late_fee_accrued.
    # It may have varying whitespace and default values.
    pattern = r'^\s*late_fee_accrued\s*=\s*models\.DecimalField\([^)]*\)\s*$'
    new_content, count = re.subn(pattern, "", content, flags=re.MULTILINE)

    if count == 0:
        # If not found, maybe it's split across lines? Unlikely, but we try a broader pattern.
        # Remove the entire line containing 'late_fee_accrued' and 'DecimalField'
        lines = content.splitlines()
        new_lines = []
        removed = False
        for line in lines:
            if 'late_fee_accrued' in line and 'DecimalField' in line:
                removed = True
                continue
            new_lines.append(line)
        if removed:
            new_content = "\n".join(new_lines)
            count = 1
        else:
            print("⚠️  late_fee_accrued field not found – nothing to do.")
            return

    with open(MODELS_PATH, "w") as f:
        f.write(new_content)

    print(f"✅ Removed late_fee_accrued field from models.py (removed {count} occurrence(s)).")
    print("✅ Restart your server: python manage.py runserver")

if __name__ == "__main__":
    patch()
