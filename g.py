#!/usr/bin/env python3
"""
Single patcher to enable offline support for ALL Product Details pages.
Run: python3 patch_product_offline_complete.py
"""

import re
import os

# ----------------------------------------------------------------------
# 1. Patch static/sw.js – add product detail patterns (if missing)
# ----------------------------------------------------------------------
def patch_sw_js():
    path = 'static/sw.js'
    if not os.path.exists(path):
        print(f"❌ {path} not found")
        return

    with open(path, 'r') as f:
        content = f.read()

    pattern = r'(const isCachedPage = )(.*?)(;)'
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        print("❌ Could not find 'const isCachedPage' in sw.js")
        return

    prefix = match.group(1)
    body = match.group(2)
    suffix = match.group(3)

    if 'stock/product' not in body:
        new_patterns = [
            "/^\\/portal\\/[^\\/]+\\/stock\\/product\\/\\d+\\/?$/.test(url.pathname)",
            "/^\\/portal\\/[^\\/]+\\/stock\\/product\\/\\d+\\/mobile\\/?$/.test(url.pathname)"
        ]
        body_trim = body.rstrip()
        if body_trim and not body_trim.endswith('||'):
            body_trim += ' ||'
        body_trim += '\n                         ' + ' ||\n                         '.join(new_patterns)
        new_line = prefix + body_trim + suffix
        content = content.replace(match.group(0), new_line)
        with open(path, 'w') as f:
            f.write(content)
        print("✅ static/sw.js patched (product-detail).")
    else:
        print("✅ Product details already in sw.js, skipping.")


# ----------------------------------------------------------------------
# 2. Add new API view to views_school.py
# ----------------------------------------------------------------------
def patch_views_school():
    path = 'axis_saas/views_school.py'
    if not os.path.exists(path):
        print(f"❌ {path} not found")
        return

    with open(path, 'r') as f:
        content = f.read()

    # Check if the function already exists
    if 'def product_list_api' in content:
        print("✅ product_list_api already exists in views_school.py, skipping.")
        return

    # Find the end of the file, or insert after a known function like global_search_api
    # We'll insert after the global_search_api function (or at the end)
    # Look for "def global_search_api" and insert after its closing
    marker = 'def global_search_api'
    if marker not in content:
        print("❌ Could not find global_search_api function to anchor insertion.")
        return

    # Find the end of the global_search_api function (the next def or end of file)
    lines = content.splitlines(keepends=True)
    insertion_index = None
    for i, line in enumerate(lines):
        if line.strip().startswith('def global_search_api'):
            # Find the next function definition or end of file
            for j in range(i+1, len(lines)):
                if lines[j].strip().startswith('def '):
                    insertion_index = j
                    break
            if insertion_index is None:
                insertion_index = len(lines)
            break

    if insertion_index is None:
        print("❌ Could not find insertion point.")
        return

    # New function to insert
    new_function = '''
def product_list_api(request, schema_name):
    """API: Return list of products with their detail URLs for pre‑caching."""
    from django.http import JsonResponse
    from .models import Product
    from django_tenants.utils import schema_context
    with schema_context(schema_name):
        products = Product.objects.all().values('id', 'name')
        # Build URLs for both desktop and mobile
        data = []
        for p in products:
            data.append({
                'id': p['id'],
                'desktop_url': f'/portal/{schema_name}/stock/product/{p["id"]}/',
                'mobile_url': f'/portal/{schema_name}/stock/product/{p["id"]}/mobile/',
            })
        return JsonResponse(data, safe=False)

'''
    lines.insert(insertion_index, new_function)
    with open(path, 'w') as f:
        f.writelines(lines)
    print("✅ product_list_api added to views_school.py.")


# ----------------------------------------------------------------------
# 3. Add URL pattern in public_urls.py
# ----------------------------------------------------------------------
def patch_public_urls():
    path = 'axis_saas/public_urls.py'
    if not os.path.exists(path):
        print(f"❌ {path} not found")
        return

    with open(path, 'r') as f:
        content = f.read()

    # Check if already added
    if 'product_list_api' in content:
        print("✅ product_list_api URL already present, skipping.")
        return

    # We need to import the new view and add the URL pattern
    # Find the import section to add the view
    import_line = 'from .views import'
    if import_line not in content:
        print("❌ Could not find import line for views.")
        return

    # Add the view to the import list
    # Find the line and add ', product_list_api'
    lines = content.splitlines(keepends=True)
    for i, line in enumerate(lines):
        if line.strip().startswith('from .views import'):
            # Check if product_list_api already in the list (but we already checked)
            # Add it if not present
            if 'product_list_api' not in line:
                # Add after the import (could be multiline, but simple)
                # Replace the line with same plus , product_list_api
                # But better to add in the line before the end of imports
                # We'll insert a line after the import line
                # Actually we can add it to the import list by appending to the line
                # But it's safer to add a new line
                # We'll insert a new import line after the from .views import ...
                # Find the semicolon or end of line
                if line.rstrip().endswith(','):
                    new_line = line.rstrip() + ' product_list_api'
                else:
                    new_line = line.rstrip() + ', product_list_api'
                lines[i] = new_line + '\n'
                break
    else:
        # If the line is not found, we'll add a new import line near the top
        # Find the first 'from' import
        for i, line in enumerate(lines):
            if line.strip().startswith('from .views import'):
                # Insert after this line
                lines.insert(i+1, 'from .views import product_list_api\n')
                break

    # Now add the URL pattern
    url_pattern = "    path('portal/<slug:schema_name>/api/products/', portal_wrapper(login_required_for_schema(product_list_api)), name='product_list_api'),\n"
    # Find the urlpatterns list
    urlpatterns_start = None
    for i, line in enumerate(lines):
        if line.strip() == 'urlpatterns = [':
            urlpatterns_start = i
            break
    if urlpatterns_start is not None:
        # Insert the new URL pattern after the opening bracket
        lines.insert(urlpatterns_start+1, url_pattern)
    else:
        print("❌ Could not find urlpatterns list.")
        return

    with open(path, 'w') as f:
        f.writelines(lines)
    print("✅ product_list_api URL added to public_urls.py.")


# ----------------------------------------------------------------------
# 4. Update base templates to pre‑cache all product details
# ----------------------------------------------------------------------
def patch_base_template(template_path):
    if not os.path.exists(template_path):
        print(f"❌ {template_path} not found")
        return

    with open(template_path, 'r') as f:
        content = f.read()

    # We need to inject a script after the existing pre-caching script
    # Find the existing pre-caching script block
    # It starts with: // PRECACHE_PAGES – automatically cache dashboard, student list, and defaulters pages on every load
    # We'll insert a new block after it, or modify it.

    # Check if the dynamic product caching script already exists
    if '// DYNAMIC_PRECACHE_PRODUCTS' in content:
        print(f"✅ Dynamic product pre-caching already in {template_path}, skipping.")
        return

    # Find the location after the existing pre-caching script
    # Look for the closing </script> tag of the existing script
    # We'll insert after it.
    # But easier: we can add a new <script> block just before the closing </body> tag.
    # Since base.html ends with </body>, we can insert right before that.

    # Find the last </body> tag
    body_end = content.rfind('</body>')
    if body_end == -1:
        print(f"❌ Could not find </body> tag in {template_path}")
        return

    # New script to fetch and cache all product detail pages
    new_script = '''
<script>
// DYNAMIC_PRECACHE_PRODUCTS – fetch and cache all product detail pages
(function() {
    if (!('caches' in window)) return;
    const schema = '{{ tenant.schema_name }}';
    const apiUrl = `/portal/${schema}/api/products/`;
    const cacheName = 'axis-pwa-v4';

    // Wait for page to be fully loaded
    window.addEventListener('load', function() {
        fetch(apiUrl, { cache: 'reload' })
            .then(res => res.json())
            .then(products => {
                if (!products || products.length === 0) return;
                const urls = products.flatMap(p => [p.desktop_url, p.mobile_url]);
                // Fetch each URL with cache: 'reload' to ensure fresh data
                Promise.all(urls.map(url =>
                    fetch(url, { cache: 'reload' })
                        .then(res => {
                            if (res.ok) {
                                // Add to cache
                                return caches.open(cacheName)
                                    .then(cache => cache.put(url, res));
                            }
                        })
                        .catch(() => {}) // ignore offline errors
                )).then(() => console.log('[AXIS] Pre‑cached all product detail pages'));
            })
            .catch(() => {}); // ignore if API fails
    });
})();
</script>
'''

    # Insert the script before </body>
    content = content[:body_end] + new_script + content[body_end:]

    with open(template_path, 'w') as f:
        f.write(content)
    print(f"✅ Dynamic product pre-caching added to {template_path}.")


# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------
def main():
    print("🚀 AXIS Product Details Offline Patcher (Complete)")
    patch_sw_js()
    patch_views_school()
    patch_public_urls()
    patch_base_template('templates/tenant/base.html')
    patch_base_template('templates/mobile/base.html')
    print("\n✅ Done! Restart your server and clear browser cache.")
    print("   On the next page load, all product detail pages will be pre‑cached in the background.")
    print("   Offline visits to any product detail page will then work.")


if __name__ == "__main__":
    main()
