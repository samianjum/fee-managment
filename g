#!/usr/bin/env python3
"""
AXIS School System – Remove "Generate Current Month Fee" modal from desktop student_profile.html
Run: python3 remove_gen_fee_modal.py
"""

import re
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
FILE_PATH = BASE_DIR / "templates" / "tenant" / "student_profile.html"

with open(FILE_PATH, "r") as f:
    content = f.read()

# Find the start of the modal block
start_marker = "<!-- Custom Fee Modal (inside body block) -->"
if start_marker not in content:
    print("⚠️ Could not find the modal comment. Maybe already removed?")
    # Try to find by id="customFeeModal"
    start_pattern = r'<div\s+id="customFeeModal"[^>]*>'
    match = re.search(start_pattern, content)
    if not match:
        print("❌ Modal not found. Nothing to remove.")
        exit(0)
    start_pos = match.start()
else:
    start_pos = content.find(start_marker)

# Find the next occurrence of <style> tag, which comes after the modal
style_pos = content.find("<style", start_pos)
if style_pos == -1:
    # Fallback: find the closing </div> that ends the modal (look for the last </div> before <script>)
    # But safer to just find the next </div> that is at the same level? We'll use the style tag.
    print("⚠️ Could not find <style> tag. Trying to find the end of modal by closing </div> pattern.")
    # Find the matching closing </div> for the modal using a stack counter
    # We'll find the opening <div id="customFeeModal"> and then count.
    opening_tag = re.search(r'<div\s+id="customFeeModal"[^>]*>', content)
    if opening_tag:
        start_pos = opening_tag.start()
        # Now find matching closing </div>
        depth = 0
        i = start_pos
        while i < len(content):
            if content.startswith("<div", i):
                depth += 1
                i += 4
            elif content.startswith("</div>", i):
                depth -= 1
                i += 6
                if depth == 0:
                    end_pos = i
                    break
            else:
                i += 1
        if depth == 0:
            # Remove from start to end_pos
            content = content[:start_pos] + content[end_pos:]
            print("✅ Removed modal using opening tag and closing tag.")
            with open(FILE_PATH, "w") as f:
                f.write(content)
            exit(0)
        else:
            print("❌ Could not match closing tag. Aborting.")
            exit(1)
    else:
        print("❌ No modal found. Aborting.")
        exit(1)
else:
    # Remove everything from start_pos to just before the <style> tag
    # We'll also remove any trailing whitespace and the </div> that closes the modal
    # Actually, we want to remove the entire modal including its closing </div>s.
    # The modal is before the <style> tag. We'll find the last </div> before <style>.
    end_marker = "</div>"
    # Find the last </div> before the style tag
    end_pos = content.rfind(end_marker, start_pos, style_pos)
    if end_pos == -1:
        # If no </div> found, remove up to style_pos
        end_pos = style_pos
    else:
        end_pos += len(end_marker)  # include the closing tag

    # Remove the block
    content = content[:start_pos] + content[end_pos:]
    print("✅ Removed modal block between comment and style tag.")

# Write back
with open(FILE_PATH, "w") as f:
    f.write(content)

print("\n🎯 Done! The 'Generate Current Month Fee' modal has been removed from the desktop student profile.")
print("🚀 Refresh the page to see the changes.")
