import json
with open('issues2.json', 'r', encoding='utf-16') as f:
    d = json.load(f)

for i in d.get('diagnostics', []):
    if i['severity'] == 'ERROR':
        print(f"{i['location']['file']}:{i['location']['range']['start']['line']} - {i['code']} - {i['problemMessage']}")
