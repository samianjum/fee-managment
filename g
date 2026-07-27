#!/usr/bin/env python3
"""
AXIS View Splitter – FIXED
Splits axis_saas/views.py into helpers, school, gym, and API files.
Run: python3 split_views_fixed.py
"""

import os
import shutil
from pathlib import Path

# -------------------------------------------------------------------
# 1. Configuration
# -------------------------------------------------------------------
PROJECT_ROOT = Path(__file__).resolve().parent
VIEWS_PATH = PROJECT_ROOT / "axis_saas" / "views.py"
BACKUP_SUFFIX = ".bak"

# Helper functions – we’ll move these to views_helpers.py
HELPER_FUNCS = {
    "MOBILE_AGENT_RE",
    "is_mobile_user_agent",
    "get_tenant",
    "get_dashboard_context",
    "require_tenant_type",
    "require_school_feature",
    "create_fee_generation_notification",
    "get_overall_pending",
    "local_time_str",
    "_extract_item_sales_from_remarks",
    "get_student_list_context",
    "get_student_profile_context",
}

# API functions – those that return JSON or are named *_api
API_FUNCS = {
    "debug_payments_api",
    "fee_status_api",
    "manual_generate_api",
    "manual_generate_single_api",
    "student_fee_records_api",
    "student_payments_api",
    "student_current_fee_status_api",
    "gym_checkin_api",
    "gym_checkout_api",
    "gym_revenue_stats_api",
    "gym_attendance_stats_api",
    "gym_customers_list_api",
    "gym_customer_detail_api",
    "gym_subscription_status_api",
    "gym_attendance_data_api",
    "gym_eligible_customers_api",
    "gym_search_customer_api",
    "gym_export_attendance_api",
    "notifications_list_api",
    "mark_notification_read_api",
    "mark_all_notifications_read_api",
    "global_search_api",
    "voucher_status_api",
    "generate_voucher_api",
    "voucher_html_api",
}

# Gym views – either start with "gym_" or have @require_tenant_type(['gym'])
GYM_FUNCS = {
    "gym_dashboard",
    "gym_customer_list",
    "gym_customer_add",
    "gym_customer_edit",
    "gym_customer_profile",
    "gym_payment",
    "gym_receipt",
    "gym_reports",
    "gym_settings",
    "gym_attendance",
    "gym_generate_subscription",
    "gym_cancel_subscription",
    "gym_update_subscription",
    "gym_edit_attendance",
}

# -------------------------------------------------------------------
# 2. Utility functions
# -------------------------------------------------------------------
def backup_file(path):
    """Create a backup of the given file."""
    backup_path = path.with_suffix(path.suffix + BACKUP_SUFFIX)
    shutil.copy2(path, backup_path)
    print(f"📦 Backed up {path} -> {backup_path}")

def get_file_header(lines):
    """Extract the header (imports, constants) before first function/class."""
    header = []
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("def ") or stripped.startswith("class "):
            # We need to include decorators that might be on the same line? No, they are on separate lines.
            break
        header.append(line)
    return header

def extract_chunks(lines):
    """
    Parse lines into top-level chunks (decorators + function/class).
    Returns a list of (chunk_lines, name, decorator_text).
    """
    chunks = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.lstrip()
        # Skip empty lines and comments that are not decorators
        if not stripped or stripped.startswith("#"):
            i += 1
            continue

        # Check if it's a decorator line (starts with '@')
        if stripped.startswith("@"):
            # Collect consecutive decorators
            decorators = []
            while i < len(lines) and lines[i].lstrip().startswith("@"):
                decorators.append(lines[i])
                i += 1
            # Now we expect a function or class definition
            if i < len(lines):
                def_line = lines[i]
                if def_line.lstrip().startswith("def ") or def_line.lstrip().startswith("class "):
                    chunk = decorators + [def_line]
                    i += 1
                    # Collect the body until next top-level def/class or decorator
                    while i < len(lines):
                        next_line = lines[i]
                        if next_line and not next_line[0].isspace() and (next_line.lstrip().startswith("@") or next_line.lstrip().startswith("def ") or next_line.lstrip().startswith("class ")):
                            break
                        chunk.append(next_line)
                        i += 1
                    name = None
                    for part in def_line.split():
                        if part.startswith("def ") or part.startswith("class "):
                            name = part.split()[1].split("(")[0]
                            break
                    if name:
                        chunks.append((chunk, name, "".join(decorators)))
                    else:
                        chunks.append((chunk, None, "".join(decorators)))
                else:
                    # Decorator not followed by def/class? skip
                    i += 1
            else:
                break
        elif stripped.startswith("def ") or stripped.startswith("class "):
            # Function/class without decorators
            def_line = lines[i]
            chunk = [def_line]
            i += 1
            while i < len(lines):
                next_line = lines[i]
                if next_line and not next_line[0].isspace() and (next_line.lstrip().startswith("@") or next_line.lstrip().startswith("def ") or next_line.lstrip().startswith("class ")):
                    break
                chunk.append(next_line)
                i += 1
            name = None
            for part in def_line.split():
                if part.startswith("def ") or part.startswith("class "):
                    name = part.split()[1].split("(")[0]
                    break
            if name:
                chunks.append((chunk, name, ""))
            else:
                chunks.append((chunk, None, ""))
        else:
            # Other top-level lines (assignments, etc.) – treat as part of header?
            # We'll skip them here; they should be in the header.
            i += 1

    return chunks

def categorize_function(name, decorator_text):
    """Return category: 'helper', 'api', 'gym', or 'school'."""
    if name in HELPER_FUNCS:
        return "helper"
    if name in API_FUNCS:
        return "api"
    if name in GYM_FUNCS:
        return "gym"
    if "@require_tenant_type(['gym'])" in decorator_text or "@require_tenant_type([\"gym\"])" in decorator_text:
        return "gym"
    if name.startswith("gym_"):
        return "gym"
    if name.startswith("api_"):
        return "api"
    return "school"

# -------------------------------------------------------------------
# 3. Main splitting logic
# -------------------------------------------------------------------
def split_views():
    if not VIEWS_PATH.exists():
        print(f"❌ views.py not found at {VIEWS_PATH}")
        return

    # Backup original
    backup_file(VIEWS_PATH)

    # Read views.py
    with open(VIEWS_PATH, "r", encoding="utf-8") as f:
        lines = f.readlines()

    # Extract header
    header = get_file_header(lines)

    # Extract chunks
    chunks = extract_chunks(lines)

    # Categorize chunks – store only the line chunks (not names)
    categories = {
        "helper": [],
        "api": [],
        "gym": [],
        "school": []
    }

    for chunk_lines, name, decorator_text in chunks:
        if name is None:
            # Fallback: put into school
            categories["school"].append(chunk_lines)
        else:
            cat = categorize_function(name, decorator_text)
            categories[cat].append(chunk_lines)

    # Write new files
    out_dir = VIEWS_PATH.parent

    file_map = {
        "helper": "views_helpers.py",
        "api": "views_api.py",
        "gym": "views_gym.py",
        "school": "views_school.py"
    }

    for cat, file_name in file_map.items():
        cat_chunks = categories.get(cat, [])
        if not cat_chunks:
            continue
        file_path = out_dir / file_name
        with open(file_path, "w", encoding="utf-8") as f:
            f.write("".join(header))
            f.write("\n\n")
            for chunk_lines in cat_chunks:
                f.write("".join(chunk_lines))
                f.write("\n\n")
        print(f"✅ Created {file_path} with {len(cat_chunks)} definitions.")

    # Rewrite views.py as a re‑exporter
    with open(VIEWS_PATH, "w", encoding="utf-8") as f:
        f.write('"""\n')
        f.write('AXIS views – re‑export from split modules.\n')
        f.write('This file is automatically generated. Do not edit manually.\n')
        f.write('"""\n\n')
        for cat, file_name in file_map.items():
            if categories.get(cat):
                f.write(f"from .{file_name[:-3]} import *  # noqa\n")
        f.write("\n")
    print(f"✅ Rewrote {VIEWS_PATH} as a re‑exporter.")

    print("\n🎉 Split completed successfully.")
    print("Your new files are in axis_saas/:")
    for cat, file_name in file_map.items():
        if categories.get(cat):
            print(f"  - {file_name}")

if __name__ == "__main__":
    split_views()
