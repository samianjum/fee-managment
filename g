#!/usr/bin/env python3
"""
AXIS School System – Remove duplicate voucher button from student_profile.html
Run: python3 remove_duplicate_voucher.py
"""

import re
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
FILE_PATH = BASE_DIR / "templates" / "tenant" / "student_profile.html"

with open(FILE_PATH, "r") as f:
    content = f.read()

# Pattern to match the voucher button block (flex div + button)
pattern = r'<div style="display: flex; gap: 0\.75rem; margin-bottom: 1\.5rem; justify-content: flex-end;">\s*<button class="btn-primary" id="voucherBtnDesktop".*?</button>\s*</div>'

# Find all matches
matches = list(re.finditer(pattern, content, re.DOTALL))

if len(matches) > 1:
    # Keep only the first occurrence, remove the rest
    # We'll replace all matches with the first match's content
    first_match = matches[0]
    first_block = first_match.group(0)
    # Replace all occurrences with the first block (so duplicates become one)
    content = re.sub(pattern, first_block, content, flags=re.DOTALL)
    print("✅ Removed duplicate voucher buttons. Only one remains.")
elif len(matches) == 1:
    print("ℹ️ Only one voucher button found, nothing to remove.")
else:
    print("⚠️ No voucher button block found. Nothing changed.")

# Write back
with open(FILE_PATH, "w") as f:
    f.write(content)

print("\n🎯 Done! Restart the server to see the change.")
