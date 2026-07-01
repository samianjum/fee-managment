#!/usr/bin/env python3
"""
Final PWA fix – ensures the install button works, with clear fallback.
Run once.
"""
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.absolute()
TEMPLATES = [
    PROJECT_ROOT / "templates" / "mobile" / "base.html",
    PROJECT_ROOT / "templates" / "tenant" / "base.html"
]

INSTALL_JS = """
<script>
(function() {
    let deferredPrompt = null;
    const installBtn = document.getElementById('installAppBtn');
    const container = document.getElementById('pwaInstallContainer');
    const fallbackModal = document.getElementById('installFallbackModal');

    if (window.matchMedia('(display-mode: standalone)').matches) {
        if (container) container.style.display = 'none';
        return;
    }

    window.addEventListener('beforeinstallprompt', (e) => {
        e.preventDefault();
        deferredPrompt = e;
        console.log('Install prompt captured');
        if (container) container.style.display = 'flex';
    });

    window.addEventListener('appinstalled', () => {
        if (container) container.style.display = 'none';
        deferredPrompt = null;
    });

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
                    // Still show fallback in case they change mind
                    if (fallbackModal) fallbackModal.style.display = 'flex';
                }
                deferredPrompt = null;
            } else {
                // No prompt – show fallback
                if (fallbackModal) fallbackModal.style.display = 'flex';
            }
        });
    }

    // Fallback modal close
    document.getElementById('closeFallbackModal')?.addEventListener('click', () => {
        if (fallbackModal) fallbackModal.style.display = 'none';
    });
    fallbackModal?.addEventListener('click', (e) => {
        if (e.target === fallbackModal) fallbackModal.style.display = 'none';
    });

    // If after 3 seconds no prompt, still show button
    setTimeout(() => {
        if (!window.matchMedia('(display-mode: standalone)').matches && container) {
            container.style.display = 'flex';
        }
    }, 3000);
})();
</script>
"""

BUTTON_HTML = '''<!-- PWA Install Button -->
<div id="pwaInstallContainer" style="position: fixed; bottom: 80px; left: 50%; transform: translateX(-50%); z-index: 9999; display: none;">
    <button id="installAppBtn" style="background: rgba(79,70,229,0.92); backdrop-filter: blur(8px); color: white; border: none; border-radius: 30px; padding: 8px 18px; font-weight: 600; box-shadow: 0 4px 16px rgba(0,0,0,0.15); cursor: pointer; display: flex; align-items: center; gap: 6px; font-size: 0.8rem;">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1M12 4v12m-4-4l4 4 4-4"/></svg>
        Install App
    </button>
</div>'''

FALLBACK_MODAL = '''<!-- Install Fallback Modal -->
<div id="installFallbackModal" style="display:none; position:fixed; top:0; left:0; width:100%; height:100%; background:rgba(0,0,0,0.5); z-index:9999; align-items:center; justify-content:center; backdrop-filter:blur(4px);">
    <div style="background: var(--surface, #fff); border-radius: 1rem; padding: 1.5rem; max-width: 400px; width: 90%; box-shadow: 0 20px 60px rgba(0,0,0,0.3);">
        <h3 style="margin-top:0;">Install AXIS App</h3>
        <p>To install this app manually:</p>
        <ul style="padding-left:1.5rem; margin:0.5rem 0;">
            <li><strong>Chrome/Edge:</strong> Tap the <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1M12 4v12m-4-4l4 4 4-4"/></svg> icon in the address bar.</li>
            <li><strong>Firefox:</strong> Menu → "Add to Home screen".</li>
            <li><strong>Safari (iOS):</strong> Share → "Add to Home Screen".</li>
        </ul>
        <button id="closeFallbackModal" style="background: var(--primary, #4F46E5); color: white; border: none; border-radius: 2rem; padding: 0.5rem 1.2rem; font-weight: 600; cursor: pointer;">Got it</button>
    </div>
</div>'''

def update_template(filepath):
    if not filepath.exists():
        print(f"⚠️  {filepath} not found")
        return
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    # Remove old PWA code
    for pat in [
        r'<div id="pwaInstallContainer"[^>]*>.*?</div>',
        r'<div id="installFallbackModal"[^>]*>.*?</div>',
        r'<script>[\s\S]*?beforeinstallprompt[\s\S]*?</script>',
    ]:
        content = re.sub(pat, '', content, flags=re.DOTALL)
    insert = FALLBACK_MODAL + '\n' + BUTTON_HTML + '\n' + INSTALL_JS
    content = content.replace('</body>', insert + '\n</body>')
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"✅ Updated {filepath}")

def main():
    print("🔧 Final PWA fix")
    for tmpl in TEMPLATES:
        update_template(tmpl)
    print("\n✅ Done! Now visit your site via **localhost** or an HTTPS URL.")
    print("   The install button will trigger the native prompt when available.")
    print("   If not, it shows clear instructions.")

if __name__ == "__main__":
    main()
