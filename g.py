#!/usr/bin/env python3
"""
AXIS PWA Caching Optimizer
Removes excessive background refreshes that cause high load.
Only initial pre-cache will run once; subsequent updates happen per-page.
"""
import os
import re

def patch_file(filepath, replacements):
    """Apply multiple regex replacements to a file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        for pattern, repl in replacements:
            content = re.sub(pattern, repl, content, flags=re.MULTILINE | re.DOTALL)
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✅ Patched: {filepath}")
    except Exception as e:
        print(f"❌ Failed to patch {filepath}: {e}")

# ---- 1. Patch base.html (desktop) ----
base_html_path = 'templates/tenant/base.html'
if os.path.exists(base_html_path):
    # Remove the on-load and interval refresh calls, and the visibility change listener.
    # We'll comment them out to keep the function definition (if needed elsewhere) but remove invocations.
    replacements = [
        # Comment out window.addEventListener('load', refreshProfiles);
        (r'(\s*)(window\.addEventListener\(\s*[\'"]load[\'"]\s*,\s*refreshProfiles\s*\);)',
         r'\1// \2  // disabled to reduce load'),
        # Comment out the setInterval for 30 min
        (r'(\s*)(setInterval\(\(\)\s*=>\s*\{[\s\S]*?refreshProfiles\(\);[\s\S]*?\}\s*,\s*30\s*\*\s*60\s*\*\s*1000\s*\);)',
         r'\1// \2  // disabled to reduce load'),
        # Comment out visibilitychange listener that calls refreshProfiles
        (r'(\s*)(document\.addEventListener\(\s*[\'"]visibilitychange[\'"]\s*,\s*\(\)\s*=>\s*\{[\s\S]*?refreshProfiles\(\);[\s\S]*?\}\s*\);)',
         r'\1// \2  // disabled to reduce load'),
    ]
    patch_file(base_html_path, replacements)
else:
    print(f"⚠️ File not found: {base_html_path}")

# ---- 2. Patch mobile/base.html ----
mobile_html_path = 'templates/mobile/base.html'
if os.path.exists(mobile_html_path):
    replacements = [
        (r'(\s*)(window\.addEventListener\(\s*[\'"]load[\'"]\s*,\s*refreshProfiles\s*\);)',
         r'\1// \2  // disabled to reduce load'),
        (r'(\s*)(setInterval\(\(\)\s*=>\s*\{[\s\S]*?refreshProfiles\(\);[\s\S]*?\}\s*,\s*30\s*\*\s*60\s*\*\s*1000\s*\);)',
         r'\1// \2  // disabled to reduce load'),
        (r'(\s*)(document\.addEventListener\(\s*[\'"]visibilitychange[\'"]\s*,\s*\(\)\s*=>\s*\{[\s\S]*?refreshProfiles\(\);[\s\S]*?\}\s*\);)',
         r'\1// \2  // disabled to reduce load'),
    ]
    patch_file(mobile_html_path, replacements)
else:
    print(f"⚠️ File not found: {mobile_html_path}")

# ---- 3. Patch sw.js ----
sw_path = 'static/sw.js'
if os.path.exists(sw_path):
    # Remove the periodic refresh and immediate refresh on activate.
    # We'll comment out the whole block that sets up interval.
    replacements = [
        # Match the block inside activate that calls refreshStudentProfiles and setInterval
        (r'(//\s*Start periodic refresh every 15 minutes[\s\S]*?)(setInterval\(\(\)\s*=>\s*\{[\s\S]*?refreshStudentProfiles\(schema\);[\s\S]*?\}\s*,\s*15\s*\*\s*60\s*\*\s*1000\s*\);)',
         r'\1// \2  // disabled to reduce load'),
        # Also remove the immediate refresh call after finding clients
        (r'(//\s*Start periodic refresh every 15 minutes[\s\S]*?)(refreshStudentProfiles\(schema\);)([\s\S]*?)(setInterval\(\(\)\s*=>\s*\{[\s\S]*?refreshStudentProfiles\(schema\);[\s\S]*?\}\s*,\s*15\s*\*\s*60\s*\*\s*1000\s*\);)',
         r'\1// \2  // disabled\n\3// \4  // disabled'),
        # Simpler: just comment out the lines that call refreshStudentProfiles and setInterval
        # We'll do a more robust approach: find the block and replace with comment.
        (r'(self\.clients\.matchAll\(\)\.then\(clients\s*=>\s*\{[\s\S]*?if\s*\(clients\.length\s*>\s*0\)\s*\{[\s\S]*?const\s*url\s*=\s*new\s*URL\(clients\[0\]\.url\)\;[\s\S]*?const\s*parts\s*=\s*url\.pathname\.split\(\'\/\'\)\;[\s\S]*?if\s*\(parts\.length\s*>=\s*3\s*&&\s*parts\[1\]\s*===\s*\'portal\'\)\s*\{[\s\S]*?const\s*schema\s*=\s*parts\[2\]\;[\s\S]*?refreshStudentProfiles\(schema\)\;[\s\S]*?setInterval\(\(\)\s*=>\s*\{[\s\S]*?refreshStudentProfiles\(schema\)\;[\s\S]*?\}\s*,\s*15\s*\*\s*60\s*\*\s*1000\s*\)\;[\s\S]*?\}[\s\S]*?\}\))',
         '// Disabled background refresh to reduce load\n// self.clients.matchAll().then(clients => { ... })  // removed'),
    ]
    patch_file(sw_path, replacements)
else:
    print(f"⚠️ File not found: {sw_path}")

print("\n✅ Patching complete. Restart your application or clear browser cache to see effects.")
print("   Note: Initial pre-cache will still run once (if not already done).")
print("   Subsequent updates will only happen when you visit a specific student profile page.")
