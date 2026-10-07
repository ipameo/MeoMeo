import urllib.request, json

url = 'https://api.github.com/repos/xuantrun/vipmof/actions/runs?per_page=1'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode())
        run_id = data['workflow_runs'][0]['id']
        print(f"Latest run id: {run_id}")
        print(f"Status: {data['workflow_runs'][0]['status']}, Conclusion: {data['workflow_runs'][0]['conclusion']}")
        
        jobs_url = data['workflow_runs'][0]['jobs_url']
        with urllib.request.urlopen(urllib.request.Request(jobs_url, headers={'User-Agent': 'Mozilla/5.0'})) as jresp:
            jobs_data = json.loads(jresp.read().decode())
            for job in jobs_data['jobs']:
                print(f"Job: {job['name']}, Status: {job['status']}, Conclusion: {job['conclusion']}")
                if job['conclusion'] == 'failure':
                    print(f"Job {job['name']} failed. Logs url: {job['html_url']}")
except Exception as e:
    print(f'Error: {e}')
