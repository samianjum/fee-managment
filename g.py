#!/usr/bin/env python3
"""
Add missing student context functions to axis_saas/views/helpers.py.
Run once: python3 fix_student_context.py
"""

import re
from pathlib import Path

HELPERS_PATH = Path("axis_saas/views/helpers.py")

# Functions to add (copied from views_school.py with correct naming)
MISSING_FUNCTIONS = """

# ========== STUDENT CONTEXT HELPERS (added by patcher) ==========

def extract_item_sales_from_remarks(remarks):
    \"\"\"Extract item sale chunks from payment remarks for analytics and detail pages.\"\"\"
    import re
    from decimal import Decimal

    text = remarks or ''
    marker_match = re.search(r'items sold\\s*:\\s*(.*)', text, flags=re.IGNORECASE)
    if not marker_match:
        marker_match = re.search(r'items sold\\s+(.*)', text, flags=re.IGNORECASE)

    candidate_text = marker_match.group(1) if marker_match else text
    pattern = re.compile(
        r'(?P<name>.+?)\\s*x\\s*(?P<qty>\\d+)\\s*@\\s*₹\\s*(?P<price>\\d+(?:\\.\\d+)?)\\s*=\\s*₹\\s*(?P<total>\\d+(?:\\.\\d+)?)',
        flags=re.IGNORECASE,
    )

    items = []
    for chunk in re.split(r';\\s*', candidate_text):
        chunk = chunk.strip().strip('.').strip()
        if not chunk:
            continue
        match = pattern.search(chunk)
        if not match:
            continue
        items.append({
            'name': match.group('name').strip(),
            'quantity': int(match.group('qty')),
            'unit_price': Decimal(match.group('price')),
            'line_total': Decimal(match.group('total')),
            'raw': chunk,
        })
    return items


def get_student_list_context(request, schema_name):
    tenant = get_tenant(request, schema_name)
    query = request.GET.get('q', '')
    grade = request.GET.get('grade', '')
    section = request.GET.get('section', '')
    status = request.GET.get('status', '')
    pending_only = request.GET.get('pending_only') == '1'
    page_number = request.GET.get('page', 1)
    with schema_context(schema_name):
        students = Student.objects.all()
        if query:
            students = students.filter(
                Q(name__icontains=query) | Q(roll_number__icontains=query) |
                Q(father_name__icontains=query) | Q(father_cnic__icontains=query) |
                Q(parent_mobile__icontains=query) | Q(grade__icontains=query)
            )
        if grade:
            students = students.filter(grade=grade)
        if section:
            students = students.filter(section=section)
        if status:
            students = students.filter(status=status)
        students = students.order_by('-enrolled_on')
        
        student_list = []
        for s in students:
            s.pending_amount = get_overall_pending(s)
            student_list.append(s)
        
        if pending_only:
            student_list = [s for s in student_list if s.pending_amount > 0]
        
        total_pending_all = sum(s.pending_amount for s in student_list)
        paginator = Paginator(student_list, 20)
        page_obj = paginator.get_page(page_number)
        
        grades = list(Student.objects.values_list('grade', flat=True).distinct().order_by('grade'))
        sections = list(Student.objects.values_list('section', flat=True).distinct().order_by('section'))
        status_choices = Student.STATUS_CHOICES
        total_active = Student.objects.filter(status='active').count()
        
    return {
        'tenant': tenant,
        'students': page_obj,
        'grades': grades,
        'sections': sections,
        'status_choices': status_choices,
        'search_query': query,
        'total_pending_all': total_pending_all,
        'total_active': total_active,
        'logo_url': tenant.school_logo.url if tenant.school_logo else None,
    }


def get_student_profile_context(request, schema_name, student_id):
    tenant = get_tenant(request, schema_name)
    page = request.GET.get('page', 1)
    search_date = request.GET.get('date', '').strip()
    with schema_context(schema_name):
        student = get_object_or_404(Student, id=student_id)
        today = date.today()
        current_month = today.month
        current_year = today.year

        fee_records_qs = student.fee_records.all().order_by('-year', '-month')
        total_fee = Decimal('0')
        for fr in fee_records_qs:
            total_fee += fr.total_amount
        fee_records = list(fee_records_qs)

        payments_qs_all = student.payments.all().order_by('payment_date')
        if search_date:
            try:
                parsed = datetime.strptime(search_date, '%Y-%m-%d').date()
                payments_qs_all = payments_qs_all.filter(payment_date=parsed)
            except ValueError:
                pass

        total_items_cost_all = Decimal('0')
        items_cost_per_payment = {}
        for p in payments_qs_all:
            items = extract_item_sales_from_remarks(p.remarks or '')
            cost = sum(item['line_total'] for item in items)
            items_cost_per_payment[p.id] = cost
            total_items_cost_all += cost

        cumulative_fee_paid = Decimal('0')
        cumulative_items_paid = Decimal('0')
        payment_list = []

        for p in payments_qs_all:
            fee_paid = sum(fr.paid_amount for fr in p.fee_records.all())
            items_cost = items_cost_per_payment.get(p.id, Decimal('0'))
            total_due_before = (total_fee - cumulative_fee_paid) + (total_items_cost_all - cumulative_items_paid)

            cumulative_fee_paid += fee_paid
            cumulative_items_paid += (p.amount - fee_paid)

            remaining_balance = (total_fee - cumulative_fee_paid) + (total_items_cost_all - cumulative_items_paid)
            if remaining_balance < 0:
                remaining_balance = Decimal('0')

            has_fee = p.fee_records.exists()
            remarks = (p.remarks or '').lower()
            has_items = 'items sold' in remarks
            if has_fee and has_items:
                p_type = 'Fee & Items'
            elif has_fee:
                p_type = 'Fee'
            elif has_items:
                p_type = 'Items'
            else:
                p_type = 'Unknown'
            p.payment_type_display = p_type

            payment_list.append({
                'payment': p,
                'fee_paid': fee_paid,
                'total_due_before': total_due_before,
                'remaining_balance': remaining_balance,
            })

        payment_list.reverse()
        paginator = Paginator(payment_list, 10)
        page_obj = paginator.get_page(page)

        total_paid = student.payments.aggregate(Sum('amount'))['amount__sum'] or 0
        fee_paid_total = sum(fr.paid_amount for fr in fee_records)
        item_purchase_total = total_paid - fee_paid_total
        pending_total = total_fee + total_items_cost_all - total_paid

        return {
            'tenant': tenant,
            'student': student,
            'fee_records': fee_records,
            'payments': page_obj,
            'total_fee': total_fee,
            'total_paid': total_paid,
            'pending_total': pending_total,
            'item_purchase_total': item_purchase_total,
            'current_month': current_month,
            'current_year': current_year,
            'logo_url': tenant.school_logo.url if tenant.school_logo else None,
            'search_date': search_date,
        }
"""

def main():
    if not HELPERS_PATH.exists():
        print(f"❌ {HELPERS_PATH} not found. Are you in the project root?")
        return

    with open(HELPERS_PATH, "r") as f:
        content = f.read()

    # Check if already patched
    if "def get_student_list_context" in content:
        print("✅ Student context functions already present. No changes needed.")
        return

    # Find a good insertion point: after the last function definition or before the final 'def'?
    # We'll insert before the last line (usually the final newline) or after the existing functions.
    # We'll find the end of the file and append.
    # But we should import necessary modules if they are not already imported.
    # The helpers.py already has imports for most things, but we need to ensure
    # that Q, Paginator, get_object_or_404, datetime, Sum, etc. are imported.
    # However, helpers.py already has many imports (from django.shortcuts import get_object_or_404 etc.)
    # We'll add them if missing, but we can just add the functions and assume imports are present.
    # Actually helpers.py imports get_object_or_404? It imports from django.shortcuts import ... yes.
    # It also has Q, Paginator, Sum, etc. So it should be fine.

    # Append the missing functions
    new_content = content + "\n" + MISSING_FUNCTIONS
    with open(HELPERS_PATH, "w") as f:
        f.write(new_content)

    print("✅ Successfully added student context functions to helpers.py")
    print("📌 Restart your Django server: python3 manage.py runserver")
    print("   The student pages should now work.")

if __name__ == "__main__":
    main()
