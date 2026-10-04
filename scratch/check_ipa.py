import urllib.request
import json

token = "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"
url = "https://api.github.com/repos/xuantrun/vipmof/actions/runs?per_page=6"

req = urllib.request.Request(url, headers={
    "Authorization": f"token {token}",
    "User-Agent": "MeoMeoChecker"
})

with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read().decode())

print("=== RECENT GITHUB ACTIONS RUNS ===")
for r in data.get("workflow_runs", []):
    run_id = r["id"]
    status = r["status"]
    conclusion = r["conclusion"]
    commit = r["head_commit"]["message"].split("\n")[0]
    html_url = r["html_url"]
    artifacts_url = r["artifacts_url"]
    print(f"ID: {run_id} | Status: {status} | Conclusion: {conclusion}")
    print(f"   Commit: {commit}")
    print(f"   URL: {html_url}")
    
    # Check artifacts
    art_req = urllib.request.Request(artifacts_url, headers={
        "Authorization": f"token {token}",
        "User-Agent": "MeoMeoChecker"
    })
    try:
        with urllib.request.urlopen(art_req) as art_resp:
            art_data = json.loads(art_resp.read().decode())
            artifacts = art_data.get("artifacts", [])
            if artifacts:
                for a in artifacts:
                    size_mb = a['size_in_bytes'] / (1024 * 1024)
                    print(f"   -> Artifact: {a['name']} ({size_mb:.2f} MB)")
                    print(f"   -> Download API: {a['archive_download_url']}")
            else:
                print("   -> No artifacts yet.")
    except Exception as e:
        print(f"   -> Artifact check error: {e}")
    print("-" * 50)
