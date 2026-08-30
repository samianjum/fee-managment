#!/usr/bin/env python3
"""
axis_patcher.py

Patcher script to fix staff_list.html:
- Move {% extends 'tenant/base.html' %} to the very first line.
- Optionally add CSS styles if not already present (but currently skipped).

Usage:
    python axis_patcher.py [--dry-run] [--verbose] [--target-dir PATH]

Options:
    --dry-run      Preview changes without writing files.
    --verbose      Show detailed output.
    --target-dir   Project root directory (default: current directory).
"""

import os
import re
import sys
from pathlib import Path
from datetime import datetime
import argparse


# -----------------------------------------------------------------------------
# Utility functions
# -----------------------------------------------------------------------------

def log(msg, verbose=False):
    """Print a log message with timestamp if verbose."""
    if verbose:
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] {msg}")


def fix_extends_order(file_path, dry_run, verbose):
    """
    Ensure that {% extends 'tenant/base.html' %} is the very first tag in the file.
    If not, move it to the top.
    Returns True if file was changed, False otherwise.
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception as e:
        log(f"Error reading {file_path}: {e}", verbose)
        return False

    # Find the extends line
    extend_line = None
    extend_idx = -1
    for i, line in enumerate(lines):
        if re.search(r"{%\s*extends\s+['\"]tenant/base\.html['\"]\s*%}", line):
            extend_line = line
            extend_idx = i
            break

    if extend_line is None:
        log(f"No extends tag found in {file_path}", verbose)
        return False

    # If extend is already at the very beginning (first non-whitespace line), skip
    first_non_empty = 0
    for i, line in enumerate(lines):
        if line.strip():
            first_non_empty = i
            break
    if first_non_empty == extend_idx:
        log(f"extends already at top in {file_path}", verbose)
        return False

    # Remove the extend line from its current position
    lines.pop(extend_idx)
    # Insert at the very beginning
    lines.insert(0, extend_line)

    if dry_run:
        log(f"[DRY RUN] Would reorder extends to top in {file_path}", verbose)
        return True

    try:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.writelines(lines)
        log(f"Fixed extends order in {file_path}", verbose)
        return True
    except Exception as e:
        log(f"Error writing {file_path}: {e}", verbose)
        return False


# -----------------------------------------------------------------------------
# Main patcher
# -----------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="AXIS Patcher - fix staff_list.html")
    parser.add_argument('--dry-run', action='store_true', help="Preview changes without applying")
    parser.add_argument('--verbose', action='store_true', help="Show detailed output")
    parser.add_argument('--target-dir', default='.', help="Project root directory (default: current)")
    args = parser.parse_args()

    target_dir = Path(args.target_dir).resolve()
    if not target_dir.is_dir():
        print(f"Error: target directory '{target_dir}' does not exist.")
        sys.exit(1)

    log(f"Target directory: {target_dir}", args.verbose)

    staff_list_path = target_dir / "templates" / "tenant" / "staff_list.html"
    if not staff_list_path.exists():
        print(f"Error: {staff_list_path} not found.")
        sys.exit(1)

    success = True

    # Step 1: Fix extends order
    if not fix_extends_order(staff_list_path, args.dry_run, args.verbose):
        success = False

    if args.dry_run:
        print("Dry-run completed. No files were changed.")
    else:
        if success:
            print("Patcher completed successfully.")
        else:
            print("Patcher completed with errors. See log above.")

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
