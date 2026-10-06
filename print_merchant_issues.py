import json
try:
    with open('merchant_issues.json', encoding='utf-8-sig') as f:
        d = json.load(f)
        for i in d.get('diagnostics', []):
            print(f"{i['location']['range']['start']['line']}:{i['location']['range']['start']['column']} {i['code']} {i['problemMessage']}")
except Exception as e:
    try:
        with open('merchant_issues.json', encoding='utf-16le') as f:
            d = json.load(f)
            for i in d.get('diagnostics', []):
                print(f"{i['location']['range']['start']['line']}:{i['location']['range']['start']['column']} {i['code']} {i['problemMessage']}")
    except Exception as e2:
        print("Error:", e2)
