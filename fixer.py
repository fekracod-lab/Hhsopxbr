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

fixes_applied = 0

for path, issues in files_to_fix.items():
    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    modified = False
    # Sort issues by line number descending so length changes in a line don't affect previous issues on same line?
    # Actually, we apply line-by-line modifications.
    
    for issue in issues:
        code = issue['code']
        msg = issue['problemMessage']
        line_idx = issue['location']['range']['start']['line'] - 1
        col_start = issue['location']['range']['start']['column'] - 1
        col_end = issue['location']['range']['end']['column'] - 1
        
        if line_idx >= len(lines): continue
        line = lines[line_idx]
        
        if code == 'deprecated_member_use' or code == 'deprecated_member_use_from_same_package':
            if "'withOpacity' is deprecated" in msg:
                # regex to replace .withOpacity(...) with .withValues(alpha: ...)
                # It might span multiple lines if formatted poorly, but usually it's on one line.
                new_line = re.sub(r'\.withOpacity\(([^)]+)\)', r'.withValues(alpha: \1)', line)
                if new_line != line:
                    lines[line_idx] = new_line
                    modified = True
                    fixes_applied += 1
            elif "'christmasRed' is deprecated" in msg:
                new_line = line.replace('christmasRed', 'primaryColor')
                if new_line != line:
                    lines[line_idx] = new_line
                    modified = True
                    fixes_applied += 1
            elif "'christmasGreen' is deprecated" in msg:
                new_line = line.replace('christmasGreen', 'accentColor')
                if new_line != line:
                    lines[line_idx] = new_line
                    modified = True
                    fixes_applied += 1
            elif "'value' is deprecated" in msg and "initialValue" in msg:
                # Look for value: and replace with initialValue: 
                # but only around the column.
                new_line = line[:col_start] + line[col_start:].replace('value:', 'initialValue:', 1)
                if new_line != line:
                    lines[line_idx] = new_line
                    modified = True
                    fixes_applied += 1
            elif "'activeColor' is deprecated" in msg and "activeThumbColor" in msg:
                new_line = line[:col_start] + line[col_start:].replace('activeColor:', 'activeThumbColor:', 1)
                if new_line != line:
                    lines[line_idx] = new_line
                    modified = True
                    fixes_applied += 1
                    
        elif code in ['unused_local_variable', 'unused_field', 'unused_element']:
            # comment out the line
            if not line.strip().startswith('//'):
                lines[line_idx] = '// ' + line
                modified = True
                fixes_applied += 1
                
        elif code == 'dead_null_aware_expression':
            if "The '!' will have no effect" in msg:
                # the issue range highlights the !
                # Let's just remove the ! at col_start
                if col_start < len(line) and line[col_start] == '!':
                    lines[line_idx] = line[:col_start] + line[col_start+1:]
                    modified = True
                    fixes_applied += 1
                    
        elif code == 'undefined_hidden_name':
            # "The library ... doesn't export a member with the hidden name 'accentColor'."
            # highlight is the name. We can remove it.
            name = issue['problemMessage'].split("'")[-2]
            new_line = re.sub(r'\b' + re.escape(name) + r'\b,?\s*', '', line)
            # if line ends with 'hide ;' -> 'hide '
            new_line = new_line.replace('hide ;', ';').replace('hide  ;', ';')
            if new_line != line:
                lines[line_idx] = new_line
                modified = True
                fixes_applied += 1

    if modified:
        with open(path, 'w', encoding='utf-8') as f:
            f.writelines(lines)

print(f"Applied {fixes_applied} fixes.")
