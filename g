#!/usr/bin/env python3
"""
Mobile Install Button Patcher for AXIS School System
Adds the PWA install button and logic to mobile/base.html
Run: python3 mobile_install_patcher.py
"""

import os
import re

MOBILE_BASE = "templates/mobile/base.html"
FLOATING_BTN_HTML = '''
    <!-- Floating Install Button (mobile) -->
    <div id="pwaInstallContainer" style="position: fixed; bottom: 80px; right: 20px; z-index: 9999; display: flex;">
        <button id="installAppBtn" style="background: var(--primary); color: white; border: none; border-radius: 2rem; padding: 0.6rem 1.2rem; font-weight: 600; box-shadow: 0 4px 12px rgba(0,0,0,0.2); cursor: pointer; display: flex; align-items: center; gap: 0.5rem; font-size: 0.9rem;">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1M12 4v12m-4-4l4 4 4-4"/>
            </svg>
            Install App
        </button>
    </div>
'''

FALLBACK_MODAL_HTML = '''
<!-- Fallback Install Modal -->
<div id="installFallbackModal" style="display:none; position:fixed; top:0; left:0; width:100%; height:100%; background:rgba(0,0,0,0.5); z-index:9999; align-items:center; justify-content:center;">
    <div style="background: var(--surface); border-radius: 1rem; padding: 1.5rem; max-width: 400px; width: 90%; box-shadow: 0 20px 60px rgba(0,0,0,0.3);">
        <h3 style="margin-top:0;">Install App</h3>
        <p>To install this app on your device:</p>
        <ul style="padding-left:1.5rem; margin:0.5rem 0;">
            <li><strong>Chrome / Edge:</strong> Click the <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1M12 4v12m-4-4l4 4 4-4"/></svg> icon in the address bar.</li>
            <li><strong>Firefox:</strong> Tap the menu (☰) → "Add to Home screen".</li>
            <li><strong>Safari (iOS):</strong> Tap the share button → "Add to Home Screen".</li>
        </ul>
        <button id="closeFallbackModal" style="background: var(--primary); color: white; border: none; border-radius: 2rem; padding: 0.5rem 1.2rem; font-weight: 600; cursor: pointer; margin-top: 0.5rem;">Got it</button>
    </div>
</div>
'''

INSTALL_SCRIPT = '''
<script>
    (function() {
        let deferredPrompt;
        const floatingBtn = document.getElementById('installAppBtn');
        const fallbackModal = document.getElementById('installFallbackModal');

        window.addEventListener('beforeinstallprompt', (e) => {
            e.preventDefault();
            deferredPrompt = e;
            console.log('beforeinstallprompt fired');
        });

        async function triggerInstall() {
            if (deferredPrompt) {
                deferredPrompt.prompt();
                const result = await deferredPrompt.userChoice;
                if (result.outcome === 'accepted') {
                    console.log('User accepted install');
                    const container = document.getElementById('pwaInstallContainer');
                    if (container) container.style.display = 'none';
                } else {
                    console.log('User dismissed install');
                }
                deferredPrompt = null;
            } else {
                // No native prompt – show fallback modal
                if (fallbackModal) fallbackModal.style.display = 'flex';
            }
        }

        if (floatingBtn) {
            floatingBtn.addEventListener('click', triggerInstall);
        }

        window.addEventListener('appinstalled', () => {
            console.log('App installed');
            const container = document.getElementById('pwaInstallContainer');
            if (container) container.style.display = 'none';
        });

        const closeFallback = document.getElementById('closeFallbackModal');
        if (closeFallback) {
            closeFallback.addEventListener('click', () => {
                if (fallbackModal) fallbackModal.style.display = 'none';
            });
        }
        if (fallbackModal) {
            fallbackModal.addEventListener('click', (e) => {
                if (e.target === fallbackModal) fallbackModal.style.display = 'none';
            });
        }
    })();
</script>
'''

def patch_mobile_base():
    if not os.path.exists(MOBILE_BASE):
        print(f"❌ Error: {MOBILE_BASE} not found. Are you in the project root?")
        return

    with open(MOBILE_BASE, "r", encoding="utf-8") as f:
        content = f.read()

    # Check if already patched
    if 'pwaInstallContainer' in content:
        print("✅ Mobile base already contains install button. No changes needed.")
        return

    # Insert floating button before the bottom nav (or before closing body)
    # Locate the bottom nav div or the closing body tag
    bottom_nav_match = re.search(r'<nav class="bottom-nav">', content)
    if bottom_nav_match:
        insert_pos = bottom_nav_match.start()
        # Insert the floating button just before the bottom nav
        content = content[:insert_pos] + FLOATING_BTN_HTML + "\n\n" + content[insert_pos:]
        print("✅ Inserted floating button before bottom nav.")
    else:
        # Fallback: insert before </body>
        body_end = content.rfind('</body>')
        if body_end != -1:
            content = content[:body_end] + FLOATING_BTN_HTML + "\n" + content[body_end:]
            print("✅ Inserted floating button before closing body.")
        else:
            print("⚠️ Could not locate insertion point. Please add the button manually.")
            return

    # Insert fallback modal and script just before </body> as well
    # We'll put them after the floating button, before </body>
    body_end = content.rfind('</body>')
    if body_end != -1:
        insert = FALLBACK_MODAL_HTML + "\n" + INSTALL_SCRIPT + "\n"
        content = content[:body_end] + insert + content[body_end:]
        print("✅ Added fallback modal and install script.")
    else:
        print("⚠️ Could not find </body> to insert scripts.")

    # Write back
    with open(MOBILE_BASE, "w", encoding="utf-8") as f:
        f.write(content)

    print("🎉 Patcher completed successfully!")
    print("👉 Restart your server and test on mobile.")

if __name__ == "__main__":
    patch_mobile_base()
