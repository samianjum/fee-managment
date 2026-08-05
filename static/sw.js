// AXIS PWA Service Worker – Corrected
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
                         /^\/portal\/[^\/]+\/students\/\d+\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/students\/\d+\/mobile\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/fee\/receipt\/\d+\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/fee\/receipt\/mobile\/\d+\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/fee\/collection\/\d+\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/fee\/collection\/mobile\/\d+\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/fee\/collection\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/fee\/collection\/mobile\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/fee\/settings\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/fee\/settings\/mobile\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/settings\/?$/.test(url.pathname) ||
                         /^\/portal\/[^\/]+\/settings\/mobile\/?$/.test(url.pathname);

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
