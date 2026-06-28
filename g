#!/usr/bin/env python3
"""
AXIS Vouchers Page Patcher
- Adds a central Vouchers listing page for all students
- Desktop: accessible from sidebar
- Mobile: accessible from "More" page
- Filters by month/year (defaults to current month)
- Shows voucher status, amount, paid, due date, and actions
"""

import os
import re
from datetime import datetime

# ========== CONFIG ==========
VIEWS_FILE = "axis_saas/views.py"
URLS_FILE = "axis_saas/public_urls.py"
TENANT_BASE = "templates/tenant/base.html"
MOBILE_MORE = "templates/mobile/more.html"
TEMPLATE_DESKTOP = "templates/tenant/vouchers.html"
TEMPLATE_MOBILE = "templates/mobile/vouchers.html"


# ========== 1. APPEND VIEWS ==========
def append_views():
    with open(VIEWS_FILE, "a") as f:
        f.write("""

# ==================== VOUCHERS LIST (Central page) ====================

@require_tenant_type(['school'])
def vouchers_list(request, schema_name):
    \"\"\"List all fee vouchers (fee records) with filters and actions.\"\"\"
    tenant = get_tenant(request, schema_name)
    with schema_context(schema_name):
        # Filter by month/year
        today = timezone.localdate()
        current_month = today.month
        current_year = today.year

        month = request.GET.get('month')
        year = request.GET.get('year')
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

        # Fetch fee records for the selected month/year
        fee_records = FeeRecord.objects.filter(month=month, year=year).select_related('student').order_by('student__name')

        # Pagination
        paginator = Paginator(fee_records, 20)
        page_number = request.GET.get('page')
        page_obj = paginator.get_page(page_number)

        # Build context
        context = {
            'tenant': tenant,
            'fee_records': page_obj,
            'month': month,
            'year': year,
            'months': list(range(1, 13)),
            'years': list(range(current_year - 5, current_year + 2)),
            'logo_url': tenant.school_logo.url if tenant.school_logo else None,
        }
        return render(request, 'tenant/vouchers.html', context)


@require_tenant_type(['school'])
def mobile_vouchers_list(request, schema_name):
    \"\"\"Mobile version of vouchers list.\"\"\"
    tenant = get_tenant(request, schema_name)
    with schema_context(schema_name):
        today = timezone.localdate()
        current_month = today.month
        current_year = today.year

        month = request.GET.get('month')
        year = request.GET.get('year')
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

        fee_records = FeeRecord.objects.filter(month=month, year=year).select_related('student').order_by('student__name')
        paginator = Paginator(fee_records, 15)
        page_number = request.GET.get('page')
        page_obj = paginator.get_page(page_number)

        context = {
            'tenant': tenant,
            'fee_records': page_obj,
            'month': month,
            'year': year,
            'months': list(range(1, 13)),
            'years': list(range(current_year - 5, current_year + 2)),
            'logo_url': tenant.school_logo.url if tenant.school_logo else None,
        }
        return render(request, 'mobile/vouchers.html', context)
""")


# ========== 2. ADD URL PATTERNS ==========
def add_urls():
    with open(URLS_FILE, "r") as f:
        content = f.read()

    # Find the section where we want to insert (after fee_structure/mobile_fee_structure maybe)
    # We'll insert right before the sell_separately route or at the end of school routes.
    # Look for '# ===== SELL SEPARATELY' and insert before that.
    insert_point = content.find("# ===== SELL SEPARATELY")
    if insert_point == -1:
        # fallback: find 'path('portal/<slug:schema_name>/sell/''
        insert_point = content.find("path('portal/<slug:schema_name>/sell/")
        if insert_point == -1:
            # fallback: insert before the final ']' of urlpatterns? we'll just append before ']'
            insert_point = content.rfind("]")
            if insert_point == -1:
                print("❌ Could not find insertion point in public_urls.py")
                return

    # Prepare the new lines
    new_lines = """
    # ===== VOUCHERS (central listing) =====
    path('portal/<slug:schema_name>/vouchers/', portal_wrapper(login_required_for_schema(vouchers_list)), name='vouchers_list'),
    path('portal/<slug:schema_name>/vouchers/mobile/', portal_wrapper(login_required_for_schema(mobile_vouchers_list)), name='mobile_vouchers_list'),

"""
    # Insert at the insertion point
    content = content[:insert_point] + new_lines + content[insert_point:]

    # Also need to import the views at top if not already imported
    # We'll add the import line if missing
    if "from .views import vouchers_list" not in content:
        # find the existing import line from .views import ...
        import_line = "from .views import "
        idx = content.find(import_line)
        if idx != -1:
            # Find the end of that import line (newline)
            end_idx = content.find("\n", idx)
            existing_imports = content[idx:end_idx]
            # Append the new view names
            content = content[:end_idx] + ", vouchers_list, mobile_vouchers_list" + content[end_idx:]
        else:
            # No existing import? add a new one after other imports
            # Find a spot after other imports
            last_import = content.rfind("from ")
            if last_import != -1:
                end_idx = content.find("\n", last_import)
                content = content[:end_idx+1] + "from .views import vouchers_list, mobile_vouchers_list\n" + content[end_idx+1:]

    with open(URLS_FILE, "w") as f:
        f.write(content)


# ========== 3. CREATE TEMPLATES ==========
def create_templates():
    # Desktop template
    desktop_html = """{% extends 'tenant/base.html' %}
{% load fee_extras %}
{% block title %}Fee Vouchers | {{ tenant.name }}{% endblock %}

{% block extra_head %}
<style>
    .filter-bar {
        display: flex;
        flex-wrap: wrap;
        gap: 1rem;
        align-items: flex-end;
        margin-bottom: 1.5rem;
        padding: 1rem 1.25rem;
        background: var(--surface);
        border-radius: var(--radius);
        border: 1px solid var(--border);
        box-shadow: var(--shadow-sm);
    }
    .filter-group {
        display: flex;
        flex-direction: column;
        gap: 0.2rem;
        flex: 0 0 auto;
    }
    .filter-group label {
        font-size: 0.7rem;
        text-transform: uppercase;
        color: var(--muted);
        font-weight: 600;
        letter-spacing: 0.3px;
    }
    .filter-group select {
        padding: 0.4rem 0.6rem;
        border-radius: 0.5rem;
        border: 1px solid var(--border);
        background: var(--surface-alt);
        color: var(--text);
    }
    .btn-filter {
        padding: 0.4rem 1rem;
        border-radius: 2rem;
        background: var(--primary);
        color: white;
        border: none;
        cursor: pointer;
        font-weight: 600;
    }
    .btn-filter:hover {
        background: var(--primary-dark);
    }
    .btn-reset {
        padding: 0.4rem 1rem;
        border-radius: 2rem;
        background: var(--surface-alt);
        color: var(--text);
        border: 1px solid var(--border);
        cursor: pointer;
    }
    .voucher-table {
        width: 100%;
        border-collapse: collapse;
    }
    .voucher-table th, .voucher-table td {
        padding: 0.75rem 0.5rem;
        text-align: left;
        border-bottom: 1px solid var(--border);
        font-size: 0.85rem;
    }
    .voucher-table th {
        background: var(--surface-alt);
        font-weight: 600;
        color: var(--muted);
        text-transform: uppercase;
        font-size: 0.7rem;
    }
    .status-badge {
        display: inline-block;
        padding: 0.2rem 0.6rem;
        border-radius: 2rem;
        font-size: 0.7rem;
        font-weight: 600;
    }
    .status-pending { background: #fef3c7; color: #92400e; }
    .status-partial { background: #dbeafe; color: #1e40af; }
    .status-paid { background: #d1fae5; color: #065f46; }
    .status-overdue { background: #fee2e2; color: #991b1b; }
    .action-btns {
        display: flex;
        gap: 0.3rem;
        align-items: center;
        flex-wrap: wrap;
    }
    .btn-sm {
        background: var(--primary);
        color: white;
        padding: 0.15rem 0.6rem;
        border-radius: 2rem;
        font-size: 0.7rem;
        text-decoration: none;
        display: inline-block;
        border: none;
        cursor: pointer;
        transition: 0.2s;
    }
    .btn-sm:hover {
        background: var(--primary-dark);
    }
    .btn-sm.outline {
        background: transparent;
        color: var(--primary);
        border: 1px solid var(--primary);
    }
    .btn-sm.outline:hover {
        background: var(--primary);
        color: white;
    }
    .pagination {
        display: flex;
        justify-content: center;
        gap: 0.5rem;
        margin-top: 1.5rem;
        flex-wrap: wrap;
    }
    .page-link {
        padding: 0.3rem 0.8rem;
        border-radius: 2rem;
        border: 1px solid var(--border);
        background: var(--surface);
        text-decoration: none;
        color: var(--text);
        font-size: 0.8rem;
    }
    .page-link:hover {
        background: var(--primary);
        color: white;
    }
    .page-link.active {
        background: var(--primary);
        color: white;
    }
    .empty-row {
        text-align: center;
        padding: 2rem;
        color: var(--muted);
    }
    @media (max-width: 768px) {
        .filter-bar {
            flex-direction: column;
            align-items: stretch;
        }
        .voucher-table th, .voucher-table td {
            padding: 0.4rem 0.3rem;
            font-size: 0.75rem;
        }
    }
</style>
{% endblock %}

{% block body %}
<div class="page-header">
    <div>
        <h1 class="page-title">Fee Vouchers</h1>
        <p class="page-desc">View all generated fee vouchers for students</p>
    </div>
</div>

<!-- Filter Bar -->
<div class="filter-bar">
    <form method="get" class="filter-form" style="display: flex; flex-wrap: wrap; gap: 1rem; align-items: flex-end; width: 100%;">
        <div class="filter-group">
            <label>Month</label>
            <select name="month">
                {% for m in months %}
                <option value="{{ m }}" {% if m == month %}selected{% endif %}>{{ m }}</option>
                {% endfor %}
            </select>
        </div>
        <div class="filter-group">
            <label>Year</label>
            <select name="year">
                {% for y in years %}
                <option value="{{ y }}" {% if y == year %}selected{% endif %}>{{ y }}</option>
                {% endfor %}
            </select>
        </div>
        <div class="filter-group">
            <button type="submit" class="btn-filter">Apply</button>
        </div>
        <div class="filter-group">
            <a href="{% url 'vouchers_list' schema_name=tenant.schema_name %}" class="btn-reset">Reset to Current</a>
        </div>
    </form>
</div>

<!-- Vouchers Table -->
<div class="table-card" style="background: var(--surface); border-radius: var(--radius); border: 1px solid var(--border); overflow-x: auto;">
    <table class="voucher-table">
        <thead>
            <tr>
                <th>Student</th>
                <th>Roll No</th>
                <th>Grade</th>
                <th>Month/Year</th>
                <th>Amount</th>
                <th>Paid</th>
                <th>Due Date</th>
                <th>Status</th>
                <th>Actions</th>
            </tr>
        </thead>
        <tbody>
            {% for fr in fee_records %}
            <tr>
                <td><strong>{{ fr.student.name }}</strong></td>
                <td>{{ fr.student.roll_number }}</td>
                <td>{{ fr.student.grade }} - {{ fr.student.section }}</td>
                <td>{{ fr.month }}/{{ fr.year }}</td>
                <td>₹{{ fr.amount|floatformat:2 }}</td>
                <td>₹{{ fr.paid_amount|floatformat:2 }}</td>
                <td>{{ fr.due_date|date:"Y-m-d" }}</td>
                <td><span class="status-badge status-{{ fr.status }}">{{ fr.get_status_display }}</span></td>
                <td class="action-btns">
                    <button class="btn-sm" data-open-voucher data-student-id="{{ fr.student.id }}" data-schema-name="{{ tenant.schema_name }}">View</button>
                    <a href="{% url 'fee_collection' schema_name=tenant.schema_name student_id=fr.student.id %}" class="btn-sm outline">Collect</a>
                </td>
            </tr>
            {% empty %}
            <tr><td colspan="9" class="empty-row">No fee records found for this month.</td></tr>
            {% endfor %}
        </tbody>
    </table>
</div>

<!-- Pagination -->
{% if fee_records.has_other_pages %}
<div class="pagination">
    {% if fee_records.has_previous %}
        <a href="?page=1&month={{ month }}&year={{ year }}" class="page-link">&laquo; First</a>
        <a href="?page={{ fee_records.previous_page_number }}&month={{ month }}&year={{ year }}" class="page-link">Previous</a>
    {% endif %}
    <span class="page-link active">{{ fee_records.number }}</span>
    {% if fee_records.has_next %}
        <a href="?page={{ fee_records.next_page_number }}&month={{ month }}&year={{ year }}" class="page-link">Next</a>
        <a href="?page={{ fee_records.paginator.num_pages }}&month={{ month }}&year={{ year }}" class="page-link">Last &raquo;</a>
    {% endif %}
</div>
{% endif %}

{% include "tenant/voucher_modal.html" %}
{% endblock %}
"""

    # Mobile template
    mobile_html = """{% extends 'mobile/base.html' %}
{% load fee_extras %}
{% block title %}Fee Vouchers | {{ tenant.name }}{% endblock %}

{% block extra_head %}
<style>
    .filter-bar {
        display: flex;
        flex-wrap: wrap;
        gap: 0.5rem;
        align-items: center;
        background: var(--surface);
        border-radius: 1.5rem;
        padding: 0.5rem 1rem;
        margin-bottom: 1rem;
        border: 1px solid var(--border);
    }
    .filter-bar select {
        flex: 1;
        padding: 0.4rem 0.6rem;
        border-radius: 2rem;
        border: 1px solid var(--border);
        background: var(--surface-alt);
        font-size: 0.8rem;
    }
    .filter-bar button {
        padding: 0.4rem 1rem;
        border-radius: 2rem;
        background: var(--primary);
        color: white;
        border: none;
        font-weight: 600;
        cursor: pointer;
    }
    .filter-bar .reset-link {
        padding: 0.4rem 0.8rem;
        color: var(--muted);
        text-decoration: none;
        font-size: 0.8rem;
    }
    .voucher-card {
        background: var(--surface);
        border-radius: 1.25rem;
        padding: 0.75rem;
        margin-bottom: 0.75rem;
        border: 1px solid var(--border);
        box-shadow: 0 2px 8px rgba(0,0,0,0.04);
    }
    .voucher-card .top-row {
        display: flex;
        justify-content: space-between;
        align-items: center;
    }
    .voucher-card .student-name {
        font-weight: 700;
        font-size: 1rem;
    }
    .voucher-card .student-meta {
        font-size: 0.8rem;
        color: var(--muted);
    }
    .voucher-card .amount {
        font-weight: 700;
        color: var(--primary);
    }
    .voucher-card .status-badge {
        display: inline-block;
        padding: 0.2rem 0.6rem;
        border-radius: 2rem;
        font-size: 0.65rem;
        font-weight: 600;
    }
    .status-pending { background: #fef3c7; color: #92400e; }
    .status-partial { background: #dbeafe; color: #1e40af; }
    .status-paid { background: #d1fae5; color: #065f46; }
    .status-overdue { background: #fee2e2; color: #991b1b; }
    .voucher-card .actions {
        display: flex;
        gap: 0.5rem;
        margin-top: 0.5rem;
        justify-content: flex-end;
    }
    .voucher-card .actions button, .voucher-card .actions a {
        padding: 0.2rem 0.8rem;
        border-radius: 2rem;
        font-size: 0.7rem;
        font-weight: 600;
        text-decoration: none;
        border: none;
        cursor: pointer;
    }
    .btn-view {
        background: var(--primary);
        color: white;
    }
    .btn-collect {
        background: transparent;
        color: var(--primary);
        border: 1px solid var(--primary);
    }
    .pagination {
        display: flex;
        justify-content: center;
        gap: 0.3rem;
        margin-top: 1rem;
    }
    .page-link {
        padding: 0.3rem 0.7rem;
        border-radius: 2rem;
        border: 1px solid var(--border);
        background: var(--surface);
        text-decoration: none;
        color: var(--text);
        font-size: 0.7rem;
    }
    .page-link.active {
        background: var(--primary);
        color: white;
    }
    .empty-state {
        text-align: center;
        padding: 2rem 1rem;
        color: var(--muted);
    }
</style>
{% endblock %}

{% block body %}
<div class="page-header">
    <h1 class="page-title">Fee Vouchers</h1>
    <p class="page-desc">All generated vouchers</p>
</div>

<!-- Filter -->
<div class="filter-bar">
    <form method="get" style="display: flex; flex-wrap: wrap; gap: 0.5rem; width: 100%; align-items: center;">
        <select name="month">
            {% for m in months %}
            <option value="{{ m }}" {% if m == month %}selected{% endif %}>{{ m }}</option>
            {% endfor %}
        </select>
        <select name="year">
            {% for y in years %}
            <option value="{{ y }}" {% if y == year %}selected{% endif %}>{{ y }}</option>
            {% endfor %}
        </select>
        <button type="submit">Apply</button>
        <a href="{% url 'mobile_vouchers_list' schema_name=tenant.schema_name %}" class="reset-link">Reset</a>
    </form>
</div>

<!-- Voucher Cards -->
<div class="voucher-list">
    {% for fr in fee_records %}
    <div class="voucher-card">
        <div class="top-row">
            <div>
                <div class="student-name">{{ fr.student.name }}</div>
                <div class="student-meta">{{ fr.student.roll_number }} • {{ fr.student.grade }} - {{ fr.student.section }}</div>
            </div>
            <div>
                <span class="status-badge status-{{ fr.status }}">{{ fr.get_status_display }}</span>
            </div>
        </div>
        <div style="display: flex; justify-content: space-between; margin-top: 0.3rem;">
            <span>{{ fr.month }}/{{ fr.year }}</span>
            <span class="amount">₹{{ fr.amount|floatformat:2 }}</span>
        </div>
        <div style="display: flex; justify-content: space-between; font-size:0.75rem; color:var(--muted);">
            <span>Paid: ₹{{ fr.paid_amount|floatformat:2 }}</span>
            <span>Due: {{ fr.due_date|date:"Y-m-d" }}</span>
        </div>
        <div class="actions">
            <button class="btn-view" data-open-voucher data-student-id="{{ fr.student.id }}" data-schema-name="{{ tenant.schema_name }}">View</button>
            <a href="{% url 'mobile_fee_collection' schema_name=tenant.schema_name student_id=fr.student.id %}" class="btn-collect">Collect</a>
        </div>
    </div>
    {% empty %}
    <div class="empty-state">No vouchers for this month.</div>
    {% endfor %}
</div>

<!-- Pagination -->
{% if fee_records.has_other_pages %}
<div class="pagination">
    {% if fee_records.has_previous %}
        <a href="?page=1&month={{ month }}&year={{ year }}" class="page-link">&laquo;</a>
        <a href="?page={{ fee_records.previous_page_number }}&month={{ month }}&year={{ year }}" class="page-link">‹</a>
    {% endif %}
    <span class="page-link active">{{ fee_records.number }}</span>
    {% if fee_records.has_next %}
        <a href="?page={{ fee_records.next_page_number }}&month={{ month }}&year={{ year }}" class="page-link">›</a>
        <a href="?page={{ fee_records.paginator.num_pages }}&month={{ month }}&year={{ year }}" class="page-link">&raquo;</a>
    {% endif %}
</div>
{% endif %}

{% include "tenant/voucher_modal.html" %}
{% endblock %}
"""

    # Write templates
    with open(TEMPLATE_DESKTOP, "w") as f:
        f.write(desktop_html)

    with open(TEMPLATE_MOBILE, "w") as f:
        f.write(mobile_html)

    print("✅ Templates created.")


# ========== 4. MODIFY SIDEBAR (desktop) ==========
def modify_sidebar():
    with open(TENANT_BASE, "r") as f:
        content = f.read()

    # Find the Fee Structure nav item and insert a new nav item after it.
    # We'll look for the block that contains fee_structure.
    # There is a conditional: {% if tenant|has_feature:'fee_structure' %}
    # We'll insert after that block.
    pattern = r"({% if tenant\|has_feature:'fee_structure' %}.*?</a>\s*{% endif %})"
    match = re.search(pattern, content, re.DOTALL)
    if match:
        block = match.group(1)
        # Insert a new nav item after the block
        new_item = """
                {% if tenant.tenant_type == 'school' %}
                <a href="{% url 'vouchers_list' schema_name=tenant.schema_name %}" class="nav-item">
                    <svg class="nav-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path d="M4 4v16h16M8 12h8M12 8v8"/></svg>
                    <span>Vouchers</span>
                </a>
                {% endif %}
"""
        # Insert after the block, but within the same indentation level as other nav items.
        # We'll insert right after the closing </a> of the fee_structure block.
        # But we need to be careful: the block may have multiple lines.
        # We'll replace the matched block with itself plus the new item.
        new_block = block + new_item
        content = content.replace(block, new_block)
        with open(TENANT_BASE, "w") as f:
            f.write(content)
        print("✅ Sidebar updated with Vouchers link.")
    else:
        print("⚠️ Could not find fee_structure nav item in sidebar. Vouchers link not added.")


# ========== 5. MODIFY MOBILE MORE PAGE ==========
def modify_mobile_more():
    with open(MOBILE_MORE, "r") as f:
        content = f.read()

    # Find the more-grid div and add a new card.
    # Look for <div class="more-grid"> and insert after the first card or at the end.
    # We'll insert right after the "Sell Separately" card (first card) or before "Add Student".
    # We'll find the <div class="more-grid"> and insert a card at the beginning or end.
    pattern = r'(<div class="more-grid">\s*)'
    match = re.search(pattern, content)
    if match:
        new_card = """
    <!-- Fee Vouchers -->
    <a href="{% url 'mobile_vouchers_list' schema_name=tenant.schema_name %}" class="more-card">
        <div class="icon-wrapper">
            <svg viewBox="0 0 24 24"><path d="M4 4v16h16M8 12h8M12 8v8"/></svg>
        </div>
        <h3>Fee Vouchers</h3>
        <p>View all student fee vouchers.</p>
    </a>
"""
        # Insert after the opening more-grid div
        content = content.replace(match.group(1), match.group(1) + new_card)
        with open(MOBILE_MORE, "w") as f:
            f.write(content)
        print("✅ Mobile More page updated with Vouchers card.")
    else:
        print("⚠️ Could not find more-grid in mobile more.html. Vouchers card not added.")


# ========== MAIN ==========
def main():
    print("🚀 AXIS Vouchers Page Patcher")
    print("=============================")
    append_views()
    add_urls()
    create_templates()
    modify_sidebar()
    modify_mobile_more()
    print("\n✅ All changes applied successfully!")
    print("   Restart your server and visit /portal/<schema>/vouchers/")

if __name__ == "__main__":
    main()
