import re

VIEWS_FILE = "axis_saas/views.py"

with open(VIEWS_FILE, "r") as f:
    content = f.read()

# Fix the duplicated return in mobile_fee_settings
pattern = r"def mobile_fee_settings\(request, schema_name\):\s+return fee_settings\(request, schema_name, force_mobile=True\)\s+fee_settings\(request, schema_name, force_mobile=True\)"
replacement = "def mobile_fee_settings(request, schema_name):\n    return fee_settings(request, schema_name, force_mobile=True)"

content = re.sub(pattern, replacement, content, flags=re.DOTALL)

with open(VIEWS_FILE, "w") as f:
    f.write(content)

print("✅ Fixed mobile_fee_settings syntax error.")
