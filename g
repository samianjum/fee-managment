#!/usr/bin/env python3
"""
Fix voucher snippet: Monthly Fee row should show base fee, not total.
"""

FILE = "templates/tenant/voucher_snippet.html"

def patch():
    try:
        with open(FILE, "r") as f:
            content = f.read()
    except FileNotFoundError:
        print(f"❌ File not found: {FILE}")
        return

    # Replace the Monthly Fee row to use fee_record.amount (base) instead of total_amount
    old_line = '<td>Monthly Fee</td>\n                    <td>{{ fee_record.total_amount|floatformat:2 }}</td>'
    new_line = '<td>Monthly Fee</td>\n                    <td>{{ fee_record.amount|floatformat:2 }}</td>'

    if old_line in content:
        content = content.replace(old_line, new_line)
        with open(FILE, "w") as f:
            f.write(content)
        print("✅ Voucher snippet fixed: Monthly Fee now shows base fee only.")
    else:
        print("⚠️ Could not find the exact line. Trying alternative pattern...")
        # Fallback: replace any occurrence of fee_record.total_amount in that context
        # More robust: replace the first occurrence in the Monthly Fee row
        import re
        pattern = r'(<td>Monthly Fee</td>\s*<td>)\{\{ fee_record\.total_amount\|floatformat:2 \}\}(</td>)'
        replacement = r'\1{{ fee_record.amount|floatformat:2 }}\2'
        new_content, count = re.subn(pattern, replacement, content)
        if count:
            with open(FILE, "w") as f:
                f.write(new_content)
            print("✅ Voucher snippet fixed (regex).")
        else:
            print("❌ Could not find the line to patch. Please check manually.")

if __name__ == "__main__":
    patch()
