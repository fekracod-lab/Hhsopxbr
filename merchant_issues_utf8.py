import codecs
with codecs.open('merchant_issues.txt', 'r', 'utf-16le') as f:
    text = f.read()
with open('merchant_issues_utf8.txt', 'w', encoding='utf-8') as f:
    f.write(text)
