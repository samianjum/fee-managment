#!/usr/bin/env python3
"""
AXIS Patcher – Fix dynamic section dropdown in student list templates.

This script corrects the JavaScript that populates the section dropdown
based on the selected class. The original code used `const` inside a
Django for loop, causing redeclaration errors. This patch replaces the
entire dynamic section script block with a corrected version.

Usage:
    python axis_patcher.py [--dry-run] [--verbose] [--target-dir /path/to/project]

Options:
    --dry-run      Preview changes without writing files.
    --verbose      Show detailed output.
    --target-dir   Project root directory (default: current directory).
"""

import os
import re
import sys
import time
from pathlib import Path
from typing import Optional, List, Tuple

# ----------------------------------------------------------------------
# CONFIGURATION
# ----------------------------------------------------------------------
DRY_RUN = False
VERBOSE = False
TARGET_DIR = Path(os.getcwd())

# ----------------------------------------------------------------------
# LOGGING
# ----------------------------------------------------------------------
def log_info(msg: str) -> None:
    print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {msg}")

def log_verbose(msg: str) -> None:
    if VERBOSE:
        log_info(f"  {msg}")

def log_error(msg: str) -> None:
    print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] ERROR: {msg}")

def log_warning(msg: str) -> None:
    print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] WARNING: {msg}")

# ----------------------------------------------------------------------
# FILE HELPERS
# ----------------------------------------------------------------------
def read_file(path: Path) -> Optional[str]:
    if not path.exists():
        log_error(f"File not found: {path}")
        return None
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def write_file(path: Path, content: str) -> None:
    if DRY_RUN:
        log_info(f"[DRY-RUN] Would write: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    log_info(f"Written: {path}")

# ----------------------------------------------------------------------
# PATCH LOGIC
# ----------------------------------------------------------------------

# The corrected JavaScript block for student_list.html and mobile_student_list.html
CORRECTED_SCRIPT = """
    // Dynamic section dropdown based on class selection
    const classSelect = document.getElementById('classSelect') || document.querySelector('select[name="class_id"]');
    const sectionSelect = document.getElementById('sectionSelect') || document.querySelector('select[name="section"]');
    if (classSelect && sectionSelect) {
        // Build classData from server-side classes
        const classData = {};
        {% for cls in classes %}
            if (!classData[{{ cls.id }}]) {
                classData[{{ cls.id }}] = [];
            }
            var sec = '{{ cls.section|default:"" }}';
            if (sec && classData[{{ cls.id }}].indexOf(sec) === -1) {
                classData[{{ cls.id }}].push(sec);
            }
        {% endfor %}
        console.log('[DEBUG] classData:', classData);
        
        // Also collect all sections for "All Classes"
        const allSections = [];
        for (const clsId in classData) {
            classData[clsId].forEach(s => {
                if (!allSections.includes(s)) allSections.push(s);
            });
        }
        allSections.sort();
        console.log('[DEBUG] allSections:', allSections);

        function updateSectionOptions() {
            const selectedClass = classSelect.value;
            let sections = [];
            if (selectedClass && classData[selectedClass]) {
                sections = classData[selectedClass];
                console.log('[DEBUG] Sections for class ' + selectedClass + ':', sections);
            } else {
                sections = allSections;
                console.log('[DEBUG] No class selected, showing all sections:', sections);
            }
            const currentSection = sectionSelect.value;
            sectionSelect.innerHTML = '';
            const emptyOpt = document.createElement('option');
            emptyOpt.value = '';
            emptyOpt.textContent = 'All Sections';
            sectionSelect.appendChild(emptyOpt);
            if (sections.length === 0) {
                // If no sections, add a disabled option to indicate none
                const noOpt = document.createElement('option');
                noOpt.value = '';
                noOpt.textContent = 'No sections';
                noOpt.disabled = true;
                sectionSelect.appendChild(noOpt);
            } else {
                sections.forEach(sec => {
                    const opt = document.createElement('option');
                    opt.value = sec;
                    opt.textContent = sec || '—';
                    if (sec === currentSection) {
                        opt.selected = true;
                    }
                    sectionSelect.appendChild(opt);
                });
            }
            // Keep "All Sections" selected if currentSection is empty
            if (!currentSection) {
                sectionSelect.value = '';
            }
        }

        classSelect.addEventListener('change', function() {
            updateSectionOptions();
            const filterForm = document.getElementById('studentFilterForm') || document.querySelector('.filter-form');
            if (filterForm) {
                filterForm.submit();
            }
        });

        // Initial update on page load
        updateSectionOptions();
        console.log('[DEBUG] Initial section dropdown updated.');
    } else {
        console.warn('[DEBUG] classSelect or sectionSelect not found.');
    }
"""

def patch_student_list_template(file_path: Path) -> bool:
    """Apply the section dropdown fix to the given template file."""
    content = read_file(file_path)
    if content is None:
        return False

    # Find the script block that contains the dynamic section logic.
    # We look for the comment "// Dynamic section dropdown based on class selection"
    # and match everything until the closing </script> that follows.
    # We'll use a non-greedy match to capture the whole script block.
    pattern = re.compile(
        r'(<script[^>]*>.*?// Dynamic section dropdown based on class selection.*?</script>)',
        re.DOTALL | re.IGNORECASE
    )
    match = pattern.search(content)
    if not match:
        log_warning(f"No dynamic section dropdown script found in {file_path}. Skipping.")
        return False

    old_script_block = match.group(1)

    # Extract the opening <script> tag (with any attributes) and the closing </script>
    # We need to keep the same tag attributes.
    script_tag_match = re.match(r'(<script[^>]*>)', old_script_block, re.IGNORECASE)
    if not script_tag_match:
        log_error(f"Could not parse script tag in {file_path}. Skipping.")
        return False
    opening_tag = script_tag_match.group(1)

    # Build the new script block with the same opening tag and our corrected content.
    new_script_block = opening_tag + '\n' + CORRECTED_SCRIPT + '\n</script>'

    # Replace the old block with the new one.
    new_content = content.replace(old_script_block, new_script_block)

    if new_content == content:
        log_info(f"No changes needed for {file_path}")
        return False

    write_file(file_path, new_content)
    return True

# ----------------------------------------------------------------------
# MAIN
# ----------------------------------------------------------------------
def main() -> None:
    global DRY_RUN, VERBOSE, TARGET_DIR

    args = sys.argv[1:]
    for arg in args:
        if arg == '--dry-run':
            DRY_RUN = True
        elif arg == '--verbose':
            VERBOSE = True
        elif arg.startswith('--target-dir='):
            TARGET_DIR = Path(arg.split('=', 1)[1])
        else:
            log_error(f"Unknown argument: {arg}")
            sys.exit(1)

    log_info("AXIS Patcher – Fix dynamic section dropdown in student list templates")
    log_info(f"Target directory: {TARGET_DIR}")
    log_info(f"Dry run: {DRY_RUN}")
    log_info(f"Verbose: {VERBOSE}")

    # Define template files to patch.
    template_files = [
        TARGET_DIR / "templates" / "tenant" / "student_list.html",
        TARGET_DIR / "templates" / "mobile" / "student_list.html",
    ]

    patched = 0
    for file_path in template_files:
        if file_path.exists():
            log_info(f"Processing: {file_path}")
            if patch_student_list_template(file_path):
                patched += 1
        else:
            log_verbose(f"File not found: {file_path} (skipping)")

    if patched > 0:
        log_info(f"✅ Successfully patched {patched} file(s).")
    else:
        log_info("No files were patched. Ensure the templates exist and contain the dynamic section dropdown script.")

if __name__ == "__main__":
    main()
