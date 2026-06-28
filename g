#!/usr/bin/env python3
"""
Patcher: Fix extra charges handling in fee generation and totals.

- manual_generate_single_api: store amount as base fee, extra_charges separately.
- get_overall_pending: include extra charges in total fee.
- get_student_profile_context: include extra charges in total fee.
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
# 1. Fix manual_generate_single_api
# ------------------------------------------------------------------
# We'll replace the block that computes final_amount and the create/update calls.
# The function is long; we'll use a precise replacement.

# Find the function start
func_start = "def manual_generate_single_api(request):"
if func_start not in content:
    print("⚠️ Could not find manual_generate_single_api. Skipping.")
else:
    # We'll replace the part that sets final_amount and uses it.
    # Look for the lines:
    #   extra_charges = settings.default_extra_charges or []
    #   total_extra = sum((ch.get('amount', 0) for ch in extra_charges), 0)
    #   final_amount = base_fee + total_extra
    # Replace with:
    #   extra_charges = settings.default_extra_charges or []
    #   # Keep base fee separate; extra charges stored separately
    #   final_amount = base_fee

    # Then we need to adjust the create/update to set amount=base_fee and extra_charges=extra_charges.
    # We'll do a broader replacement: replace the whole if/else block for existing_record? 
    # Simpler: we'll do a search and replace for the relevant lines.

    # Replace the lines that set final_amount.
    old_lines = """            extra_charges = settings.default_extra_charges or []
            total_extra = sum((ch.get('amount', 0) for ch in extra_charges), 0)
            final_amount = base_fee + total_extra"""
    new_lines = """            extra_charges = settings.default_extra_charges or []
            # Keep base fee separate; extra charges stored separately
            final_amount = base_fee"""
    if old_lines in content:
        content = content.replace(old_lines, new_lines)
        print("✅ Updated final_amount calculation in manual_generate_single_api")
    else:
        print("⚠️ Could not find the exact lines for final_amount. Skipping this part.")

    # Now adjust the create/update to set amount=base_fee and extra_charges=extra_charges.
    # We'll replace the existing_record update block and the create block.
    # Look for:
    #   if existing_record:
    #       existing_record.amount = final_amount
    #       existing_record.due_date = due_date
    #       existing_record.extra_charges = extra_charges
    # ...
    #   else:
    #       FeeRecord.objects.create(..., amount=final_amount, ...)
    # We'll change those to use base_fee instead of final_amount.
    # We'll do a direct replace on those lines.

    # For the update:
    old_update = """            if existing_record:
            # Update existing record with the new amount and extra charges
            existing_record.amount = final_amount
            existing_record.due_date = due_date
            existing_record.extra_charges = extra_charges
            existing_record.due_date_offset = settings.due_date_offset
            existing_record.late_fee_per_day = settings.late_fee_penalty
            existing_record.save()
            print(f"[DEBUG] Updated fee for {student.name} to ₹{final_amount} (base: {base_fee}, extras: {total_extra})")
            return JsonResponse({
                "message": f"Fee amount updated for {student.name} for {month}/{year} to ₹{final_amount} (including extras)."
            })"""
    new_update = """            if existing_record:
            # Update existing record: amount is base fee, extra charges stored separately
            existing_record.amount = base_fee
            existing_record.due_date = due_date
            existing_record.extra_charges = extra_charges
            existing_record.due_date_offset = settings.due_date_offset
            existing_record.late_fee_per_day = settings.late_fee_penalty
            existing_record.save()
            total_extra = sum((ch.get('amount', 0) for ch in extra_charges), 0)
            print(f"[DEBUG] Updated fee for {student.name}: base {base_fee}, extras {total_extra}")
            return JsonResponse({
                "message": f"Fee amount updated for {student.name} for {month}/{year} (base: {base_fee}, extras: {total_extra})."
            })"""
    if old_update in content:
        content = content.replace(old_update, new_update)
        print("✅ Updated existing_record update block")
    else:
        print("⚠️ Could not find existing_record update block. Skipping.")

    # For the create:
    old_create = """            else:
            FeeRecord.objects.create(
                student=student, month=month, year=year,
                amount=final_amount, due_date=due_date, status="pending",
                extra_charges=extra_charges,
                due_date_offset=settings.due_date_offset,
                late_fee_per_day=settings.late_fee_penalty
            )
            print(f"[DEBUG] Created fee for {student.name} with amount ₹{final_amount} (base: {base_fee}, extras: {total_extra})")
            return JsonResponse({
                "message": f"Fee record created for {student.name} for {month}/{year} with amount ₹{final_amount} (including extras)."
            })"""
    new_create = """            else:
            FeeRecord.objects.create(
                student=student, month=month, year=year,
                amount=base_fee, due_date=due_date, status="pending",
                extra_charges=extra_charges,
                due_date_offset=settings.due_date_offset,
                late_fee_per_day=settings.late_fee_penalty
            )
            total_extra = sum((ch.get('amount', 0) for ch in extra_charges), 0)
            print(f"[DEBUG] Created fee for {student.name}: base {base_fee}, extras {total_extra}")
            return JsonResponse({
                "message": f"Fee record created for {student.name} for {month}/{year} (base: {base_fee}, extras: {total_extra})."
            })"""
    if old_create in content:
        content = content.replace(old_create, new_create)
        print("✅ Updated FeeRecord.create block")
    else:
        print("⚠️ Could not find FeeRecord.create block. Skipping.")


# ------------------------------------------------------------------
# 2. Fix get_overall_pending to include extra charges
# ------------------------------------------------------------------
old_get_overall = """def get_overall_pending(student):
    \"\"\"Compute overall remaining balance: total fee + total items cost - total paid.\"\"\"
    from decimal import Decimal
    from django.db.models import Sum
    total_fee = student.fee_records.aggregate(Sum('amount'))['amount__sum'] or Decimal('0')
    total_paid = student.payments.aggregate(Sum('amount'))['amount__sum'] or Decimal('0')
    # Compute total items cost from all payments
    total_items_cost = Decimal('0')
    for p in student.payments.all():
        items = _extract_item_sales_from_remarks(p.remarks or '')
        total_items_cost += sum(item['line_total'] for item in items)
    return total_fee + total_items_cost - total_paid"""

new_get_overall = """def get_overall_pending(student):
    \"\"\"Compute overall remaining balance: total fee + total items cost - total paid.\"\"\"
    from decimal import Decimal
    from django.db.models import Sum
    total_fee = Decimal('0')
    for fr in student.fee_records.all():
        total_fee += fr.amount
        for ch in (fr.extra_charges or []):
            total_fee += Decimal(str(ch.get('amount', 0)))
    total_paid = student.payments.aggregate(Sum('amount'))['amount__sum'] or Decimal('0')
    # Compute total items cost from all payments
    total_items_cost = Decimal('0')
    for p in student.payments.all():
        items = _extract_item_sales_from_remarks(p.remarks or '')
        total_items_cost += sum(item['line_total'] for item in items)
    return total_fee + total_items_cost - total_paid"""

if old_get_overall in content:
    content = content.replace(old_get_overall, new_get_overall)
    print("✅ Updated get_overall_pending to include extra charges")
else:
    print("⚠️ Could not find get_overall_pending function. Skipping.")


# ------------------------------------------------------------------
# 3. Fix get_student_profile_context to include extra charges in total_fee
# ------------------------------------------------------------------
# We need to replace the calculation of total_fee in that function.
# We'll locate the lines:
#   fee_records_qs = student.fee_records.all().order_by('-year', '-month')
#   total_fee = fee_records_qs.aggregate(Sum('amount'))['amount__sum'] or 0
# We'll replace with computation that includes extra charges.
old_profile_total = """        fee_records_qs = student.fee_records.all().order_by('-year', '-month')
        total_fee = fee_records_qs.aggregate(Sum('amount'))['amount__sum'] or 0"""
new_profile_total = """        fee_records_qs = student.fee_records.all().order_by('-year', '-month')
        total_fee = Decimal('0')
        for fr in fee_records_qs:
            total_fee += fr.amount
            for ch in (fr.extra_charges or []):
                total_fee += Decimal(str(ch.get('amount', 0)))"""

if old_profile_total in content:
    content = content.replace(old_profile_total, new_profile_total)
    print("✅ Updated get_student_profile_context total_fee to include extra charges")
else:
    print("⚠️ Could not find the total_fee computation in get_student_profile_context. Skipping.")


# Write back
with open(FILE, "w") as f:
    f.write(content)

print("\n🎯 All patches applied. Restart the server to see the changes.")
