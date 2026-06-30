#!/usr/bin/env python3
"""
Patcher: Add month/year of latest fee vouchers to the notification banner.
"""

import re
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
VIEWS_FILE = BASE_DIR / "axis_saas" / "views.py"
BANNER_FILE = BASE_DIR / "templates" / "mobile" / "notification_banner.html"

def patch_views():
    """Modify mobile_dashboard to compute and pass voucher_month/year."""
    if not VIEWS_FILE.exists():
        print(f"❌ {VIEWS_FILE} not found.")
        return False

    with open(VIEWS_FILE, 'r') as f:
        content = f.read()

    # Find the mobile_dashboard function body and insert the logic to get latest fee month/year.
    # We'll look for the part where we compute show_banner and new_count.
    # We'll insert after that block, before returning the render.
    # We'll replace the existing mobile_dashboard function with an updated version.

    # First, locate the function definition.
    pattern = r'(def mobile_dashboard\(request, schema_name\):.*?)(?=\n@require_tenant_type|\n\ndef |\nclass |\n$)'
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        print("❌ Could not find mobile_dashboard function.")
        return False

    original_func = match.group(1)
    # We'll replace the entire function with a new version.
    # We'll keep the existing logic and add the month/year extraction.

    # We'll insert after the banner logic block, before the return statement.
    # The existing code ends with:
    #   context['show_notification_banner'] = show_banner
    #   context['new_vouchers_count'] = new_count
    #   # ---- End banner logic ----
    #   return render(request, 'mobile/dashboard.html', context)

    # We'll insert after the banner logic and before the return.
    # We'll add:
    #   # ---- Get latest fee month/year ----
    #   with schema_context(schema_name):
    #       latest_fee = FeeRecord.objects.order_by('-id').first()
    #       if latest_fee:
    #           context['voucher_month'] = latest_fee.month
    #           context['voucher_year'] = latest_fee.year
    #       else:
    #           context['voucher_month'] = None
    #           context['voucher_year'] = None

    # We'll find the line with "context['new_vouchers_count'] = new_count" and insert after that.

    # We'll use regex to find that line and insert after it.
    insert_after = "context['new_vouchers_count'] = new_count"
    if insert_after not in original_func:
        print("❌ Could not find insertion point in mobile_dashboard.")
        return False

    new_code = f"""
    {insert_after}
    # ---- Get latest fee month/year ----
    with schema_context(schema_name):
        from .models import FeeRecord
        latest_fee = FeeRecord.objects.order_by('-id').first()
        if latest_fee:
            context['voucher_month'] = latest_fee.month
            context['voucher_year'] = latest_fee.year
        else:
            context['voucher_month'] = None
            context['voucher_year'] = None
    # ---- End month/year logic ----
"""
    # Replace the line with itself plus the new code.
    # But we need to replace only the first occurrence? We'll replace the whole function body.
    # Better: we can replace the function entirely.
    # Let's construct a new function from scratch using the existing logic but adding the month/year extraction.

    # We'll extract the existing function body (after the def line).
    # We'll split by "def mobile_dashboard(...):" and then find the indented block.

    # Actually simpler: we can use a more precise replacement.
    # We'll locate the line that sets context['new_vouchers_count'] and insert after it.

    new_func = original_func.replace(insert_after, new_code)

    # Also ensure we have the import of FeeRecord if not already.
    # But it's already imported at top, so fine.

    # Replace the original function with the new one.
    new_content = content.replace(original_func, new_func)

    with open(VIEWS_FILE, 'w') as f:
        f.write(new_content)

    print("✅ Updated mobile_dashboard in views.py")
    return True

def patch_banner_template():
    """Update the banner template to display month/year."""
    if not BANNER_FILE.exists():
        print(f"❌ {BANNER_FILE} not found.")
        return False

    with open(BANNER_FILE, 'r') as f:
        content = f.read()

    # Replace the message line to include month/year if available.
    # Current line:
    # <strong>New Fee Vouchers Generated!</strong>
    # <span>{{ new_vouchers_count }} new voucher(s) have been created.</span>

    # We'll change to:
    # <strong>New Fee Vouchers Generated!</strong>
    # <span>{{ new_vouchers_count }} new voucher(s) have been created for {{ voucher_month }}/{{ voucher_year }}.</span>

    # Or if month/year not available, just show the count.

    # We'll replace the span with a conditional.
    # Use:
    # <span>
    #     {{ new_vouchers_count }} new voucher(s) have been created
    #     {% if voucher_month and voucher_year %}for {{ voucher_month }}/{{ voucher_year }}{% endif %}.
    # </span>

    new_span = """<span>
        {{ new_vouchers_count }} new voucher(s) have been created
        {% if voucher_month and voucher_year %}for {{ voucher_month }}/{{ voucher_year }}{% endif %}.
    </span>"""

    # Find the existing span and replace.
    pattern = r'<span>\s*\{\{ new_vouchers_count \}\} new voucher\(s\) have been created\.\s*</span>'
    if re.search(pattern, content):
        content = re.sub(pattern, new_span, content, flags=re.DOTALL)
    else:
        # Fallback: try to find the span with the text.
        old_span = '<span>{{ new_vouchers_count }} new voucher(s) have been created.</span>'
        if old_span in content:
            content = content.replace(old_span, new_span)
        else:
            print("⚠️ Could not find the span to replace. Please update manually.")
            return False

    with open(BANNER_FILE, 'w') as f:
        f.write(content)

    print("✅ Updated notification_banner.html")
    return True

def main():
    print("🔧 Adding month/year to notification banner...")
    views_ok = patch_views()
    banner_ok = patch_banner_template()
    if views_ok and banner_ok:
        print("\n✅ All changes applied successfully.")
        print("Restart your Django server to see the updated banner.")
    else:
        print("\n⚠️ Some changes may have failed. Please check the output above.")

if __name__ == "__main__":
    main()
