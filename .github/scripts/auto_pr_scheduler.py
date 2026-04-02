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
    return [b["name"] for b in r.json()]

def matches_pattern(branch, pattern):
    return branch.startswith(pattern)

def pr_exists(source, dest):
    url = f"https://api.github.com/repos/{REPO}/pulls"
    params = {
        "head": f"{REPO.split('/')[0]}:{source}",
        "base": dest,
        "state": "open"
    }
    r = requests.get(url, headers=HEADERS, params=params)
    return len(r.json()) > 0

def has_changes(source, dest):
    url = f"https://api.github.com/repos/{REPO}/compare/{dest}...{source}"
    r = requests.get(url, headers=HEADERS)
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
        print(f"✅ Created PR: {source} → {dest}")
    else:
        print(f"❌ Failed: {r.json()}")

def main():
    config = load_config()

    if not config.get("auto_pr_enabled", True):
        print("⛔ Auto PR disabled")
        return

    branches = get_branches()

    for rule in config["rules"]:
        for branch in branches:
            if matches_pattern(branch, rule["source_pattern"]):

                for dest in rule["destinations"]:

                    if branch == dest:
                        continue

                    if pr_exists(branch, dest):
                        print(f"⚠️ PR exists: {branch} → {dest}")
                        continue

                    if has_changes(branch, dest):
                        create_pr(branch, dest)
                    else:
                        print(f"✅ No changes: {branch} → {dest}")

if __name__ == "__main__":
    main()
