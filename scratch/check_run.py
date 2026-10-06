import urllib.request, json
req = urllib.request.Request('https://api.github.com/repos/xuantrun/vipmof/actions/runs?per_page=1', headers={'User-Agent': 'Mozilla/5.0'})
res = urllib.request.urlopen(req)
data = json.loads(res.read())
run = data['workflow_runs'][0]
print(f"Status: {run['status']}, Conclusion: {run['conclusion']}, URL: {run['html_url']}")
