#!/usr/bin/env python3
"""
AXIS Voucher Double-Count Patcher
Fixes generation of fee records so that extra charges are NOT added to amount.
Modifies manual_generate_api and auto_generate_fees command.
Run once and restart server.
"""

import os
import re

# ----- 1. Patch views.py – manual_generate_api -----
VIEWS_FILE = "axis_saas/views.py"

def patch_manual_generate_api():
    if not os.path.exists(VIEWS_FILE):
        print(f"❌ Views file not found: {VIEWS_FILE}")
        return False

    with open(VIEWS_FILE, "r") as f:
        content = f.read()

    # Find the block that sets total_fee = base_fee + total_extra
    # We want to replace it with total_fee = base_fee (and keep extra_charges separate)
    # Look for the line: total_fee = base_fee + total_extra
    old_pattern = r'total_fee\s*=\s*base_fee\s*\+\s*total_extra'
    replacement = 'total_fee = base_fee  # extra charges stored separately in extra_charges field'

    if re.search(old_pattern, content):
        content = re.sub(old_pattern, replacement, content)
        with open(VIEWS_FILE, "w") as f:
            f.write(content)
        print("✅ Patched views.py: manual_generate_api now stores only base fee in amount.")
        return True
    else:
        print("⚠️ Could not find total_fee = base_fee + total_extra in views.py – maybe already patched?")
        # Check if the line already has no addition
        if re.search(r'total_fee\s*=\s*base_fee\s*#', content):
            print("   It seems already patched.")
            return True
        return False

# ----- 2. Patch auto_generate_fees.py -----
AUTO_GEN_FILE = "axis_saas/management/commands/auto_generate_fees.py"

def patch_auto_generate():
    if not os.path.exists(AUTO_GEN_FILE):
        print(f"❌ Auto-generate command file not found: {AUTO_GEN_FILE}")
        return False

    with open(AUTO_GEN_FILE, "r") as f:
        content = f.read()

    # Look for the line where total_fee is computed: total_fee = base_fee + total_extra
    old_pattern = r'total_fee\s*=\s*base_fee\s*\+\s*total_extra'
    replacement = 'total_fee = base_fee  # extra charges stored separately in extra_charges field'

    if re.search(old_pattern, content):
        content = re.sub(old_pattern, replacement, content)
        with open(AUTO_GEN_FILE, "w") as f:
            f.write(content)
        print("✅ Patched auto_generate_fees.py: now stores only base fee in amount.")
        return True
    else:
        print("⚠️ Could not find total_fee = base_fee + total_extra in auto_generate_fees.py – maybe already patched?")
        if re.search(r'total_fee\s*=\s*base_fee\s*#', content):
            print("   It seems already patched.")
            return True
        return False

# ----- 3. Also ensure manual_generate_single_api (already correct) but we can skip -----

def main():
    print("🚀 AXIS Voucher Double-Count Patcher")
    print("-------------------------------------")
    print("This script fixes the generation of fee records to avoid double-counting extra charges in vouchers.\n")

    success_views = patch_manual_generate_api()
    success_auto = patch_auto_generate()

    if success_views and success_auto:
        print("\n✅ All patches applied successfully.")
        print("   Restart your server: python manage.py runserver")
        print("   Newly generated fee records will now have the correct base fee and separate extra charges.")
        print("   Existing records are not modified; you may need to regenerate them if they are incorrect.")
    else:
        print("\n⚠️ Some patches may have failed. Check the output above.")
        print("   If the files are already patched, you can ignore this.")

if __name__ == "__main__":
    main()
