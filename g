#!/usr/bin/env python3
"""
AXIS Fee Automation Patcher
Fixes auto-generation, adds working charges UI, and provides cron check.
Run this from the project root: python3 fee_automation_patcher.py
"""

import os
import shutil
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent

# --------------------------------------------------------------------
# 1. NEW fee_settings.html (complete replacement)
# --------------------------------------------------------------------
NEW_FEE_SETTINGS_HTML = '''{% extends 'tenant/base.html' %}
{% load static %}
{% block title %}Fee Settings | {{ tenant.name }}{% endblock %}

{% block extra_head %}
<style>
    .settings-grid {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 1.5rem;
        margin-bottom: 1.5rem;
    }
    .settings-card {
        background: var(--surface);
        border-radius: var(--radius);
        border: 1px solid var(--border);
        overflow: hidden;
    }
    .card-header {
        display: flex;
        align-items: center;
        gap: 0.75rem;
        padding: 1rem 1.25rem;
        background: var(--surface-alt);
        border-bottom: 1px solid var(--border);
    }
    .card-header h3 {
        font-size: 1.1rem;
        font-weight: 600;
        margin: 0;
    }
    .settings-form {
        padding: 1.25rem;
    }
    .form-field {
        margin-bottom: 1.25rem;
    }
    .form-field label {
        display: block;
        font-weight: 600;
        font-size: 0.85rem;
        margin-bottom: 0.3rem;
    }
    .input-icon {
        position: relative;
    }
    .input-icon input, .input-icon select {
        width: 100%;
        padding: 0.6rem 0.6rem 0.6rem 2rem;
        border-radius: 0.5rem;
        border: 1px solid var(--border);
        background: var(--surface-alt);
        color: var(--text);
        font-size: 0.9rem;
    }
    .input-icon svg {
        position: absolute;
        left: 0.6rem;
        top: 50%;
        transform: translateY(-50%);
        color: var(--muted);
        width: 18px;
        height: 18px;
    }
    .form-field small {
        display: block;
        font-size: 0.7rem;
        color: var(--muted);
        margin-top: 0.25rem;
    }
    .extra-charges-section {
        margin-top: 1.5rem;
        border-top: 1px solid var(--border);
        padding-top: 1rem;
    }
    .charge-item {
        display: flex;
        gap: 0.5rem;
        align-items: center;
        margin-bottom: 0.5rem;
    }
    .charge-item input {
        flex: 1;
        padding: 0.4rem 0.6rem;
        border-radius: 0.5rem;
        border: 1px solid var(--border);
        background: var(--surface-alt);
    }
    .charge-item .remove-charge {
        background: none;
        border: none;
        color: var(--danger);
        cursor: pointer;
        font-size: 1.2rem;
        padding: 0 0.3rem;
    }
    .charge-item .edit-charge {
        background: none;
        border: none;
        color: var(--primary);
        cursor: pointer;
    }
    .total-extra {
        font-weight: 700;
        color: var(--primary);
        margin: 0.5rem 0;
    }
    .btn-add-charge {
        background: var(--primary);
        color: white;
        border: none;
        border-radius: 2rem;
        padding: 0.4rem 1rem;
        cursor: pointer;
        font-weight: 600;
    }
    .btn-add-charge:hover {
        background: var(--primary-dark);
    }
    .automation-status {
        display: flex;
        gap: 1rem;
        align-items: center;
        margin: 1rem 0;
        flex-wrap: wrap;
    }
    .status-indicator {
        display: inline-flex;
        align-items: center;
        gap: 0.5rem;
        padding: 0.3rem 0.8rem;
        border-radius: 2rem;
        font-weight: 600;
    }
    .status-indicator.active {
        background: #d1fae5;
        color: #065f46;
    }
    .status-indicator.inactive {
        background: #fee2e2;
        color: #991b1b;
    }
    .btn-toggle {
        padding: 0.5rem 1.2rem;
        border-radius: 2rem;
        font-weight: 600;
        border: none;
        cursor: pointer;
        transition: all 0.2s;
    }
    .btn-toggle.start {
        background: #10b981;
        color: white;
    }
    .btn-toggle.start:hover {
        background: #059669;
    }
    .btn-toggle.stop {
        background: #ef4444;
        color: white;
    }
    .btn-toggle.stop:hover {
        background: #dc2626;
    }
    .btn-toggle:disabled {
        opacity: 0.6;
        cursor: not-allowed;
    }
    .form-actions {
        margin-top: 1.5rem;
        text-align: right;
    }
    .btn-primary {
        background: var(--primary);
        color: white;
        border: none;
        border-radius: 2rem;
        padding: 0.5rem 1.2rem;
        font-weight: 600;
        cursor: pointer;
        display: inline-flex;
        align-items: center;
        gap: 0.5rem;
    }
    .btn-primary:hover {
        background: var(--primary-dark);
        transform: translateY(-1px);
    }
    .btn-secondary {
        background: var(--surface-alt);
        color: var(--text);
        border: 1px solid var(--border);
        border-radius: 2rem;
        padding: 0.5rem 1.2rem;
        font-weight: 600;
        cursor: pointer;
    }
    .info-card {
        background: var(--surface);
        border-radius: var(--radius);
        border: 1px solid var(--border);
        padding: 1rem;
        margin-top: 1.5rem;
    }
    .info-card h3 {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        font-size: 1rem;
    }
    .info-card ul {
        padding-left: 1.5rem;
        margin: 0.5rem 0;
    }
    .info-card ul li {
        margin-bottom: 0.4rem;
        font-size: 0.85rem;
    }
    @media (max-width: 768px) {
        .settings-grid {
            grid-template-columns: 1fr;
        }
    }
</style>
{% endblock %}

{% block body %}
<div class="page-header">
    <div>
        <h1 class="page-title">Fee Automation</h1>
        <p class="page-desc">Configure automated fee generation and default charges</p>
    </div>
    <div class="header-actions">
        <a href="{% url 'fee_logs' schema_name=tenant.schema_name %}" class="btn-primary">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/></svg>
            View Logs
        </a>
    </div>
</div>

<div class="settings-grid">
    <!-- Automation Settings Card -->
    <div class="settings-card">
        <div class="card-header">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                <path d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
                <path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
            </svg>
            <h3>Automation Rules</h3>
        </div>
        <form method="post" id="settingsForm" class="settings-form">
            {% csrf_token %}
            <div class="form-field">
                <label>Generation Day of Month</label>
                <div class="input-icon">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M3 12h3l3-9 3 18 3-9h3"/></svg>
                    {{ form.fee_generation_day }}
                </div>
                <small>Fees will be created automatically on this day every month.</small>
            </div>
            <div class="form-field">
                <label>Due Date Offset (days after generation)</label>
                <div class="input-icon">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>
                    {{ form.due_date_offset }}
                </div>
                <small>Number of days after generation when fee becomes due.</small>
            </div>
            <div class="form-field">
                <label>Late Fee Amount (₹ per day)</label>
                <div class="input-icon">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83"/></svg>
                    {{ form.late_fee_penalty }}
                </div>
                <small>Fixed amount added per day after due date for overdue fees.</small>
            </div>

            <!-- Extra Charges Section -->
            <div class="extra-charges-section">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem;">
                    <h4 style="margin:0;">Default Extra Charges</h4>
                    <button type="button" class="btn-add-charge" id="addChargeBtn">+ Add Charge</button>
                </div>
                <div id="chargesContainer">
                    {% for charge in extra_charges %}
                    <div class="charge-item" data-index="{{ forloop.counter0 }}">
                        <input type="text" class="charge-title" value="{{ charge.title }}" placeholder="Title">
                        <input type="number" step="0.01" class="charge-amount" value="{{ charge.amount }}" placeholder="Amount">
                        <button type="button" class="edit-charge" title="Edit">✎</button>
                        <button type="button" class="remove-charge" title="Remove">×</button>
                    </div>
                    {% empty %}
                    <div id="noChargesMsg" style="color: var(--muted); font-size: 0.85rem;">No extra charges added yet.</div>
                    {% endfor %}
                </div>
                <div class="total-extra">Total Extra Charges: ₹<span id="totalExtraDisplay">{{ total_extra|floatformat:2 }}</span></div>
                <input type="hidden" name="extra_charges_json" id="extraChargesJson" value='{{ extra_charges|safe }}'>
            </div>

            <div class="form-actions">
                <button type="submit" class="btn-primary">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M5 13l4 4L19 7"/></svg>
                    Save Settings
                </button>
            </div>
        </form>
    </div>

    <!-- Automation Status & Controls Card -->
    <div class="settings-card">
        <div class="card-header">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                <path d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
            </svg>
            <h3>Automation Status</h3>
        </div>
        <div style="padding: 1.25rem;">
            <div class="automation-status">
                <span class="status-indicator {% if automation_enabled %}active{% else %}inactive{% endif %}">
                    {% if automation_enabled %}● Active{% else %}● Inactive{% endif %}
                </span>
                <form method="post" style="display: inline;">
                    {% csrf_token %}
                    <input type="hidden" name="toggle_automation" value="1">
                    <button type="submit" class="btn-toggle {% if automation_enabled %}stop{% else %}start{% endif %}"
                            {% if not automation_enabled %}id="startAutomationBtn"{% else %}id="stopAutomationBtn"{% endif %}>
                        {% if automation_enabled %}⏹ Stop Automation{% else %}▶ Start Automation{% endif %}
                    </button>
                </form>
            </div>
            <div style="margin-top: 1rem; font-size: 0.85rem; color: var(--muted);">
                <p><strong>Current Generation Day:</strong> {{ settings.fee_generation_day }}</p>
                <p><strong>Due Date Offset:</strong> {{ settings.due_date_offset }} days</p>
                <p><strong>Late Fee:</strong> ₹{{ settings.late_fee_penalty }} per day</p>
            </div>
            <div style="margin-top: 1rem; border-top: 1px solid var(--border); padding-top: 1rem;">
                <p><strong>Next generation:</strong> <span id="nextGenDate">Calculating...</span></p>
            </div>
        </div>
    </div>
</div>

<!-- Info Card -->
<div class="info-card">
    <h3>
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/></svg>
        How Automation Works
    </h3>
    <ul>
        <li><strong>Auto-generation:</strong> On the selected day each month, the system creates fee records for all active students (with a defined fee structure or custom fee).</li>
        <li><strong>Extra Charges:</strong> The default extra charges are added to every student's fee when generated.</li>
        <li><strong>Due Date:</strong> Fee becomes due after the offset days from generation.</li>
        <li><strong>Late Fee:</strong> The fixed amount is added per day for overdue unpaid fees.</li>
        <li><strong>Start/Stop:</strong> Toggle automation on/off. When stopped, no automatic generation occurs.</li>
    </ul>
</div>

<!-- Manual Generation Section -->
<div class="settings-card" style="margin-top: 1.5rem; border-left: 4px solid #10b981;">
    <div class="card-header">
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
            <path d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
        </svg>
        <h3 style="margin:0;">Manual Fee Generation</h3>
        <span style="margin-left:auto; font-size:0.7rem; background:#10b981; color:white; padding:0.15rem 0.6rem; border-radius:2rem;">Current Month</span>
    </div>
    <div style="padding:1.25rem;">
        <p style="color:var(--muted); margin-bottom:0.75rem; font-size:0.9rem;">
            Generate fee records for <strong>all active students</strong> for the current month.
            <br>Priority: <strong>class fee structure</strong> → <strong>custom fee</strong>.
            Students who already have a fee for this month will be skipped.
        </p>
        <div style="display:flex; gap:1rem; flex-wrap:wrap; align-items:center;">
            <button id="manualGenerateBtn" class="btn-primary" style="background:#10b981; padding:0.5rem 1.5rem;">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/></svg>
                Generate Fees Now
            </button>
            <span id="manualGenStatus" style="font-size:0.85rem; color:var(--muted);">Ready</span>
        </div>
        <div id="manualGenResult" style="margin-top:0.75rem; display:none; padding:0.75rem; border-radius:0.5rem; background:var(--surface-alt); font-size:0.85rem;"></div>
    </div>
</div>

<script>
    (function() {
        // ---- Extra Charges Management ----
        const chargesContainer = document.getElementById('chargesContainer');
        const noChargesMsg = document.getElementById('noChargesMsg');
        const totalExtraDisplay = document.getElementById('totalExtraDisplay');
        const extraChargesJson = document.getElementById('extraChargesJson');

        function updateTotal() {
            let total = 0;
            const items = chargesContainer.querySelectorAll('.charge-item');
            items.forEach(item => {
                const amountInput = item.querySelector('.charge-amount');
                if (amountInput) {
                    total += parseFloat(amountInput.value) || 0;
                }
            });
            totalExtraDisplay.innerText = total.toFixed(2);
            // Update hidden JSON
            const charges = [];
            items.forEach(item => {
                const title = item.querySelector('.charge-title').value.trim();
                const amount = parseFloat(item.querySelector('.charge-amount').value) || 0;
                if (title || amount) {
                    charges.push({ title: title || 'Unnamed', amount: amount });
                }
            });
            extraChargesJson.value = JSON.stringify(charges);
            // Show/hide no charges message
            if (noChargesMsg) {
                noChargesMsg.style.display = items.length === 0 ? 'block' : 'none';
            }
        }

        // Add charge
        document.getElementById('addChargeBtn').addEventListener('click', function() {
            const idx = chargesContainer.querySelectorAll('.charge-item').length;
            const div = document.createElement('div');
            div.className = 'charge-item';
            div.dataset.index = idx;
            div.innerHTML = `
                <input type="text" class="charge-title" placeholder="Title">
                <input type="number" step="0.01" class="charge-amount" placeholder="Amount">
                <button type="button" class="edit-charge" title="Edit">✎</button>
                <button type="button" class="remove-charge" title="Remove">×</button>
            `;
            // Insert before the "Add Charge" button? Actually we put it inside container before the button? 
            // The container is the div; we'll append to it.
            chargesContainer.appendChild(div);
            attachChargeEvents(div);
            updateTotal();
        });

        function attachChargeEvents(container) {
            const removeBtn = container.querySelector('.remove-charge');
            const editBtn = container.querySelector('.edit-charge');
            const titleInput = container.querySelector('.charge-title');
            const amountInput = container.querySelector('.charge-amount');

            if (removeBtn) {
                removeBtn.addEventListener('click', function() {
                    if (confirm('Remove this charge?')) {
                        container.remove();
                        updateTotal();
                    }
                });
            }
            if (editBtn) {
                editBtn.addEventListener('click', function() {
                    // Simple edit: just focus the title input
                    titleInput.focus();
                });
            }
            if (titleInput) {
                titleInput.addEventListener('input', updateTotal);
            }
            if (amountInput) {
                amountInput.addEventListener('input', updateTotal);
            }
        }

        // Attach events to existing charge items
        document.querySelectorAll('.charge-item').forEach(item => {
            attachChargeEvents(item);
        });

        // Initial total update
        updateTotal();

        // ---- Manual Generate ----
        const manualBtn = document.getElementById('manualGenerateBtn');
        const manualStatus = document.getElementById('manualGenStatus');
        const manualResult = document.getElementById('manualGenResult');

        if (manualBtn) {
            manualBtn.addEventListener('click', async function(e) {
                e.preventDefault();
                const originalText = manualBtn.innerHTML;
                manualBtn.disabled = true;
                manualBtn.innerHTML = '⏳ Generating...';
                manualStatus.textContent = 'Generating...';
                manualResult.style.display = 'block';
                manualResult.innerHTML = '⏳ Processing, please wait...';
                manualResult.style.background = 'var(--surface-alt)';
                manualResult.style.color = 'var(--text)';

                try {
                    const csrfToken = getCsrfToken();
                    const resp = await fetch('/api/manual-generate/', {
                        method: 'POST',
                        headers: {
                            'X-CSRFToken': csrfToken,
                            'Content-Type': 'application/json',
                        },
                        credentials: 'same-origin'
                    });
                    const data = await resp.json();
                    if (data.error) {
                        manualResult.innerHTML = '❌ Error: ' + data.error;
                        manualResult.style.background = '#fee2e2';
                        manualResult.style.color = '#991b1b';
                        manualStatus.textContent = 'Failed';
                    } else {
                        const msg = data.message || 'Fee generation completed.';
                        const details = `Created: ${data.created || 0} | Skipped (already exist): ${data.skipped_existing || 0} | Skipped (no fee structure): ${data.skipped_no_fee || 0}`;
                        manualResult.innerHTML = '✅ ' + msg + '<br><small>' + details + '</small>';
                        manualResult.style.background = '#d1fae5';
                        manualResult.style.color = '#065f46';
                        manualStatus.textContent = '✅ Done';
                    }
                } catch (err) {
                    manualResult.innerHTML = '❌ Error: ' + err.message;
                    manualResult.style.background = '#fee2e2';
                    manualResult.style.color = '#991b1b';
                    manualStatus.textContent = '❌ Error';
                } finally {
                    manualBtn.disabled = false;
                    manualBtn.innerHTML = originalText;
                }
            });
        }

        function getCsrfToken() {
            let name = 'csrftoken';
            let cookieValue = null;
            if (document.cookie && document.cookie !== '') {
                const cookies = document.cookie.split(';');
                for (let i = 0; i < cookies.length; i++) {
                    const cookie = cookies[i].trim();
                    if (cookie.substring(0, name.length + 1) === (name + '=')) {
                        cookieValue = decodeURIComponent(cookie.substring(name.length + 1));
                        break;
                    }
                }
            }
            return cookieValue;
        }

        // ---- Next generation date (from server or calculate) ----
        // Use the existing status API or compute client-side
        // We'll compute from settings: fee_generation_day
        const genDayInput = document.querySelector('input[name="fee_generation_day"]');
        if (genDayInput) {
            const genDay = parseInt(genDayInput.value) || 1;
            const today = new Date();
            let nextDate = new Date(today);
            if (today.getDate() < genDay) {
                nextDate.setDate(genDay);
            } else {
                nextDate.setMonth(today.getMonth() + 1);
                nextDate.setDate(genDay);
            }
            const nextGenSpan = document.getElementById('nextGenDate');
            if (nextGenSpan) {
                nextGenSpan.innerText = nextDate.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
            }
        }
    })();
</script>
{% endblock %}
'''

# --------------------------------------------------------------------
# 2. PATCHED auto_generate_fees.py (management command)
# --------------------------------------------------------------------
NEW_AUTO_GENERATE_PY = '''from django.core.management.base import BaseCommand
from django_tenants.utils import schema_context
from axis_saas.views import create_fee_generation_notification
from axis_saas.models import SchoolClient, SchoolFeeSettings, Student, FeeRecord, FeeStructure, ManualGenerationLog
from datetime import date, timedelta
from decimal import Decimal

class Command(BaseCommand):
    help = 'Automatically generate monthly fees for tenants with automation enabled'

    def handle(self, *args, **options):
        tenants = SchoolClient.objects.filter(is_active=True).exclude(schema_name='public')
        today = date.today()
        generated_total = 0

        for tenant in tenants:
            with schema_context(tenant.schema_name):
                settings, _ = SchoolFeeSettings.objects.get_or_create(pk=1)

                if not settings.automation_enabled:
                    self.stdout.write(self.style.WARNING(f"{tenant.schema_name}: automation disabled, skipping"))
                    continue

                if today.day != settings.fee_generation_day:
                    self.stdout.write(self.style.WARNING(f"{tenant.schema_name}: today {today.day} != generation day {settings.fee_generation_day}, skipping"))
                    continue

                month, year = today.month, today.year
                due_date = today + timedelta(days=settings.due_date_offset)
                students = Student.objects.filter(status='active')
                created = 0
                skipped_existing = 0
                skipped_no_fee = 0

                # Pre-fetch fee structures for efficiency
                fee_structs = {fs.grade: fs.monthly_fee for fs in FeeStructure.objects.all()}

                extra_charges = settings.default_extra_charges or []
                total_extra = sum(Decimal(str(ch.get('amount', 0))) for ch in extra_charges)

                for student in students:
                    if FeeRecord.objects.filter(student=student, month=month, year=year).exists():
                        skipped_existing += 1
                        continue

                    base_fee = student.custom_fee if student.custom_fee > 0 else 0
                    if base_fee == 0:
                        base_fee = fee_structs.get(student.grade, 0)

                    if base_fee > 0:
                        total_fee = base_fee + total_extra
                        FeeRecord.objects.create(
                            student=student,
                            month=month,
                            year=year,
                            amount=total_fee,          # base + extras
                            due_date=due_date,
                            status='pending',
                            extra_charges=extra_charges,
                            due_date_offset=settings.due_date_offset,
                            late_fee_per_day=settings.late_fee_penalty
                        )
                        created += 1
                    else:
                        skipped_no_fee += 1

                if created > 0 or skipped_existing > 0 or skipped_no_fee > 0:
                    ManualGenerationLog.objects.create(
                        month=month,
                        year=year,
                        created_count=created,
                        skipped_existing=skipped_existing,
                        skipped_no_fee=skipped_no_fee,
                        triggered_by='system',
                        log_type='auto'
                    )
                    # Create notification (only if fees were created)
                    if created > 0:
                        create_fee_generation_notification(tenant.schema_name, month, year, created, 'system', mobile=False)

                    self.stdout.write(
                        f"{tenant.schema_name}: generated {created}, "
                        f"already had fee: {skipped_existing}, "
                        f"skipped (no fee structure): {skipped_no_fee} for {month}/{year}"
                    )
                    generated_total += created

        self.stdout.write(self.style.SUCCESS(f"Total fees generated: {generated_total}"))
'''

# --------------------------------------------------------------------
# 3. NEW MANAGEMENT COMMAND: check_cron.py
# --------------------------------------------------------------------
CHECK_CRON_PY = '''from django.core.management.base import BaseCommand
from django_tenants.utils import schema_context
from axis_saas.models import SchoolClient, SchoolFeeSettings
from datetime import date

class Command(BaseCommand):
    help = 'Check the status of fee automation cron job'

    def handle(self, *args, **options):
        tenants = SchoolClient.objects.filter(is_active=True).exclude(schema_name='public')
        today = date.today()
        self.stdout.write(f"Today: {today.isoformat()}")
        self.stdout.write("=" * 50)
        found_enabled = False

        for tenant in tenants:
            with schema_context(tenant.schema_name):
                settings, _ = SchoolFeeSettings.objects.get_or_create(pk=1)
                enabled = settings.automation_enabled
                gen_day = settings.fee_generation_day
                status = "✅" if enabled else "❌"
                matches = "✅" if enabled and today.day == gen_day else " "
                self.stdout.write(
                    f"{status} {tenant.schema_name:20} | Automation: {'ON' if enabled else 'OFF':4} | "
                    f"Gen day: {gen_day:2} | Today matches: {matches}"
                )
                if enabled:
                    found_enabled = True

        if not found_enabled:
            self.stdout.write(self.style.WARNING("No tenant has automation enabled."))
        else:
            self.stdout.write(self.style.SUCCESS("Automation is enabled for at least one tenant."))
            self.stdout.write("To test actual generation, run: python manage.py auto_generate_fees")
'''

# --------------------------------------------------------------------
# 4. MAIN PATCHER LOGIC
# --------------------------------------------------------------------
def backup_file(filepath):
    if filepath.exists():
        backup = filepath.with_suffix(filepath.suffix + '.bak')
        shutil.copy2(filepath, backup)
        print(f"✅ Backed up {filepath} -> {backup}")
    else:
        print(f"⚠️ File {filepath} not found (skipping backup)")

def write_file(filepath, content):
    filepath.parent.mkdir(parents=True, exist_ok=True)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"✅ Written {filepath}")

def main():
    print("AXIS Fee Automation Patcher")
    print("============================\n")

    # 1. Backup and replace fee_settings.html
    fee_settings_path = PROJECT_ROOT / 'templates' / 'tenant' / 'fee_settings.html'
    backup_file(fee_settings_path)
    write_file(fee_settings_path, NEW_FEE_SETTINGS_HTML)

    # 2. Backup and replace auto_generate_fees.py
    auto_gen_path = PROJECT_ROOT / 'axis_saas' / 'management' / 'commands' / 'auto_generate_fees.py'
    backup_file(auto_gen_path)
    write_file(auto_gen_path, NEW_AUTO_GENERATE_PY)

    # 3. Create check_cron.py
    check_cron_path = PROJECT_ROOT / 'axis_saas' / 'management' / 'commands' / 'check_cron.py'
    write_file(check_cron_path, CHECK_CRON_PY)

    print("\n✅ Patcher completed successfully!")
    print("\nNext steps:")
    print("1. Run database migrations (if any):")
    print("   python manage.py makemigrations")
    print("   python manage.py migrate")
    print("2. Test the cron check:")
    print("   python manage.py check_cron")
    print("3. Set up the cron job (if not already):")
    print("   Add to crontab (runs daily at 2am):")
    print("   0 2 * * * cd /home/psami/axis_school_sys && /usr/bin/python3 manage.py auto_generate_fees >> /var/log/axis_cron.log 2>&1")
    print("4. Verify automation is enabled in the UI and the generation day is set correctly.")
    print("5. Manually test generation: python manage.py auto_generate_fees")

if __name__ == '__main__':
    main()
