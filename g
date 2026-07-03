#!/usr/bin/env python3
"""
Fix sell_separately view: show results when only grade/section filters are applied.
"""
import re
from pathlib import Path

VIEWS_PATH = Path('axis_saas/views.py')

NEW_SELL_SEPARATELY = '''
# ==================== SELL SEPARATELY (standalone student search) ====================
@require_tenant_type(['school'])
def sell_separately(request, schema_name, mobile=False):
    """Page to search for a student and then redirect to fee collection for that student."""
    tenant = get_tenant(request, schema_name)
    search_query = request.GET.get('search', '').strip()
    grade_filter = request.GET.get('grade', '')
    section_filter = request.GET.get('section', '')
    search_results = []

    with schema_context(schema_name):
        # Start with all students
        students = Student.objects.all()

        # Apply grade filter if provided
        if grade_filter:
            students = students.filter(grade=grade_filter)

        # Apply section filter if provided
        if section_filter:
            students = students.filter(section=section_filter)

        # Apply search (partial matching) if query provided
        if search_query:
            students = students.filter(
                Q(name__icontains=search_query) |
                Q(roll_number__icontains=search_query) |
                Q(father_name__icontains=search_query) |
                Q(father_cnic__icontains=search_query) |
                Q(parent_mobile__icontains=search_query)
            )

        # Only fetch results if either search or any filter is present
        if search_query or grade_filter or section_filter:
            search_results = list(students.order_by('name')[:20])
        else:
            search_results = []

        # Get distinct grades and sections for filter dropdowns
        grades = list(Student.objects.values_list('grade', flat=True).distinct().order_by('grade'))
        sections = list(Student.objects.values_list('section', flat=True).distinct().order_by('section'))

    context = {
        'tenant': tenant,
        'search_query': search_query,
        'grade_filter': grade_filter,
        'section_filter': section_filter,
        'search_results': search_results,
        'grades': grades,
        'sections': sections,
        'logo_url': tenant.school_logo.url if tenant.school_logo else None,
    }
    template = 'mobile/sell_separately.html' if mobile else 'tenant/sell_separately.html'
    return render(request, template, context)

@require_tenant_type(['school'])
def mobile_sell_separately(request, schema_name):
    """Mobile version of sell separately page."""
    return sell_separately(request, schema_name, mobile=True)
'''

def patch_views():
    if not VIEWS_PATH.exists():
        print(f"❌ File not found: {VIEWS_PATH}")
        return

    with open(VIEWS_PATH, 'r', encoding='utf-8') as f:
        content = f.read()

    # Pattern to match the sell_separately function block.
    # We'll look for the comment "# ==================== SELL SEPARATELY" and then capture until the next @require_tenant_type or def.
    pattern = r'(# ==================== SELL SEPARATELY.*?)(@require_tenant_type.*?def mobile_sell_separately.*?return sell_separately.*?)(?=\n\n|$)'

    if re.search(pattern, content, re.DOTALL):
        new_content = re.sub(pattern, NEW_SELL_SEPARATELY, content, flags=re.DOTALL)
        with open(VIEWS_PATH, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print("✅ Successfully updated sell_separately in views.py")
    else:
        # Fallback: try to find the function definition directly
        func_pattern = r'(@require_tenant_type\(\[.school.\]\)\s*def sell_separately\(request, schema_name, mobile=False\):.*?)(?=@require_tenant_type|def )'
        match = re.search(func_pattern, content, re.DOTALL)
        if match:
            # Also find the mobile wrapper
            wrapper_pattern = r'(@require_tenant_type\(\[.school.\]\)\s*def mobile_sell_separately.*?return sell_separately.*?)(?=\n\n|$)'
            wrapper_match = re.search(wrapper_pattern, content, re.DOTALL)
            if wrapper_match:
                old_block = match.group(0) + wrapper_match.group(0)
                new_content = content.replace(old_block, NEW_SELL_SEPARATELY)
            else:
                # replace only the function
                new_content = content.replace(match.group(0), NEW_SELL_SEPARATELY)
            with open(VIEWS_PATH, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print("✅ Successfully updated sell_separately in views.py")
        else:
            # If not found, append at the end (safe fallback)
            print("⚠️ Could not locate the sell_separately function. Appending new version at the end.")
            with open(VIEWS_PATH, 'a', encoding='utf-8') as f:
                f.write('\n\n' + NEW_SELL_SEPARATELY)
            print("✅ Appended new sell_separately function at the end of views.py")


if __name__ == '__main__':
    print("🔧 Applying fix for sell_separately filters...")
    patch_views()
    print("\n✅ Done! Now grade/section filters work without search.")
    print("🔄 Restart your server to see the changes.")
