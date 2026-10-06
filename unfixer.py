import json
import re

with open('issues.json', 'r', encoding='utf-16') as f:
    d = json.load(f)

files_to_fix = {}
for issue in d.get('diagnostics', []):
    path = issue['location']['file']
    if path not in files_to_fix:
        files_to_fix[path] = []
    files_to_fix[path].append(issue)

reverts_applied = 0

for path, issues in files_to_fix.items():
    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    modified = False
    
    for issue in issues:
        code = issue['code']
        line_idx = issue['location']['range']['start']['line'] - 1
        
        if line_idx >= len(lines): continue
        line = lines[line_idx]
        
        if code in ['unused_local_variable', 'unused_field', 'unused_element']:
            # revert the comment
            if line.startswith('// '):
                lines[line_idx] = line[3:]
                modified = True
                reverts_applied += 1

    if modified:
        with open(path, 'w', encoding='utf-8') as f:
            f.writelines(lines)

print(f"Applied {reverts_applied} reverts.")
