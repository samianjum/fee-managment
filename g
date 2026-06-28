#!/usr/bin/env python3
"""
Fix for PWA Install Button on Mobile
- Moves install script to top of body for early event capture
- Hides button when app is already installed
- Replaces fallback modal with a simple toast notification
"""

import re
import os

MOBILE_BASE = "templates/mobile/base.html"

# New install script block (to be placed at top of body)
NEW_SCRIPT = """
<script>
    (function() {
        let deferredPrompt = null;
        const installBtn = document.getElementById('installAppBtn');
        const container = document.getElementById('pwaInstallContainer');

        // Hide button if already installed
        if (window.matchMedia('(display-mode: standalone)').matches) {
            if (container) container.style.display = 'none';
            return;
        }

        // Listen for beforeinstallprompt as early as possible
        window.addEventListener('beforeinstallprompt', (e) => {
            e.preventDefault();
            deferredPrompt = e;
            console.log('Install prompt captured');
            // Show the button (in case it was hidden)
            if (container) container.style.display = 'flex';
        });

        // Also listen for appinstalled to hide button
        window.addEventListener('appinstalled', () => {
            if (container) container.style.display = 'none';
            deferredPrompt = null;
        });

        // Click handler
        if (installBtn) {
            installBtn.addEventListener('click', async () => {
                if (deferredPrompt) {
                    deferredPrompt.prompt();
                    const result = await deferredPrompt.userChoice;
                    if (result.outcome === 'accepted') {
                        console.log('User accepted install');
                        if (container) container.style.display = 'none';
                    } else {
                        console.log('User dismissed install');
                    }
                    deferredPrompt = null;
                } else {
                    // No native prompt – show a brief toast instead of a modal
                    showToast('Installation is not supported in this browser or already installed.');
                }
            });
        }

        // Simple toast function
        function showToast(msg) {
            const existing = document.getElementById('installToast');
            if (existing) existing.remove();
            const toast = document.createElement('div');
            toast.id = 'installToast';
            toast.style.cssText = `
                position: fixed; bottom: 100px; left: 50%; transform: translateX(-50%);
                background: #333; color: white; padding: 12px 24px;
                border-radius: 30px; font-size: 14px; z-index: 9999;
                box-shadow: 0 4px 12px rgba(0,0,0,0.2);
                max-width: 90%; text-align: center;
                transition: opacity 0.3s;
            `;
            toast.textContent = msg;
            document.body.appendChild(toast);
            setTimeout(() => {
                toast.style.opacity = '0';
                setTimeout(() => toast.remove(), 400);
            }, 4000);
        }
    })();
</script>
"""

# Remove the old install script from the bottom and replace with the new one at the top
def patch_mobile_base():
    if not os.path.exists(MOBILE_BASE):
        print(f"❌ Error: {MOBILE_BASE} not found.")
        return

    with open(MOBILE_BASE, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Remove existing install scripts from the bottom (we'll replace with new one)
    # We'll remove the old <script> block that contains the old install logic
    # and also remove the fallback modal if present.
    # But we want to keep the fallback modal? No, we'll remove it and use toast.
    # However, the fallback modal might be used elsewhere, but it's only for install.

    # Remove the old install script block (between <script> and </script> that contains beforeinstallprompt)
    # We'll use a regex to find the old script block.
    # The old script block starts with: (function() { ... })();
    # We'll remove everything from the old script start to the closing </script>.
    # But we need to be careful not to remove other scripts.

    # The pattern: look for a script that contains "beforeinstallprompt" and "deferredPrompt"
    pattern = r'<script>\s*\(function\(\)\s*\{[\s\S]*?deferredPrompt[\s\S]*?\}\);\s*</script>'
    content = re.sub(pattern, '', content)

    # Also remove the fallback modal div (id="installFallbackModal")
    pattern_modal = r'<div id="installFallbackModal"[\s\S]*?</div>'
    content = re.sub(pattern_modal, '', content)

    # Also remove any leftover closeFallbackModal references
    content = re.sub(r'closeFallbackModal', '', content)

    # 2. Insert the new script right after <body> tag
    body_match = re.search(r'<body[^>]*>', content)
    if body_match:
        insert_pos = body_match.end()
        # Insert the new script right after the opening body tag
        content = content[:insert_pos] + "\n" + NEW_SCRIPT + "\n" + content[insert_pos:]
        print("✅ Inserted new install script at top of body.")
    else:
        print("❌ Could not find <body> tag.")
        return

    # 3. Write back
    with open(MOBILE_BASE, "w", encoding="utf-8") as f:
        f.write(content)

    print("✅ Patched mobile/base.html successfully.")
    print("🔧 Install button will now show native prompt if available, or a brief toast if not.")

if __name__ == "__main__":
    patch_mobile_base()
