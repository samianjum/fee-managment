#!/usr/bin/env python3
"""
Patch notification bell templates to fix mobile redirection.
"""

import os
import re
from pathlib import Path

# Files to patch (relative to project root)
TEMPLATE_PATHS = [
    Path("templates/tenant/notification_bell.html"),
    Path("templates/mobile/notification_bell.html"),
]

OLD_BLOCK = """
item.addEventListener('click', function(e) {
    if (e.target.classList.contains('dismiss')) return;
    if (link) {
        window.location.href = link;
    }
    // Mark as read
    markRead(id);
});
"""

NEW_BLOCK = """
item.addEventListener('click', function(e) {
    if (e.target.classList.contains('dismiss')) return;
    if (link) {
        const targetLink = fixMobileLink(link);
        window.location.href = targetLink;
    }
    // Mark as read
    markRead(id);
});
"""

def patch_file(file_path):
    if not file_path.exists():
        print(f"⚠️  File not found: {file_path}")
        return False

    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    if 'fixMobileLink(link)' in content:
        print(f"✅ Already patched: {file_path}")
        return True

    if OLD_BLOCK not in content:
        print(f"❌ Pattern not found in {file_path}. Skipping.")
        return False

    new_content = content.replace(OLD_BLOCK, NEW_BLOCK)
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(new_content)

    print(f"✅ Patched: {file_path}")
    return True

def main():
    print("🔧 AXIS Notification Link Patcher")
    print("=================================")
    success = True
    for path in TEMPLATE_PATHS:
        if not patch_file(path):
            success = False

    if success:
        print("\n✅ Done! Notification links will now redirect to the mobile version on mobile devices.")
        print("   Restart your Django server if running.")
    else:
        print("\n❌ Some files could not be patched. Check output above.")

if __name__ == "__main__":
    main()
