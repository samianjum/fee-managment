// AXIS PWA Service Worker
const CACHE_NAME = 'axis-pwa-v4';
const STATIC_ASSETS = [
    '/manifest.json',
    '/static/icons/icon-192.png',
    '/static/icons/icon-512.png'
];

// Install event – cache static assets
self.addEventListener('install', event => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then(cache => {
                // Add all static assets we can find
                return cache.addAll(STATIC_ASSETS).catch(err => {
                    console.warn('Some assets failed to cache:', err);
                });
            })
    );
    self.skipWaiting();
});

// Activate – clean old caches
self.addEventListener('activate', event => {
    event.waitUntil(
        caches.keys().then(cacheNames => {
            return Promise.all(
                cacheNames.map(cacheName => {
                    if (cacheName !== CACHE_NAME) {
                        return caches.delete(cacheName);
                    }
                })
            );
        })
    );
    self.clients.claim();
});

// Fetch strategy: network-first for API/portal, cache-first for static
// OFFLINE_PATCH: cache on fetch for portal/api, fallback to cache
// OFFLINE_PATCH: cache-first for dashboard, network-first for others
// OFFLINE_PATCH: cache-first for dashboard & student list, network-first for others
self.addEventListener('fetch', event => {
    const url = new URL(event.request.url);

    // Check if this is a dashboard or student list page
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
                         /^\/portal\/[^\/]+\/fee\/structure\/mobile\/?$/.test(url.pathname); (serve from cache if available)
    if (isCachedPage) {
        event.respondWith(
            caches.match(event.request)
                .then(cached => {
                    if (cached) {
                        // Return cached version, but also fetch and update in background
                        fetch(event.request).then(response => {
                            caches.open(CACHE_NAME).then(cache => {
                                cache.put(event.request, response);
                            });
                        }).catch(() => {});
                        return cached;
                    }
                    // Not in cache: fetch and cache
                    return fetch(event.request).then(response => {
                        const cloned = response.clone();
                        caches.open(CACHE_NAME).then(cache => {
                            cache.put(event.request, cloned);
                        });
                        return response;
                    });
                })
        );
    }
    // For API calls and other portal pages: network-first, fallback to cache
    else if (url.pathname.startsWith('/api/') || url.pathname.startsWith('/portal/') || url.pathname === '/') {
        event.respondWith(
            fetch(event.request)
                .then(response => {
                    const cloned = response.clone();
                    caches.open(CACHE_NAME).then(cache => {
                        cache.put(event.request, cloned);
                    });
                    return response;
                })
                .catch(() => {
                    return caches.match(event.request);
                })
        );
    }
    // Static assets: cache-first
    else {
        event.respondWith(
            caches.match(event.request)
                .then(cached => {
                    if (cached) {
                        return cached;
                    }
                    return fetch(event.request).then(response => {
                        const cloned = response.clone();
                        caches.open(CACHE_NAME).then(cache => {
                            cache.put(event.request, cloned);
                        });
                        return response;
                    });
                })
        );
    }
}););););
