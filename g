#!/usr/bin/env python3
"""
AXIS Railway Deployment Patcher
- Fixes database connection by making start.sh wait for PostgreSQL
- Creates default tenant 'sh' if missing
- Enforces DATABASE_URL in production
Run once, then push to Railway.
"""

import os
import re

START_SH = "start.sh"
SETTINGS_FILE = "axis_saas/settings.py"

# --------------------------------------------------------------
# 1. NEW START.SH (robust, with wait and tenant creation)
# --------------------------------------------------------------
NEW_START_SH = """#!/bin/bash
set -e

# Wait for database to be ready (max 30s)
echo "Waiting for PostgreSQL..."
for i in {1..30}; do
    if python -c "import os, psycopg2; psycopg2.connect(os.environ['DATABASE_URL'])" 2>/dev/null; then
        echo "Database ready!"
        break
    fi
    echo "Waiting... ($i/30)"
    sleep 1
done

# Run migrations (public + tenants)
echo "Running migrations..."
python manage.py migrate

# Ensure default tenant 'sh' exists
echo "Creating default tenant (if missing)..."
python manage.py shell -c "
from axis_saas.models import SchoolClient
SchoolClient.objects.get_or_create(
    schema_name='sh',
    defaults={
        'name': 'School',
        'admin_username': 'admin',
        'admin_password': 'admin123',
        'is_active': True
    }
)
print('Tenant check complete.')
"

# Start Gunicorn
echo "Starting Gunicorn..."
exec gunicorn axis_saas.wsgi:application --bind 0.0.0.0:7860 --workers 2 --threads 4 --worker-class gthread
"""

# --------------------------------------------------------------
# 2. PATCH SETTINGS.PY – enforce DATABASE_URL in production
# --------------------------------------------------------------
def patch_settings():
    with open(SETTINGS_FILE, "r") as f:
        content = f.read()

    # Add a check after the DATABASES block
    if "if not os.environ.get('DATABASE_URL'):" not in content:
        # Insert right after the DATABASES assignment
        pattern = r"(DATABASES\s*=\s*\{.*?\n\s*\})"
        replacement = r"\1\n\n# Production check: ensure DATABASE_URL is set\nif not DEBUG and not os.environ.get('DATABASE_URL'):\n    raise RuntimeError(\"DATABASE_URL environment variable is required in production.\")\n"
        new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
        with open(SETTINGS_FILE, "w") as f:
            f.write(new_content)
        print("✅ Patched settings.py: enforced DATABASE_URL in production.")
    else:
        print("ℹ️ settings.py already contains the DATABASE_URL check.")

# --------------------------------------------------------------
# 3. OVERWRITE START.SH
# --------------------------------------------------------------
def patch_start_sh():
    with open(START_SH, "w") as f:
        f.write(NEW_START_SH)
    print("✅ Replaced start.sh with robust version (waits for DB, creates tenant).")

# --------------------------------------------------------------
# 4. RUN
# --------------------------------------------------------------
if __name__ == "__main__":
    print("🔧 AXIS Railway Patcher")
    patch_start_sh()
    patch_settings()
    print("\n🎉 Done! Now commit and push to Railway.")
    print("   The container will wait for PostgreSQL, run migrations, create tenant 'sh', and start.")
