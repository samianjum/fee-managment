#!/usr/bin/env python3
"""
AXIS Railway Deployment Patcher
Ensures a default tenant exists before migrations.
Run this once, then push to Railway.
"""

import os
import re

START_SH = "start.sh"
TENANT_SCHEMA = "sh"          # change if you want a different schema name
TENANT_NAME = "School"
ADMIN_USER = "admin"
ADMIN_PASS = "admin123"

def patch_start_sh():
    if not os.path.exists(START_SH):
        print(f"❌ {START_SH} not found. Are you in the project root?")
        return

    with open(START_SH, "r") as f:
        content = f.read()

    # Already patched?
    if "get_or_create(schema_name=" in content:
        print("✅ start.sh already has tenant creation.")
        return

    # Find the migrate command and insert tenant creation before it
    if "python manage.py migrate" not in content:
        print("⚠️ Could not find 'python manage.py migrate' in start.sh. Please add the creation line manually.")
        return

    # Build the creation command
    create_cmd = (
        f'python manage.py shell -c "from axis_saas.models import SchoolClient; '
        f'SchoolClient.objects.get_or_create(schema_name=\'{TENANT_SCHEMA}\', '
        f"defaults={{'name':'{TENANT_NAME}', 'admin_username':'{ADMIN_USER}', 'admin_password':'{ADMIN_PASS}'}})\""
    )

    # Insert before the migrate line
    new_content = content.replace(
        "python manage.py migrate",
        f"{create_cmd}\npython manage.py migrate"
    )

    with open(START_SH, "w") as f:
        f.write(new_content)

    print("✅ Patched start.sh:")
    print(f"   - Will create tenant '{TENANT_SCHEMA}' (if missing) before migrations.")
    print("   - Then runs migrations for all schemas (including the new tenant).")
    print("\nNow push your code to Railway and restart the deployment.")

if __name__ == "__main__":
    patch_start_sh()
