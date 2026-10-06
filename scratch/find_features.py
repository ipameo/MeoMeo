import re

dump_file = r"dumps\unknown_package_name_1.132.1.cs"

interesting = ['Fly', 'Speed', 'Gravity', 'FieldOfView', 'Teleport', 'NightMode', 'Damage', 'Recoil', 'Parachute', 'Fall']
found_methods = {k: [] for k in interesting}
prev_class = ""

with open(dump_file, 'r', encoding='utf-8', errors='ignore') as f:
    for line in f:
        line = line.strip()
        if 'public' in line and '(' in line and ')' in line:
            for k in interesting:
                if k.lower() in line.lower() and 'set_' not in line.lower() and 'get_' not in line.lower():
                    found_methods[k].append(prev_class + " | " + line)
        elif 'class' in line or 'struct' in line:
            prev_class = line

print("=== NEW FEATURES FOUND ===")
for k, methods in found_methods.items():
    if methods:
        print(f"\n[{k} Features]")
        for m in list(set(methods))[:10]:
            print(f"  {m}")
