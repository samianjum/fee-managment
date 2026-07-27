#!/usr/bin/env python3
import re
import os
from pathlib import Path

# Fix the replaces list
file_path = Path('axis_saas/migrations/0001_initial.py')
if not file_path.exists():
    print("❌ 0001_initial.py not found.")
    exit(1)

content = file_path.read_text()
# Remove the entire replaces list
content = re.sub(r'replaces = \[[^\]]*\]', 'replaces = []', content, flags=re.DOTALL)
file_path.write_text(content)
print("✅ Replaces list removed.")

# Fake apply the migration
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'axis_saas.settings')
import django
django.setup()
from django.core.management import call_command
call_command('migrate', 'axis_saas', '0001', fake=True, verbosity=1)
print("✅ Fake migration applied.")
