#!/usr/bin/env python3
"""
Single patcher to enable offline support for Settings page.
Usage: python3 patch_settings_offline.py
"""

import re
import os

# ----------------------------------------------------------------------
# 1. Patch static/sw.js – add settings patterns
# ----------------------------------------------------------------------
def patch_sw_js():
    path = 'static/sw.js'
    if not os.path.exists(path):
        print(f"❌ {path} not found")
        return

    with open(path, 'r') as f:
        content = f.read()

    pattern = r'(const isCachedPage = )(.*?)(;)'
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        print("❌ Could not find 'const isCachedPage' in sw.js")
        return

    prefix = match.group(1)
    body = match.group(2)
    suffix = match.group(3)

    # Check if already present
    if '/settings/' in body:
        print("✅ Settings patterns already in sw.js, skipping.")
        return

    new_patterns = [
        "/^\\/portal\\/[^\\/]+\\/settings\\/?$/.test(url.pathname)",
        "/^\\/portal\\/[^\\/]+\\/settings\\/mobile\\/?$/.test(url.pathname)"
    ]
    body_trim = body.rstrip()
    if body_trim and not body_trim.endswith('||'):
        body_trim += ' ||'
    body_trim += '\n                         ' + ' ||\n                         '.join(new_patterns)
    new_line = prefix + body_trim + suffix
    content = content.replace(match.group(0), new_line)

    with open(path, 'w') as f:
        f.write(content)
    print("✅ static/sw.js patched (settings).")

# ----------------------------------------------------------------------
# 2. Update base templates: add settings URLs to PRECACHE_PAGES
# ----------------------------------------------------------------------
def patch_base_template(template_path):
    if not os.path.exists(template_path):
        print(f"❌ {template_path} not found")
        return

    with open(template_path, 'r') as f:
        content = f.read()

    # Check if already added
    if '/settings/' in content:
        print(f"✅ Settings URLs already in {template_path}, skipping.")
        return

    # Find the urls array definition
    pattern = r'(const urls = \[)(.*?)(\];)'
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        print(f"❌ Could not find urls array in {template_path}")
        return

    prefix = match.group(1)
    body = match.group(2)
    suffix = match.group(3)

    new_urls = [
        f"    `/portal/${{schema}}/settings/`,",
        f"    `/portal/${{schema}}/settings/mobile/`,"
    ]
    body_trim = body.rstrip()
    if body_trim and not body_trim.endswith(','):
        body_trim += ','
    body_trim += '\n' + '\n'.join(new_urls) + '\n'
    new_line = prefix + body_trim + suffix
    content = content.replace(match.group(0), new_line)

    with open(template_path, 'w') as f:
        f.write(content)
    print(f"✅ Settings URLs added to {template_path}.")

# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------
def main():
    print("🚀 AXIS Settings Page Offline Patcher")
    patch_sw_js()
    patch_base_template('templates/tenant/base.html')
    patch_base_template('templates/mobile/base.html')
    print("\n✅ Done! Restart your server and clear browser cache.")
    print("   The Settings page will now be cached and available offline.")

if __name__ == "__main__":
    main()
