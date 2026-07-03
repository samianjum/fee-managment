{% load static %}
<!DOCTYPE html>
<html lang="en">
<head>
    <link rel="manifest" href="/portal/{{ tenant.schema_name }}/manifest.json">
    <meta name="theme-color" content="#ffffff" id="themeColorMeta">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
    <title>{% block title %}AXIS Portal{% endblock %}</title>
    <style>
        * { margin:0; padding:0; box-sizing:border-box; }

        /* ---- Light Theme (default) ---- */
        :root {
            --bg: #FFFFFF;
            --surface: #FFFFFF;
            --surface-alt: #F5F5F5;
            --text: #000000;
            --muted: #666666;
            --border: #DDDDDD;
            --shadow: 0 2px 12px rgba(0,0,0,0.08);
            --accent: #000000;          /* same as text for pure 2‑color */
            --accent-hover: #333333;
            --accent-light: #F0F0F0;
            --radius: 1rem;
            --safe-bottom: env(safe-area-inset-bottom, 0px);
            --transition: all 0.2s ease;
        }

        /* ---- Dark Theme ---- */
        html.dark {
            --bg: #000000;
            --surface: #0A0A0A;
            --surface-alt: #1A1A1A;
            --text: #FFFFFF;
            --muted: #AAAAAA;
            --border: #333333;
            --shadow: 0 2px 12px rgba(0,0,0,0.6);
            --accent: #FFFFFF;
            --accent-hover: #CCCCCC;
            --accent-light: #1A1A1A;
        }

        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background: var(--bg);
            color: var(--text);
            padding-bottom: 80px;
            overflow-x: hidden;
            transition: background 0.3s, color 0.3s;
        }

        /* ---- Top Bar ---- */
        .top-bar {
            background: var(--surface);
            padding: 12px 20px 10px;
            border-bottom: 1px solid var(--border);
            display: flex;
            align-items: center;
            justify-content: space-between;
            position: sticky;
            top: 0;
            z-index: 20;
            box-shadow: 0 1px 4px rgba(0,0,0,0.04);
            transition: background 0.3s, border-color 0.3s;
        }
        .top-bar .left {
            display: flex;
            align-items: center;
            gap: 12px;
            cursor: pointer;  /* indicate clickable */
        }
        .top-bar .logo {
            width: 38px;
            height: 38px;
            background: var(--accent);
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: var(--bg);
            font-weight: 700;
            font-size: 15px;
            flex-shrink: 0;
            transition: background 0.3s, color 0.3s;
        }
        .top-bar .school-name {
            font-weight: 600;
            font-size: 16px;
            line-height: 1.2;
            color: var(--text);
        }
        .top-bar .school-name small {
            display: block;
            font-weight: 400;
            font-size: 11px;
            color: var(--muted);
        }
        .top-bar .actions {
            display: flex;
            align-items: center;
            gap: 6px;
        }

        /* ---- Main Content ---- */
        .main-content {
            padding: 16px 16px 20px;
            position: relative;
            z-index: 1;
        }

        /* ---- Bottom Navigation ---- */
        .bottom-nav {
            position: fixed;
            bottom: 0;
            left: 0;
            right: 0;
            background: var(--surface);
            border-top: 1px solid var(--border);
            display: flex;
            justify-content: space-around;
            padding: 6px 0 calc(6px + var(--safe-bottom));
            z-index: 30;
            box-shadow: 0 -2px 10px rgba(0,0,0,0.04);
            transition: background 0.3s, border-color 0.3s;
        }
        .bottom-nav .nav-item {
            display: flex;
            flex-direction: column;
            align-items: center;
            font-size: 10px;
            color: var(--muted);
            text-decoration: none;
            padding: 4px 8px;
            border-radius: 8px;
            transition: var(--transition);
            gap: 2px;
        }
        .bottom-nav .nav-item.active {
            color: var(--accent);
            background: var(--accent-light);
        }
        .bottom-nav .nav-item svg {
            width: 24px;
            height: 24px;
            stroke: currentColor;
            fill: none;
            stroke-width: 1.8;
        }
        .bottom-nav .nav-item span {
            font-weight: 500;
            font-size: 9px;
            letter-spacing: 0.02em;
        }

        /* ---- Messages ---- */
        .message {
            margin: 8px 16px;
            padding: 10px 14px;
            border-radius: 8px;
            background: var(--surface);
            border-left: 4px solid var(--accent);
            font-size: 13px;
            box-shadow: var(--shadow);
            transition: background 0.3s, border-color 0.3s;
        }
        .message.success { border-left-color: #2E7D32; }
        .message.error { border-left-color: #C62828; }

        /* ---- Utilities ---- */
        .mt-2 { margin-top: 8px; }
        .mb-2 { margin-bottom: 8px; }
        .text-center { text-align: center; }
        .text-muted { color: var(--muted); }
        .scroll-x {
            display: flex;
            flex-wrap: nowrap;
            overflow-x: auto;
            gap: 12px;
            padding-bottom: 8px;
            -webkit-overflow-scrolling: touch;
            scroll-snap-type: x mandatory;
        }
        .scroll-x > * { scroll-snap-align: start; flex-shrink: 0; }

        /* ---- Cards ---- */
        .glass-card {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: var(--radius);
            box-shadow: var(--shadow);
            padding: 1rem;
            transition: background 0.3s, border-color 0.3s, box-shadow 0.3s;
        }

        /* ---- Mobile Search ---- */
        .mobile-search-wrapper {
            margin: 0 0 0.75rem 0;
            padding: 0 0.25rem;
            width: 100%;
        }
        .mobile-search-wrapper .global-search-wrapper {
            width: 100%;
        }
        .mobile-search-wrapper .search-input-container {
            background: var(--surface);
            border-radius: 2rem;
            padding: 0.2rem 0.6rem;
            border: 1px solid var(--border);
            transition: border-color 0.2s, box-shadow 0.2s, background 0.3s;
            display: flex;
            align-items: center;
        }
        .mobile-search-wrapper .search-input-container:focus-within {
            border-color: var(--accent);
            box-shadow: 0 0 0 3px rgba(0,0,0,0.1);
        }
        .mobile-search-wrapper .search-input-container input {
            font-size: 0.95rem;
            padding: 0.6rem 0.3rem;
            background: transparent;
            border: none;
            outline: none;
            width: 100%;
            color: var(--text);
        }
        .mobile-search-wrapper .search-input-container input::placeholder {
            color: var(--muted);
            font-weight: 400;
        }
        .mobile-search-wrapper .search-input-container .search-icon {
            color: var(--muted);
            margin-right: 0.3rem;
            flex-shrink: 0;
        }
        .mobile-search-wrapper .search-dropdown {
            position: absolute;
            top: calc(100% + 0.5rem);
            left: 0;
            right: 0;
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 1rem;
            box-shadow: 0 12px 40px rgba(0,0,0,0.1);
            max-height: 60vh;
            overflow-y: auto;
            z-index: 1000;
            display: none;
            width: 100%;
        }
        .mobile-search-wrapper .search-dropdown.open {
            display: block;
        }
        .mobile-search-wrapper .search-result-item {
            padding: 0.6rem 0.8rem;
            font-size: 0.85rem;
            min-height: 48px;
            align-items: center;
        }
        .mobile-search-wrapper .search-result-item .item-title {
            font-weight: 500;
            font-size: 0.9rem;
        }
        .mobile-search-wrapper .search-result-item .item-sub {
            font-size: 0.7rem;
        }
        .mobile-search-wrapper .search-result-item .item-badge {
            font-size: 0.6rem;
            padding: 0.1rem 0.4rem;
        }
        .mobile-search-wrapper .search-dropdown .empty-message {
            padding: 1rem;
            font-size: 0.85rem;
        }

        /* ---- PWA Install Button ---- */
        #installAppBtn {
            background: var(--accent) !important;
            color: var(--bg) !important;
            transition: background 0.3s, color 0.3s;
        }
        #installAppBtn:hover {
            background: var(--accent-hover) !important;
        }
        .fallback-modal-content {
            background: var(--surface);
            color: var(--text);
            border: 1px solid var(--border);
        }
    </style>
    {% block extra_head %}{% endblock %}
</head>
<body>

    <!-- Top Bar -->
    <div class="top-bar">
        <div class="left" id="themeToggle">
            <div class="logo">{{ tenant.name|slice:":2"|upper }}</div>
            <div class="school-name">
                {{ tenant.name }}
                <small>Management Portal</small>
            </div>
        </div>
        <div class="actions">
            {% include "mobile/notification_bell.html" %}
        </div>
    </div>

    <!-- Messages -->
    {% include "tenant/messages.html" %}

    <!-- Main Content -->
    <div class="main-content">
        <div class="mobile-search-wrapper">
            {% include "tenant/global_search.html" %}
        </div>
        {% block body %}{% endblock %}
    </div>

    <!-- Bottom Navigation -->
    <nav class="bottom-nav">
        <a href="{% url 'mobile_dashboard' schema_name=tenant.schema_name %}" class="nav-item {% if request.resolver_match.url_name == 'dashboard' or request.resolver_match.url_name == 'mobile_dashboard' %}active{% endif %}">
            <svg viewBox="0 0 24 24"><path d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"/></svg>
            <span>Home</span>
        </a>
        <a href="{% url 'mobile_student_list' schema_name=tenant.schema_name %}" class="nav-item {% if 'mobile_student' in request.resolver_match.url_name or request.resolver_match.url_name == 'student_list' %}active{% endif %}">
            <svg viewBox="0 0 24 24"><path d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"/></svg>
            <span>Students</span>
        </a>
        <a href="{% url 'mobile_fee_collection' schema_name=tenant.schema_name %}" class="nav-item {% if 'fee_collection' in request.resolver_match.url_name %}active{% endif %}">
            <svg viewBox="0 0 24 24"><path d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2z"/></svg>
            <span>Collect</span>
        </a>
        <a href="{% url 'mobile_stock_management' schema_name=tenant.schema_name %}" class="nav-item {% if 'stock' in request.resolver_match.url_name %}active{% endif %}">
            <svg viewBox="0 0 24 24"><path d="M20 7h-4.18A3 3 0 0016 5.18V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v1.18A3 3 0 008.18 7H4a2 2 0 00-2 2v10a2 2 0 002 2h16a2 2 0 002-2V9a2 2 0 00-2-2z"/><path d="M12 12v4m-2-2h4"/></svg>
            <span>Stock</span>
        </a>
        <a href="{% url 'mobile_more' schema_name=tenant.schema_name %}" class="nav-item {% if request.resolver_match.url_name == 'mobile_more' %}active{% endif %}">
            <svg viewBox="0 0 24 24"><path d="M12 6a2 2 0 110-4 2 2 0 010 4zm0 8a2 2 0 110-4 2 2 0 010 4zm0 8a2 2 0 110-4 2 2 0 010 4z"/></svg>
            <span>More</span>
        </a>
    </nav>

    <!-- PWA Install Button (hidden if already installed) -->
    <div id="pwaInstallContainer" style="position: fixed; bottom: 80px; right: 20px; z-index: 9999; display: flex;">
        <button id="installAppBtn" style="border: none; border-radius: 2rem; padding: 0.6rem 1.2rem; font-weight: 600; box-shadow: 0 4px 12px rgba(0,0,0,0.15); cursor: pointer; display: flex; align-items: center; gap: 0.5rem; font-size: 0.9rem; transition: all 0.2s;">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1M12 4v12m-4-4l4 4 4-4"/>
            </svg>
            Install App
        </button>
    </div>

    <!-- Install Fallback Modal -->
    <div id="installFallbackModal" style="display:none; position:fixed; top:0; left:0; width:100%; height:100%; background:rgba(0,0,0,0.5); z-index:9999; align-items:center; justify-content:center; backdrop-filter:blur(4px);">
        <div class="fallback-modal-content" style="border-radius: 1rem; padding: 1.5rem; max-width: 400px; width: 90%; box-shadow: 0 20px 60px rgba(0,0,0,0.2);">
            <h3 style="margin-top:0; color: var(--text);">Install AXIS App</h3>
            <p style="color: var(--muted);">To install this app manually:</p>
            <ul style="padding-left:1.5rem; margin:0.5rem 0; color: var(--text);">
                <li><strong>Chrome/Edge:</strong> Tap the <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1M12 4v12m-4-4l4 4 4-4"/></svg> icon in the address bar.</li>
                <li><strong>Firefox:</strong> Menu → "Add to Home screen".</li>
                <li><strong>Safari (iOS):</strong> Share → "Add to Home Screen".</li>
            </ul>
            <button id="closeFallbackModal" style="background: var(--accent); color: var(--bg); border: none; border-radius: 2rem; padding: 0.5rem 1.2rem; font-weight: 600; cursor: pointer;">Got it</button>
        </div>
    </div>

    <script>
        (function() {
            // ---------- Theme Toggle (hidden on logo) ----------
            const toggleElement = document.getElementById('themeToggle');
            const html = document.documentElement;
            const themeMeta = document.getElementById('themeColorMeta');

            function setTheme(dark) {
                if (dark) {
                    html.classList.add('dark');
                    themeMeta.content = '#000000';
                    localStorage.setItem('axisTheme', 'dark');
                } else {
                    html.classList.remove('dark');
                    themeMeta.content = '#ffffff';
                    localStorage.setItem('axisTheme', 'light');
                }
            }

            // Load saved theme
            const savedTheme = localStorage.getItem('axisTheme');
            if (savedTheme === 'dark') {
                setTheme(true);
            } else if (savedTheme === 'light') {
                setTheme(false);
            } else {
                // Default to light
                setTheme(false);
            }

            // Toggle on click
            toggleElement.addEventListener('click', function(e) {
                const isDark = html.classList.contains('dark');
                setTheme(!isDark);
            });

            // ---------- PWA Install ----------
            let deferredPrompt = null;
            const installBtn = document.getElementById('installAppBtn');
            const container = document.getElementById('pwaInstallContainer');
            const fallbackModal = document.getElementById('installFallbackModal');

            if (window.matchMedia('(display-mode: standalone)').matches) {
                if (container) container.style.display = 'none';
            }

            window.addEventListener('beforeinstallprompt', (e) => {
                e.preventDefault();
                deferredPrompt = e;
                if (container) container.style.display = 'flex';
            });

            window.addEventListener('appinstalled', () => {
                if (container) container.style.display = 'none';
                deferredPrompt = null;
            });

            installBtn.addEventListener('click', async () => {
                if (deferredPrompt) {
                    deferredPrompt.prompt();
                    const result = await deferredPrompt.userChoice;
                    if (result.outcome === 'accepted') {
                        if (container) container.style.display = 'none';
                    } else {
                        if (fallbackModal) fallbackModal.style.display = 'flex';
                    }
                    deferredPrompt = null;
                } else {
                    if (fallbackModal) fallbackModal.style.display = 'flex';
                }
            });

            document.getElementById('closeFallbackModal')?.addEventListener('click', () => {
                if (fallbackModal) fallbackModal.style.display = 'none';
            });
            fallbackModal?.addEventListener('click', (e) => {
                if (e.target === fallbackModal) fallbackModal.style.display = 'none';
            });
        })();
    </script>

    {% include "tenant/voucher_modal.html" %}
</body>
</html>	

