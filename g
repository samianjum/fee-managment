#!/usr/bin/env python3
import os
import shutil
from datetime import datetime

FILE_PATH = "templates/mobile/base.html"
MARKER = "<!-- VOUCHER MODAL INCLUDED -->"
INCLUDE_LINE = '    {% include "tenant/voucher_modal.html" %}'
STYLE_PATCH = """
<style>
    /* Ensure voucher modal works on mobile */
    .modal { position: fixed; top:0; left:0; width:100%; height:100%; background:rgba(0,0,0,0.5); display:none; align-items:center; justify-content:center; z-index:9999; backdrop-filter:blur(4px); padding:1rem; }
    .modal.show { display:flex; }
    .modal-content { background: #ffffff; border-radius: 1.5rem; max-width: 820px; width:100%; max-height:90vh; overflow-y:auto; padding:1.5rem; box-shadow:0 20px 60px rgba(0,0,0,0.3); position:relative; }
    .close-modal { position:absolute; top:0.8rem; right:1rem; background:none; border:none; font-size:1.8rem; cursor:pointer; color:#6b7280; line-height:1; padding:0 0.3rem; z-index:10; }
    .modal-footer { display:flex; flex-wrap:wrap; gap:0.5rem; justify-content:flex-end; margin-top:1rem; padding-top:0.75rem; border-top:1px solid #e5e7eb; }
    .btn-action { display:inline-flex; align-items:center; gap:0.4rem; padding:0.5rem 1rem; border-radius:0.5rem; font-weight:600; font-size:0.85rem; border:1px solid #e5e7eb; background:#f9fafb; color:#1f2937; cursor:pointer; }
    .btn-action:hover { background:#f3f4f6; }
    .voucher-form { padding:0.2rem 0; }
    /* ... plus all the other styles from voucher_modal.html ... */
"""
def main():
    if not os.path.isfile(FILE_PATH):
        print(f"❌ File not found: {FILE_PATH}")
        return

    with open(FILE_PATH, 'r', encoding='utf-8') as f:
        content = f.read()

    if MARKER in content:
        print("✅ Fix already applied. Nothing to do.")
        return

    # Insert the include before </body>
    if '</body>' not in content:
        print("❌ Could not find </body> tag.")
        return

    # We also need the styles from voucher_modal.html, but they are inside that file.
    # To avoid duplication, we'll just include the file, and it will bring its own style.
    # However, to ensure the modal works, we also need to ensure the modal styles are present.
    # The voucher_modal.html contains a <style> block with all required styles, so including it is enough.

    # Backup
    backup = f"{FILE_PATH}.bak.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    shutil.copy2(FILE_PATH, backup)
    print(f"📁 Backup created: {backup}")

    # Insert the include before </body>
    # We'll add a newline and the include line, and also the marker comment.
    new_content = content.replace('</body>', f"\n    {INCLUDE_LINE}\n    {MARKER}\n</body>", 1)

    with open(FILE_PATH, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print("✅ Mobile voucher modal included successfully!")
    print("➡️ Restart your Django server and test the voucher button on mobile.")

if __name__ == "__main__":
    main()
