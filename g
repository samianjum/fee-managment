#!/usr/bin/env python3
"""
Final PWA Patcher – makes install button always visible (if not installed)
and uses fallback modal for browsers without beforeinstallprompt.
Usage: python3 pwa_final_patcher.py
"""

import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent

# ===== New PWA views =====
PWA_VIEWS_CONTENT = '''from django.http import JsonResponse, HttpResponse
from django.shortcuts import get_object_or_404
from django_tenants.utils import schema_context
from .models import SchoolClient

def manifest(request, schema_name):
    with schema_context('public'):
        tenant = get_object_or_404(SchoolClient, schema_name=schema_name)
    name = tenant.name or schema_name.title()
    short_name = name[:12]
    start_url = f'/portal/{schema_name}/dashboard/'
    icon_url = '/static/pwa/icon-192x192.png'
    large_icon_url = '/static/pwa/icon-512x512.png'
    manifest_data = {
        "name": name,
        "short_name": short_name,
        "description": f"{name} – School & Gym Management",
        "start_url": start_url,
        "display": "standalone",
        "background_color": "#f0f4ff",
        "theme_color": "#4F46E5",
        "orientation": "portrait",
        "icons": [
            {
                "src": icon_url,
                "sizes": "192x192",
                "type": "image/png",
                "purpose": "any maskable"
            },
            {
                "src": large_icon_url,
                "sizes": "512x512",
                "type": "image/png",
                "purpose": "any maskable"
            }
        ]
    }
    return JsonResponse(manifest_data)

def service_worker(request):
    sw_js = \"\"\"// AXIS PWA Service Worker
const CACHE_NAME = 'axis-pwa-v3';
const STATIC_EXTENSIONS = ['css', 'js', 'png', 'jpg', 'svg', 'ico', 'json', 'woff2'];
const STATIC_URLS = [
    '/static/pwa/icon-192x192.png',
    '/static/pwa/icon-512x512.png',
];

self.addEventListener('install', event => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then(cache => {
                return cache.addAll(STATIC_URLS)
                    .catch(err => console.warn('Could not cache static URLs:', err));
            })
            .then(() => self.skipWaiting())
    );
});

self.addEventListener('activate', event => {
    event.waitUntil(
        caches.keys().then(keys => {
            return Promise.all(
                keys.filter(key => key !== CACHE_NAME)
                    .map(key => caches.delete(key))
            );
        }).then(() => self.clients.claim())
    );
});

self.addEventListener('fetch', event => {
    const url = new URL(event.request.url);
    const isStatic = STATIC_EXTENSIONS.some(ext => url.pathname.endsWith('.' + ext));
    if (isStatic || url.pathname.startsWith('/static/')) {
        event.respondWith(
            caches.match(event.request)
                .then(response => response || fetch(event.request))
                .catch(() => {
                    return new Response('Offline', { status: 503 });
                })
        );
    } else {
        event.respondWith(
            fetch(event.request)
                .then(response => {
                    const clone = response.clone();
                    caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
                    return response;
                })
                .catch(() => caches.match(event.request))
        );
    }
});
\"\"\"
    return HttpResponse(sw_js, content_type='application/javascript')
'''

# ===== NEW INSTALL BUTTON HTML (visible by default) =====
INSTALL_BUTTON_HTML = '''
    <!-- PWA Install Button – always visible (if not installed) -->
    <div id="pwaInstallContainer" style="position: fixed; bottom: 80px; right: 20px; z-index: 9999; display: flex;">
        <button id="installAppBtn" style="background: var(--primary); color: white; border: none; border-radius: 2rem; padding: 0.6rem 1.2rem; font-weight: 600; box-shadow: 0 4px 12px rgba(0,0,0,0.2); cursor: pointer; display: flex; align-items: center; gap: 0.5rem; font-size: 0.9rem;">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1M12 4v12m-4-4l4 4 4-4"/>
            </svg>
            Install App
        </button>
    </div>
'''

# ===== NEW INSTALL JS (with fallback) =====
INSTALL_JS = '''
    <script>
        (function() {
            let deferredPrompt = null;
            const installBtn = document.getElementById('installAppBtn');
            const container = document.getElementById('pwaInstallContainer');
            const fallbackModal = document.getElementById('installFallbackModal');

            // Hide if already installed
            if (window.matchMedia('(display-mode: standalone)').matches) {
                if (container) container.style.display = 'none';
                return;
            }

            // Listen for beforeinstallprompt
            window.addEventListener('beforeinstallprompt', (e) => {
                e.preventDefault();
                deferredPrompt = e;
                console.log('Install prompt captured');
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
                        console.log('User accepted install');
                        if (container) container.style.display = 'none';
                    } else {
                        console.log('User dismissed install');
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
'''

# ===== FALLBACK MODAL HTML =====
FALLBACK_MODAL = '''
    <!-- Install Fallback Modal -->
    <div id="installFallbackModal" style="display:none; position:fixed; top:0; left:0; width:100%; height:100%; background:rgba(0,0,0,0.5); z-index:9999; align-items:center; justify-content:center; backdrop-filter:blur(4px);">
        <div style="background: var(--surface, #fff); border-radius: 1rem; padding: 1.5rem; max-width: 400px; width: 90%; box-shadow: 0 20px 60px rgba(0,0,0,0.3);">
            <h3 style="margin-top:0;">Install AXIS App</h3>
            <p>To install this app manually:</p>
            <ul style="padding-left:1.5rem; margin:0.5rem 0;">
                <li><strong>Chrome/Edge:</strong> Tap the <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1M12 4v12m-4-4l4 4 4-4"/></svg> icon in the address bar.</li>
                <li><strong>Firefox:</strong> Menu → "Add to Home screen".</li>
                <li><strong>Safari (iOS):</strong> Share → "Add to Home Screen".</li>
            </ul>
            <button id="closeFallbackModal" style="background: var(--primary, #4F46E5); color: white; border: none; border-radius: 2rem; padding: 0.5rem 1.2rem; font-weight: 600; cursor: pointer;">Got it</button>
        </div>
    </div>
'''

def update_template(template_path):
    """Remove old install button and modal, inject new ones."""
    if not template_path.exists():
        print(f"⚠️ Template {template_path} not found, skipping.")
        return

    with open(template_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Remove all existing pwa install related blocks
    content = re.sub(r'<div id="pwaInstallContainer".*?</div>', '', content, flags=re.DOTALL)
    content = re.sub(r'<div id="installFallbackModal".*?</div>', '', content, flags=re.DOTALL)
    content = re.sub(r'<script>.*?beforeinstallprompt.*?</script>', '', content, flags=re.DOTALL)

    # Inject new install button and fallback modal (before </body>)
    if '</body>' in content:
        content = content.replace('</body>', INSTALL_BUTTON_HTML + FALLBACK_MODAL + INSTALL_JS + '\n</body>')
    else:
        content += INSTALL_BUTTON_HTML + FALLBACK_MODAL + INSTALL_JS

    # Ensure manifest link exists
    if '<link rel="manifest"' not in content:
        content = content.replace('<head>', '<head>\n    <link rel="manifest" href="/portal/{{ tenant.schema_name }}/manifest.json">\n    <meta name="theme-color" content="#3b82f6">\n    <meta name="apple-mobile-web-app-capable" content="yes">')

    with open(template_path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"✅ Updated {template_path}")

def main():
    print("🚀 Applying PWA final fix...")

    # 1. Update pwa_views.py
    pwa_path = PROJECT_ROOT / "axis_saas" / "pwa_views.py"
    with open(pwa_path, "w", encoding="utf-8") as f:
        f.write(PWA_VIEWS_CONTENT)
    print("✅ Updated pwa_views.py")

    # 2. Update templates
    update_template(PROJECT_ROOT / "templates" / "tenant" / "base.html")
    update_template(PROJECT_ROOT / "templates" / "mobile" / "base.html")

    print("\n✅ PWA final patching complete!")
    print("   - Install button is now always visible (unless installed).")
    print("   - Clicking it will try native install, else show fallback modal.")
    print("   - Please run: python manage.py collectstatic")
    print("   - Restart server and test.")

if __name__ == "__main__":
    main()
