#!/usr/bin/env python3
"""
AXIS Fee Charges Patcher
Fixes the issue where extra charges vanish after saving in Fee Settings.
Patches both desktop and mobile templates by adding a submit event listener
that updates the hidden JSON input before the form is sent.
"""

import os
import re

TEMPLATES = [
    "templates/tenant/fee_settings.html",
    "templates/mobile/fee_settings.html",
]

def patch_template(filepath):
    """Add a submit handler to the settings form in the given template."""
    if not os.path.exists(filepath):
        print(f"⚠️  File not found: {filepath} – skipping.")
        return False

    with open(filepath, "r") as f:
        content = f.read()

    # Check if already patched (avoid duplicate)
    if "document.getElementById('settingsForm').addEventListener('submit'" in content:
        print(f"✅ Already patched: {filepath}")
        return True

    # Find the first </script> tag and insert our script block before it
    script_block = """
    // ----- PATCH: Ensure extra charges JSON is updated on submit -----
    document.getElementById('settingsForm').addEventListener('submit', function(e) {
        if (typeof updateTotal === 'function') {
            updateTotal();  // refresh the hidden input value
        }
        // Debug: log the submitted JSON (you can view in browser console)
        console.log('Submitting extra charges:', document.getElementById('extraChargesJson').value);
    });
    """
    # Insert before the first closing script tag
    pattern = r'(</script>)'
    replacement = script_block + '\n\\1'
    content = re.sub(pattern, replacement, content, count=1)

    with open(filepath, "w") as f:
        f.write(content)

    print(f"✅ Patched: {filepath}")
    return True

def main():
    print("🚀 AXIS Fee Charges Patcher")
    print("--------------------------------")
    success = True
    for tpl in TEMPLATES:
        if not patch_template(tpl):
            success = False

    if success:
        print("\n🎯 All templates patched successfully.")
        print("   Restart your server (python manage.py runserver) and test Fee Settings.")
        print("   Extra charges should now be saved correctly.")
    else:
        print("\n❌ Some files were not found. Ensure you are in the project root.")
        print("   Expected paths:")
        for tpl in TEMPLATES:
            print(f"      - {tpl}")

if __name__ == "__main__":
    main()
