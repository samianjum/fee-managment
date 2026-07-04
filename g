#!/usr/bin/env python3
"""
Fix double-counting of extra charges in student profile.
Run: python3 fix_double_count_extra_charges.py
"""

import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent
VIEWS_PATH = PROJECT_ROOT / "axis_saas" / "views.py"

def fix_get_student_profile_context():
    if not VIEWS_PATH.exists():
        print(f"❌ {VIEWS_PATH} not found.")
        return

    with open(VIEWS_PATH, "r") as f:
        content = f.read()

    # Find the block where total_fee is computed inside get_student_profile_context
    # We'll replace the whole loop with a correct version.

    # Pattern to match the double-counting block
    pattern = r'(total_fee = Decimal\(\'0\'\)\s+for fr in fee_records_qs:\s+total_fee \+= fr\.total_amount\s+for ch in \(fr\.extra_charges or \[\]\):\s+total_fee \+= Decimal\(str\(ch\.get\(\'amount\', 0\)\)\))'

    replacement = '''total_fee = Decimal('0')
        for fr in fee_records_qs:
            total_fee += fr.total_amount'''

    # We need to be careful about indentation. The original has 8 spaces indentation (inside the function).
    # We'll use a more precise replacement by locating the exact lines.
    # We'll look for the line "total_fee = Decimal('0')" and then replace the subsequent block.

    # Instead of regex, we'll do a direct string replacement on the function body.
    # We'll search for the exact block from the provided code.
    old_block = '''        total_fee = Decimal('0')

        for fr in fee_records_qs:

            total_fee += fr.total_amount
            for ch in (fr.extra_charges or []):
                total_fee += Decimal(str(ch.get('amount', 0)))'''

    new_block = '''        total_fee = Decimal('0')

        for fr in fee_records_qs:
            total_fee += fr.total_amount'''

    if old_block in content:
        content = content.replace(old_block, new_block)
        with open(VIEWS_PATH, "w") as f:
            f.write(content)
        print("✅ Fixed get_student_profile_context – removed extra charges double-counting.")
    else:
        print("ℹ️ Could not find the exact block. Attempting more flexible replacement.")

        # Fallback: use regex with flexible whitespace
        pattern = r'(        total_fee = Decimal\(\'0\'\)\s+)\n(        for fr in fee_records_qs:\s+)\n(            total_fee \+= fr\.total_amount\s+)\n(            for ch in \(fr\.extra_charges or \[\]\):\s+)\n(                total_fee \+= Decimal\(str\(ch\.get\(\'amount\', 0\)\)\))'
        replacement = r'\1\n\2\n\3'
        new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
        if new_content != content:
            with open(VIEWS_PATH, "w") as f:
                f.write(new_content)
            print("✅ Fixed get_student_profile_context (using regex).")
        else:
            print("❌ Could not fix automatically. Please manually edit the file.")
            print("   In axis_saas/views.py, inside get_student_profile_context, remove the for loop that iterates over extra_charges.")
            print("   The correct code should only have: total_fee += fr.total_amount")

if __name__ == "__main__":
    print("🔧 Fixing double-count of extra charges in student profile...")
    fix_get_student_profile_context()
    print("\n✅ Done. Restart the server to see the correct total fee.")
