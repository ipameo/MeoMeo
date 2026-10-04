import base64
import requests

token = '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'
repo = 'xuantrun/vipmof'
path = 'Assembly-CSharp-patch.bytes'
local_path = 'dist/Assembly-CSharp-patch.bytes'

url = f'https://api.github.com/repos/{repo}/contents/{path}'
headers = {'Authorization': f'token {token}', 'Accept': 'application/vnd.github.v3+json'}

r = requests.get(url, headers=headers)
sha = None
if r.status_code == 200:
    sha = r.json()['sha']

with open(local_path, 'rb') as f:
    content = base64.b64encode(f.read()).decode('utf-8')

data = {
    'message': 'Update: Count Enemy only (removed isbot), text-only Name',
    'content': content
}
if sha:
    data['sha'] = sha

r = requests.put(url, headers=headers, json=data)
if r.status_code in (200, 201):
    sha_short = r.json().get('content', {}).get('sha', '')[:10]
    print(f'OK {r.status_code} sha={sha_short}')
else:
    print(f'ERROR {r.status_code}: {r.text[:300]}')
