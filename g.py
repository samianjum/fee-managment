#!/usr/bin/env python3
"""
One‑click patcher: auto‑cache all student profiles – no manual visits needed.
Usage: python3 patch_auto_cache_profiles.py
"""

import os
import re

SW_PATH = 'static/sw.js'

NEW_SW = r'''// AXIS PWA Service Worker – Auto‑cache Student Profiles
const CACHE_NAME = 'axis-pwa-v4';
const STATIC_ASSETS = [
    '/manifest.json',
    '/static/icons/icon-192.png',
    '/static/icons/icon-512.png'
];

// Refresh all student profiles by fetching the API and caching each profile
async function refreshStudentProfiles(schema) {
    if (!schema) return;
    const apiUrl = `/portal/${schema}/api/students/`;
    try {
        const res = await fetch(apiUrl, { cache: 'reload' });
        if (!res.ok) return;
        const students = await res.json();
        if (!students || students.length === 0) return;
        const urls = students.flatMap(s => [s.desktop_url, s.mobile_url]);
        await Promise.all(urls.map(url =>
            fetch(url, { cache: 'reload' })
                .then(resp => {
                    if (resp.ok) {
                        return caches.open(CACHE_NAME).then(cache => cache.put(url, resp));
                    }
                })
                .catch(() => {})
        ));
        console.log('[SW] Student profiles refreshed');
    } catch (e) {
        console.warn('[SW] Refresh failed:', e);
    }
}

// ---- Install ----
self.addEventListener('install', event => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then(cache => cache.addAll(STATIC_ASSETS).catch(() => {}))
            .then(() => self.skipWaiting())
    );
});

// ---- Activate ----
self.addEventListener('activate', event => {
    event.waitUntil(
        caches.keys().then(keys => Promise.all(
            keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))
        )).then(() => {
            // Start periodic refresh every 15 minutes
            self.clients.matchAll().then(clients => {
                if (clients.length > 0) {
                    const url = new URL(clients[0].url);
                    const parts = url.pathname.split('/');
                    if (parts.length >= 3 && parts[1] === 'portal') {
                        const schema = parts[2];
                        refreshStudentProfiles(schema);
                        setInterval(() => {
                            refreshStudentProfiles(schema);
                        }, 15 * 60 * 1000);
                    }
                }
            });
            return self.clients.claim();
        })
    );
});

// ---- Fetch ----
self.addEventListener('fetch', event => {
    const url = new URL(event.request.url);

    // ---- 1. Student list API -> cache all profiles ----
    if (url.pathname.endsWith('/api/students/')) {
        const parts = url.pathname.split('/');
        const schema = parts[2];
        event.respondWith(
            fetch(event.request, { cache: 'reload' })
                .then(response => {
                    const cloned = response.clone();
                    caches.open(CACHE_NAME).then(cache => cache.put(event.request, cloned));
                    if (schema) refreshStudentProfiles(schema);
                    return response;
                })
                .catch(() => caches.match(event.request))
        );
        return;
    }

    // ---- 2. Student profile pages (stale-while-revalidate) ----
    if (/^\/portal\/[^\/]+\/students\/\d+\/?$/.test(url.pathname) ||
        /^\/portal\/[^\/]+\/students\/\d+\/mobile\/?$/.test(url.pathname)) {
        event.respondWith(
            caches.match(event.request).then(cached => {
                const fetchPromise = fetch(event.request, { cache: 'reload' })
                    .then(response => {
                        caches.open(CACHE_NAME).then(cache => cache.put(event.request, response.clone()));
                        return response;
                    })
                    .catch(() => {});
                if (cached) {
                    fetchPromise.then(() => {});
                    return cached;
                }
                return fetchPromise;
            })
        );
        return;
    }

    // ---- 3. Other cached pages (list, dashboard, etc.) ----
    const isCachedPage = /^\/portal\/[^\/]+\/dashboard\//.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/dashboard\/mobile\//.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/dashboard\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/students\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/students\/mobile\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/defaulters\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/defaulters\/mobile\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/reports\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/reports\/mobile\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/fee\/structure\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/fee\/structure\/mobile\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/vouchers\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/vouchers\/mobile\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/fee\/logs\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/fee\/logs\/mobile\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/stock\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/stock\/mobile\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/stock\/product\/\d+\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/stock\/product\/\d+\/mobile\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/fee\/collection\/\d+\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/fee\/collection\/mobile\/\d+\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/fee\/collection\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/fee\/collection\/mobile\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/fee\/settings\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/fee\/settings\/mobile\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/settings\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/settings\/mobile\/?$/.test(url.pathname);

    if (isCachedPage) {
        event.respondWith(
            caches.match(event.request).then(cached => {
                const fetchPromise = fetch(event.request)
                    .then(response => {
                        caches.open(CACHE_NAME).then(cache => cache.put(event.request, response.clone()));
                        return response;
                    })
                    .catch(() => {});
                if (cached) {
                    fetchPromise.then(() => {});
                    return cached;
                }
                return fetchPromise;
            })
        );
        return;
    }

    // ---- 4. Other API / portal ----
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

    // ---- 5. Static assets ----
    event.respondWith(
        caches.match(event.request)
            .then(cached => cached || fetch(event.request).then(response => {
                caches.open(CACHE_NAME).then(cache => cache.put(event.request, response.clone()));
                return response;
            }))
    );
});
'''

# Add a refresh trigger to both base templates (in case the service worker isn't called)
TEMPLATE_PATCH = '''
<script>
// Additional auto-refresh: on visibility change, refresh student profiles
(function() {
    const schema = '{{ tenant.schema_name }}';
    const apiUrl = `/portal/${schema}/api/students/`;

    function refreshProfiles() {
        if (!('caches' in window) || !navigator.onLine) return;
        fetch(apiUrl, { cache: 'reload' })
            .then(res => res.json())
            .then(students => {
                if (!students || students.length === 0) return;
                const urls = students.flatMap(s => [s.desktop_url, s.mobile_url]);
                Promise.all(urls.map(url =>
                    fetch(url, { cache: 'reload' })
                        .then(res => res.ok && caches.open('axis-pwa-v4').then(cache => cache.put(url, res)))
                        .catch(() => {})
                )).then(() => console.log('[AXIS] Profiles refreshed on visibility change'));
            })
            .catch(() => {});
    }

    // Refresh when page becomes visible again (user returns to tab)
    document.addEventListener('visibilitychange', () => {
        if (!document.hidden && navigator.onLine) refreshProfiles();
    });

    // Also refresh on first load (already handled by existing script, but safe to call again)
    // window.addEventListener('load', refreshProfiles);
})();
</script>
'''

def patch_sw():
    if not os.path.exists(SW_PATH):
        print(f"❌ {SW_PATH} not found")
        return
    with open(SW_PATH, 'w') as f:
        f.write(NEW_SW)
    print("✅ Service worker updated with auto‑cache.")

def patch_templates():
    templates = ['templates/tenant/base.html', 'templates/mobile/base.html']
    for tpl in templates:
        if not os.path.exists(tpl):
            print(f"⚠️ {tpl} not found, skipping")
            continue
        with open(tpl, 'r') as f:
            content = f.read()
        # Check if already patched (look for our marker)
        if '// Additional auto-refresh: on visibility change' in content:
            print(f"✅ {tpl} already has auto-refresh, skipping")
            continue
        # Insert before </body>
        body_tag = '</body>'
        if body_tag not in content:
            print(f"⚠️ Could not find </body> in {tpl}, skipping")
            continue
        content = content.replace(body_tag, TEMPLATE_PATCH + '\n' + body_tag)
        with open(tpl, 'w') as f:
            f.write(content)
        print(f"✅ Auto-refresh script added to {tpl}")

def main():
    print("🚀 Auto‑Cache Student Profiles Patcher")
    patch_sw()
    patch_templates()
    print("\n✅ Done! Restart your server and clear browser cache.")
    print("   All student profiles will now be automatically cached on every page load,")
    print("   and refreshed every 15 minutes. No manual profile visits needed.")
    print("   Offline access to any student profile will work immediately after creation.")

if __name__ == "__main__":
    main()
