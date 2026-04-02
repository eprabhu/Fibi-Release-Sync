import os
import json
import requests

TOKEN = os.environ["GITHUB_TOKEN"]
REPO = os.environ["REPO"]

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Accept": "application/vnd.github+json"
}

def load_config():
    with open(".github/auto-pr-config.json") as f:
        return json.load(f)

def get_branches():
    url = f"https://api.github.com/repos/{REPO}/branches"
    r = requests.get(url, headers=HEADERS)
    if r.status_code != 200:
        print(f"❌ Error fetching branches: {r.status_code} - {r.text}")
        return []
    return [b["name"] for b in r.json()]

def matches_pattern(branch, pattern):
    # If the pattern is meant to be an exact match, we can check that.
    # For now, startswith is used as requested.
    return branch == pattern or branch.startswith(pattern + "/")

def pr_exists(source, dest):
    url = f"https://api.github.com/repos/{REPO}/pulls"
    params = {
        "head": f"{REPO.split('/')[0]}:{source}",
        "base": dest,
        "state": "open"
    }
    r = requests.get(url, headers=HEADERS, params=params)
    if r.status_code != 200:
        print(f"❌ Error checking PR existence: {r.status_code} - {r.text}")
        return False
    return len(r.json()) > 0

def has_changes(source, dest):
    url = f"https://api.github.com/repos/{REPO}/compare/{dest}...{source}"
    r = requests.get(url, headers=HEADERS)
    if r.status_code != 200:
        print(f"❌ Error comparing branches: {r.status_code} - {r.text}")
        return False
    data = r.json()
    return data.get("ahead_by", 0) > 0

def create_pr(source, dest):
    url = f"https://api.github.com/repos/{REPO}/pulls"

    data = {
        "title": f"[Scheduled] {source} → {dest}",
        "head": source,
        "base": dest,
        "body": f"Auto-created scheduled PR from {source} to {dest}"
    }

    r = requests.post(url, headers=HEADERS, json=data)

    if r.status_code == 201:
        print(f"✅ Successfully created PR: {source} → {dest}")
    else:
        print(f"❌ Failed to create PR {source} → {dest}: {r.status_code} - {r.text}")

def main():
    print(f"🚀 Starting Auto PR Scheduler for {REPO}")
    config = load_config()

    if not config.get("auto_pr_enabled", True):
        print("⛔ Auto PR disabled in config")
        return

    print("🔍 Fetching branches...")
    branches = get_branches()
    if not branches:
        print("❓ No branches found or error during fetch")
        return
    print(f"📋 Found branches: {', '.join(branches)}")

    for rule in config["rules"]:
        pattern = rule["source_pattern"]
        print(f"📌 Rule: source pattern='{pattern}' destinations={rule['destinations']}")
        
        matches = [b for b in branches if matches_pattern(b, pattern)]
        if not matches:
            print(f"❓ No branches match pattern '{pattern}'")
            continue

        for branch in matches:
            print(f"✨ Matched branch: {branch}")
            for dest in rule["destinations"]:
                if branch == dest:
                    continue

                print(f"🔗 Checking {branch} → {dest}")
                
                if pr_exists(branch, dest):
                    print(f"⚠️ Open PR already exists: {branch} → {dest}")
                    continue

                if has_changes(branch, dest):
                    print(f"🚩 Changes found! Creating PR: {branch} → {dest}")
                    create_pr(branch, dest)
                else:
                    print(f"✅ Already in sync: {branch} → {dest}")

if __name__ == "__main__":
    main()
