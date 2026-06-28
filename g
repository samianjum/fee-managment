#!/usr/bin/env python3
"""
Patcher to add tabbed navigation to fee voucher pages.
Run: python3 patcher_tabs.py
"""

import os
from pathlib import Path

BASE_DIR = Path(__file__).parent

TEMPLATE_TENANT = BASE_DIR / "templates" / "tenant" / "vouchers.html"
TEMPLATE_MOBILE = BASE_DIR / "templates" / "mobile" / "vouchers.html"

# ----------------------------------------------------------------------------
# New desktop template (tenant/vouchers.html)
# ----------------------------------------------------------------------------
NEW_TENANT_TEMPLATE = '''{% extends 'tenant/base.html' %}
{% load fee_extras %}
{% block title %}Fee Vouchers | {{ tenant.name }}{% endblock %}

{% block extra_head %}
<style>
    /* ----- Filters & Search ----- */
    .filter-bar {
        display: flex;
        flex-wrap: wrap;
        gap: 0.75rem;
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
        flex: 1;
        min-width: 120px;
    }
    .filter-group label {
        font-size: 0.7rem;
        text-transform: uppercase;
        color: var(--muted);
        font-weight: 600;
        letter-spacing: 0.3px;
    }
    .filter-group input, .filter-group select {
        padding: 0.4rem 0.6rem;
        border-radius: 0.5rem;
        border: 1px solid var(--border);
        background: var(--surface-alt);
        color: var(--text);
        font-size: 0.85rem;
    }
    .filter-actions {
        display: flex;
        gap: 0.5rem;
        flex-wrap: wrap;
    }
    .btn-filter, .btn-reset {
        padding: 0.4rem 1rem;
        border-radius: 2rem;
        font-weight: 600;
        border: none;
        cursor: pointer;
    }
    .btn-filter { background: var(--primary); color: white; }
    .btn-filter:hover { background: var(--primary-dark); }
    .btn-reset { background: var(--surface-alt); color: var(--text); border: 1px solid var(--border); }

    /* ----- Tab Bar ----- */
    .tab-bar {
        display: flex;
        gap: 0.5rem;
        margin-bottom: 1.5rem;
        border-bottom: 2px solid var(--border);
        padding-bottom: 0.5rem;
        flex-wrap: wrap;
        background: var(--surface);
        border-radius: var(--radius);
        padding: 0.5rem 1rem;
        border: 1px solid var(--border);
    }
    .tab-btn {
        background: transparent;
        border: none;
        padding: 0.5rem 1.2rem;
        border-radius: 2rem;
        font-weight: 600;
        font-size: 0.85rem;
        color: var(--muted);
        cursor: pointer;
        transition: var(--transition);
        display: flex;
        align-items: center;
        gap: 0.4rem;
    }
    .tab-btn:hover {
        background: var(--surface-alt);
        color: var(--text);
    }
    .tab-btn.active {
        background: var(--primary);
        color: white;
        box-shadow: 0 2px 8px rgba(59,130,246,0.3);
    }
    .tab-btn .badge {
        background: var(--surface-alt);
        color: var(--text);
        padding: 0.1rem 0.5rem;
        border-radius: 2rem;
        font-size: 0.7rem;
        font-weight: 600;
    }
    .tab-btn.active .badge {
        background: rgba(255,255,255,0.2);
        color: white;
    }

    /* ----- Section Cards (hidden by default, shown by tab) ----- */
    .section-card {
        background: var(--surface);
        border-radius: var(--radius);
        border: 1px solid var(--border);
        margin-bottom: 2rem;
        overflow: hidden;
        display: none;
    }
    .section-card.active {
        display: block;
    }
    .section-header {
        padding: 0.75rem 1.25rem;
        background: var(--surface-alt);
        border-bottom: 1px solid var(--border);
        display: flex;
        justify-content: space-between;
        align-items: center;
    }
    .section-header h3 {
        margin: 0;
        font-size: 1.1rem;
        font-weight: 600;
    }
    .section-header .badge {
        background: var(--primary);
        color: white;
        padding: 0.15rem 0.7rem;
        border-radius: 2rem;
        font-size: 0.75rem;
        font-weight: 600;
    }
    .voucher-table {
        width: 100%;
        border-collapse: collapse;
        font-size: 0.85rem;
    }
    .voucher-table th, .voucher-table td {
        padding: 0.65rem 0.5rem;
        text-align: left;
        border-bottom: 1px solid var(--border);
        vertical-align: middle;
    }
    .voucher-table th {
        background: var(--surface-alt);
        font-weight: 600;
        color: var(--muted);
        text-transform: uppercase;
        font-size: 0.7rem;
        white-space: nowrap;
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
    .status-missing { background: #e5e7eb; color: #374151; }
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
    .btn-sm:hover { background: var(--primary-dark); }
    .btn-sm.outline { background: transparent; color: var(--primary); border: 1px solid var(--primary); }
    .btn-sm.outline:hover { background: var(--primary); color: white; }
    .btn-sm.warning { background: #f59e0b; color: white; }
    .btn-sm.warning:hover { background: #d97706; }

    .empty-row { text-align: center; padding: 1.5rem; color: var(--muted); }
    .missing-reason { font-size: 0.7rem; color: var(--muted); margin-top: 0.1rem; }

    /* ----- Pagination ----- */
    .pagination {
        display: flex;
        justify-content: center;
        gap: 0.5rem;
        margin: 1rem 0 0.5rem;
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
    .page-link:hover { background: var(--primary); color: white; }
    .page-link.active { background: var(--primary); color: white; }
    .page-link.disabled { opacity: 0.4; pointer-events: none; }

    @media (max-width: 768px) {
        .filter-bar { flex-direction: column; align-items: stretch; }
        .voucher-table th, .voucher-table td { padding: 0.4rem 0.3rem; font-size: 0.75rem; }
        .action-btns .btn-sm { font-size: 0.65rem; }
        .tab-bar { flex-wrap: nowrap; overflow-x: auto; -webkit-overflow-scrolling: touch; }
        .tab-btn { white-space: nowrap; }
    }
</style>
{% endblock %}

{% block body %}
<div class="page-header">
    <div>
        <h1 class="page-title">Fee Vouchers</h1>
        <p class="page-desc">All fee records grouped by status</p>
    </div>
    <div>
        <a href="{% url 'fee_settings' schema_name=tenant.schema_name %}" class="btn-primary">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/></svg>
            Generate All Fees
        </a>
    </div>
</div>

<!-- Filter Bar (without status) -->
<div class="filter-bar">
    <form method="get" class="filter-form" style="display: flex; flex-wrap: wrap; gap: 0.75rem; width: 100%; align-items: flex-end;">
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
        <div class="filter-group" style="flex: 2; min-width: 180px;">
            <label>Search</label>
            <input type="text" name="search" value="{{ search_query }}" placeholder="Name, Roll, Father, Grade, Section">
        </div>
        <div class="filter-actions">
            <button type="submit" class="btn-filter">Apply</button>
            <a href="{% url 'vouchers_list' schema_name=tenant.schema_name %}" class="btn-reset">Reset</a>
        </div>
    </form>
</div>

<!-- Tab Bar -->
<div class="tab-bar" id="tabBar">
    <button class="tab-btn active" data-tab="pending">
        Pending <span class="badge">{{ pending_page.paginator.count }}</span>
    </button>
    <button class="tab-btn" data-tab="partial">
        Partially Paid <span class="badge">{{ partial_page.paginator.count }}</span>
    </button>
    <button class="tab-btn" data-tab="paid">
        Paid <span class="badge">{{ paid_page.paginator.count }}</span>
    </button>
    <button class="tab-btn" data-tab="missing">
        Not Generated <span class="badge">{{ missing_page.paginator.count }}</span>
    </button>
</div>

<!-- Section: Pending -->
<div class="section-card active" id="section-pending">
    <div class="section-header">
        <h3>Pending</h3>
        <span class="badge">{{ pending_page.paginator.count }}</span>
    </div>
    <div style="overflow-x: auto;">
        <table class="voucher-table">
            <thead>
                <tr>
                    <th>Student</th>
                    <th>Roll No</th>
                    <th>Grade/Section</th>
                    <th>Month/Year</th>
                    <th>Amount</th>
                    <th>Paid</th>
                    <th>Due Date</th>
                    <th>Status</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                {% for item in pending_page %}
                <tr>
                    <td><strong>{{ item.student.name }}</strong></td>
                    <td>{{ item.student.roll_number }}</td>
                    <td>{{ item.student.grade }} - {{ item.student.section }}</td>
                    <td>{{ item.month }}/{{ item.year }}</td>
                    <td>₹{{ item.amount|floatformat:2 }}</td>
                    <td>₹{{ item.paid|floatformat:2 }}</td>
                    <td>{% if item.due_date %}{{ item.due_date|date:"Y-m-d" }}{% else %}—{% endif %}</td>
                    <td><span class="status-badge status-{{ item.status }}">{{ item.get_status_display|default:item.status }}</span></td>
                    <td class="action-btns">
                        <a href="{% url 'student_profile' schema_name=tenant.schema_name student_id=item.student.id %}" class="btn-sm outline" title="Profile">👤</a>
                        {% if item.status != 'paid' %}
                        <a href="{% url 'fee_collection' schema_name=tenant.schema_name student_id=item.student.id %}" class="btn-sm">Collect</a>
                        {% endif %}
                    </td>
                </tr>
                {% empty %}
                <tr><td colspan="9" class="empty-row">No pending vouchers.</td></tr>
                {% endfor %}
            </tbody>
        </table>
        {% if pending_page.has_other_pages %}
        <div class="pagination">
            {% if pending_page.has_previous %}
                <a href="?tab=pending&pending_page=1&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">&laquo;</a>
                <a href="?tab=pending&pending_page={{ pending_page.previous_page_number }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">‹</a>
            {% endif %}
            <span class="page-link active">{{ pending_page.number }}</span>
            {% if pending_page.has_next %}
                <a href="?tab=pending&pending_page={{ pending_page.next_page_number }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">›</a>
                <a href="?tab=pending&pending_page={{ pending_page.paginator.num_pages }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">&raquo;</a>
            {% endif %}
        </div>
        {% endif %}
    </div>
</div>

<!-- Section: Partial -->
<div class="section-card" id="section-partial">
    <div class="section-header">
        <h3>Partially Paid</h3>
        <span class="badge">{{ partial_page.paginator.count }}</span>
    </div>
    <div style="overflow-x: auto;">
        <table class="voucher-table">
            <thead>
                <tr>
                    <th>Student</th>
                    <th>Roll No</th>
                    <th>Grade/Section</th>
                    <th>Month/Year</th>
                    <th>Amount</th>
                    <th>Paid</th>
                    <th>Due Date</th>
                    <th>Status</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                {% for item in partial_page %}
                <tr>
                    <td><strong>{{ item.student.name }}</strong></td>
                    <td>{{ item.student.roll_number }}</td>
                    <td>{{ item.student.grade }} - {{ item.student.section }}</td>
                    <td>{{ item.month }}/{{ item.year }}</td>
                    <td>₹{{ item.amount|floatformat:2 }}</td>
                    <td>₹{{ item.paid|floatformat:2 }}</td>
                    <td>{% if item.due_date %}{{ item.due_date|date:"Y-m-d" }}{% else %}—{% endif %}</td>
                    <td><span class="status-badge status-{{ item.status }}">{{ item.get_status_display|default:item.status }}</span></td>
                    <td class="action-btns">
                        <a href="{% url 'student_profile' schema_name=tenant.schema_name student_id=item.student.id %}" class="btn-sm outline" title="Profile">👤</a>
                        <a href="{% url 'fee_collection' schema_name=tenant.schema_name student_id=item.student.id %}" class="btn-sm">Collect</a>
                    </td>
                </tr>
                {% empty %}
                <tr><td colspan="9" class="empty-row">No partially paid vouchers.</td></tr>
                {% endfor %}
            </tbody>
        </table>
        {% if partial_page.has_other_pages %}
        <div class="pagination">
            {% if partial_page.has_previous %}
                <a href="?tab=partial&partial_page=1&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">&laquo;</a>
                <a href="?tab=partial&partial_page={{ partial_page.previous_page_number }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">‹</a>
            {% endif %}
            <span class="page-link active">{{ partial_page.number }}</span>
            {% if partial_page.has_next %}
                <a href="?tab=partial&partial_page={{ partial_page.next_page_number }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">›</a>
                <a href="?tab=partial&partial_page={{ partial_page.paginator.num_pages }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">&raquo;</a>
            {% endif %}
        </div>
        {% endif %}
    </div>
</div>

<!-- Section: Paid -->
<div class="section-card" id="section-paid">
    <div class="section-header">
        <h3>Paid</h3>
        <span class="badge">{{ paid_page.paginator.count }}</span>
    </div>
    <div style="overflow-x: auto;">
        <table class="voucher-table">
            <thead>
                <tr>
                    <th>Student</th>
                    <th>Roll No</th>
                    <th>Grade/Section</th>
                    <th>Month/Year</th>
                    <th>Amount</th>
                    <th>Paid</th>
                    <th>Due Date</th>
                    <th>Status</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                {% for item in paid_page %}
                <tr>
                    <td><strong>{{ item.student.name }}</strong></td>
                    <td>{{ item.student.roll_number }}</td>
                    <td>{{ item.student.grade }} - {{ item.student.section }}</td>
                    <td>{{ item.month }}/{{ item.year }}</td>
                    <td>₹{{ item.amount|floatformat:2 }}</td>
                    <td>₹{{ item.paid|floatformat:2 }}</td>
                    <td>{% if item.due_date %}{{ item.due_date|date:"Y-m-d" }}{% else %}—{% endif %}</td>
                    <td><span class="status-badge status-{{ item.status }}">{{ item.get_status_display|default:item.status }}</span></td>
                    <td class="action-btns">
                        <a href="{% url 'student_profile' schema_name=tenant.schema_name student_id=item.student.id %}" class="btn-sm outline" title="Profile">👤</a>
                    </td>
                </tr>
                {% empty %}
                <tr><td colspan="9" class="empty-row">No paid vouchers.</td></tr>
                {% endfor %}
            </tbody>
        </table>
        {% if paid_page.has_other_pages %}
        <div class="pagination">
            {% if paid_page.has_previous %}
                <a href="?tab=paid&paid_page=1&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">&laquo;</a>
                <a href="?tab=paid&paid_page={{ paid_page.previous_page_number }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">‹</a>
            {% endif %}
            <span class="page-link active">{{ paid_page.number }}</span>
            {% if paid_page.has_next %}
                <a href="?tab=paid&paid_page={{ paid_page.next_page_number }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">›</a>
                <a href="?tab=paid&paid_page={{ paid_page.paginator.num_pages }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">&raquo;</a>
            {% endif %}
        </div>
        {% endif %}
    </div>
</div>

<!-- Section: Not Generated -->
<div class="section-card" id="section-missing">
    <div class="section-header">
        <h3>Not Generated</h3>
        <span class="badge">{{ missing_page.paginator.count }}</span>
    </div>
    <div style="overflow-x: auto;">
        <table class="voucher-table">
            <thead>
                <tr>
                    <th>Student</th>
                    <th>Roll No</th>
                    <th>Grade/Section</th>
                    <th>Month/Year</th>
                    <th>Amount</th>
                    <th>Paid</th>
                    <th>Due Date</th>
                    <th>Status</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                {% for item in missing_page %}
                <tr>
                    <td><strong>{{ item.student.name }}</strong></td>
                    <td>{{ item.student.roll_number }}</td>
                    <td>{{ item.student.grade }} - {{ item.student.section }}</td>
                    <td>{{ item.month }}/{{ item.year }}</td>
                    <td>—</td>
                    <td>—</td>
                    <td>—</td>
                    <td>
                        <span class="status-badge status-missing">Missing</span>
                        <div class="missing-reason">{{ item.reason }}</div>
                    </td>
                    <td class="action-btns">
                        <a href="{% url 'student_profile' schema_name=tenant.schema_name student_id=item.student.id %}" class="btn-sm outline" title="Profile">👤</a>
                        {% if is_current_month %}
                        <a href="{% url 'student_profile' schema_name=tenant.schema_name student_id=item.student.id %}?open_voucher=1" class="btn-sm warning">Generate</a>
                        {% endif %}
                    </td>
                </tr>
                {% empty %}
                <tr><td colspan="9" class="empty-row">All active students have vouchers for this month.</td></tr>
                {% endfor %}
            </tbody>
        </table>
        {% if missing_page.has_other_pages %}
        <div class="pagination">
            {% if missing_page.has_previous %}
                <a href="?tab=missing&missing_page=1&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">&laquo;</a>
                <a href="?tab=missing&missing_page={{ missing_page.previous_page_number }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">‹</a>
            {% endif %}
            <span class="page-link active">{{ missing_page.number }}</span>
            {% if missing_page.has_next %}
                <a href="?tab=missing&missing_page={{ missing_page.next_page_number }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">›</a>
                <a href="?tab=missing&missing_page={{ missing_page.paginator.num_pages }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">&raquo;</a>
            {% endif %}
        </div>
        {% endif %}
    </div>
</div>

{% include "tenant/voucher_modal.html" %}

<script>
    (function() {
        // Get tab from URL parameter
        const urlParams = new URLSearchParams(window.location.search);
        let activeTab = urlParams.get('tab') || 'pending';

        // If no tab parameter, default to the first tab that has items
        // But we'll just set to 'pending' if not specified.

        // Get all tab buttons and sections
        const tabBtns = document.querySelectorAll('.tab-btn');
        const sections = {
            pending: document.getElementById('section-pending'),
            partial: document.getElementById('section-partial'),
            paid: document.getElementById('section-paid'),
            missing: document.getElementById('section-missing')
        };

        function activateTab(tabId) {
            // Update buttons
            tabBtns.forEach(btn => {
                btn.classList.toggle('active', btn.dataset.tab === tabId);
            });
            // Update sections
            Object.keys(sections).forEach(key => {
                sections[key].classList.toggle('active', key === tabId);
            });
            // Update URL without reload
            const url = new URL(window.location);
            url.searchParams.set('tab', tabId);
            window.history.replaceState({}, '', url);
        }

        // Add click listeners
        tabBtns.forEach(btn => {
            btn.addEventListener('click', function(e) {
                const tabId = this.dataset.tab;
                activateTab(tabId);
            });
        });

        // Activate the tab from URL or default
        if (activeTab && sections[activeTab]) {
            activateTab(activeTab);
        } else {
            // fallback to pending
            activateTab('pending');
        }
    })();
</script>
{% endblock %}
'''

# ----------------------------------------------------------------------------
# New mobile template (mobile/vouchers.html)
# ----------------------------------------------------------------------------
NEW_MOBILE_TEMPLATE = '''{% extends 'mobile/base.html' %}
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
    .filter-bar select, .filter-bar input {
        flex: 1;
        padding: 0.4rem 0.6rem;
        border-radius: 2rem;
        border: 1px solid var(--border);
        background: var(--surface-alt);
        font-size: 0.8rem;
        min-width: 60px;
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

    /* Mobile Tab Bar */
    .tab-bar {
        display: flex;
        gap: 0.4rem;
        margin-bottom: 1rem;
        overflow-x: auto;
        -webkit-overflow-scrolling: touch;
        padding: 0.25rem 0.25rem 0.5rem;
        scroll-snap-type: x mandatory;
        background: var(--surface);
        border-radius: 1.25rem;
        border: 1px solid var(--border);
        padding: 0.5rem;
        flex-wrap: nowrap;
    }
    .tab-bar .tab-btn {
        flex: 0 0 auto;
        background: transparent;
        border: none;
        padding: 0.4rem 1rem;
        border-radius: 2rem;
        font-weight: 600;
        font-size: 0.75rem;
        color: var(--muted);
        cursor: pointer;
        transition: var(--transition);
        scroll-snap-align: start;
        white-space: nowrap;
        display: flex;
        align-items: center;
        gap: 0.3rem;
    }
    .tab-bar .tab-btn.active {
        background: var(--primary);
        color: white;
        box-shadow: 0 2px 8px rgba(59,130,246,0.3);
    }
    .tab-bar .tab-btn .badge {
        background: var(--surface-alt);
        color: var(--text);
        padding: 0.05rem 0.4rem;
        border-radius: 2rem;
        font-size: 0.6rem;
        font-weight: 600;
    }
    .tab-bar .tab-btn.active .badge {
        background: rgba(255,255,255,0.2);
        color: white;
    }

    .section-card {
        background: var(--surface);
        border-radius: 1.25rem;
        border: 1px solid var(--border);
        margin-bottom: 1.25rem;
        overflow: hidden;
        display: none;
    }
    .section-card.active {
        display: block;
    }
    .section-header {
        padding: 0.6rem 1rem;
        background: var(--surface-alt);
        border-bottom: 1px solid var(--border);
        display: flex;
        justify-content: space-between;
        align-items: center;
    }
    .section-header h4 {
        margin: 0;
        font-size: 0.95rem;
        font-weight: 600;
    }
    .section-header .badge {
        background: var(--primary);
        color: white;
        padding: 0.1rem 0.6rem;
        border-radius: 2rem;
        font-size: 0.7rem;
        font-weight: 600;
    }

    .voucher-card {
        background: var(--surface);
        border-radius: 1rem;
        padding: 0.75rem;
        margin: 0.5rem 0.75rem;
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
    .status-badge {
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
    .status-missing { background: #e5e7eb; color: #374151; }
    .voucher-card .actions {
        display: flex;
        gap: 0.5rem;
        margin-top: 0.5rem;
        flex-wrap: wrap;
    }
    .voucher-card .actions a, .voucher-card .actions button {
        padding: 0.2rem 0.8rem;
        border-radius: 2rem;
        font-size: 0.7rem;
        font-weight: 600;
        text-decoration: none;
        border: none;
        cursor: pointer;
    }
    .btn-view { background: var(--primary); color: white; }
    .btn-collect { background: transparent; color: var(--primary); border: 1px solid var(--primary); }
    .btn-generate { background: #f59e0b; color: white; }
    .missing-reason { font-size: 0.7rem; color: var(--muted); margin-top: 0.2rem; }

    .pagination {
        display: flex;
        justify-content: center;
        gap: 0.3rem;
        margin: 0.5rem 0;
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
    .page-link.active { background: var(--primary); color: white; }
    .empty-state { text-align: center; padding: 1.5rem; color: var(--muted); }

    .mobile-header-actions {
        display: flex;
        gap: 0.5rem;
        margin-bottom: 0.5rem;
    }
    .mobile-header-actions a {
        padding: 0.4rem 0.8rem;
        border-radius: 2rem;
        background: var(--primary);
        color: white;
        text-decoration: none;
        font-size: 0.8rem;
        font-weight: 600;
    }
</style>
{% endblock %}

{% block body %}
<div class="page-header">
    <h1 class="page-title">Fee Vouchers</h1>
    <p class="page-desc">All generated vouchers</p>
</div>

<div class="mobile-header-actions">
    <a href="{% url 'mobile_fee_settings' schema_name=tenant.schema_name %}">⚙️ Generate All</a>
</div>

<!-- Filter -->
<div class="filter-bar">
    <form method="get" style="display: flex; flex-wrap: wrap; gap: 0.4rem; width: 100%; align-items: center;">
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
        <input type="text" name="search" value="{{ search_query }}" placeholder="Search...">
        <button type="submit">Apply</button>
        <a href="{% url 'mobile_vouchers_list' schema_name=tenant.schema_name %}" class="reset-link">Reset</a>
    </form>
</div>

<!-- Tab Bar -->
<div class="tab-bar" id="tabBar">
    <button class="tab-btn active" data-tab="pending">
        Pending <span class="badge">{{ pending_page.paginator.count }}</span>
    </button>
    <button class="tab-btn" data-tab="partial">
        Partial <span class="badge">{{ partial_page.paginator.count }}</span>
    </button>
    <button class="tab-btn" data-tab="paid">
        Paid <span class="badge">{{ paid_page.paginator.count }}</span>
    </button>
    <button class="tab-btn" data-tab="missing">
        Missing <span class="badge">{{ missing_page.paginator.count }}</span>
    </button>
</div>

<!-- Section: Pending -->
<div class="section-card active" id="section-pending">
    <div class="section-header">
        <h4>Pending</h4>
        <span class="badge">{{ pending_page.paginator.count }}</span>
    </div>
    <div class="voucher-list">
        {% for item in pending_page %}
        <div class="voucher-card">
            <div class="top-row">
                <div>
                    <div class="student-name">{{ item.student.name }}</div>
                    <div class="student-meta">{{ item.student.roll_number }} • {{ item.student.grade }} - {{ item.student.section }}</div>
                </div>
                <div>
                    <span class="status-badge status-{{ item.status }}">{{ item.get_status_display|default:item.status }}</span>
                </div>
            </div>
            <div style="display: flex; justify-content: space-between; margin-top: 0.3rem;">
                <span>{{ item.month }}/{{ item.year }}</span>
                <span class="amount">₹{{ item.amount|floatformat:2 }}</span>
            </div>
            <div style="display: flex; justify-content: space-between; font-size:0.75rem; color:var(--muted);">
                <span>Paid: ₹{{ item.paid|floatformat:2 }}</span>
                <span>Due: {% if item.due_date %}{{ item.due_date|date:"Y-m-d" }}{% else %}—{% endif %}</span>
            </div>
            <div class="actions">
                <a href="{% url 'mobile_student_profile' schema_name=tenant.schema_name student_id=item.student.id %}" class="btn-view">Profile</a>
                {% if item.status != 'paid' %}
                <a href="{% url 'mobile_fee_collection' schema_name=tenant.schema_name student_id=item.student.id %}" class="btn-collect">Collect</a>
                {% endif %}
            </div>
        </div>
        {% empty %}
        <div class="empty-state">No pending vouchers.</div>
        {% endfor %}
        {% if pending_page.has_other_pages %}
        <div class="pagination">
            {% if pending_page.has_previous %}
                <a href="?tab=pending&pending_page=1&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">&laquo;</a>
                <a href="?tab=pending&pending_page={{ pending_page.previous_page_number }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">‹</a>
            {% endif %}
            <span class="page-link active">{{ pending_page.number }}</span>
            {% if pending_page.has_next %}
                <a href="?tab=pending&pending_page={{ pending_page.next_page_number }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">›</a>
                <a href="?tab=pending&pending_page={{ pending_page.paginator.num_pages }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">&raquo;</a>
            {% endif %}
        </div>
        {% endif %}
    </div>
</div>

<!-- Section: Partial -->
<div class="section-card" id="section-partial">
    <div class="section-header">
        <h4>Partially Paid</h4>
        <span class="badge">{{ partial_page.paginator.count }}</span>
    </div>
    <div class="voucher-list">
        {% for item in partial_page %}
        <div class="voucher-card">
            <div class="top-row">
                <div>
                    <div class="student-name">{{ item.student.name }}</div>
                    <div class="student-meta">{{ item.student.roll_number }} • {{ item.student.grade }} - {{ item.student.section }}</div>
                </div>
                <div>
                    <span class="status-badge status-{{ item.status }}">{{ item.get_status_display|default:item.status }}</span>
                </div>
            </div>
            <div style="display: flex; justify-content: space-between; margin-top: 0.3rem;">
                <span>{{ item.month }}/{{ item.year }}</span>
                <span class="amount">₹{{ item.amount|floatformat:2 }}</span>
            </div>
            <div style="display: flex; justify-content: space-between; font-size:0.75rem; color:var(--muted);">
                <span>Paid: ₹{{ item.paid|floatformat:2 }}</span>
                <span>Due: {% if item.due_date %}{{ item.due_date|date:"Y-m-d" }}{% else %}—{% endif %}</span>
            </div>
            <div class="actions">
                <a href="{% url 'mobile_student_profile' schema_name=tenant.schema_name student_id=item.student.id %}" class="btn-view">Profile</a>
                <a href="{% url 'mobile_fee_collection' schema_name=tenant.schema_name student_id=item.student.id %}" class="btn-collect">Collect</a>
            </div>
        </div>
        {% empty %}
        <div class="empty-state">No partially paid vouchers.</div>
        {% endfor %}
        {% if partial_page.has_other_pages %}
        <div class="pagination">
            {% if partial_page.has_previous %}
                <a href="?tab=partial&partial_page=1&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">&laquo;</a>
                <a href="?tab=partial&partial_page={{ partial_page.previous_page_number }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">‹</a>
            {% endif %}
            <span class="page-link active">{{ partial_page.number }}</span>
            {% if partial_page.has_next %}
                <a href="?tab=partial&partial_page={{ partial_page.next_page_number }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">›</a>
                <a href="?tab=partial&partial_page={{ partial_page.paginator.num_pages }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">&raquo;</a>
            {% endif %}
        </div>
        {% endif %}
    </div>
</div>

<!-- Section: Paid -->
<div class="section-card" id="section-paid">
    <div class="section-header">
        <h4>Paid</h4>
        <span class="badge">{{ paid_page.paginator.count }}</span>
    </div>
    <div class="voucher-list">
        {% for item in paid_page %}
        <div class="voucher-card">
            <div class="top-row">
                <div>
                    <div class="student-name">{{ item.student.name }}</div>
                    <div class="student-meta">{{ item.student.roll_number }} • {{ item.student.grade }} - {{ item.student.section }}</div>
                </div>
                <div>
                    <span class="status-badge status-{{ item.status }}">{{ item.get_status_display|default:item.status }}</span>
                </div>
            </div>
            <div style="display: flex; justify-content: space-between; margin-top: 0.3rem;">
                <span>{{ item.month }}/{{ item.year }}</span>
                <span class="amount">₹{{ item.amount|floatformat:2 }}</span>
            </div>
            <div style="display: flex; justify-content: space-between; font-size:0.75rem; color:var(--muted);">
                <span>Paid: ₹{{ item.paid|floatformat:2 }}</span>
                <span>Due: {% if item.due_date %}{{ item.due_date|date:"Y-m-d" }}{% else %}—{% endif %}</span>
            </div>
            <div class="actions">
                <a href="{% url 'mobile_student_profile' schema_name=tenant.schema_name student_id=item.student.id %}" class="btn-view">Profile</a>
            </div>
        </div>
        {% empty %}
        <div class="empty-state">No paid vouchers.</div>
        {% endfor %}
        {% if paid_page.has_other_pages %}
        <div class="pagination">
            {% if paid_page.has_previous %}
                <a href="?tab=paid&paid_page=1&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">&laquo;</a>
                <a href="?tab=paid&paid_page={{ paid_page.previous_page_number }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">‹</a>
            {% endif %}
            <span class="page-link active">{{ paid_page.number }}</span>
            {% if paid_page.has_next %}
                <a href="?tab=paid&paid_page={{ paid_page.next_page_number }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">›</a>
                <a href="?tab=paid&paid_page={{ paid_page.paginator.num_pages }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">&raquo;</a>
            {% endif %}
        </div>
        {% endif %}
    </div>
</div>

<!-- Section: Not Generated -->
<div class="section-card" id="section-missing">
    <div class="section-header">
        <h4>Not Generated</h4>
        <span class="badge">{{ missing_page.paginator.count }}</span>
    </div>
    <div class="voucher-list">
        {% for item in missing_page %}
        <div class="voucher-card">
            <div class="top-row">
                <div>
                    <div class="student-name">{{ item.student.name }}</div>
                    <div class="student-meta">{{ item.student.roll_number }} • {{ item.student.grade }} - {{ item.student.section }}</div>
                </div>
                <div>
                    <span class="status-badge status-missing">Missing</span>
                </div>
            </div>
            <div style="display: flex; justify-content: space-between; margin-top: 0.3rem;">
                <span>{{ item.month }}/{{ item.year }}</span>
                <span class="amount">—</span>
            </div>
            <div style="display: flex; justify-content: space-between; font-size:0.75rem; color:var(--muted);">
                <span>Paid: —</span>
                <span>Due: —</span>
            </div>
            <div class="missing-reason">{{ item.reason }}</div>
            <div class="actions">
                <a href="{% url 'mobile_student_profile' schema_name=tenant.schema_name student_id=item.student.id %}" class="btn-view">Profile</a>
                {% if is_current_month %}
                <a href="{% url 'mobile_student_profile' schema_name=tenant.schema_name student_id=item.student.id %}?open_voucher=1" class="btn-generate">Generate</a>
                {% endif %}
            </div>
        </div>
        {% empty %}
        <div class="empty-state">All active students have vouchers for this month.</div>
        {% endfor %}
        {% if missing_page.has_other_pages %}
        <div class="pagination">
            {% if missing_page.has_previous %}
                <a href="?tab=missing&missing_page=1&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">&laquo;</a>
                <a href="?tab=missing&missing_page={{ missing_page.previous_page_number }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">‹</a>
            {% endif %}
            <span class="page-link active">{{ missing_page.number }}</span>
            {% if missing_page.has_next %}
                <a href="?tab=missing&missing_page={{ missing_page.next_page_number }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">›</a>
                <a href="?tab=missing&missing_page={{ missing_page.paginator.num_pages }}&month={{ month }}&year={{ year }}&search={{ search_query }}" class="page-link">&raquo;</a>
            {% endif %}
        </div>
        {% endif %}
    </div>
</div>

{% include "tenant/voucher_modal.html" %}

<script>
    (function() {
        const urlParams = new URLSearchParams(window.location.search);
        let activeTab = urlParams.get('tab') || 'pending';

        const tabBtns = document.querySelectorAll('.tab-btn');
        const sections = {
            pending: document.getElementById('section-pending'),
            partial: document.getElementById('section-partial'),
            paid: document.getElementById('section-paid'),
            missing: document.getElementById('section-missing')
        };

        function activateTab(tabId) {
            tabBtns.forEach(btn => {
                btn.classList.toggle('active', btn.dataset.tab === tabId);
            });
            Object.keys(sections).forEach(key => {
                sections[key].classList.toggle('active', key === tabId);
            });
            const url = new URL(window.location);
            url.searchParams.set('tab', tabId);
            window.history.replaceState({}, '', url);
        }

        tabBtns.forEach(btn => {
            btn.addEventListener('click', function(e) {
                const tabId = this.dataset.tab;
                activateTab(tabId);
            });
        });

        if (activeTab && sections[activeTab]) {
            activateTab(activeTab);
        } else {
            activateTab('pending');
        }
    })();
</script>
{% endblock %}
'''

# ----------------------------------------------------------------------------
# Write files
# ----------------------------------------------------------------------------
def main():
    with open(TEMPLATE_TENANT, "w") as f:
        f.write(NEW_TENANT_TEMPLATE)
    print("✅ Updated templates/tenant/vouchers.html")

    with open(TEMPLATE_MOBILE, "w") as f:
        f.write(NEW_MOBILE_TEMPLATE)
    print("✅ Updated templates/mobile/vouchers.html")

    print("\n🎉 Patcher completed successfully!")
    print("Now your voucher pages have a premium tabbed interface.")
    print("Restart Django to see the changes.")

if __name__ == "__main__":
    main()
