#!/usr/bin/env python3
"""
Patcher: Add mobile parameter to global search API call and view.
"""

import os
import re

VIEWS_PATH = "axis_saas/views.py"
TEMPLATE_PATH = "templates/tenant/global_search.html"

def patch_views(filepath):
    """Modify global_search_api to use mobile GET param."""
    if not os.path.exists(filepath):
        print(f"❌ File not found: {filepath}")
        return False

    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    # Find the global_search_api function
    func_pattern = r'(def global_search_api\(request, schema_name\):.*?)(?=\n\S*def |\Z)'
    match = re.search(func_pattern, content, re.DOTALL)
    if not match:
        print("❌ Could not find global_search_api function.")
        return False

    old_func = match.group(1)

    # Replace the mobile detection lines with a single line using GET param
    # We'll find the line(s) setting mobile and replace with:
    # mobile = request.GET.get('mobile') == '1'
    lines = old_func.splitlines()
    new_lines = []
    inside_function = False
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("def global_search_api"):
            inside_function = True
            new_lines.append(line)
            # Insert the new mobile detection line after the def
            new_lines.append("    mobile = request.GET.get('mobile') == '1'")
            continue
        if inside_function and stripped.startswith("mobile ="):
            # Skip the old mobile lines
            continue
        new_lines.append(line)

    new_func = "\n".join(new_lines)

    # Replace old function with new one
    new_content = content.replace(old_func, new_func)

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(new_content)

    print(f"✅ Patched {filepath}")
    return True


def patch_template(filepath):
    """Modify the JavaScript to add mobile=1 to the API fetch."""
    if not os.path.exists(filepath):
        print(f"❌ File not found: {filepath}")
        return False

    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    # Find the fetch call: `fetch(\`/portal/${schema}/api/global-search/?q=${encodeURIComponent(currentQuery)}\`)`
    # We need to add `&mobile=1` if the page URL contains /mobile/.
    # We'll replace the fetch line with a dynamic construction.

    pattern = r'(fetch\(`/portal/\${schema}/api/global-search/\?q=\${encodeURIComponent\(currentQuery\)}`\))'
    # We'll replace with a function call that builds the URL with mobile param.
    replacement = """(function() {
            let url = `/portal/${schema}/api/global-search/?q=${encodeURIComponent(currentQuery)}`;
            if (window.location.pathname.includes('/mobile/')) {
                url += '&mobile=1';
            }
            return fetch(url);
        })()"""

    # To avoid breaking, we'll use a regex to replace.
    # The pattern might be inside the .then chain.
    # We'll search for the exact fetch line and replace.
    new_content = re.sub(pattern, replacement, content)

    # Also need to handle the case where we have the same fetch in the code.
    # Actually there might be multiple? Only one fetch call in this file.
    # Check if the replacement happened.
    if new_content == content:
        # Try a more flexible approach: find the fetch line with a regex.
        # Use a pattern to find fetch(`/portal/${schema}/api/global-search/?q=${...}`)
        pattern2 = r'fetch\(`/portal/\${schema}/api/global-search/\?q=\${encodeURIComponent\(currentQuery\)}`\)'
        replacement2 = """(function() {
            let url = `/portal/${schema}/api/global-search/?q=${encodeURIComponent(currentQuery)}`;
            if (window.location.pathname.includes('/mobile/')) {
                url += '&mobile=1';
            }
            return fetch(url);
        })()"""
        new_content = re.sub(pattern2, replacement2, content)

    if new_content == content:
        print("⚠️ Could not find fetch call in global_search.html. Please manually add mobile=1.")
        return False

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(new_content)

    print(f"✅ Patched {filepath}")
    return True


if __name__ == "__main__":
    views_ok = patch_views(VIEWS_PATH)
    template_ok = patch_template(TEMPLATE_PATH)
    if views_ok and template_ok:
        print("✨ Mobile search param fix applied. Restart your Django server to see changes.")
    else:
        print("❌ Some patches failed. Check file paths.")
