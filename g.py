#!/usr/bin/env python3
"""
Replace all occurrences of _extract_item_sales_from_remarks
with extract_item_sales_from_remarks in all views/*.py files.
Run once.
"""
import re
from pathlib import Path

VIEWS_DIR = Path("axis_saas/views")

if not VIEWS_DIR.exists():
    print(f"❌ Directory {VIEWS_DIR} not found. Are you in the project root?")
    exit(1)

updated = 0
for py_file in VIEWS_DIR.glob("*.py"):
    with open(py_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace with word boundaries to avoid partial matches
    new_content = re.sub(r'\b_extract_item_sales_from_remarks\b', 'extract_item_sales_from_remarks', content)

    if new_content != content:
        with open(py_file, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"✅ Updated {py_file.name}")
        updated += 1

if updated:
    print(f"\n🎉 Updated {updated} file(s). Restart Django server now.")
else:
    print("\n✅ No changes needed – all files already use the correct name.")
