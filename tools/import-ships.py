#!/usr/bin/env python3
"""Generate ships.js: the starship profiles the GM tab's Ships section shows.

    python3 tools/import-ships.py [vault] [out.js]

Two sources, same note layout ("### Name", a stat table, a line of bold fields, weapons):
  - a short pick list from the fad_core vault's Starship Profiles (Core Rulebook numbers only;
    the descriptive text stays in the vault, since the site is public)
  - every ship in homebrew/Ships (the campaign's own ships; flagged hb, description kept)

Stdlib only; never hand-edit ships.js, re-run this instead.
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VAULT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'fad_core')
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, 'ships.js')
CORE = os.path.join(VAULT, '07 - Starships and Vehicles', 'Starship Profiles', 'Starship Profiles.md')
HB = os.path.join(ROOT, 'homebrew', 'Ships')
# Core Rulebook ships the campaign uses: heading fragment → group shown in the tracker
PICK = [('X-Wing', 'Alliance'), ('Y-Wing', 'Alliance'), ('CR90', 'Alliance'), ('TIE/LN', 'Imperial'), ('Lambda', 'Imperial')]
GROUPS = ['The Crew', 'Alliance', 'Imperial', 'Chiss', 'Far Outsiders']
SKIP_INFO = ('manufacturer', 'price/rarity', 'weapons')


def clean(s):
    s = re.sub(r'<!--.*?-->', '', s)
    s = re.sub(r'\[\[[^\]|]*\\?\|([^\]]*)\]\]', r'\1', s)
    s = re.sub(r'\[\[#?([^\]]*)\]\]', r'\1', s)
    s = re.sub(r'\[([A-Za-z][A-Za-z ]*)\]', r'\1', s)         # Range [Close] → Range Close
    s = s.replace('**', '').replace('*', '')
    return re.sub(r'\s+', ' ', s).strip()


def split_top(s, sep):
    out, depth, cur = [], 0, ''
    for ch in s:
        depth += ch == '('
        depth -= ch == ')' and depth > 0
        if ch == sep and depth == 0:
            out.append(cur)
            cur = ''
        else:
            cur += ch
    out.append(cur)
    return [x.strip() for x in out if x.strip()]


def weapon(piece):
    m = re.match(r'^(.+?)\s*\((Fire Arc.*)\)\s*\.?$', clean(piece))
    if not m:
        return None
    w = {'n': m.group(1)[:1].upper() + m.group(1)[1:]}
    extra = []
    for p in [x.strip() for x in m.group(2).split(';')]:
        for key, rx in (('arc', r'^Fire Arc (.+)$'), ('dam', r'^Damage (.+)$'), ('crit', r'^Critical (.+)$'), ('rng', r'^Range (.+)$')):
            hit = re.match(rx, p)
            if hit:
                w[key] = hit.group(1)
                break
        else:
            extra.append(p)
    if extra:
        w['q'] = '; '.join(extra)
    return w


def parse(path, hb):
    text = open(path, encoding='utf-8').read()
    out, group = [], ''
    for m in re.finditer(r'^(#{2,3}) (.+?)\s*\n(.*?)(?=^#{1,3} |\Z)', text, re.M | re.S):
        if m.group(1) == '##':
            group = clean(m.group(2))
            continue
        name, body = clean(m.group(2)), m.group(3)
        row = re.search(r'^\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*([+\-−–]?\d+)\s*\|\s*([^|]+?)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|', body, re.M)
        if not row:
            print('skipped (no stat table):', name)
            continue
        if not hb:
            pick = [g for frag, g in PICK if frag.lower() in name.lower()]
            if not pick:
                continue
            group = pick[0]
        dfn = [None if not re.match(r'^\d+$', x.strip()) else int(x) for x in row.group(4).split('/')]
        ship = {'n': name, 'grp': group, 'sil': int(row.group(1)), 'spd': int(row.group(2)),
                'hnd': row.group(3).replace('−', '-').replace('–', '-'), 'def': dfn,
                'arm': int(row.group(5)), 'ht': int(row.group(6)), 'ss': int(row.group(7))}
        if hb:
            ship['hb'] = 1
            desc = re.match(r'\s*([^|\n*#-][^\n]+)\n', body)
            if desc:
                ship['d'] = clean(desc.group(1))
        info, weapons = [], []
        for line in body.split('\n'):
            if line.startswith('**') and ' · ' in line or re.match(r'^\*\*Hull Type', line):
                for part in line.split(' · '):
                    f = re.match(r'^\*\*([^*:]+):\*\*\s*(.*)$', part.strip())
                    if not f:
                        continue
                    if f.group(1).strip().lower() == 'weapons':
                        weapons += [w for w in map(weapon, split_top(f.group(2), ',')) if w]
                    elif f.group(1).strip().lower() not in SKIP_INFO:
                        info.append([clean(f.group(1)), clean(f.group(2))])
            elif line.startswith('- '):
                w = weapon(line[2:])
                if w:
                    weapons.append(w)
        ab = re.search(r'^\*\*Abilities:\*\*\s*(.*)$', body, re.M)
        if ab:
            ship['ab'] = []
            for piece in split_top(clean(ab.group(1)), ';'):
                a = re.match(r'^([^(]+?)\s*\((.*)\)\s*\.?$', piece, re.S)
                ship['ab'].append([a.group(1), a.group(2)] if a else [piece, ''])
        ship['info'] = info
        if weapons:
            ship['w'] = weapons
        out.append(ship)
    return out


def main():
    ships = []
    if os.path.isfile(CORE):
        ships += parse(CORE, False)
    else:
        print('vault Starship Profiles not found at', CORE)
    if os.path.isdir(HB):
        for fn in sorted(os.listdir(HB)):
            if fn.endswith('.md') and not fn.startswith('_'):
                ships += parse(os.path.join(HB, fn), True)
    order = {g: i for i, g in enumerate(GROUPS)}
    ships.sort(key=lambda s: (order.get(s['grp'], 99), s['sil'], s['n'].lower()))
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write('// GENERATED by tools/import-ships.py from the fad_core vault and homebrew/Ships — do not edit by hand.\n')
        f.write('const SHIPS = ' + json.dumps(ships, ensure_ascii=False, separators=(',', ':')) + ';\n')
    print('ships: %d (%d homebrew), %d KB' % (len(ships), sum(1 for s in ships if s.get('hb')), os.path.getsize(OUT) // 1024))


if __name__ == '__main__':
    main()
