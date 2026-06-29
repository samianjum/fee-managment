#!/usr/bin/env python3
"""
Fixes missing ManualGenerationLog model and applies migration.
Run: python3 fix_manual_generation_log.py
"""

import os
import sys
import shutil
import subprocess

MODELS_FILE = "axis_saas/models.py"

# The model class to insert (after GymSettings)
MODEL_DEFINITION = """
# ------------------- Manual Generation Log -------------------
class ManualGenerationLog(models.Model):
    LOG_TYPE_CHOICES = [
        ('manual', 'Manual'),
        ('auto', 'Auto'),
    ]
    month = models.PositiveSmallIntegerField()
    year = models.PositiveSmallIntegerField()
    created_count = models.PositiveIntegerField(default=0)
    skipped_existing = models.PositiveIntegerField(default=0)
    skipped_no_fee = models.PositiveIntegerField(default=0)
    generated_at = models.DateTimeField(auto_now_add=True)
    triggered_by = models.CharField(max_length=150, blank=True, null=True)
    log_type = models.CharField(max_length=10, choices=LOG_TYPE_CHOICES, default='manual', help_text="Type of generation (manual or auto)")

    class Meta:
        ordering = ['-generated_at']

    def __str__(self):
        return f"{self.month}/{self.year} - {self.get_log_type_display()} - {self.generated_at.strftime('%Y-%m-%d %H:%M')}"
"""

def insert_model():
    if not os.path.exists(MODELS_FILE):
        print(f"❌ {MODELS_FILE} not found!")
        sys.exit(1)

    with open(MODELS_FILE, 'r') as f:
        content = f.read()

    # Check if model already exists
    if 'class ManualGenerationLog' in content:
        print("✅ ManualGenerationLog already exists in models.py – nothing to do.")
        return

    # Find insertion point: after the GymSettings class
    gym_settings_marker = 'class GymSettings(models.Model):'
    if gym_settings_marker not in content:
        print("❌ Could not find 'class GymSettings' – cannot determine insertion point.")
        sys.exit(1)

    # We'll insert after the entire GymSettings class definition, which ends with a blank line or next class
    # Find the end of GymSettings class: look for a line that starts with 'class ' but not indented, after the class.
    lines = content.splitlines()
    insert_index = None
    in_gym_settings = False
    for i, line in enumerate(lines):
        if line.startswith('class GymSettings'):
            in_gym_settings = True
        elif in_gym_settings and line.startswith('class ') and not line.startswith('    '):
            # Found next class; insert before this line
            insert_index = i
            break
        elif in_gym_settings and i == len(lines)-1:
            # End of file
            insert_index = len(lines)
            break

    if insert_index is None:
        print("⚠️ Could not automatically find insertion point – adding at the end of the file.")
        insert_index = len(lines)

    # Insert the model definition (with a newline before)
    lines.insert(insert_index, MODEL_DEFINITION)
    new_content = '\n'.join(lines)
    with open(MODELS_FILE, 'w') as f:
        f.write(new_content)
    print("✅ Inserted ManualGenerationLog model into models.py")

def run_migration():
    print("🔄 Running migration 0022...")
    # Ensure the migration file exists
    migration_file = "axis_saas/migrations/0022_add_log_type_to_manualgenerationlog.py"
    if not os.path.exists(migration_file):
        print("❌ Migration file 0022 not found! Please ensure the patcher created it.")
        sys.exit(1)

    # Run migrate for axis_saas
    result = subprocess.run([sys.executable, "manage.py", "migrate", "axis_saas"], capture_output=True, text=True)
    if result.returncode != 0:
        print("❌ Migration failed:")
        print(result.stderr)
        sys.exit(1)
    print("✅ Migration applied successfully.")

if __name__ == "__main__":
    insert_model()
    run_migration()
    print("\n🎉 Done! Now restart the server: python manage.py runserver")
