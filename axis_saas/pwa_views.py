from django.http import JsonResponse, HttpResponse
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
    sw_js = """// AXIS PWA Service Worker
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
"""
    return HttpResponse(sw_js, content_type='application/javascript')
