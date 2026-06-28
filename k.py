import os
import subprocess

def run_cmd(cmd):
    try:
        result = subprocess.run(cmd, shell=True, check=True, text=True, capture_output=True)
        print(f"✅ Success: {cmd}")
        if result.stdout:
            print(result.stdout.strip())
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed: {cmd}")
        print(f"Error: {e.stderr.strip()}")
        return False

def main():
    print("🛠️  Git Force Fetch & Reset Tool")
    print("---------------------------------")
    
    # User se input URL maangein
    repo_url = input("Target GitHub Repository URL daalein: ").strip()
    
    if not repo_url.endswith(".git") and "github.com" in repo_url:
        repo_url = repo_url + ".git"
        
    if not repo_url:
        print("❌ URL empty nahi ho sakta!")
        return

    # 1. Purana index lock clear karein agar stuck ho
    if os.path.exists(".git/index.lock"):
        os.remove(".git/index.lock")
        
    # 2. Purana temporary remote clear karein agar koi bacha ho
    subprocess.run("git remote remove temp_force_remote", shell=True, capture_output=True)
    
    # 3. Naya temporary remote add karein user ke URL se
    print(f"\n🔄 Connecting to: {repo_url}...")
    if not run_cmd(f"git remote add temp_force_remote {repo_url}"):
        return

    # 4. Fetch karein (Pehle 'main' check karein, phir 'master')
    print("📥 Fetching latest code...")
    branch = "main"
    if not run_cmd("git fetch temp_force_remote main"):
        print("⚠️ 'main' branch nahi mili, 'master' try kar rahe hain...")
        if not run_cmd("git fetch temp_force_remote master"):
            run_cmd("git remote remove temp_force_remote")
            return
        branch = "master"

    # 5. Local folder ko forcefully us branch par reset karein
    print("⚡ Forcefully resetting local repository...")
    if run_cmd(f"git reset --hard temp_force_remote/{branch}"):
        print(f"\n🎉 Mubarak ho! Saara code ab diye gaye URL ke mutabiq forcefully sync ho chuka hai.")

    # 6. Clean up remote
    run_cmd("git remote remove temp_force_remote")

if __name__ == "__main__":
    main()
    # Is baar self-destruct code remove kar diya hai taake file hamesha save rahe!
