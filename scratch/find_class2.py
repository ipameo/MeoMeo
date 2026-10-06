import sys
lines = open('c:/Users/Administrator/Downloads/FIX-CRASH-ESP/project-freefire_c#/project-freefire_c#/dumps/unknown_package_name_1.132.1.cs', encoding='utf-8').read().splitlines()
idx = [i for i, l in enumerate(lines) if 'public class COW.UGCWeaponRepItem' in l]
print('\n'.join(lines[idx[0]:idx[0]+200]))
