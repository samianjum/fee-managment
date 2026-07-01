#!/usr/bin/env python3
"""
<<<<<<< HEAD
Final PWA fix – ensures the install button works, with clear fallback.
Run once.
"""
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.absolute()
TEMPLATES = [
    PROJECT_ROOT / "templates" / "mobile" / "base.html",
    PROJECT_ROOT / "templates" / "tenant" / "base.html"
]

INSTALL_JS = """
<script>
(function() {
    let deferredPrompt = null;
    const installBtn = document.getElementById('installAppBtn');
    const container = document.getElementById('pwaInstallContainer');
    const fallbackModal = document.getElementById('installFallbackModal');

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
                    // Still show fallback in case they change mind
                    if (fallbackModal) fallbackModal.style.display = 'flex';
                }
                deferredPrompt = null;
            } else {
                // No prompt – show fallback
                if (fallbackModal) fallbackModal.style.display = 'flex';
            }
        });
    }

    // Fallback modal close
    document.getElementById('closeFallbackModal')?.addEventListener('click', () => {
        if (fallbackModal) fallbackModal.style.display = 'none';
    });
    fallbackModal?.addEventListener('click', (e) => {
        if (e.target === fallbackModal) fallbackModal.style.display = 'none';
    });

    // If after 3 seconds no prompt, still show button
    setTimeout(() => {
        if (!window.matchMedia('(display-mode: standalone)').matches && container) {
            container.style.display = 'flex';
        }
    }, 3000);
})();
</script>
"""

BUTTON_HTML = '''<!-- PWA Install Button -->
<div id="pwaInstallContainer" style="position: fixed; bottom: 80px; left: 50%; transform: translateX(-50%); z-index: 9999; display: none;">
    <button id="installAppBtn" style="background: rgba(79,70,229,0.92); backdrop-filter: blur(8px); color: white; border: none; border-radius: 30px; padding: 8px 18px; font-weight: 600; box-shadow: 0 4px 16px rgba(0,0,0,0.15); cursor: pointer; display: flex; align-items: center; gap: 6px; font-size: 0.8rem;">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1M12 4v12m-4-4l4 4 4-4"/></svg>
        Install App
    </button>
</div>'''

FALLBACK_MODAL = '''<!-- Install Fallback Modal -->
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
</div>'''

def update_template(filepath):
    if not filepath.exists():
        print(f"⚠️  {filepath} not found")
        return
    with open(filepath, 'r', encoding='utf-8') as f:
=======
PWA Patcher for AXIS School System
Removes old PWA implementation and installs a new, fully functional one.
Usage: python3 pwa_patcher.py
"""

import os
import shutil
import re
from pathlib import Path
import sys
from datetime import datetime

# ========== CONFIGURATION ==========
PROJECT_ROOT = Path(__file__).resolve().parent
STATIC_PWA_DIR = PROJECT_ROOT / "static" / "pwa"

# ========== UTILITIES ==========
def backup_file(filepath):
    """Create a backup of the file before modifying."""
    if filepath.exists():
        backup = filepath.with_suffix(filepath.suffix + ".pwa_backup")
        shutil.copy2(filepath, backup)
        print(f"📁 Backed up {filepath} -> {backup}")

def write_file(path, content):
    """Write content to a file, creating directories if needed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"✅ Written: {path}")

def delete_file(path):
    """Delete a file if it exists."""
    if path.exists():
        path.unlink()
        print(f"🗑️ Deleted: {path}")

# ========== NEW PWA VIEWS ==========
NEW_PWA_VIEWS = """from django.http import JsonResponse, HttpResponse
from django.shortcuts import get_object_or_404
from django_tenants.utils import schema_context
from .models import SchoolClient
import json

def manifest(request, schema_name):
    \"\"\"Return PWA manifest JSON for the given tenant.\"\"\"
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
        "description": f"{name} – School/Gym Management",
        "start_url": start_url,
        "display": "standalone",
        "background_color": "#f0f2f5",
        "theme_color": "#3b82f6",
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
    \"\"\"Service Worker for AXIS PWA – modern caching strategy.\"\"\"
    sw_js = \"\"\"// AXIS PWA Service Worker
const CACHE_NAME = 'axis-pwa-v2';
const STATIC_EXTENSIONS = ['css', 'js', 'png', 'jpg', 'svg', 'ico', 'json', 'woff2'];
const STATIC_URLS = [
    '/static/pwa/icon-192x192.png',
    '/static/pwa/icon-512x512.png',
    '/static/css/base.css',   // adjust if you have a main CSS file
];

// Install: cache essential static files
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

// Activate: claim clients and clean old caches
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

// Fetch: cache-first for static files, network-first for everything else
self.addEventListener('fetch', event => {
    const url = new URL(event.request.url);
    const isStatic = STATIC_EXTENSIONS.some(ext => url.pathname.endsWith('.' + ext));
    if (isStatic || url.pathname.startsWith('/static/')) {
        event.respondWith(
            caches.match(event.request)
                .then(response => response || fetch(event.request))
                .catch(() => {
                    // Offline fallback for static files
                    return new Response('Offline', { status: 503 });
                })
        );
    } else {
        // For other requests (HTML, API), try network first, fallback to cache
        event.respondWith(
            fetch(event.request)
                .then(response => {
                    // Cache a copy for offline use
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
"""

# ========== UPDATED PUBLIC_URLS (only the PWA part) ==========
def update_public_urls():
    path = PROJECT_ROOT / "axis_saas" / "public_urls.py"
    if not path.exists():
        print("❌ public_urls.py not found")
        return

    backup_file(path)
    with open(path, "r", encoding="utf-8") as f:
>>>>>>> 7888712 (PWA new)
        content = f.read()
    # Remove old PWA code
    for pat in [
        r'<div id="pwaInstallContainer"[^>]*>.*?</div>',
        r'<div id="installFallbackModal"[^>]*>.*?</div>',
        r'<script>[\s\S]*?beforeinstallprompt[\s\S]*?</script>',
    ]:
        content = re.sub(pat, '', content, flags=re.DOTALL)
    insert = FALLBACK_MODAL + '\n' + BUTTON_HTML + '\n' + INSTALL_JS
    content = content.replace('</body>', insert + '\n</body>')
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"✅ Updated {filepath}")

<<<<<<< HEAD
def main():
    print("🔧 Final PWA fix")
    for tmpl in TEMPLATES:
        update_template(tmpl)
    print("\n✅ Done! Now visit your site via **localhost** or an HTTPS URL.")
    print("   The install button will trigger the native prompt when available.")
    print("   If not, it shows clear instructions.")
=======
    # Remove old imports (keep only what's needed)
    # We'll replace the pwa imports with the new ones.
    # The old import might be: from .pwa_views import manifest, service_worker
    # We'll change to: from .pwa_views import manifest, service_worker (they are the same names)
    # So no import change needed.

    # Ensure the routes are present and correct.
    # They already exist: path('sw.js', service_worker, name='service_worker'),
    # and path('portal/<slug:schema_name>/manifest.json', manifest, name='pwa_manifest')
    # We just need to make sure they point to the new functions, which they do if we replaced the file.

    # If there are any other PWA references, we can clean them.

    # Optionally, we can add a comment.
    # We'll not modify the file content itself, because the imports remain the same.
    # But we'll ensure that the pwa_views file is replaced.

    print("✅ public_urls.py updated (routes remain the same)")

# ========== BASE TEMPLATE OVERHAUL ==========
# We'll extract the install button HTML and JS and replace with new.

# New install button snippet (to be included in base templates)
INSTALL_BUTTON_HTML = """
    <!-- PWA Install Button (hidden when installed or not supported) -->
    <div id="pwaInstallContainer" style="position: fixed; bottom: 80px; right: 20px; z-index: 9999; display: none;">
        <button id="installAppBtn" style="background: var(--primary); color: white; border: none; border-radius: 2rem; padding: 0.6rem 1.2rem; font-weight: 600; box-shadow: 0 4px 12px rgba(0,0,0,0.2); cursor: pointer; display: flex; align-items: center; gap: 0.5rem; font-size: 0.9rem;">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1M12 4v12m-4-4l4 4 4-4"/>
            </svg>
            Install App
        </button>
    </div>
"""

INSTALL_BUTTON_JS = """
    <script>
        (function() {
            let deferredPrompt = null;
            const installBtn = document.getElementById('installAppBtn');
            const container = document.getElementById('pwaInstallContainer');

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
                        }
                        deferredPrompt = null;
                    } else {
                        showToast('Installation is not supported in this browser or already installed.');
                    }
                });
            }

            function showToast(msg) {
                const existing = document.getElementById('installToast');
                if (existing) existing.remove();
                const toast = document.createElement('div');
                toast.id = 'installToast';
                toast.style.cssText = `
                    position: fixed; bottom: 100px; left: 50%; transform: translateX(-50%);
                    background: #1e293b; color: white; padding: 12px 24px;
                    border-radius: 30px; font-size: 14px; z-index: 9999;
                    box-shadow: 0 4px 12px rgba(0,0,0,0.2);
                    max-width: 90%; text-align: center;
                    transition: opacity 0.3s;
                `;
                toast.textContent = msg;
                document.body.appendChild(toast);
                setTimeout(() => {
                    toast.style.opacity = '0';
                    setTimeout(() => toast.remove(), 400);
                }, 4000);
            }
        })();
    </script>
"""

def update_template(template_path):
    """Update a base template to use new PWA install button and remove old ones."""
    if not template_path.exists():
        print(f"⚠️ Template {template_path} not found, skipping.")
        return

    backup_file(template_path)
    with open(template_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Remove any existing install containers (old floating button, sidebar button)
    # We'll look for patterns: id="pwaInstallContainer", id="installAppSidebarBtn", etc.
    # Using regex to remove them.
    # 1. Remove the old floating container (if any)
    content = re.sub(r'<div id="pwaInstallContainer".*?</div>', '', content, flags=re.DOTALL)
    content = re.sub(r'<button id="installAppBtn".*?</button>', '', content, flags=re.DOTALL)
    # Remove sidebar install button (if exists)
    content = re.sub(r'<button id="installAppSidebarBtn".*?</button>', '', content, flags=re.DOTALL)

    # Remove any leftover install fallback modal (if any)
    content = re.sub(r'<div id="installFallbackModal".*?</div>', '', content, flags=re.DOTALL)

    # Add the new install button container (just before </body>)
    # Find the last occurrence of </body> and insert before it.
    if '</body>' in content:
        content = content.replace('</body>', INSTALL_BUTTON_HTML + INSTALL_BUTTON_JS + '\n</body>')
    else:
        # fallback: append to end
        content += INSTALL_BUTTON_HTML + INSTALL_BUTTON_JS

    # Also ensure the manifest link and sw registration are present (they already are, but we'll keep them)

    # Write back
    write_file(template_path, content)
    print(f"✅ Updated {template_path}")

# ========== GENERATE PWA ICONS ==========
def generate_icons():
    """Generate 192x192 and 512x512 PNG icons using Pillow."""
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("❌ Pillow not installed. Skipping icon generation.")
        print("   Please install Pillow: pip install Pillow")
        return

    # Create directory
    STATIC_PWA_DIR.mkdir(parents=True, exist_ok=True)

    # Colors
    bg_color = (79, 70, 229)  # Indigo
    text_color = (255, 255, 255)

    for size in [192, 512]:
        img = Image.new('RGB', (size, size), bg_color)
        draw = ImageDraw.Draw(img)
        # Draw a rounded rectangle background (optional)
        # Draw text "AXIS"
        try:
            # Use a default font (may not be available)
            font = ImageFont.truetype("arial.ttf", int(size * 0.2))
        except:
            font = ImageFont.load_default()
        text = "AXIS"
        # Get text size
        # For PIL 9.x, use textbbox
        try:
            bbox = draw.textbbox((0,0), text, font=font)
            text_width = bbox[2] - bbox[0]
            text_height = bbox[3] - bbox[1]
        except AttributeError:
            text_width, text_height = draw.textsize(text, font=font)
        x = (size - text_width) // 2
        y = (size - text_height) // 2
        draw.text((x, y), text, fill=text_color, font=font)

        # Save
        icon_path = STATIC_PWA_DIR / f"icon-{size}x{size}.png"
        img.save(icon_path, "PNG")
        print(f"✅ Generated icon: {icon_path}")

# ========== REMOVE OLD BACKUP TEMPLATES (if any) ==========
def remove_old_backup_templates():
    """Remove the mobile_backup* directories that are not used."""
    for pattern in ["mobile_backup", "mobile_backup_v2", "mobile_backup_v2_clean"]:
        backup_dir = PROJECT_ROOT / "templates" / pattern
        if backup_dir.exists():
            shutil.rmtree(backup_dir)
            print(f"🗑️ Removed old backup template directory: {backup_dir}")

# ========== MAIN ==========
def main():
    print("🚀 PWA Patcher for AXIS School System")
    print("========================================")

    # 1. Write new pwa_views.py
    pwa_views_path = PROJECT_ROOT / "axis_saas" / "pwa_views.py"
    backup_file(pwa_views_path)
    write_file(pwa_views_path, NEW_PWA_VIEWS)

    # 2. Update public_urls (no changes needed, but we ensure routes exist)
    update_public_urls()

    # 3. Update base templates (desktop and mobile)
    update_template(PROJECT_ROOT / "templates" / "tenant" / "base.html")
    update_template(PROJECT_ROOT / "templates" / "mobile" / "base.html")

    # 4. Generate icons
    generate_icons()

    # 5. Remove old backup templates (optional)
    remove_old_backup_templates()

    print("\n✅ PWA patching complete!")
    print("   - Service worker and manifest have been updated.")
    print("   - Install button logic improved.")
    print("   - PWA icons generated in static/pwa/")
    print("   - Old backup templates removed (if any).")
    print("   - Please collect static files: python manage.py collectstatic")
    print("   - Restart the server and test PWA installation.")
>>>>>>> 7888712 (PWA new)

if __name__ == "__main__":
    main()
