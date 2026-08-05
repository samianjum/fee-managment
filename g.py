#!/usr/bin/env python3
"""
AXIS Offline Caching Patcher
-----------------------------
Fixes service worker to properly cache all student profiles automatically.
Also ensures pre‑caching script runs on every page load.
"""

import os
import re
import shutil
from pathlib import Path

SW_FILE = Path("static/sw.js")
TENANT_BASE = Path("templates/tenant/base.html")
MOBILE_BASE = Path("templates/mobile/base.html")

def backup_file(path):
    backup = path.with_suffix(path.suffix + ".bak")
    shutil.copy2(path, backup)
    print(f"✅ Backup: {backup}")

def patch_sw():
    """Replace sw.js with a corrected, robust version."""
    if not SW_FILE.exists():
        print(f"❌ {SW_FILE} not found.")
        return False

    backup_file(SW_FILE)

    new_sw = """// AXIS PWA Service Worker – Corrected
const CACHE_NAME = 'axis-pwa-v4';
const STATIC_ASSETS = [
    '/manifest.json',
    '/static/icons/icon-192.png',
    '/static/icons/icon-512.png'
];

// Install – cache static assets
self.addEventListener('install', event => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then(cache => cache.addAll(STATIC_ASSETS).catch(() => {}))
    );
    self.skipWaiting();
});

// Activate – clean old caches
self.addEventListener('activate', event => {
    event.waitUntil(
        caches.keys().then(keys => Promise.all(
            keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))
        ))
    );
    self.clients.claim();
});

// Fetch strategy
self.addEventListener('fetch', event => {
    const url = new URL(event.request.url);

    // ---- 1. Student list API intercept – cache all profiles ----
    if (url.pathname.endsWith('/api/students/')) {
        event.respondWith(
            fetch(event.request).then(response => {
                const cloned = response.clone();
                // Cache the API response
                caches.open(CACHE_NAME).then(cache => cache.put(event.request, cloned));
                // Parse and cache each student profile
                response.json().then(students => {
                    if (!students || students.length === 0) return;
                    const urls = students.flatMap(s => [s.desktop_url, s.mobile_url]);
                    // Use background fetching (no need to wait)
                    Promise.all(urls.map(url =>
                        fetch(url, { cache: 'reload' })
                            .then(res => {
                                if (res.ok) {
                                    return caches.open(CACHE_NAME)
                                        .then(cache => cache.put(url, res));
                                }
                            })
                            .catch(() => {})
                    )).then(() => console.log('[SW] Pre‑cached all student profiles from API'));
                }).catch(() => {});
                return response;
            }).catch(() => caches.match(event.request))
        );
        return;
    }

    // ---- 2. Portal pages that should be cached (dashboard, students, etc.) ----
    const isCachedPage = /^\\/portal\\/[^\\/]+\\/dashboard\\//.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/dashboard\\/mobile\\//.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/dashboard\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/students\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/students\\/mobile\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/defaulters\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/defaulters\\/mobile\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/reports\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/reports\\/mobile\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/fee\\/structure\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/fee\\/structure\\/mobile\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/vouchers\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/vouchers\\/mobile\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/fee\\/logs\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/fee\\/logs\\/mobile\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/stock\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/stock\\/mobile\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/stock\\/product\\/\\d+\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/stock\\/product\\/\\d+\\/mobile\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/students\\/\\d+\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/students\\/\\d+\\/mobile\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/fee\\/receipt\\/\\d+\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/fee\\/receipt\\/mobile\\/\\d+\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/fee\\/collection\\/\\d+\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/fee\\/collection\\/mobile\\/\\d+\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/fee\\/collection\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/fee\\/collection\\/mobile\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/fee\\/settings\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/fee\\/settings\\/mobile\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/settings\\/?$/.test(url.pathname) ||
                         /^\\/portal\\/[^\\/]+\\/settings\\/mobile\\/?$/.test(url.pathname);

    // If cached page – serve from cache, update in background
    if (isCachedPage) {
        event.respondWith(
            caches.match(event.request).then(cached => {
                const fetchPromise = fetch(event.request).then(response => {
                    caches.open(CACHE_NAME).then(cache => cache.put(event.request, response.clone()));
                    return response;
                }).catch(() => {});
                if (cached) {
                    // Return cached, but update in background
                    fetchPromise.then(() => {}); // fire and forget
                    return cached;
                }
                return fetchPromise;
            })
        );
        return;
    }

    // ---- 3. API and portal requests – network first, fallback to cache ----
    if (url.pathname.startsWith('/api/') || url.pathname.startsWith('/portal/') || url.pathname === '/') {
        event.respondWith(
            fetch(event.request)
                .then(response => {
                    caches.open(CACHE_NAME).then(cache => cache.put(event.request, response.clone()));
                    return response;
                })
                .catch(() => caches.match(event.request))
        );
        return;
    }

    // ---- 4. Static assets – cache first ----
    event.respondWith(
        caches.match(event.request)
            .then(cached => cached || fetch(event.request).then(response => {
                caches.open(CACHE_NAME).then(cache => cache.put(event.request, response.clone()));
                return response;
            }))
    );
});
"""
    with open(SW_FILE, 'w') as f:
        f.write(new_sw)
    print(f"✅ {SW_FILE} rewritten with corrected service worker.")
    return True

def ensure_precache_script(template_path):
    """Make sure the pre‑caching script is present and add a periodic refresh if not already."""
    if not template_path.exists():
        print(f"⚠️ {template_path} not found, skipping.")
        return

    backup_file(template_path)

    with open(template_path, 'r') as f:
        content = f.read()

    # Check if our dynamic pre‑cache script already exists
    if 'DYNAMIC_PRECACHE_STUDENTS' in content:
        print(f"✅ {template_path} already has pre‑caching script.")
    else:
        # If missing, add it (shouldn't happen, but just in case)
        print(f"⚠️ Adding missing pre‑caching script to {template_path}")
        # We'll insert after the existing PRECACHE_PAGES script
        insert_script = """
<script>
// DYNAMIC_PRECACHE_STUDENTS – fetch and cache all student profile pages
(function() {
    if (!('caches' in window)) return;
    const schema = '{{ tenant.schema_name }}';
    const apiUrl = `/portal/${schema}/api/students/`;
    const cacheName = 'axis-pwa-v4';

    function refreshCache() {
        fetch(apiUrl, { cache: 'reload' })
            .then(res => res.json())
            .then(students => {
                if (!students || students.length === 0) return;
                const urls = students.flatMap(s => [s.desktop_url, s.mobile_url]);
                Promise.all(urls.map(url =>
                    fetch(url, { cache: 'reload' })
                        .then(res => {
                            if (res.ok) {
                                return caches.open(cacheName)
                                    .then(cache => cache.put(url, res));
                            }
                        })
                        .catch(() => {})
                )).then(() => console.log('[AXIS] Pre‑cached all student profile pages'));
            })
            .catch(() => {});
    }

    window.addEventListener('load', refreshCache);
    // Also refresh every 30 minutes if page is visible
    setInterval(() => {
        if (!document.hidden) refreshCache();
    }, 30 * 60 * 1000);
})();
</script>
"""
        # Find position after the existing PRECACHE_PAGES script (or before </body>)
        # We'll insert before </body>
        content = content.replace('</body>', insert_script + '</body>')

    # Also ensure periodic refresh is present (if not already)
    if 'setInterval' not in content or 'refreshCache' not in content:
        # Add a periodic refresh to the existing script
        # We'll add a setInterval after the load event
        # We'll search for the existing DYNAMIC_PRECACHE_STUDENTS script and inject the interval
        pattern = r'(DYNAMIC_PRECACHE_STUDENTS.*?\);\s*\}\);?\s*\}\);?\s*\}\(\)\);?)'
        # This is tricky; simpler: we'll just append a new script block
        interval_script = """
<script>
// Periodic refresh for student profiles (every 30 min)
(function() {
    if (!('caches' in window)) return;
    const schema = '{{ tenant.schema_name }}';
    const apiUrl = `/portal/${schema}/api/students/`;
    const cacheName = 'axis-pwa-v4';

    function refreshProfiles() {
        fetch(apiUrl, { cache: 'reload' })
            .then(res => res.json())
            .then(students => {
                if (!students || students.length === 0) return;
                const urls = students.flatMap(s => [s.desktop_url, s.mobile_url]);
                Promise.all(urls.map(url =>
                    fetch(url, { cache: 'reload' })
                        .then(res => {
                            if (res.ok) {
                                return caches.open(cacheName)
                                    .then(cache => cache.put(url, res));
                            }
                        })
                        .catch(() => {})
                )).then(() => console.log('[AXIS] Periodic refresh: student profiles cached'));
            })
            .catch(() => {});
    }

    // Refresh on load and then every 30 minutes
    window.addEventListener('load', refreshProfiles);
    setInterval(() => {
        if (!document.hidden) refreshProfiles();
    }, 30 * 60 * 1000);
})();
</script>
"""
        # Insert before </body>
        if interval_script not in content:
            content = content.replace('</body>', interval_script + '</body>')
            print(f"✅ Added periodic refresh to {template_path}")

    with open(template_path, 'w') as f:
        f.write(content)
    print(f"✅ {template_path} updated.")

def main():
    print("🚀 AXIS Offline Caching Patcher")
    print("   This script fixes service worker and ensures all student profiles are cached automatically.\n")

    if not patch_sw():
        print("❌ Service worker patching failed.")
        return

    # Update base templates
    ensure_precache_script(TENANT_BASE)
    ensure_precache_script(MOBILE_BASE)

    print("\n✅ All patches applied successfully!")
    print("   ▶ Restart your server and clear browser cache (or hard reload).")
    print("   ▶ Now, every page load will fetch and cache **all** student profiles with fresh data.")
    print("   ▶ Plus, every 30 minutes it will refresh if the page is open.")
    print("   ▶ No manual visits needed – all profiles stay up‑to‑date automatically.")

if __name__ == "__main__":
    main()
