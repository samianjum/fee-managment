#!/usr/bin/env python3
"""
Final patch to enforce strict desktop/mobile separation for stock management.

- Modifies axis_saas/views.py to redirect to mobile_stock_management when
  request comes from mobile (user agent or mobile_redirect POST param).
- Fixes the back link in templates/mobile/product_detail.html to use
  mobile_stock_management.
"""

import re
import sys

VIEWS_FILE = "axis_saas/views.py"
TEMPLATE_FILE = "templates/mobile/product_detail.html"

def patch_views():
    try:
        with open(VIEWS_FILE, "r", encoding="utf-8") as f:
            content = f.read()
    except FileNotFoundError:
        print(f"❌ Error: {VIEWS_FILE} not found.", file=sys.stderr)
        sys.exit(1)

    # ----- Helper: replace final redirect in a view function -----
    # We'll look for the pattern: return redirect('stock_management', schema_name=schema_name)
    # but only in the context of the four functions.
    # To be safe, we'll replace all occurrences with a conditional check.
    # However, we must ensure we don't break other places (like in error handling).
    # We'll specifically target lines that are immediately after the main logic.

    # We'll replace:
    #   return redirect('stock_management', schema_name=schema_name)
    # with:
    #   if is_mobile_user_agent(request) or request.POST.get('mobile_redirect') == '1':
    #       return redirect('mobile_stock_management', schema_name=schema_name)
    #   return redirect('stock_management', schema_name=schema_name)

    # But we must also ensure we don't double-patch. Check if the pattern already exists.
    if "if is_mobile_user_agent(request) or request.POST.get('mobile_redirect')" in content:
        print("ℹ️  Views already patched? Skipping views patch.")
        return

    # Replace all occurrences of the exact redirect line (with possible whitespace)
    # Use a regex that matches the line with optional whitespace and the exact string.
    pattern = r'^(\s*)return redirect\([\'"]stock_management[\'"],\s*schema_name=schema_name\)\s*$'
    replacement = r'''\1if is_mobile_user_agent(request) or request.POST.get('mobile_redirect') == '1':
\1    return redirect('mobile_stock_management', schema_name=schema_name)
\1return redirect('stock_management', schema_name=schema_name)'''

    # Use MULTILINE flag to match line start
    content = re.sub(pattern, replacement, content, flags=re.MULTILINE)

    # Also handle the case where the line might be broken or have different quoting (single vs double)
    # We'll also replace a more generic pattern: return redirect('stock_management', schema_name=schema_name)
    # with the same conditional, but we'll do it line by line.
    # The above should catch most.

    # Additional safety: if any function still has the old line without condition, we'll catch them.
    # We'll do a second pass with a more flexible pattern (no line start anchor).
    # But we already did multiline.

    with open(VIEWS_FILE, "w", encoding="utf-8") as f:
        f.write(content)

    print("✅ Views patched: added conditional redirects for stock actions.")

def patch_template():
    try:
        with open(TEMPLATE_FILE, "r", encoding="utf-8") as f:
            content = f.read()
    except FileNotFoundError:
        print(f"❌ Error: {TEMPLATE_FILE} not found.", file=sys.stderr)
        sys.exit(1)

    # Replace the back link: href="{% url 'stock_management' ... %}" -> href="{% url 'mobile_stock_management' ... %}"
    # We'll look for the exact line.
    old = r'href="{% url \'stock_management\' schema_name=tenant\.schema_name %}"'
    new = 'href="{% url \'mobile_stock_management\' schema_name=tenant.schema_name %}"'

    # Check if already patched
    if "mobile_stock_management" in content and "Back to Stock" in content:
        print("ℹ️  Template already patched? Skipping template patch.")
        return

    content = re.sub(old, new, content)

    with open(TEMPLATE_FILE, "w", encoding="utf-8") as f:
        f.write(content)

    print("✅ Template patched: back link now uses mobile_stock_management.")

def main():
    patch_views()
    patch_template()
    print("\n✅ All patches applied successfully.")
    print("Now all stock actions and back links will respect desktop/mobile separation.")

if __name__ == "__main__":
    main()
