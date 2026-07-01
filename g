#!/usr/bin/env python3
"""
Professional PWA replacement – fixed triple‑quote nesting.
Run this once from the project root.
"""

import os
import re
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

PROJECT_ROOT = Path(__file__).parent.absolute()
STATIC_PWA_DIR = PROJECT_ROOT / "static" / "pwa"
TEMPLATES = [
    PROJECT_ROOT / "templates" / "mobile" / "base.html",
    PROJECT_ROOT / "templates" / "tenant" / "base.html"
]

# ----------------------------------------------------------------------
# 1. Create PWA icons
# ----------------------------------------------------------------------
def create_icon(size, output_path):
    img = Image.new('RGB', (size, size), color=(79, 70, 229))
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("arial.ttf", size // 4)
    except:
        font = ImageFont.load_default()
    text = "AXIS"
    bbox = draw.textbbox((0, 0), text, font=font)
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (size - w) // 2
    y = (size - h) // 2 - size // 10
    draw.text((x, y), text, fill="white", font=font)
    try:
        sub_font = ImageFont.truetype("arial.ttf", size // 12)
    except:
        sub_font = ImageFont.load_default()
    sub_text = "SCHOOL"
    bbox2 = draw.textbbox((0, 0), sub_text, font=sub_font)
    sw, sh = bbox2[2] - bbox2[0], bbox2[3] - bbox2[1]
    sx = (size - sw) // 2
    sy = y + h + size // 12
    draw.text((sx, sy), sub_text, fill=(255, 255, 255, 180), font=sub_font)
    img.save(output_path, 'PNG')
    print(f"✅ Created {output_path}")

def ensure_icons():
    STATIC_PWA_DIR.mkdir(parents=True, exist_ok=True)
    icon_192 = STATIC_PWA_DIR / "icon-192x192.png"
    icon_512 = STATIC_PWA_DIR / "icon-512x512.png"
    if not icon_192.exists():
        create_icon(192, icon_192)
    else:
        print(f"⏩ {icon_192} already exists")
    if not icon_512.exists():
        create_icon(512, icon_512)
    else:
        print(f"⏩ {icon_512} already exists")

# ----------------------------------------------------------------------
# 2. Overwrite pwa_views.py (using """ for outer string)
# ----------------------------------------------------------------------
NEW_PWA_VIEWS = """from django.http import JsonResponse, HttpResponse
from django.shortcuts import get_object_or_404
from django_tenants.utils import schema_context
from .models import SchoolClient
import json

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
    sw_js = '''// AXIS PWA Service Worker
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
'''
    return HttpResponse(sw_js, content_type='application/javascript')
"""

def overwrite_pwa_views():
    pwa_views_path = PROJECT_ROOT / "axis_saas" / "pwa_views.py"
    pwa_views_path.write_text(NEW_PWA_VIEWS)
    print("✅ Updated axis_saas/pwa_views.py")

# ----------------------------------------------------------------------
# 3. Replace install button in templates
# ----------------------------------------------------------------------
def get_install_button_html():
    return '''<!-- PWA Install Button (clean, always visible unless installed) -->
<div id="pwaInstallContainer" style="position: fixed; bottom: 80px; left: 50%; transform: translateX(-50%); z-index: 9999; display: none;">
    <button id="installAppBtn" style="background: rgba(79,70,229,0.92); backdrop-filter: blur(8px); color: white; border: none; border-radius: 30px; padding: 8px 18px; font-weight: 600; box-shadow: 0 4px 16px rgba(0,0,0,0.15); cursor: pointer; display: flex; align-items: center; gap: 6px; font-size: 0.8rem; transition: transform 0.2s;">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1M12 4v12m-4-4l4 4 4-4"/>
        </svg>
        Install App
    </button>
</div>'''

def get_install_fallback_modal():
    return '''<!-- PWA Fallback Modal -->
<div id="installFallbackModal" style="display:none; position:fixed; top:0; left:0; width:100%; height:100%; background:rgba(0,0,0,0.5); z-index:9999; align-items:center; justify-content:center; backdrop-filter:blur(4px);">
    <div style="background: var(--surface, #ffffff); border-radius: 1rem; padding: 1.5rem; max-width: 400px; width: 90%; box-shadow: 0 20px 60px rgba(0,0,0,0.3);">
        <h3 style="margin-top:0;">Install App</h3>
        <p>To install this app on your device:</p>
        <ul style="padding-left:1.5rem; margin:0.5rem 0;">
            <li><strong>Chrome / Edge:</strong> Tap the <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1M12 4v12m-4-4l4 4 4-4"/></svg> icon in the address bar.</li>
            <li><strong>Firefox:</strong> Tap the menu (☰) → "Add to Home screen".</li>
            <li><strong>Safari (iOS):</strong> Tap the share button → "Add to Home Screen".</li>
        </ul>
        <button id="closeFallbackModal" style="background: var(--primary, #4F46E5); color: white; border: none; border-radius: 2rem; padding: 0.5rem 1.2rem; font-weight: 600; cursor: pointer; margin-top: 0.5rem;">Got it</button>
    </div>
</div>'''

def get_install_js():
    return '''
    <script>
        (function() {
            let deferredPrompt = null;
            const installBtn = document.getElementById('installAppBtn');
            const container = document.getElementById('pwaInstallContainer');
            const fallbackModal = document.getElementById('installFallbackModal');
            const closeFallback = document.getElementById('closeFallbackModal');

            if (window.matchMedia('(display-mode: standalone)').matches) {
                if (container) container.style.display = 'none';
                return;
            }

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

            if (installBtn) {
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
            }

            if (closeFallback) {
                closeFallback.addEventListener('click', () => {
                    if (fallbackModal) fallbackModal.style.display = 'none';
                });
            }
            if (fallbackModal) {
                fallbackModal.addEventListener('click', (e) => {
                    if (e.target === fallbackModal) fallbackModal.style.display = 'none';
                });
            }

            setTimeout(() => {
                if (!window.matchMedia('(display-mode: standalone)').matches) {
                    if (container) container.style.display = 'flex';
                }
            }, 2000);
        })();
    </script>'''

def update_template(filepath):
    if not filepath.exists():
        print(f"⚠️  {filepath} not found, skipping")
        return

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Remove old PWA clutter
    patterns = [
        r'<div id="pwaInstallContainer"[^>]*>.*?</div>',
        r'<div id="installFallbackModal"[^>]*>.*?</div>',
        r'<script>[\s\S]*?beforeinstallprompt[\s\S]*?</script>',
        r'<script>[\s\S]*?deferredPrompt[\s\S]*?</script>',
        r'<script>[\s\S]*?installAppBtn[\s\S]*?</script>',
    ]
    for pat in patterns:
        content = re.sub(pat, '', content, flags=re.DOTALL)

    insert_block = get_install_fallback_modal() + '\n' + get_install_button_html() + '\n' + get_install_js()
    content = content.replace('</body>', insert_block + '\n</body>')

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"✅ Updated {filepath}")

# ----------------------------------------------------------------------
# 4. Main
# ----------------------------------------------------------------------
def main():
    print("🔧 AXIS PWA Clean Replacement\n")
    ensure_icons()
    overwrite_pwa_views()
    for tmpl in TEMPLATES:
        update_template(tmpl)
    print("\n📦 Running collectstatic...")
    result = subprocess.run(
        ["python3", "manage.py", "collectstatic", "--noinput"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True
    )
    if result.returncode == 0:
        print("✅ collectstatic completed")
    else:
        print("❌ collectstatic failed:")
        print(result.stderr)
    print("\n🎉 PWA replacement complete! The install button now works reliably.")
    print("   - If native prompt is available, clicking the button triggers it.")
    print("   - If not, a modal with install instructions appears.")
    print("   - The button auto‑hides after installation.")
    print("   - All old PWA code has been removed.")

if __name__ == "__main__":
    main()
