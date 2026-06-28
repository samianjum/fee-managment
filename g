#!/usr/bin/env python3
"""
Patcher: Fix fee collection view to use get_overall_pending
for student pending totals and overall pending sum.
"""

import re
import os

FILE = "axis_saas/views.py"

if not os.path.exists(FILE):
    print(f"❌ {FILE} not found. Run from project root.")
    exit(1)

with open(FILE, "r") as f:
    content = f.read()

# ------------------------------------------------------------------
# 1. Replace the pending_students computation
# ------------------------------------------------------------------
# We'll locate the block that starts with:
#   pending_students = []
#   for s in students_qs:
#       pending = sum(fr.remaining for fr in s.fee_records.all())
#       if pending > 0:
#           s.pending_total = pending
#           pending_students.append(s)
# We'll replace it with a version that uses get_overall_pending.

old_pending_list = """        pending_students = []
        for s in students_qs:
            pending = sum(fr.remaining for fr in s.fee_records.all())
            if pending > 0:
                s.pending_total = pending
                pending_students.append(s)
        pending_students.sort(key=lambda x: x.pending_total, reverse=True)"""

new_pending_list = """        pending_students = []
        for s in students_qs:
            pending = get_overall_pending(s)
            if pending > 0:
                s.pending_total = pending
                pending_students.append(s)
        pending_students.sort(key=lambda x: x.pending_total, reverse=True)"""

if old_pending_list in content:
    content = content.replace(old_pending_list, new_pending_list)
    print("✅ Updated pending_students loop to use get_overall_pending")
else:
    print("⚠️ Could not find the pending_students block. Skipping.")


# ------------------------------------------------------------------
# 2. Replace the total_pending_all computation
# ------------------------------------------------------------------
# We'll locate the line:
#   total_pending_all = sum(fr.remaining for fr in FeeRecord.objects.filter(status__in=['pending', 'partial', 'overdue']))
# Replace with a sum over all students using get_overall_pending.

# Use regex to match the line with possibly different spacing.
pattern = r'(\s*)total_pending_all\s*=\s*sum\(fr\.remaining for fr in FeeRecord\.objects\.filter\(status__in=\[.*?\]\)\)'
match = re.search(pattern, content)
if match:
    indent = match.group(1)
    new_line = f'{indent}total_pending_all = sum(get_overall_pending(s) for s in Student.objects.all())'
    content = content.replace(match.group(0), new_line)
    print("✅ Updated total_pending_all to use get_overall_pending")
else:
    # Fallback: try to find a simple variant
    old_line = "total_pending_all = sum(fr.remaining for fr in FeeRecord.objects.filter(status__in=['pending', 'partial', 'overdue']))"
    if old_line in content:
        content = content.replace(old_line, "total_pending_all = sum(get_overall_pending(s) for s in Student.objects.all())")
        print("✅ Updated total_pending_all (simple replace)")
    else:
        print("⚠️ Could not find total_pending_all line. Skipping.")


# ------------------------------------------------------------------
# 3. Write back
# ------------------------------------------------------------------
with open(FILE, "w") as f:
    f.write(content)

print("\n🎯 All patches applied. Restart the server to see the changes.")
