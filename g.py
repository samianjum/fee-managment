#!/usr/bin/env python3
"""
Patcher to enhance service worker: when student list API is fetched,
automatically cache all student profile pages.
Run: python3 patch_student_offline_sw.py
"""

import re
import os

SW_PATH = 'static/sw.js'

# ----------------------------------------------------------------------
# Patch service worker to intercept student list API and cache profiles
# ----------------------------------------------------------------------
def patch_sw():
    if not os.path.exists(SW_PATH):
        print(f"❌ {SW_PATH} not found")
        return

    with open(SW_PATH, 'r') as f:
        content = f.read()

    # Check if already patched
    if 'student-list-cache' in content:
        print("✅ Service worker already patched for student list API, skipping.")
        return

    # Find the fetch event handler's API/portal branch
    # We'll insert a check for /api/students/ and cache profile pages.
    # Look for the line: else if (url.pathname.startsWith('/api/') || url.pathname.startsWith('/portal/') || url.pathname === '/') {
    pattern = r'(else if \(url\.pathname\.startsWith\(\'\/api\/\'\) \|\| url\.pathname\.startsWith\(\'\/portal\/\'\) \|\| url\.pathname === \'\/\'\) \{)'
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        print("❌ Could not find the API/portal fetch branch in sw.js")
        return

    # We'll insert our custom logic inside that branch, before the existing fetch/respondWith.
    # We need to locate the exact fetch call and add a .then that caches profiles.
    # But we can also add a separate condition before that block, but to keep it clean, we'll add a new branch before it.

    # Actually we can add a new condition specifically for the student list API.
    # Find the start of the fetch event listener.
    fetch_listener = 'self.addEventListener(\'fetch\', event => {'
    if fetch_listener not in content:
        print("❌ Could not find fetch event listener")
        return

    # We'll add a new conditional block inside the fetch listener, before the existing isCachedPage check.
    # But to avoid messing up, we'll insert after the isCachedPage block, before the else-if for API.
    # Let's find the line where isCachedPage ends and the else-if begins.
    # The existing code has:
    # if (isCachedPage) { ... }
    # else if (url.pathname.startsWith('/api/') || ... ) { ... }
    # We'll insert a new 'if' after the isCachedPage block.

    # We'll find the position after the closing brace of the isCachedPage if statement.
    # It's easier to append our logic after the isCachedPage block but before the next else-if.
    # We'll search for the end of the isCachedPage block: the line with the closing brace before the next else.
    # Pattern: if (isCachedPage) { ... } (the block may span multiple lines)
    # We'll use a regex to find the entire isCachedPage block and insert after it.

    is_cached_block = r'(if \(isCachedPage\) \{.*?\n\s*\})'
    match_block = re.search(is_cached_block, content, re.DOTALL)
    if not match_block:
        print("❌ Could not find isCachedPage block")
        return

    # Build the new block to insert after it
    new_block = '''
    // student-list-cache: when student list API is fetched, cache all student profile pages
    if (url.pathname.endsWith('/api/students/')) {
        event.respondWith(
            fetch(event.request).then(response => {
                const cloned = response.clone();
                // Cache the API response itself
                caches.open(CACHE_NAME).then(cache => {
                    cache.put(event.request, cloned);
                });
                // Also fetch and cache each student profile
                response.json().then(students => {
                    if (!students || students.length === 0) return;
                    const urls = students.flatMap(s => [s.desktop_url, s.mobile_url]);
                    Promise.all(urls.map(url =>
                        fetch(url, { cache: 'reload' })
                            .then(res => {
                                if (res.ok) {
                                    return caches.open(CACHE_NAME)
                                        .then(cache => cache.put(url, res));
                                }
                            })
                            .catch(() => {})
                    )).then(() => console.log('[SW] Pre‑cached student profiles from API'));
                }).catch(() => {});
                return response;
            }).catch(() => {
                return caches.match(event.request);
            })
        );
    }
    else '''
    # Insert after the isCachedPage block
    insert_pos = match_block.end()
    content = content[:insert_pos] + new_block + content[insert_pos:]

    with open(SW_PATH, 'w') as f:
        f.write(content)
    print("✅ Service worker patched with student list API caching.")

# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------
def main():
    print("🚀 AXIS Student Profile Offline SW Patcher")
    patch_sw()
    print("\n✅ Done! Restart your server and clear browser cache.")
    print("   Now, whenever the student list API is called (on any page load),")
    print("   all student profile pages will be cached automatically.")

if __name__ == "__main__":
    main()
