#!/usr/bin/env python3
"""
Commit all changes and push to origin/main.
Usage: python3 push.py
"""

import subprocess
import sys

def run(cmd):
    print(f"$ {cmd}")
    subprocess.run(cmd, shell=True, check=True)

if __name__ == "__main__":
    msg = input("Commit title: ").strip()
    if not msg:
        print("❌ Commit title cannot be empty.")
        sys.exit(1)

    run("git add -A")
    run(f'git commit -m "{msg}"')
    result = subprocess.run("git log -1 --format='%H %s'", shell=True, capture_output=True, text=True)
    print("✅ Commit created:", result.stdout.strip())
    run("git push origin main")
    print("✅ Push completed.")
