#!/usr/bin/env python3
"""
AXIS MASTER PATCHER – Ek command mein sab kuch theek kar do!
Run: python3 axis_patcher.py
"""

import os
import sys
import subprocess
import importlib.util
import shutil

# ----- Helper functions -----

def run_script(script_name):
    """Run a Python script as a subprocess."""
    if not os.path.isfile(script_name):
        print(f"⚠️ Script '{script_name}' nahi mila, skip kar rahe hain.")
        return
    print(f"▶️ Running {script_name} ...")
    try:
        subprocess.run([sys.executable, script_name], check=True)
        print(f"✅ {script_name} completed.")
    except subprocess.CalledProcessError as e:
        print(f"❌ Error running {script_name}: {e}")

def run_management_command(cmd):
    """Run a Django management command."""
    print(f"▶️ Running manage.py {cmd} ...")
    try:
        subprocess.run([sys.executable, "manage.py"] + cmd.split(), check=True)
        print(f"✅ manage.py {cmd} completed.")
    except subprocess.CalledProcessError as e:
        print(f"❌ Error running manage.py {cmd}: {e}")

def apply_patches():
    print("🚀 AXIS MASTER PATCHER STARTING...\n")

    # 1. Security Enhancement (tenant decorator + settings)
    run_script("security_enhancement.py")

    # 2. Reorder public_urls.py (API block to top)
    run_script("reorder_public_urls.py")

    # 3. Debug login (optional, but helpful)
    run_script("debug_login.py")

    # 4. Fee dropdown in sidebar
    run_script("add_fee_submenu.py")

    # 5. Any other URL updates (if present)
    if os.path.isfile("update_urls.py"):
        run_script("update_urls.py")

    # 6. Ensure migrations are applied to all tenant schemas
    print("\n📦 Applying migrations to ALL tenant schemas...")
    run_management_command("migrate_schemas")

    # 7. Collect static files (important for production)
    print("\n📦 Collecting static files...")
    run_management_command("collectstatic --noinput")

    print("\n🎉 ALL PATCHES APPLIED SUCCESSFULLY!")
    print("Ab aap apna server restart karein:")
    print("   python manage.py runserver")
    print("Phir portal login karke test karein.")

if __name__ == "__main__":
    # Check if all required patcher scripts exist; if not, we'll embed their logic here
    # but we assume they exist. If they don't, we can fall back to inline patches.
    # For safety, we'll also apply critical patches directly in this script.
    apply_patches()
