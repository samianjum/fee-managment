#!/usr/bin/env python3
"""
AXIS Class Management – Auto-Capitalization & Cache Fix
=======================================================

This script fixes two issues:
1. Class names and sections are automatically capitalized when typing:
   - Class name: Title Case (e.g., "grade 5" → "Grade 5")
   - Section: Uppercase (e.g., "a" → "A")
2. After adding/editing, the list appears empty until manual refresh.
   Fixed by adding cache-control headers and unique timestamps.

It also creates a management command to normalize existing data.

Usage:
    python3 fix_class_capitalization.py [--dry-run] [--verbose] [--target-dir /path/to/project]
"""

import os
import re
import sys
import time
from pathlib import Path

# ---------- Configuration ----------
TARGET_DIR = Path(os.getcwd())
DRY_RUN = False
VERBOSE = False

# ---------- Helpers ----------
def log_info(msg):
    print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {msg}")

def log_verbose(msg):
    if VERBOSE:
        log_info(f"  {msg}")

def log_error(msg):
    print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] ERROR: {msg}")

def write_file(path, content):
    if DRY_RUN:
        log_info(f"[DRY-RUN] Would write: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    log_info(f"Written: {path}")

# ---------- Main ----------
def main():
    global TARGET_DIR, DRY_RUN, VERBOSE

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

    log_info("AXIS Class Management – Auto-Capitalization & Cache Fix")
    log_info(f"Target directory: {TARGET_DIR}")
    log_info(f"Dry run: {DRY_RUN}")
    log_info(f"Verbose: {VERBOSE}")

    # ---- Step 1: Update models.py to ensure normalization is present ----
    models_path = TARGET_DIR / "axis_saas" / "models.py"
    if not models_path.exists():
        log_error(f"models.py not found at {models_path}")
        sys.exit(1)

    with open(models_path, 'r', encoding='utf-8') as f:
        models_content = f.read()

    # Check if normalize_fields exists
    if 'def normalize_fields' not in models_content:
        log_info("Adding normalization to models.py...")
        new_class_section = '''
# ========== CLASS & SUBJECT MANAGEMENT ==========
class SchoolClass(models.Model):
    \"\"\"Represents a class (e.g., Grade 5, Section A).\"\"\"
    name = models.CharField(max_length=100, help_text="Class name, e.g., 'Grade 5'")
    section = models.CharField(max_length=10, blank=True, help_text="Section, e.g., 'A'")
    description = models.TextField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name', 'section']
        unique_together = ['name', 'section']

    def __str__(self):
        return f"{self.name} - {self.section}" if self.section else self.name

    def normalize_fields(self):
        \"\"\"Normalize name to title case and section to uppercase.\"\"\"
        if self.name:
            self.name = self.name.strip().title()
        if self.section:
            self.section = self.section.strip().upper()

    def clean(self):
        self.normalize_fields()
        # Case-insensitive uniqueness check
        if self.pk:
            existing = SchoolClass.objects.filter(
                name__iexact=self.name,
                section__iexact=self.section
            ).exclude(pk=self.pk)
        else:
            existing = SchoolClass.objects.filter(
                name__iexact=self.name,
                section__iexact=self.section
            )
        if existing.exists():
            from django.core.exceptions import ValidationError
            raise ValidationError(f"A class with name '{self.name}' and section '{self.section}' already exists (case-insensitive).")

    def save(self, *args, **kwargs):
        self.normalize_fields()
        self.full_clean()
        super().save(*args, **kwargs)

class Subject(models.Model):
    \"\"\"Represents a subject (e.g., Mathematics).\"\"\"
    name = models.CharField(max_length=100)
    code = models.CharField(max_length=20, unique=True, blank=True)
    description = models.TextField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name

    def normalize_fields(self):
        if self.name:
            self.name = self.name.strip().title()

    def clean(self):
        self.normalize_fields()
        if self.pk:
            existing = Subject.objects.filter(name__iexact=self.name).exclude(pk=self.pk)
        else:
            existing = Subject.objects.filter(name__iexact=self.name)
        if existing.exists():
            from django.core.exceptions import ValidationError
            raise ValidationError(f"A subject with name '{self.name}' already exists (case-insensitive).")

    def save(self, *args, **kwargs):
        self.normalize_fields()
        if not self.code:
            import time
            self.code = f"SUBJ-{int(time.time())}"
        self.full_clean()
        super().save(*args, **kwargs)

class ClassSubject(models.Model):
    \"\"\"Links a subject to a class and assigns a teacher.\"\"\"
    school_class = models.ForeignKey(SchoolClass, on_delete=models.CASCADE, related_name='class_subjects')
    subject = models.ForeignKey(Subject, on_delete=models.CASCADE, related_name='class_subjects')
    teacher = models.ForeignKey('Staff', on_delete=models.SET_NULL, null=True, blank=True, related_name='class_subjects', limit_choices_to={'status': 'active'})
    academic_year = models.CharField(max_length=20, blank=True, help_text="e.g., 2024-2025")
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ['school_class', 'subject']
        ordering = ['school_class', 'subject']

    def __str__(self):
        teacher_name = self.teacher.full_name if self.teacher else "Unassigned"
        return f"{self.school_class} - {self.subject} ({teacher_name})"
'''
        # Replace the existing section
        pattern = re.compile(r'# ========== CLASS & SUBJECT MANAGEMENT ==========.*', re.DOTALL)
        if not pattern.search(models_content):
            log_error("Could not find marker in models.py. Skipping models update.")
        else:
            models_content = pattern.sub(new_class_section, models_content)
            write_file(models_path, models_content)

    # ---- Step 2: Update views/classes.py with cache-busting redirects ----
    views_path = TARGET_DIR / "axis_saas" / "views" / "classes.py"
    if not views_path.exists():
        log_error(f"views/classes.py not found at {views_path}")
        sys.exit(1)

    with open(views_path, 'r', encoding='utf-8') as f:
        views_content = f.read()

    # Add helper function if not present
    if 'redirect_with_cache_bust' not in views_content:
        helper_code = '''
def redirect_with_cache_bust(url_name, schema_name, **kwargs):
    """Return a HttpResponseRedirect with cache-control headers and a timestamp."""
    from django.shortcuts import redirect
    from django.urls import reverse
    import time
    url = reverse(url_name, kwargs={'schema_name': schema_name}) + '?updated=' + str(int(time.time()))
    response = redirect(url)
    response['Cache-Control'] = 'no-cache, no-store, must-revalidate'
    response['Pragma'] = 'no-cache'
    response['Expires'] = '0'
    return response
'''
        # Insert after the last import
        import_pattern = re.compile(r'^(from|import)\s+.*$', re.MULTILINE)
        matches = list(import_pattern.finditer(views_content))
        if matches:
            last_import = matches[-1]
            insert_pos = last_import.end()
            views_content = views_content[:insert_pos] + '\n' + helper_code + views_content[insert_pos:]
        else:
            views_content = helper_code + '\n' + views_content

        # Replace redirects
        views_content = re.sub(
            r"redirect\(reverse\('class_management', kwargs={'schema_name': schema_name}\) \+ '\?updated=1'\)",
            "redirect_with_cache_bust('class_management', schema_name)",
            views_content
        )
        views_content = re.sub(
            r"redirect\(reverse\('mobile_class_management', kwargs={'schema_name': schema_name}\) \+ '\?updated=1'\)",
            "redirect_with_cache_bust('mobile_class_management', schema_name)",
            views_content
        )
        views_content = re.sub(
            r"redirect\('class_management', schema_name=schema_name\)",
            "redirect_with_cache_bust('class_management', schema_name)",
            views_content
        )
        views_content = re.sub(
            r"redirect\('mobile_class_management', schema_name=schema_name\)",
            "redirect_with_cache_bust('mobile_class_management', schema_name)",
            views_content
        )

        write_file(views_path, views_content)

    # ---- Step 3: Update the templates to auto-capitalize input fields ----
    # Desktop template
    desk_template_path = TARGET_DIR / "templates" / "tenant" / "class_management.html"
    if desk_template_path.exists():
        with open(desk_template_path, 'r', encoding='utf-8') as f:
            desk_html = f.read()

        # Add oninput handlers to class name and section inputs.
        # We'll add the JavaScript function at the bottom of the page.
        # We'll also add the oninput attributes to the input fields.

        # Add a script block at the end (before </body>)
        capital_script = '''
<script>
    // Auto-capitalize class name and section fields
    document.addEventListener('DOMContentLoaded', function() {
        // Class name input (desktop)
        var classNameInput = document.getElementById('className');
        if (classNameInput) {
            classNameInput.addEventListener('input', function() {
                this.value = this.value.replace(/\\b\\w/g, function(m) { return m.toUpperCase(); });
            });
        }
        var classSectionInput = document.getElementById('classSection');
        if (classSectionInput) {
            classSectionInput.addEventListener('input', function() {
                this.value = this.value.toUpperCase();
            });
        }
        // Subject name input
        var subjectNameInput = document.getElementById('subjectName');
        if (subjectNameInput) {
            subjectNameInput.addEventListener('input', function() {
                this.value = this.value.replace(/\\b\\w/g, function(m) { return m.toUpperCase(); });
            });
        }
    });
</script>
'''
        # Insert before </body>
        desk_html = desk_html.replace('</body>', capital_script + '\n</body>')
        write_file(desk_template_path, desk_html)

    # Mobile template
    mob_template_path = TARGET_DIR / "templates" / "mobile" / "class_management.html"
    if mob_template_path.exists():
        with open(mob_template_path, 'r', encoding='utf-8') as f:
            mob_html = f.read()
        # Same script
        mob_html = mob_html.replace('</body>', capital_script + '\n</body>')
        write_file(mob_template_path, mob_html)

    # ---- Step 4: Create management command to normalize existing data ----
    mgmt_dir = TARGET_DIR / "axis_saas" / "management" / "commands"
    mgmt_dir.mkdir(parents=True, exist_ok=True)
    normalize_cmd = '''from django.core.management.base import BaseCommand
from django_tenants.utils import schema_context
from axis_saas.models import SchoolClient, SchoolClass, Subject

class Command(BaseCommand):
    help = 'Normalize existing class and subject names (title case, uppercase section)'

    def handle(self, *args, **options):
        tenants = SchoolClient.objects.exclude(schema_name='public')
        for tenant in tenants:
            self.stdout.write(f"Normalizing tenant: {tenant.schema_name}")
            with schema_context(tenant.schema_name):
                # Normalize classes
                classes = SchoolClass.objects.all()
                updated = 0
                for cls in classes:
                    original_name = cls.name
                    original_section = cls.section
                    cls.normalize_fields()
                    if cls.name != original_name or cls.section != original_section:
                        cls.save(update_fields=['name', 'section'])
                        updated += 1
                        self.stdout.write(f"  Updated class: {original_name} -> {cls.name}, section: {original_section} -> {cls.section}")
                self.stdout.write(f"  Updated {updated} classes.")

                # Normalize subjects
                subjects = Subject.objects.all()
                updated_subj = 0
                for subj in subjects:
                    original = subj.name
                    subj.normalize_fields()
                    if subj.name != original:
                        subj.save(update_fields=['name'])
                        updated_subj += 1
                        self.stdout.write(f"  Updated subject: {original} -> {subj.name}")
                self.stdout.write(f"  Updated {updated_subj} subjects.")
        self.stdout.write(self.style.SUCCESS("Normalization complete."))
'''
    write_file(mgmt_dir / "normalize_class_data.py", normalize_cmd)

    log_info("\n✅ All fixes applied.")
    log_info("\nNext steps:")
    log_info("  1. Restart your Django server.")
    log_info("  2. Run the normalization command to fix existing data:")
    log_info("       python manage.py normalize_class_data")
    log_info("  3. Now, when you type in the class name or section fields, they will auto-capitalize.")
    log_info("  4. The cache glitch is also fixed.")

if __name__ == "__main__":
    main()
