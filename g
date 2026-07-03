{% extends 'mobile/base.html' %}
{% load static %}
{% block title %}Settings | {{ tenant.name }}{% endblock %}

{% block extra_head %}
<style>
    /* ===== All styles use base CSS variables ===== */

    .page-header {
        margin-bottom: 1rem;
    }
    .page-title {
        font-size: 1.6rem;
        font-weight: 700;
        color: var(--text);
        margin-bottom: 0.1rem;
    }
    .page-desc {
        color: var(--muted);
        font-size: 0.9rem;
    }

    /* ---- Settings Card (read-only, grey) ---- */
    .settings-card {
        background: var(--surface);
        border: 1px solid var(--border);
        border-radius: var(--radius);
        padding: 1.25rem;
        margin-bottom: 1rem;
        box-shadow: var(--shadow);
        transition: background 0.25s, border-color 0.25s;
    }
    .settings-card .card-title {
        font-size: 1rem;
        font-weight: 700;
        display: flex;
        align-items: center;
        gap: 0.5rem;
        margin-bottom: 1rem;
        color: var(--text);
    }
    .settings-card .card-title svg {
        color: var(--accent);
    }

    /* ---- Read-only field ---- */
    .info-row {
        display: flex;
        flex-direction: column;
        margin-bottom: 0.75rem;
        padding: 0.4rem 0.6rem;
        background: var(--surface-alt);
        border-radius: 0.5rem;
        border: 1px solid var(--border);
    }
    .info-row .label {
        font-weight: 400;
        font-size: 0.65rem;
        text-transform: uppercase;
        color: var(--muted);
        letter-spacing: 0.02em;
    }
    .info-row .value {
        font-weight: 600;
        color: var(--text);
        font-size: 0.95rem;
        margin-top: 0.05rem;
        word-break: break-word;
    }
    .info-row .value .password-dots {
        letter-spacing: 0.3rem;
        font-weight: 700;
        color: var(--muted);
    }

    /* ---- Logo display ---- */
    .logo-display {
        display: flex;
        align-items: center;
        gap: 0.75rem;
        padding: 0.4rem 0.6rem;
        background: var(--surface-alt);
        border-radius: 0.5rem;
        border: 1px solid var(--border);
    }
    .logo-display .logo-img {
        max-height: 60px;
        max-width: 120px;
        border-radius: 0.3rem;
        border: 1px solid var(--border);
        padding: 0.1rem;
        background: var(--surface);
    }
    .logo-display .no-logo {
        color: var(--muted);
        font-size: 0.85rem;
    }

    /* ---- Lock icon ---- */
    .lock-icon {
        display: inline-flex;
        align-items: center;
        gap: 0.3rem;
        font-size: 0.7rem;
        color: var(--muted);
        margin-top: 0.5rem;
    }
    .lock-icon svg {
        width: 14px;
        height: 14px;
        stroke: var(--muted);
    }

    .bottom-spacer {
        height: 80px;
    }

    @media (max-width: 480px) {
        .logo-display {
            flex-direction: column;
            align-items: flex-start;
        }
        .logo-display .logo-img {
            max-height: 50px;
            max-width: 100px;
        }
    }
</style>
{% endblock %}

{% block body %}
<div class="page-header">
    <h1 class="page-title">Settings</h1>
    <p class="page-desc">View your school profile and credentials</p>
</div>

<!-- ===== School Information (Read-Only) ===== -->
<div class="settings-card">
    <div class="card-title">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
            <path d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
        </svg>
        <span>School Information</span>
    </div>

    <div class="info-row">
        <span class="label">School Name</span>
        <span class="value">{{ tenant.name }}</span>
    </div>

    <div class="info-row">
        <span class="label">School Logo</span>
        <div class="logo-display">
            {% if logo_url %}
                <img src="{{ logo_url }}" class="logo-img" alt="School logo">
            {% else %}
                <span class="no-logo">No logo uploaded</span>
            {% endif %}
        </div>
    </div>

    <div class="lock-icon">
        <svg viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0110 0v4"/></svg>
        Read-only – settings are managed by the system administrator
    </div>
</div>

<!-- ===== Account Security (Read-Only) ===== -->
<div class="settings-card">
    <div class="card-title">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
            <path d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
        </svg>
        <span>Account Security</span>
    </div>

    <div class="info-row">
        <span class="label">Admin Username</span>
        <span class="value">{{ tenant.admin_username }}</span>
    </div>

    <div class="info-row">
        <span class="label">Password</span>
        <span class="value">
            <span class="password-dots">••••••••</span>
            <span style="font-size:0.65rem; color:var(--muted); font-weight:400; margin-left:0.5rem;">(secured)</span>
        </span>
    </div>

    <div class="lock-icon">
        <svg viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0110 0v4"/></svg>
        Credentials are managed by the system administrator
    </div>
</div>

<div class="bottom-spacer"></div>
{% endblock %}
