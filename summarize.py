import json

with open('issues.json', 'r', encoding='utf-16') as f:
    d = json.load(f)

print(f"Total issues: {len(d.get('diagnostics', []))}")
types = {}
for i in d.get('diagnostics', []):
    code = i.get('code', 'unknown')
    types[code] = types.get(code, 0) + 1

from pprint import pprint
print("Issue types:")
pprint(types)
