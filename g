#!/usr/bin/env python3
"""
Fix PWA install button visibility and create missing icons.
Run this script once from the project root.
"""

import os
import re
import shutil
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

PROJECT_ROOT = Path(__file__).parent.absolute()
STATIC_PWA_DIR = PROJECT_ROOT / "static" / "pwa"
TEMPLATES_DIR = PROJECT_ROOT / "templates"

# ---------- Create PWA icons ----------
def create_icon(size, output_path):
    """Create a simple icon with text."""
    img = Image.new('RGB', (size, size), color=(79, 70, 229))  # primary color
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("arial.ttf", size // 4)
    except:
        font = ImageFont.load_default()
    text = "AXIS"
    # Center text
    bbox = draw.textbbox((0, 0), text, font=font)
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (size - w) // 2
    y = (size - h) // 2
    draw.text((x, y), text, fill="white", font=font)
    img.save(output_path)
    print(f"✅ Created {output_path}")

def ensure_icons():
    STATIC_PWA_DIR.mkdir(parents=True, exist_ok=True)
    icon_192 = STATIC_PWA_DIR / "icon-192x192.png"
    icon_512 = STATIC_PWA_DIR / "icon-512x512.png"
    if not icon_192.exists():
        create_icon(192, icon_192)
    else:
        print(f"⏩ {icon_192} already exists")
    if not icon_512.exists():
        create_icon(512, icon_512)
    else:
        print(f"⏩ {icon_512} already exists")

# ---------- Update templates ----------
def update_template(file_path):
    """Make install button always visible."""
    if not file_path.exists():
        print(f"⚠️  {file_path} not found, skipping")
        return
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    # Find the container div and change display: none; to display: flex;
    pattern = r'(<div id="pwaInstallContainer"[^>]*style="[^"]*display:\s*none[^"]*")'
    replacement = r'\1'  # we'll replace with a version that has display:flex
    # More robust: replace the entire style attribute or just the display part.
    # We'll look for the exact line and replace.
    lines = content.splitlines()
    modified = False
    for i, line in enumerate(lines):
        if 'id="pwaInstallContainer"' in line and 'display: none' in line:
            new_line = line.replace('display: none;', 'display: flex;')
            lines[i] = new_line
            modified = True
            break
    if modified:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines))
        print(f"✅ Updated {file_path}")
    else:
        print(f"ℹ️  No change needed in {file_path} (maybe already fixed)")

# ---------- Main ----------
def main():
    print("🔧 AXIS PWA Fixer\n")
    ensure_icons()
    update_template(TEMPLATES_DIR / "mobile" / "base.html")
    update_template(TEMPLATES_DIR / "tenant" / "base.html")
    # Also ensure the static files are collected
    print("\n📦 Running collectstatic...")
    result = subprocess.run(
        ["python3", "manage.py", "collectstatic", "--noinput"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True
    )
    if result.returncode == 0:
        print("✅ collectstatic completed")
    else:
        print("❌ collectstatic failed:")
        print(result.stderr)
    print("\n🎉 Done! The install button should now appear on mobile.")
    print("   If the native prompt still doesn't show, check that:")
    print("   - Your site is served over HTTPS (or localhost)")
    print("   - The manifest is valid (check browser console)")

if __name__ == "__main__":
    main()
