import json
with open('issues2.json', 'r', encoding='utf-16') as f:
    d = json.load(f)

with open('errors_utf8.txt', 'w', encoding='utf-8') as out:
    for i in d.get('diagnostics', []):
        if i['severity'] == 'ERROR':
            out.write(f"{i['location']['file']}:{i['location']['range']['start']['line']} - {i['code']} - {i['problemMessage']}\n")
