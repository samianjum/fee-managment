#!/usr/bin/env python3
"""
Single patcher to enable offline support for Student Profile pages.
Usage: python3 patch_student_offline.py
"""

import re
import os

# ----------------------------------------------------------------------
# 1. Patch static/sw.js – add student profile patterns
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

    # Check if already present
    if '/students/\\d+' in body:
        print("✅ Student profile patterns already in sw.js, skipping.")
        return

    new_patterns = [
        "/^\\/portal\\/[^\\/]+\\/students\\/\\d+\\/?$/.test(url.pathname)",
        "/^\\/portal\\/[^\\/]+\\/students\\/\\d+\\/mobile\\/?$/.test(url.pathname)"
    ]
    body_trim = body.rstrip()
    if body_trim and not body_trim.endswith('||'):
        body_trim += ' ||'
    body_trim += '\n                         ' + ' ||\n                         '.join(new_patterns)
    new_line = prefix + body_trim + suffix
    content = content.replace(match.group(0), new_line)

    with open(path, 'w') as f:
        f.write(content)
    print("✅ static/sw.js patched (student profile).")

# ----------------------------------------------------------------------
# 2. Add student_list_api to views_school.py
# ----------------------------------------------------------------------
def patch_views_school():
    path = 'axis_saas/views_school.py'
    if not os.path.exists(path):
        print(f"❌ {path} not found")
        return

    with open(path, 'r') as f:
        content = f.read()

    # Check if already exists
    if 'def student_list_api' in content:
        print("✅ student_list_api already exists in views_school.py, skipping.")
        return

    # Find a good insertion point after an existing API function, e.g., after product_list_api
    marker = 'def product_list_api'
    if marker not in content:
        # Fallback: insert after global_search_api
        marker = 'def global_search_api'
        if marker not in content:
            print("❌ Could not find product_list_api or global_search_api to anchor insertion.")
            return

    lines = content.splitlines(keepends=True)
    insertion_index = None
    for i, line in enumerate(lines):
        if line.strip().startswith(marker):
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

    # New function
    new_function = '''
def student_list_api(request, schema_name):
    """API: Return list of students with their profile URLs for pre‑caching."""
    from django.http import JsonResponse
    from .models import Student
    from django_tenants.utils import schema_context
    with schema_context(schema_name):
        students = Student.objects.filter(status='active').values('id', 'name')
        data = []
        for s in students:
            data.append({
                'id': s['id'],
                'desktop_url': f'/portal/{schema_name}/students/{s["id"]}/',
                'mobile_url': f'/portal/{schema_name}/students/{s["id"]}/mobile/',
            })
        return JsonResponse(data, safe=False)

'''
    lines.insert(insertion_index, new_function)
    with open(path, 'w') as f:
        f.writelines(lines)
    print("✅ student_list_api added to views_school.py.")

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
    if 'student_list_api' in content:
        print("✅ student_list_api URL already present, skipping.")
        return

    # Add import
    lines = content.splitlines(keepends=True)
    for i, line in enumerate(lines):
        if line.strip().startswith('from .views import'):
            if 'student_list_api' not in line:
                if line.rstrip().endswith(','):
                    new_line = line.rstrip() + ' student_list_api'
                else:
                    new_line = line.rstrip() + ', student_list_api'
                lines[i] = new_line + '\n'
            break

    # Add URL pattern
    url_pattern = "    path('portal/<slug:schema_name>/api/students/', portal_wrapper(login_required_for_schema(student_list_api)), name='student_list_api'),\n"
    urlpatterns_start = None
    for i, line in enumerate(lines):
        if line.strip() == 'urlpatterns = [':
            urlpatterns_start = i
            break
    if urlpatterns_start is not None:
        lines.insert(urlpatterns_start+1, url_pattern)
    else:
        print("❌ Could not find urlpatterns list.")
        return

    with open(path, 'w') as f:
        f.writelines(lines)
    print("✅ student_list_api URL added to public_urls.py.")

# ----------------------------------------------------------------------
# 4. Update base templates to pre‑cache all student profiles
# ----------------------------------------------------------------------
def patch_base_template(template_path):
    if not os.path.exists(template_path):
        print(f"❌ {template_path} not found")
        return

    with open(template_path, 'r') as f:
        content = f.read()

    # Check if already added
    if '// DYNAMIC_PRECACHE_STUDENTS' in content:
        print(f"✅ Dynamic student pre-caching already in {template_path}, skipping.")
        return

    # Insert before </body>
    body_end = content.rfind('</body>')
    if body_end == -1:
        print(f"❌ Could not find </body> tag in {template_path}")
        return

    new_script = '''
<script>
// DYNAMIC_PRECACHE_STUDENTS – fetch and cache all student profile pages
(function() {
    if (!('caches' in window)) return;
    const schema = '{{ tenant.schema_name }}';
    const apiUrl = `/portal/${schema}/api/students/`;
    const cacheName = 'axis-pwa-v4';

    window.addEventListener('load', function() {
        fetch(apiUrl, { cache: 'reload' })
            .then(res => res.json())
            .then(students => {
                if (!students || students.length === 0) return;
                const urls = students.flatMap(s => [s.desktop_url, s.mobile_url]);
                Promise.all(urls.map(url =>
                    fetch(url, { cache: 'reload' })
                        .then(res => {
                            if (res.ok) {
                                return caches.open(cacheName)
                                    .then(cache => cache.put(url, res));
                            }
                        })
                        .catch(() => {})
                )).then(() => console.log('[AXIS] Pre‑cached all student profile pages'));
            })
            .catch(() => {});
    });
})();
</script>
'''

    content = content[:body_end] + new_script + content[body_end:]
    with open(template_path, 'w') as f:
        f.write(content)
    print(f"✅ Dynamic student pre-caching added to {template_path}.")

# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------
def main():
    print("🚀 AXIS Student Profile Offline Patcher")
    patch_sw_js()
    patch_views_school()
    patch_public_urls()
    patch_base_template('templates/tenant/base.html')
    patch_base_template('templates/mobile/base.html')
    print("\n✅ Done! Restart your server and clear browser cache.")
    print("   All student profile pages will now be cached on first visit (or via background pre‑caching).")

if __name__ == "__main__":
    main()
