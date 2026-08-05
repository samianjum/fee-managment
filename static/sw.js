// AXIS PWA Service Worker – Auto‑cache Student Profiles
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
