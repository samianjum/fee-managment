#!/usr/bin/env python3
"""
Patch base.html to fix sidebar, dropdowns, theme toggle and merge conflicts.
Run: python3 patch_base.py
"""

import os
import re

FILE_PATH = "templates/tenant/base.html"

def patch_base_html():
    if not os.path.exists(FILE_PATH):
        print(f"❌ File not found: {FILE_PATH}")
        return

    with open(FILE_PATH, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Remove merge conflict markers and duplicate PWA mess
    # Keep everything from the first '<!-- ===== JAVASCRIPT ===== -->' up to but
    # not including the final PWA install container (which we want to keep).
    # We'll replace that whole block with a clean version.

    # Find the JavaScript comment
    js_comment = '<!-- ===== JAVASCRIPT ===== -->'
    if js_comment not in content:
        print("❌ Could not find '<!-- ===== JAVASCRIPT ===== -->' in the file.")
        return

    # Find the final PWA install container (the one we want to keep)
    pwa_container_pattern = r'<div id="pwaInstallContainer"'
    match = re.search(pwa_container_pattern, content)
    if not match:
        print("❌ Could not find '<div id=\"pwaInstallContainer\"' in the file.")
        return
    pwa_start = match.start()

    # Split: keep everything before the JS comment, and from the PWA container onwards.
    before_js = content[:content.index(js_comment) + len(js_comment)]  # include the comment line
    after_pwa = content[pwa_start:]

    # Build the new block to insert after the JS comment
    # (including the comment itself, the voucher_modal include, and our new script)
    new_block = f"""
{js_comment}
    {{% include "tenant/voucher_modal.html" %}}

    <script>
        (function() {{
            // ----- Sidebar toggle (with persistence) -----
            const sidebar = document.getElementById('sidebar');
            const toggleBtn = document.getElementById('sidebarToggleBtn');
            const mainContent = document.getElementById('mainContent');
            const overlay = document.getElementById('sidebarOverlay');
            const mobileMenuBtn = document.getElementById('mobileMenuBtn');

            function setSidebarState(collapsed) {{
                if (collapsed) {{
                    sidebar.classList.add('collapsed');
                    localStorage.setItem('sidebarCollapsed', 'true');
                }} else {{
                    sidebar.classList.remove('collapsed');
                    localStorage.setItem('sidebarCollapsed', 'false');
                }}
            }}

            // Restore saved state
            const savedCollapse = localStorage.getItem('sidebarCollapsed');
            if (savedCollapse === 'true') {{
                setSidebarState(true);
            }}

            if (toggleBtn) {{
                toggleBtn.addEventListener('click', function(e) {{
                    e.stopPropagation();
                    const isCollapsed = !sidebar.classList.contains('collapsed');
                    setSidebarState(isCollapsed);
                }});
            }}

            // ----- Mobile menu -----
            if (mobileMenuBtn) {{
                mobileMenuBtn.addEventListener('click', function() {{
                    sidebar.classList.toggle('mobile-open');
                    overlay.classList.toggle('active');
                }});
            }}

            if (overlay) {{
                overlay.addEventListener('click', function() {{
                    sidebar.classList.remove('mobile-open');
                    overlay.classList.remove('active');
                }});
            }}

            // Close mobile menu on nav link click (for better UX)
            document.querySelectorAll('.nav-item').forEach(link => {{
                link.addEventListener('click', function() {{
                    if (window.innerWidth <= 768) {{
                        sidebar.classList.remove('mobile-open');
                        overlay.classList.remove('active');
                    }}
                }});
            }});

            // ----- Dropdown toggles (Profile & Notification) -----
            function toggleDropdown(dropdownId, buttonId) {{
                const dropdown = document.getElementById(dropdownId);
                const button = document.getElementById(buttonId);
                if (!dropdown || !button) return;
                button.addEventListener('click', function(e) {{
                    e.stopPropagation();
                    // Close other dropdowns
                    document.querySelectorAll('.dropdown-menu.show').forEach(d => {{
                        if (d.id !== dropdownId) d.classList.remove('show');
                    }});
                    dropdown.classList.toggle('show');
                }});
            }}
            toggleDropdown('profileDropdown', 'profileBtn');
            toggleDropdown('headerProfileMenu', 'headerProfileBtn');

            // Notification bell
            const notifBell = document.getElementById('notificationBell');
            const notifDropdown = document.getElementById('notificationDropdown');
            if (notifBell && notifDropdown) {{
                notifBell.addEventListener('click', function(e) {{
                    e.stopPropagation();
                    notifDropdown.classList.toggle('show');
                }});
            }}

            // Close dropdowns when clicking outside
            document.addEventListener('click', function(e) {{
                const allOpen = document.querySelectorAll('.dropdown-menu.show');
                allOpen.forEach(d => {{
                    // check if click is inside the dropdown or its trigger
                    const trigger = d.id === 'profileDropdown' ? document.getElementById('profileBtn') :
                                   d.id === 'headerProfileMenu' ? document.getElementById('headerProfileBtn') :
                                   d.id === 'notificationDropdown' ? document.getElementById('notificationBell') : null;
                    if (!d.contains(e.target) && (!trigger || !trigger.contains(e.target))) {{
                        d.classList.remove('show');
                    }}
                }});
            }});

            // ----- Theme toggle -----
            function toggleTheme() {{
                const html = document.documentElement;
                const current = html.getAttribute('data-theme');
                const next = current === 'light' ? 'dark' : 'light';
                html.setAttribute('data-theme', next);
                localStorage.setItem('theme', next);
            }}
            // Restore theme
            const savedTheme = localStorage.getItem('theme');
            if (savedTheme) {{
                document.documentElement.setAttribute('data-theme', savedTheme);
            }}
            // Expose globally for inline onclick
            window.toggleTheme = toggleTheme;

            // Also handle theme toggle from dropdown items (they call toggleTheme)
            // Additional: if any dropdown item has onclick="toggleTheme()", it will work.
        }})();
    </script>

    <!-- PWA Install Button (kept from original) -->
"""

    # Combine: before_js + new_block + after_pwa
    patched_content = before_js + "\n" + new_block + "\n" + after_pwa

    # Write back
    with open(FILE_PATH, 'w', encoding='utf-8') as f:
        f.write(patched_content)

    print(f"✅ Successfully patched {FILE_PATH}")

if __name__ == "__main__":
    patch_base_html()
