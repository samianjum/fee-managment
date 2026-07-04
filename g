#!/usr/bin/env python3
"""
Patch templates/mobile/product_detail.html to change "Back to Stock" link
from stock_management to mobile_stock_management.
"""

import re
import sys

FILE_PATH = "templates/mobile/product_detail.html"

def patch_file():
    try:
        with open(FILE_PATH, "r", encoding="utf-8") as f:
            content = f.read()
    except FileNotFoundError:
        print(f"Error: {FILE_PATH} not found. Run from project root.", file=sys.stderr)
        sys.exit(1)

    # Find the line with the back link
    old_pattern = r'href="{% url \'stock_management\' schema_name=tenant\.schema_name %}"'
    new_line = 'href="{% url \'mobile_stock_management\' schema_name=tenant.schema_name %}"'

    # Use regex to replace first occurrence
    new_content, count = re.subn(old_pattern, new_line, content)
    if count == 0:
        print("❌ Could not find the back link line to patch.", file=sys.stderr)
        # fallback: try to find any line containing url 'stock_management'
        fallback_pattern = r"{% url 'stock_management'[^%]*%}"
        if re.search(fallback_pattern, content):
            new_content = re.sub(fallback_pattern, "{% url 'mobile_stock_management' schema_name=tenant.schema_name %}", content)
            print("✅ Patched using fallback regex.")
        else:
            print("❌ No matching line found. Exiting.", file=sys.stderr)
            sys.exit(1)
    else:
        print(f"✅ Replaced {count} occurrence(s).")

    with open(FILE_PATH, "w", encoding="utf-8") as f:
        f.write(new_content)

    print("✅ Patch applied successfully.")
    print(f"New line: {new_line}")

if __name__ == "__main__":
    patch_file()
