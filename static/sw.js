// AXIS PWA Service Worker – Auto‑cache Student Profiles
const CACHE_NAME = 'axis-pwa-v4';
const STATIC_ASSETS = [
    '/manifest.json',
    '/static/icons/icon-192.png',
    '/static/icons/icon-512.png'
];

// ---- Configuration ----
const REFRESH_INTERVAL = 15 * 60 * 1000;   // 15 minutes
const STALE_MAX_AGE = 60 * 60 * 1000;       // 1 hour (for profile pages)

// ---- Helpers ----
function getApiUrl(schema) {
    // Extracts schema from current client URL or uses a global variable
    // We'll build it dynamically from the request.
    return `/portal/${schema}/api/students/`;
}

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
        // Fetch each profile with cache: 'reload' to bypass HTTP cache
        await Promise.all(urls.map(url =>
            fetch(url, { cache: 'reload' })
                .then(resp => {
                    if (resp.ok) {
                        return caches.open(CACHE_NAME).then(cache => cache.put(url, resp));
                    }
                })
                .catch(() => {})
        ));
        // Store last refresh timestamp
        await caches.open(CACHE_NAME).then(cache =>
            cache.put('/__student_profiles_last_refresh', new Response(Date.now().toString()))
        );
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
            // Start periodic refresh when there are clients
            self.clients.matchAll().then(clients => {
                if (clients.length > 0) {
                    // Get schema from first client URL
                    const url = new URL(clients[0].url);
                    const parts = url.pathname.split('/');
                    if (parts.length >= 3 && parts[1] === 'portal') {
                        const schema = parts[2];
                        // Refresh immediately
                        refreshStudentProfiles(schema);
                        // Set up interval
                        setInterval(() => {
                            refreshStudentProfiles(schema);
                        }, REFRESH_INTERVAL);
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

    // ---- 1. Intercept student list API ----
    if (url.pathname.endsWith('/api/students/')) {
        // Extract schema from URL
        const parts = url.pathname.split('/');
        const schema = parts[2];
        event.respondWith(
            fetch(event.request, { cache: 'reload' })
                .then(response => {
                    const cloned = response.clone();
                    // Cache the API response
                    caches.open(CACHE_NAME).then(cache => cache.put(event.request, cloned));
                    // Refresh all profiles in background
                    if (schema) {
                        refreshStudentProfiles(schema);
                    }
                    return response;
                })
                .catch(() => caches.match(event.request))
        );
        return;
    }

    // ---- 2. Student profile pages ----
    const isProfile = /^\/portal\/[^\/]+\/students\/\d+\/?$/.test(url.pathname) ||
                      /^\/portal\/[^\/]+\/students\/\d+\/mobile\/?$/.test(url.pathname);

    if (isProfile) {
        event.respondWith(
            caches.match(event.request).then(cached => {
                const fetchPromise = fetch(event.request, { cache: 'reload' })
                    .then(response => {
                        caches.open(CACHE_NAME).then(cache => cache.put(event.request, response.clone()));
                        return response;
                    })
                    .catch(() => {});

                // If cached and not too old (1 hour), return cached immediately
                if (cached) {
                    // Check cache age (we store a timestamp in a separate cache entry)
                    // For simplicity, we use a heuristic: if we have a cached version,
                    // we serve it and update in background regardless of age.
                    // To enforce freshness, we could check a timestamp, but we'll keep it simple.
                    // Return cached, but update in background
                    fetchPromise.then(() => {});
                    return cached;
                }
                // No cache: wait for network
                return fetchPromise;
            })
        );
        return;
    }

    // ---- 3. Other portal pages (cached pages list) ----
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

    // ---- 4. Other API & portal requests ----
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
