with open('dumps/unknown_package_name_1.132.1.cs', 'r', encoding='utf-8', errors='ignore') as f:
    for i, line in enumerate(f):
        low = line.lower()
        if 'guest' in low:
            if 'void' in low or 'string' in low or 'bool' in low or 'const' in low or 'field' in low:
                s = line.strip()
                if not s.startswith('//'):
                    print(f'{i}: {s[:100]}')
