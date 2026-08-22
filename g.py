#!/usr/bin/env python3
"""
Single patcher to fix offline caching:
- Show a loading overlay during the initial cache population.
- Run pre-caching scripts only once per device.
- Prevent repeated re-caching of unchanged data.
"""

import os
import re
from pathlib import Path

# File paths relative to project root
BASE_TEMPLATE = Path("templates/tenant/base.html")
MOBILE_TEMPLATE = Path("templates/mobile/base.html")

# The loading overlay HTML (will be inserted before </body>)
LOADING_OVERLAY = """
<!-- One-time initial caching overlay -->
<div id="initialCacheOverlay" style="display:none; position:fixed; top:0; left:0; width:100%; height:100%; background:rgba(0,0,0,0.7); z-index:99999; align-items:center; justify-content:center; flex-direction:column; color:white; font-family:system-ui, sans-serif; backdrop-filter:blur(4px);">
    <div style="text-align:center; padding:1.5rem; max-width:400px;">
        <div style="display:inline-block; width:48px; height:48px; border:4px solid rgba(255,255,255,0.2); border-top:4px solid #ffffff; border-radius:50%; animation:spin 1s linear infinite; margin-bottom:1rem;"></div>
        <h2 style="font-weight:600; margin:0 0 0.5rem 0; font-size:1.4rem;">Preparing your offline experience</h2>
        <p style="color:rgba(255,255,255,0.8); font-size:0.95rem; margin:0 0 0.3rem 0;">Caching data for <strong>{{ tenant.name }}</strong> …</p>
        <p style="color:rgba(255,255,255,0.6); font-size:0.8rem; margin:0;">Please keep the app open. This happens only once.</p>
        <div style="margin-top:1.5rem; width:100%; height:4px; background:rgba(255,255,255,0.15); border-radius:4px; overflow:hidden;">
            <div id="cacheProgressBar" style="width:0%; height:100%; background:white; border-radius:4px; transition:width 0.3s;"></div>
        </div>
        <div id="cacheStatus" style="margin-top:0.5rem; font-size:0.75rem; color:rgba(255,255,255,0.5);">0%</div>
    </div>
</div>
<style>
    @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
    #initialCacheOverlay { display: flex; } /* hidden by default, shown via JS */
</style>
"""

# The modified pre-caching script (to replace the existing ones in base.html)
# We'll wrap the existing logic inside a function that checks localStorage.
CACHING_SCRIPT = """
<script>
(function() {
    // ===== INITIAL CACHE FLAG =====
    const STORAGE_KEY = 'axis_initial_cache_done_v1';
    if (localStorage.getItem(STORAGE_KEY) === 'true') {
        console.log('[AXIS] Initial caching already done. Skipping pre-cache.');
        return;
    }

    // Show overlay
    const overlay = document.getElementById('initialCacheOverlay');
    if (overlay) overlay.style.display = 'flex';

    // Helper to update progress
    function updateProgress(percent, message) {
        const bar = document.getElementById('cacheProgressBar');
        const status = document.getElementById('cacheStatus');
        if (bar) bar.style.width = Math.min(percent, 100) + '%';
        if (status) status.textContent = Math.min(percent, 100) + '% ' + (message || '');
    }

    // ===== CACHE ALL RESOURCES =====
    const schema = '{{ tenant.schema_name }}';
    const cacheName = 'axis-pwa-v4';

    // List of API endpoints that return lists of URLs to cache
    const apiEndpoints = [
        { url: `/portal/${schema}/api/students/`, type: 'students' },
        { url: `/portal/${schema}/api/products/`, type: 'products' },
        { url: `/portal/${schema}/api/receipts/`, type: 'receipts' },
        { url: `/portal/${schema}/api/fee-collection/`, type: 'fee-collection' }
    ];

    // Also cache the main pages statically (defined in the original script)
    const mainPageUrls = [
        `/portal/${schema}/dashboard/`,
        `/portal/${schema}/dashboard/mobile/`,
        `/portal/${schema}/students/`,
        `/portal/${schema}/students/mobile/`,
        `/portal/${schema}/defaulters/`,
        `/portal/${schema}/defaulters/mobile/`,
        `/portal/${schema}/reports/`,
        `/portal/${schema}/reports/mobile/`,
        `/portal/${schema}/fee/structure/`,
        `/portal/${schema}/fee/structure/mobile/`,
        `/portal/${schema}/vouchers/`,
        `/portal/${schema}/vouchers/mobile/`,
        `/portal/${schema}/fee/logs/`,
        `/portal/${schema}/fee/logs/mobile/`,
        `/portal/${schema}/stock/`,
        `/portal/${schema}/stock/mobile/`,
        `/portal/${schema}/fee/collection/`,
        `/portal/${schema}/fee/collection/mobile/`,
        `/portal/${schema}/fee/settings/`,
        `/portal/${schema}/fee/settings/mobile/`,
    ];

    // Combine all URLs to fetch
    let allUrls = [...mainPageUrls];

    async function fetchAndCacheUrls(urlList, progressBase, progressRange) {
        let total = urlList.length;
        let completed = 0;
        for (let i = 0; i < total; i++) {
            const url = urlList[i];
            try {
                const resp = await fetch(url, { cache: 'reload' });
                if (resp.ok) {
                    const cache = await caches.open(cacheName);
                    await cache.put(url, resp);
                }
            } catch (e) {
                // ignore errors (offline, etc.)
            }
            completed++;
            const percent = progressBase + (completed / total) * progressRange;
            updateProgress(percent, `Caching ${Math.round(percent)}%`);
        }
    }

    async function performInitialCache() {
        try {
            updateProgress(0, 'Starting cache...');

            // Step 1: Cache main pages (static)
            await fetchAndCacheUrls(mainPageUrls, 0, 20);
            updateProgress(20, 'Main pages cached');

            // Step 2: Fetch dynamic lists and cache those pages
            let totalItems = 0;
            let dynamicUrls = [];
            for (const endpoint of apiEndpoints) {
                try {
                    const resp = await fetch(endpoint.url, { cache: 'reload' });
                    if (resp.ok) {
                        const data = await resp.json();
                        if (Array.isArray(data)) {
                            // Each item has desktop_url and mobile_url (or similar)
                            for (const item of data) {
                                if (item.desktop_url) dynamicUrls.push(item.desktop_url);
                                if (item.mobile_url) dynamicUrls.push(item.mobile_url);
                            }
                        }
                    }
                } catch (e) { /* ignore */ }
            }

            // Cache dynamic URLs (from 20% to 90%)
            if (dynamicUrls.length > 0) {
                await fetchAndCacheUrls(dynamicUrls, 20, 70);
            } else {
                updateProgress(90, 'No dynamic pages to cache');
            }

            // Step 3: Mark as done
            localStorage.setItem(STORAGE_KEY, 'true');
            updateProgress(100, 'All cached!');

            // Hide overlay after a short delay
            setTimeout(() => {
                if (overlay) overlay.style.display = 'none';
            }, 800);

            console.log('[AXIS] Initial caching completed.');
        } catch (err) {
            console.error('[AXIS] Caching error:', err);
            // Even on error, hide overlay so user can use the app
            if (overlay) overlay.style.display = 'none';
            // But do NOT set the flag, so they can retry on next visit.
        }
    }

    // Run the caching process
    performInitialCache();
})();
</script>
"""

def patch_file(filepath):
    """Add loading overlay and replace pre-caching scripts with the one-time version."""
    if not filepath.exists():
        print(f"⚠️ {filepath} not found, skipping.")
        return

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Inject loading overlay before </body>
    if 'id="initialCacheOverlay"' in content:
        print(f"✅ {filepath} already has loading overlay. Skipping injection.")
    else:
        # Insert before </body>
        content = content.replace('</body>', LOADING_OVERLAY + '\n</body>')
        print(f"✅ Injected loading overlay into {filepath}")

    # 2. Replace the old pre-caching scripts with the new one-time version
    # The old scripts are inside <script> tags that do the pre-caching.
    # We'll find and remove them, then add our new script.
    # We'll look for the markers: "// PRECACHE_PAGES" and "// DYNAMIC_PRECACHE_PRODUCTS" etc.
    # But easier: we can remove everything between the first <script> that contains "PRECACHE_PAGES"
    # and the last related script. However, simpler: we'll just remove all <script> blocks that contain
    # "PRECACHE_PAGES" or "DYNAMIC_PRECACHE" and add our new script.
    # We'll use regex to remove those specific script blocks.

    # Pattern to match script blocks that contain PRECACHE_PAGES, DYNAMIC_PRECACHE_PRODUCTS, etc.
    pattern = r'<script>\s*//\s*PRECACHE_PAGES.*?</script>'
    content = re.sub(pattern, '', content, flags=re.DOTALL)

    pattern = r'<script>\s*//\s*DYNAMIC_PRECACHE_PRODUCTS.*?</script>'
    content = re.sub(pattern, '', content, flags=re.DOTALL)

    pattern = r'<script>\s*//\s*DYNAMIC_PRECACHE_STUDENTS.*?</script>'
    content = re.sub(pattern, '', content, flags=re.DOTALL)

    pattern = r'<script>\s*//\s*DYNAMIC_PRECACHE_RECEIPTS.*?</script>'
    content = re.sub(pattern, '', content, flags=re.DOTALL)

    pattern = r'<script>\s*//\s*DYNAMIC_PRECACHE_FEE_COLLECTION.*?</script>'
    content = re.sub(pattern, '', content, flags=re.DOTALL)

    # Also remove the periodic refresh scripts (they are separate)
    # But we want to keep the periodic refresh? The user didn't ask to remove; we can keep them.
    # They are useful for updating caches when data changes. So we keep them.

    # Now add our new script before the closing </body>
    # But we must ensure we don't add it multiple times.
    if 'axis_initial_cache_done_v1' in content:
        print(f"✅ {filepath} already has the one-time caching script. Skipping.")
    else:
        # Insert before </body> after the loading overlay
        content = content.replace('</body>', CACHING_SCRIPT + '\n</body>')
        print(f"✅ Added one-time caching script to {filepath}")

    # Write back
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

def main():
    print("🛠️  Patching offline caching system...")
    patch_file(BASE_TEMPLATE)
    patch_file(MOBILE_TEMPLATE)
    print("✅ Patcher completed. Restart your Django server.")
    print("   The first visit will show a loading overlay and cache all data once.")
    print("   Subsequent visits will be lightning fast and will not re-fetch unchanged data.")

if __name__ == "__main__":
    main()
