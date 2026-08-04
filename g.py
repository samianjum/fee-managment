#!/usr/bin/env python3
"""
Single patcher to enable offline support for Fee Structure page.
Run: python3 patch_fee_structure_offline.py
"""

import re
import os

# ----------------------------------------------------------------------
# 1. Patch static/sw.js – add fee_structure patterns to isCachedPage
# ----------------------------------------------------------------------
def patch_sw_js():
    path = 'static/sw.js'
    if not os.path.exists(path):
        print(f"❌ {path} not found")
        return

    with open(path, 'r') as f:
        content = f.read()

    # Regex to match the whole isCachedPage declaration
    pattern = r'(const isCachedPage = )(.*?)(;)'
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        print("❌ Could not find 'const isCachedPage' in sw.js")
        return

    prefix = match.group(1)
    body = match.group(2)
    suffix = match.group(3)

    # Check if already patched
    if 'fee/structure' in body:
        print("✅ Fee Structure already present in sw.js, skipping.")
        return

    # New patterns to add
    new_patterns = [
        "/^\\/portal\\/[^\\/]+\\/fee\\/structure\\/?$/.test(url.pathname)",
        "/^\\/portal\\/[^\\/]+\\/fee\\/structure\\/mobile\\/?$/.test(url.pathname)"
    ]

    # Add them after the last existing pattern (before the closing semicolon)
    body_trim = body.rstrip()
    if body_trim and not body_trim.endswith('||'):
        body_trim += ' ||'
    body_trim += '\n                         ' + ' ||\n                         '.join(new_patterns)

    new_line = prefix + body_trim + suffix
    content = content.replace(match.group(0), new_line)

    with open(path, 'w') as f:
        f.write(content)
    print("✅ static/sw.js patched (fee-structure).")


# ----------------------------------------------------------------------
# 2. Patch base templates – add fee_structure URLs to pre‑caching array
# ----------------------------------------------------------------------
def patch_base_template(template_path):
    if not os.path.exists(template_path):
        print(f"❌ {template_path} not found")
        return

    with open(template_path, 'r') as f:
        content = f.read()

    # Find the urls array definition
    pattern = r'(const urls = \[)([\s\S]*?)(\];)'
    match = re.search(pattern, content)
    if not match:
        print(f"❌ Could not find 'const urls = [' in {template_path}")
        return

    prefix = match.group(1)
    body = match.group(2)
    suffix = match.group(3)

    # Check if already patched
    if 'fee/structure' in body:
        print(f"✅ Fee Structure already in {template_path}, skipping.")
        return

    # New URLs to add
    new_urls = [
        "`/portal/${schema}/fee/structure/`",
        "`/portal/${schema}/fee/structure/mobile/`"
    ]

    # Clean up body: remove trailing whitespace, add comma if needed
    body_trim = body.rstrip()
    if body_trim and not body_trim.endswith(','):
        body_trim += ','
    # Add new lines (indent 4 spaces)
    body_trim += '\n    ' + ',\n    '.join(new_urls)

    new_block = prefix + body_trim + suffix
    content = content.replace(match.group(0), new_block)

    with open(template_path, 'w') as f:
        f.write(content)
    print(f"✅ {template_path} patched (fee-structure).")


# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------
def main():
    print("🚀 AXIS Fee Structure Offline Patcher")
    patch_sw_js()
    patch_base_template('templates/tenant/base.html')
    patch_base_template('templates/mobile/base.html')
    print("\n✅ Done! Restart your server and clear browser cache.")
    print("   Then visit the Fee Structure page while online to cache it.")


if __name__ == "__main__":
    main()
