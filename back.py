#!/usr/bin/env python3
"""
Show last 20 commits and hard reset to a selected commit.
Usage: python3 back.py
"""

import subprocess
import sys

def run(cmd, capture=False):
    print(f"$ {cmd}")
    if capture:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.stdout.strip()
    else:
        subprocess.run(cmd, shell=True, check=True)

if __name__ == "__main__":
    # Show current branch
    branch = run("git branch --show-current", capture=True)
    print(f"📌 Current branch: {branch}")

    # Fetch latest commits from remote (optional)
    run("git fetch origin", capture=False)

    # Get last 20 commits: hash, date, author, subject
    log_output = run("git log -20 --format='%H|%ad|%an|%s' --date=short", capture=True)
    if not log_output:
        print("❌ No commits found.")
        sys.exit(1)

    commits = log_output.splitlines()
    print("\n📌 Last 20 commits (newest first):\n")
    commit_list = []
    for i, line in enumerate(commits, start=1):
        parts = line.split("|", 3)
        if len(parts) == 4:
            h, date, author, subject = parts
            print(f"{i:2}. {h[:12]}  {date}  {author}  {subject}")
            commit_list.append((h, subject))
        else:
            print(f"{i:2}. {line}")
            commit_list.append((line, ""))

    print("\nEnter the number of the commit to reset to (1-20), or enter a commit hash (full or partial), or press Enter for the latest commit.")
    choice = input("Choice: ").strip()

    # Determine target hash
    if choice == "":
        target_hash = commit_list[0][0]  # latest
    elif choice.isdigit():
        idx = int(choice) - 1
        if idx < 0 or idx >= len(commit_list):
            print(f"❌ Invalid number. Must be between 1 and {len(commit_list)}.")
            sys.exit(1)
        target_hash = commit_list[idx][0]
    else:
        # Try to match as a commit hash (full or partial)
        found = None
        for h, _ in commit_list:
            if h.startswith(choice):
                found = h
                break
        if found:
            target_hash = found
        else:
            # Check if it's a valid commit hash in the repo (maybe not in the last 20)
            check = run(f"git rev-parse --verify {choice}", capture=True)
            if check:
                target_hash = check
            else:
                print(f"❌ Invalid commit hash or number: {choice}")
                sys.exit(1)

    # Show what we're resetting to
    target_subject = run(f"git log -1 --format='%s' {target_hash}", capture=True)
    print(f"\n⚠️  Resetting hard to: {target_hash[:12]} - {target_subject}")
    confirm = input("Type 'yes' to proceed: ").strip().lower()
    if confirm != "yes":
        print("❌ Aborted.")
        sys.exit(0)

    run(f"git reset --hard {target_hash}")
    print("✅ Hard reset completed. Your working directory is now at that commit.")
