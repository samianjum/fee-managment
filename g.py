#!/usr/bin/env python3
"""
Extend offline caching to the Defaulters page (desktop & mobile).
Updates the service worker to cache‑first for /defaulters/ and /defaulters/mobile/,
and adds those URLs to the pre‑caching script that runs on every page load.
Run: python3 defaulters_offline_patcher.py
"""

import re
from pathlib import Path

SW_PATH = Path("static/sw.js")
DESKTOP_BASE = Path("templates/tenant/base.html")
MOBILE_BASE = Path("templates/mobile/base.html")

# ----------------------------------------------------------------------
# 1. Update service worker – add defaulters to cached page regex
# ----------------------------------------------------------------------
def patch_sw():
    if not SW_PATH.exists():
        print("❌ static/sw.js not found. Are you in the project root?")
        return False

    content = SW_PATH.read_text(encoding="utf-8")

    # Find the isCachedPage regex. It currently looks like:
    # const isCachedPage = /^\/portal\/[^\/]+\/dashboard\//.test(...) || ... || /^\/portal\/[^\/]+\/students\/mobile\/?$/.test(...);
    # We need to add defaulters patterns:
    # /^\/portal\/[^\/]+\/defaulters\/?$/ and /^\/portal\/[^\/]+\/defaulters\/mobile\/?$/

    # We'll search for the line that defines isCachedPage.
    pattern = re.compile(
        r'(const isCachedPage\s*=\s*)(.*?)(;)\s*// For these pages: cache-first',
        re.DOTALL
    )
    match = pattern.search(content)
    if not match:
        print("❌ Could not find isCachedPage definition in sw.js")
        return False

    before = match.group(1)
    body = match.group(2)
    after = match.group(3)

    # Add new patterns if not already present
    if "/defaulters/" not in body:
        # Insert before the existing patterns
        # We'll append at the end of the OR chain
        new_patterns = (
            " /^\\/portal\\/[^\\/]+\\/defaulters\\/?$/.test(url.pathname) ||\n" +
            "                         /^\\/portal\\/[^\\/]+\\/defaulters\\/mobile\\/?$/.test(url.pathname) ||"
        )
        # Insert after the last pattern (before the closing )
        # We'll find the last part of the body before the closing )
        # Actually we can just append before the last ')'.
        # The body ends with a ')'? It ends with ';' after the entire expression.
        # We'll insert after the last pattern. But easier: we'll replace the whole body with the new one.
        # Let's extract the existing patterns and add our new ones.
        # We'll keep the existing body, but we need to add our OR conditions.
        # We'll use a more robust approach: we'll replace the entire isCachedPage line.
        # We'll generate a new line with all patterns.
        new_body = (
            "/^\\/portal\\/[^\\/]+\\/dashboard\\//.test(url.pathname) ||\n"
            "                         /^\\/portal\\/[^\\/]+\\/dashboard\\/mobile\\//.test(url.pathname) ||\n"
            "                         /^\\/portal\\/[^\\/]+\\/dashboard\\/?$/.test(url.pathname) ||\n"
            "                         /^\\/portal\\/[^\\/]+\\/students\\/?$/.test(url.pathname) ||\n"
            "                         /^\\/portal\\/[^\\/]+\\/students\\/mobile\\/?$/.test(url.pathname) ||\n"
            "                         /^\\/portal\\/[^\\/]+\\/defaulters\\/?$/.test(url.pathname) ||\n"
            "                         /^\\/portal\\/[^\\/]+\\/defaulters\\/mobile\\/?$/.test(url.pathname)"
        )
        # Replace the whole body
        new_line = before + new_body + after
        content = pattern.sub(new_line, content)
        print("✅ Added defaulters to sw.js cache‑first list")
    else:
        print("✅ Defaulters already present in sw.js")

    SW_PATH.write_text(content, encoding="utf-8")
    return True


# ----------------------------------------------------------------------
# 2. Update pre‑caching script in base templates – add defaulters URLs
# ----------------------------------------------------------------------
def update_precache_script(template_path):
    if not template_path.exists():
        print(f"⚠️  {template_path} not found, skipping")
        return False

    content = template_path.read_text(encoding="utf-8")

    # Find the pre‑caching script block
    pattern = re.compile(
        r'(// PRECACHE_PAGES – automatically cache dashboard & student list pages on every load.*?const urls = \[)(.*?)(\];)',
        re.DOTALL
    )
    match = pattern.search(content)
    if not match:
        print(f"⚠️  Could not find pre‑caching script in {template_path}, skipping")
        return False

    before = match.group(1)
    urls_block = match.group(2)
    after = match.group(3)

    # Check if defaulters are already in the urls list
    if "/defaulters/" in urls_block:
        print(f"✅ Defaulters already in pre‑cache list for {template_path}")
        return True

    # Insert new URLs before the closing `]`
    # We'll add them after the existing ones.
    new_urls = (
        urls_block.rstrip() +
        ",\n            `/portal/${schema}/defaulters/`,\n" +
        "            `/portal/${schema}/defaulters/mobile/`"
    )
    new_block = before + new_urls + after
    new_content = pattern.sub(new_block, content)

    # Also update the comment to reflect new pages
    new_content = new_content.replace(
        "dashboard & student list pages",
        "dashboard, student list, and defaulters pages"
    )

    template_path.write_text(new_content, encoding="utf-8")
    print(f"✅ Added defaulters to pre‑cache list in {template_path}")
    return True


# ----------------------------------------------------------------------
# MAIN
# ----------------------------------------------------------------------
def main():
    print("Defaulters Offline Patcher")
    print("---------------------------")
    print("This will add the Defaulters page (desktop & mobile) to the cache‑first strategy")
    print("and include it in the automatic pre‑caching that runs on every page load.")
    print()

    sw_ok = patch_sw()
    if not sw_ok:
        print("❌ Failed to patch sw.js")
        return

    desktop_ok = update_precache_script(DESKTOP_BASE)
    mobile_ok = update_precache_script(MOBILE_BASE)

    if desktop_ok or mobile_ok:
        print("\n✅ Done! Restart your server and clear browser cache.")
        print("The Defaulters page will now be cached on every page load,")
        print("and served from cache when offline (with background updates when online).")
    else:
        print("\n❌ No templates were patched. Check that the base templates exist.")

if __name__ == "__main__":
    main()
