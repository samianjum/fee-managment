#!/usr/bin/env python3
import os
import re

DESKTOP = "templates/tenant/fee_settings.html"
MOBILE = "templates/mobile/fee_settings.html"

def patch_file(filepath, btn_id, status_id, result_id):
    if not os.path.exists(filepath):
        print(f"⚠️ {filepath} not found, skipping.")
        return False

    with open(filepath, "r") as f:
        content = f.read()

    # Find the manual generation section – we'll locate the button id in the HTML
    # We'll remove any existing script block that contains the button id, then append a new one at the end.
    # Use regex to find <script>...</script> containing the button id.
    pattern = re.compile(
        r'<script>.*?' + re.escape(btn_id) + r'.*?</script>',
        re.DOTALL | re.IGNORECASE
    )
    # Remove existing script block if found
    new_content = re.sub(pattern, '', content)

    # Now add our new script just before </body>
    new_js = f'''<script>
(function() {{
    const btn = document.getElementById('{btn_id}');
    const status = document.getElementById('{status_id}');
    const resultDiv = document.getElementById('{result_id}');

    if (!btn) {{
        console.error('Button #{btn_id} not found!');
        return;
    }}
    console.log('Manual generate button found, attaching click handler.');

    btn.addEventListener('click', async function(e) {{
        e.preventDefault();
        console.log('Generate button clicked!');
        const originalText = btn.innerHTML;
        btn.disabled = true;
        btn.innerHTML = '⏳ Generating...';
        status.textContent = 'Generating fees...';
        resultDiv.style.display = 'block';
        resultDiv.innerHTML = '⏳ Processing, please wait...';
        resultDiv.style.background = 'var(--surface-alt)';
        resultDiv.style.color = 'var(--text)';

        try {{
            const csrfToken = getCsrfToken();
            if (!csrfToken) {{
                throw new Error('CSRF token not found. Please refresh the page and try again.');
            }}
            const resp = await fetch('/api/manual-generate/', {{
                method: 'POST',
                headers: {{
                    'X-CSRFToken': csrfToken,
                    'Content-Type': 'application/json',
                }},
                credentials: 'same-origin'
            }});
            console.log('Response status:', resp.status);
            if (!resp.ok) {{
                if (resp.status === 401) {{
                    throw new Error('You are not logged in. Please log in again.');
                }}
                throw new Error('Server returned ' + resp.status);
            }}
            const data = await resp.json();
            console.log('Response data:', data);

            if (data.error) {{
                resultDiv.innerHTML = '❌ Error: ' + data.error;
                resultDiv.style.background = '#fee2e2';
                resultDiv.style.color = '#991b1b';
                status.textContent = 'Failed';
                return;
            }}

            const msg = data.message || 'Fee generation completed.';
            const details = `Created: ${{data.created || 0}} | Skipped (already exist): ${{data.skipped_existing || 0}} | Skipped (no fee structure): ${{data.skipped_no_fee || 0}}`;
            resultDiv.innerHTML = '✅ ' + msg + '<br><small>' + details + '</small>';
            resultDiv.style.background = '#d1fae5';
            resultDiv.style.color = '#065f46';
            status.textContent = '✅ Done';

        }} catch (err) {{
            console.error('Error:', err);
            resultDiv.innerHTML = '❌ Error: ' + err.message;
            resultDiv.style.background = '#fee2e2';
            resultDiv.style.color = '#991b1b';
            status.textContent = '❌ Error';
        }} finally {{
            btn.disabled = false;
            btn.innerHTML = originalText;
        }}
    }});

    function getCsrfToken() {{
        let name = 'csrftoken';
        let cookieValue = null;
        if (document.cookie && document.cookie !== '') {{
            const cookies = document.cookie.split(';');
            for (let i = 0; i < cookies.length; i++) {{
                const cookie = cookies[i].trim();
                if (cookie.substring(0, name.length + 1) === (name + '=')) {{
                    cookieValue = decodeURIComponent(cookie.substring(name.length + 1));
                    break;
                }}
            }}
        }}
        console.log('CSRF token:', cookieValue ? 'found' : 'not found');
        return cookieValue;
    }}
}})();
</script>'''

    # Insert before </body>
    if "</body>" in new_content:
        new_content = new_content.replace("</body>", new_js + "\n</body>")
    else:
        new_content += new_js

    with open(filepath, "w") as f:
        f.write(new_content)

    print(f"✅ Patched {filepath}")
    return True

def main():
    print("🔧 Patching manual fee generation button JS with improved debugging...")
    ok1 = patch_file(DESKTOP, "manualGenerateBtn", "manualGenStatus", "manualGenResult")
    ok2 = patch_file(MOBILE, "manualGenerateBtnMobile", "manualGenStatusMobile", "manualGenResultMobile")
    if ok1 or ok2:
        print("\n✅ Patch applied. Restart your server and open the fee settings page.")
        print("   Open the browser console (F12) and click the 'Generate Fees Now' button.")
        print("   You will see detailed logs in the console that will help diagnose the issue.")
    else:
        print("\n❌ No files were patched. Check the template paths.")

if __name__ == "__main__":
    main()
