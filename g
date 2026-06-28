#!/usr/bin/env python3
import re
from pathlib import Path

VIEWS_PATH = Path("axis_saas/views.py")

with open(VIEWS_PATH, "r") as f:
    content = f.read()

# Check if mobile_vouchers_list already exists
if "def mobile_vouchers_list" not in content:
    # Find the end of the vouchers_list function (the line before the next def at same indent)
    # We'll insert after the vouchers_list function.
    # Simple approach: insert after the last occurrence of "def vouchers_list" block.
    # We'll use a regex to find the end of the function.
    pattern = r'(def vouchers_list\(.*?\):.*?)(?=\n\S+def |\Z)'
    match = re.search(pattern, content, re.DOTALL)
    if match:
        end_pos = match.end()
        # Insert the new function after that
        new_func = '''
@require_tenant_type(['school'])
def mobile_vouchers_list(request, schema_name):
    """Mobile version of vouchers list grouped by status."""
    tenant = get_tenant(request, schema_name)
    with schema_context(schema_name):
        today = timezone.localdate()
        current_month = today.month
        current_year = today.year

        month = request.GET.get('month')
        year = request.GET.get('year')
        search = request.GET.get('search', '').strip()

        if month:
            try:
                month = int(month)
                if month < 1 or month > 12:
                    month = current_month
            except ValueError:
                month = current_month
        else:
            month = current_month

        if year:
            try:
                year = int(year)
            except ValueError:
                year = current_year
        else:
            year = current_year

        from calendar import monthrange
        last_day = date(year, month, monthrange(year, month)[1])

        fee_records_qs = FeeRecord.objects.filter(month=month, year=year).select_related('student').order_by('student__name')
        if search:
            fee_records_qs = fee_records_qs.filter(
                Q(student__name__icontains=search) |
                Q(student__roll_number__icontains=search) |
                Q(student__father_name__icontains=search) |
                Q(student__grade__icontains=search) |
                Q(student__section__icontains=search)
            )

        existing_student_ids = fee_records_qs.values_list('student_id', flat=True)
        missing_students = Student.objects.filter(
            status='active',
            enrolled_on__lte=last_day
        ).exclude(id__in=existing_student_ids)

        pending_items = []
        partial_items = []
        paid_items = []
        missing_items = []

        for fr in fee_records_qs:
            item = {
                'type': 'record',
                'record': fr,
                'student': fr.student,
                'status': fr.status,
                'amount': fr.amount,
                'paid': fr.paid_amount,
                'due_date': fr.due_date,
                'month': fr.month,
                'year': fr.year,
            }
            if fr.status == 'pending':
                pending_items.append(item)
            elif fr.status == 'partial':
                partial_items.append(item)
            elif fr.status == 'paid':
                paid_items.append(item)
            else:
                pending_items.append(item)

        for student in missing_students:
            reason = "No fee structure"
            if student.custom_fee > 0:
                reason = "Custom fee not set"
            else:
                fee_struct = FeeStructure.objects.filter(grade=student.grade).first()
                if fee_struct:
                    reason = "Not generated"
            missing_items.append({
                'type': 'missing',
                'student': student,
                'reason': reason,
                'status': 'missing',
                'amount': 0,
                'paid': 0,
                'due_date': None,
                'month': month,
                'year': year,
            })

        per_page = 10
        pending_page = Paginator(pending_items, per_page).get_page(request.GET.get('pending_page', 1))
        partial_page = Paginator(partial_items, per_page).get_page(request.GET.get('partial_page', 1))
        paid_page = Paginator(paid_items, per_page).get_page(request.GET.get('paid_page', 1))
        missing_page = Paginator(missing_items, per_page).get_page(request.GET.get('missing_page', 1))

        context = {
            'tenant': tenant,
            'pending_page': pending_page,
            'partial_page': partial_page,
            'paid_page': paid_page,
            'missing_page': missing_page,
            'month': month,
            'year': year,
            'months': list(range(1, 13)),
            'years': list(range(current_year - 5, current_year + 2)),
            'search_query': search,
            'is_current_month': (month == current_month and year == current_year),
            'logo_url': tenant.school_logo.url if tenant.school_logo else None,
        }
        return render(request, 'mobile/vouchers.html', context)
'''
        # Insert with a newline before
        content = content[:end_pos] + "\n\n" + new_func + content[end_pos:]
        with open(VIEWS_PATH, "w") as f:
            f.write(content)
        print("✅ Added mobile_vouchers_list to views.py")
    else:
        print("❌ Could not find vouchers_list function to insert after.")
else:
    print("✅ mobile_vouchers_list already exists, no action needed.")
