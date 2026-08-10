#!/usr/bin/env python3
"""
AXIS Migration Patcher – replaces AddField with idempotent RunSQL.
Run this ONCE locally, then commit and push.
"""

import os
import re

MIGRATION_DIR = "axis_saas/migrations"
FILES = {
    "0015_feerecord_due_date_offset.py": {
        "field": "due_date_offset",
        "sql": "ALTER TABLE axis_saas_feerecord ADD COLUMN IF NOT EXISTS due_date_offset integer DEFAULT 15 NOT NULL;"
    },
    "0016_feerecord_late_fee_per_day.py": {
        "field": "late_fee_per_day",
        "sql": "ALTER TABLE axis_saas_feerecord ADD COLUMN IF NOT EXISTS late_fee_per_day numeric(6,2) DEFAULT 0.00 NOT NULL;"
    }
}

def replace_addfield_with_runsql(filepath, field_name, sql):
    with open(filepath, "r") as f:
        content = f.read()

    # Find the AddField block that contains the field name.
    # We'll locate the start of migrations.AddField(
    start_pattern = r"migrations\.AddField\s*\("
    start_match = re.search(start_pattern, content)
    if not start_match:
        print(f"❌ Could not find 'migrations.AddField(' in {filepath}")
        return False

    # From the start, find the matching closing parenthesis and the following comma.
    start_pos = start_match.start()
    # We'll search forward, counting parentheses.
    paren_count = 0
    end_pos = start_pos
    in_string = False
    for i in range(start_pos, len(content)):
        ch = content[i]
        if ch == '"' or ch == "'":
            # Toggle in_string (simple, not handling escaped quotes)
            in_string = not in_string
        if not in_string:
            if ch == '(':
                paren_count += 1
            elif ch == ')':
                paren_count -= 1
                if paren_count == 0:
                    # Found the closing parenthesis of AddField
                    # Now find the trailing comma (if any) and newline
                    end_pos = i + 1
                    # Skip whitespace and check for comma
                    while end_pos < len(content) and content[end_pos] in ' \t\n\r':
                        end_pos += 1
                    if end_pos < len(content) and content[end_pos] == ',':
                        end_pos += 1
                    break
    if paren_count != 0:
        print(f"❌ Mismatched parentheses in {filepath}")
        return False

    # Now we have the block to replace: content[start_pos:end_pos]
    # Replace it with the RunSQL operation.
    replacement = f"    migrations.RunSQL('{sql}', reverse_sql=''),"
    new_content = content[:start_pos] + replacement + content[end_pos:]

    with open(filepath, "w") as f:
        f.write(new_content)
    print(f"✅ Patched {os.path.basename(filepath)}")
    return True

def main():
    print("🚀 AXIS Migration Patcher – adding IF NOT EXISTS")
    success = True
    for filename, info in FILES.items():
        filepath = os.path.join(MIGRATION_DIR, filename)
        if not os.path.exists(filepath):
            print(f"❌ File not found: {filepath}")
            success = False
            continue
        if not replace_addfield_with_runsql(filepath, info["field"], info["sql"]):
            success = False

    if success:
        print("\n✅ All migrations patched successfully.")
        print("   Now commit and push to Railway.")
    else:
        print("\n❌ Some patches failed. Please check the migration files manually.")

if __name__ == "__main__":
    main()
