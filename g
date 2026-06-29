#!/usr/bin/env python3
"""
Patcher to add "Fee Logs" link to desktop sidebar and mobile More page.
Run with: python3 add_fee_logs_links.py
"""

import re
from pathlib import Path

DESKTOP_BASE = Path("templates/tenant/base.html")
MOBILE_MORE = Path("templates/mobile/more.html")

# Desktop sidebar link (to be inserted after Vouchers link)
DESKTOP_LINK = """
                {% if tenant.tenant_type == 'school' %}
                <a href="{% url 'fee_logs' schema_name=tenant.schema_name %}" class="nav-item">
                    <svg class="nav-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/></svg>
                    <span>Fee Logs</span>
                </a>
                {% endif %}
"""

# Mobile More card (insert after Fee Vouchers card)
MOBILE_CARD = """
    <!-- Fee Logs -->
    <a href="{% url 'mobile_fee_logs' schema_name=tenant.schema_name %}" class="more-card">
        <div class="icon-wrapper">
            <svg viewBox="0 0 24 24"><path d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/></svg>
        </div>
        <h3>Fee Logs</h3>
        <p>View fee generation history.</p>
    </a>
"""

def patch_desktop():
    if not DESKTOP_BASE.exists():
        print(f"❌ {DESKTOP_BASE} not found.")
        return False

    with open(DESKTOP_BASE, 'r', encoding='utf-8') as f:
        content = f.read()

    # Check if already added
    if 'Fee Logs' in content and 'fee_logs' in content:
        print("ℹ️ Desktop sidebar already has Fee Logs link.")
        return True

    # Find the Vouchers link and insert after it
    # Look for the line: <a href="{% url 'vouchers_list' ... and the closing </a>.
    # We'll match the entire block: from the opening <a for vouchers to the closing </a> and insert after.
    pattern = r'(<a href="{% url \'vouchers_list\' schema_name=tenant.schema_name %}" class="nav-item">.*?</a>)'
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        print("❌ Could not find Vouchers link in desktop base.html")
        return False

    # Insert the new link after the vouchers block
    new_content = content.replace(match.group(0), match.group(0) + '\n' + DESKTOP_LINK)

    with open(DESKTOP_BASE, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("✅ Added Fee Logs link to desktop sidebar.")
    return True

def patch_mobile():
    if not MOBILE_MORE.exists():
        print(f"❌ {MOBILE_MORE} not found.")
        return False

    with open(MOBILE_MORE, 'r', encoding='utf-8') as f:
        content = f.read()

    if 'Fee Logs' in content and 'mobile_fee_logs' in content:
        print("ℹ️ Mobile More page already has Fee Logs card.")
        return True

    # Find the Fee Vouchers card and insert after it
    pattern = r'(<a href="{% url \'mobile_vouchers_list\' schema_name=tenant.schema_name %}" class="more-card">.*?</a>)'
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        print("❌ Could not find Fee Vouchers card in mobile/more.html")
        return False

    new_content = content.replace(match.group(0), match.group(0) + '\n' + MOBILE_CARD)

    with open(MOBILE_MORE, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("✅ Added Fee Logs card to mobile More page.")
    return True

def main():
    print("🚀 Adding Fee Logs links to sidebar and More page.\n")
    ok_desktop = patch_desktop()
    ok_mobile = patch_mobile()
    if ok_desktop and ok_mobile:
        print("\n✅ Done! Refresh the pages to see the new links.")
    else:
        print("\n⚠️  Some steps failed. Check the output above.")

if __name__ == "__main__":
    main()
