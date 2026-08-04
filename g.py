#!/usr/bin/env python3
"""
Remove the sessionStorage check from pre‑caching script,
so the dashboard & student list pages are cached on every page load.
Run: python3 cache_update_patcher.py
"""

import re
from pathlib import Path

def update_precache_script(template_path):
    if not template_path.exists():
        print(f"⚠️  {template_path} not found, skipping")
        return False

    content = template_path.read_text(encoding="utf-8")

    # Look for the pre‑caching script block
    # We'll replace the whole block with a new one that runs on every load
    new_script = '''<script>
    // PRECACHE_PAGES – automatically cache dashboard & student list pages on every load
    (function() {
        if (!('caches' in window)) return;
        const schema = '{{ tenant.schema_name }}';
        const urls = [
            `/portal/${schema}/dashboard/`,
            `/portal/${schema}/dashboard/mobile/`,
            `/portal/${schema}/students/`,
            `/portal/${schema}/students/mobile/`
        ];
        // Wait for page to be fully loaded
        window.addEventListener('load', function() {
            // Fetch each URL with cache: 'reload' to ensure fresh data
            Promise.all(urls.map(url =>
                fetch(url, { cache: 'reload' })
                    .then(res => {
                        if (res.ok) {
                            // Add to cache
                            return caches.open('axis-pwa-v4')
                                .then(cache => cache.put(url, res));
                        }
                    })
                    .catch(() => {}) // ignore offline errors
            )).then(() => console.log('[AXIS] Pre‑cached dashboard & student list'));
        });
    })();
</script>'''

    # We need to find the existing script block. It likely contains "PRECACHE_PAGES" and "sessionStorage".
    # We'll use a simple approach: find the script tag that contains "PRECACHE_PAGES" and replace it.
    pattern = re.compile(r'<script>\s*// PRECACHE_PAGES.*?</script>', re.DOTALL)
    if not pattern.search(content):
        print(f"⚠️  Could not find PRECACHE_PAGES script in {template_path}, skipping")
        return False

    new_content = pattern.sub(new_script, content)
    if new_content == content:
        print(f"⚠️  No changes made to {template_path}")
        return False

    template_path.write_text(new_content, encoding="utf-8")
    print(f"✅ Updated pre‑caching script in {template_path}")
    return True


def main():
    print("Cache Update Patcher")
    print("--------------------")
    print("This will modify the pre‑caching script to run on every page load,")
    print("so that the dashboard & student list caches are always fresh.")
    print()

    desktop_base = Path("templates/tenant/base.html")
    mobile_base = Path("templates/mobile/base.html")

    patched = False
    if desktop_base.exists():
        if update_precache_script(desktop_base):
            patched = True
    else:
        print(f"⚠️  {desktop_base} not found")

    if mobile_base.exists():
        if update_precache_script(mobile_base):
            patched = True
    else:
        print(f"⚠️  {mobile_base} not found")

    if patched:
        print("\n✅ Done! Restart your server and clear browser cache if needed.")
        print("Now, the dashboard and student list pages will be re‑cached")
        print("on every page load, ensuring they reflect the latest data.")
        print("When you add a student and then go offline, the dashboard")
        print("will show the updated count because the cache was refreshed.")
    else:
        print("\n❌ No templates were patched. Check the paths.")

if __name__ == "__main__":
    main()
