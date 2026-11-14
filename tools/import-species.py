#!/usr/bin/env python3
"""Generate species.js (and img/species/) from the fad_core vault's Complete Species Guide.

    python3 tools/import-species.py [vault] [out.js]

Reads every note in "02 - Character Creation/Species/Complete Species Guide" and keeps only
what the table needs: the six characteristics, thresholds, starting XP, and the short ability
lines (base species and subspecies). The long lore sections (Physiology, Society, Homeworld,
...) stay in the vault on purpose: the site is public.

Each note's icon (the ![[KEY.png]] embed, found in the guide's images/ folder) is copied to
img/species/KEY.png. Stdlib only; never hand-edit species.js, re-run this instead.
"""
import json, os, re, shutil, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VAULT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'fad_core')
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, 'species.js')
GUIDE = os.path.join(VAULT, '02 - Character Creation', 'Species', 'Complete Species Guide')
IMG_OUT = os.path.join(os.path.dirname(OUT), 'img', 'species')

# same symbols as tools/import-rules.py, so species text reads like talent text
DICE = {'SU': '✸', 'AD': '▲', 'TR': '✪', 'FA': '✖', 'TH': '▼', 'DE': '⊗', 'LS': '○', 'DS': '●',
        'FO': '⬜', 'BO': '🟦', 'SB': '⬛', 'AB': '🟩', 'DI': '🟪', 'PR': '🟨', 'CH': '🟥'}
ATTRS = ['Brawn', 'Agility', 'Intellect', 'Cunning', 'Willpower', 'Presence']
BOILER = re.compile(r'\s*Skills may still not be trained above rank 2 during character creation\.?', re.I)


def clean(s):
    s = re.sub(r'<!--.*?-->', '', s)
    s = re.sub(r'\[\[[^\]|]*\\?\|([^\]]*)\]\]', r'\1', s)
    s = re.sub(r'\[\[#?([^\]]*)\]\]', r'\1', s)
    s = re.sub(r'\[([A-Z]{2})\]', lambda m: DICE.get(m.group(1), m.group(0)), s)
    s = s.replace('**', '').replace('*', '')
    s = BOILER.sub('', s)
    return re.sub(r'\s+', ' ', s).strip()


def bullets(lines):
    """'- **Name:** text' bullets, with nested '  - **option**' lines folded into the text."""
    out = []
    for ln in lines:
        m = re.match(r'^- \*\*(.+?):?\*\*:?\s*(.*)$', ln)
        if m:
            out.append([clean(m.group(1)).rstrip(':'), clean(m.group(2)), []])
        elif out and re.match(r'^\s+- ', ln):
            out[-1][2].append(clean(re.sub(r'^\s+- ', '', ln)))
        elif out and ln.strip() and not ln.startswith(('#', '|', '*', '>')):
            out[-1][1] = (out[-1][1] + ' ' + clean(ln)).strip()
    res = []
    for name, text, opts in out:
        if opts:
            text = (text + ' ' if text else '') + ' / '.join(opts)
        res.append([name, text])
    return res


def split_overrides(abilities):
    """Pull numeric overrides (thresholds, XP, characteristics) out of a subspecies' bullets."""
    over, rest = {}, []
    for name, text in abilities:
        low = name.lower()
        num = re.match(r'^(\d+)', text)
        if low == 'wound threshold' and num:
            over['wt'] = int(num.group(1))
        elif low == 'strain threshold' and num:
            over['st'] = int(num.group(1))
        elif low == 'starting xp' and num:
            over['xp'] = int(num.group(1))
        elif low == 'characteristics':
            a = {}
            for nm, v in re.findall(r'(Brawn|Agility|Intellect|Cunning|Willpower|Presence)\s*:?\s*(\d)', text):
                a[ATTRS.index(nm)] = int(v)
            if a:
                over['a'] = a
            else:
                rest.append([name, text])
        else:
            rest.append([name, text])
    return over, rest


def parse(path):
    text = open(path, encoding='utf-8').read()
    title = re.search(r'^# (.+)$', text, re.M)
    sec = re.search(r'^## Species Abilities\n(.*?)(?=^## (?!Subspecies)|\Z)', text, re.M | re.S)
    if not title or not sec:
        return None
    name = re.sub(r'\s*\(Complete Species Guide\)\s*$', '', title.group(1).strip())
    body = sec.group(1)
    base, _, subs = body.partition('\n## Subspecies')
    table = dict((k.strip(), v.strip()) for k, v in re.findall(r'^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|$', base, re.M))
    try:
        attrs = [int(table[a]) for a in ATTRS]
        wt = int(re.match(r'\d+', table['Wound Threshold']).group())
        st = int(re.match(r'\d+', table['Strain Threshold']).group())
        xp = int(re.match(r'\d+', table['Starting XP']).group())
    except (KeyError, AttributeError, ValueError):
        return None
    sp = {'n': name, 'a': attrs, 'wt': wt, 'st': st, 'xp': xp, 'ab': bullets(base.split('\n'))}
    img = re.search(r'!\[\[([^\]|]+\.png)', text)
    if img:
        sp['k'] = img.group(1)[:-4]
    sub_list = []
    for part in re.split(r'^### ', subs, flags=re.M)[1:]:
        lines = part.split('\n')
        over, rest = split_overrides(bullets(lines[1:]))
        entry = {'n': clean(lines[0]), 'ab': rest}
        if 'a' in over:                      # a subspecies lists only the characteristics it changes
            over['a'] = [over['a'].get(i, attrs[i]) for i in range(6)]
        entry.update(over)
        sub_list.append(entry)
    if sub_list:
        sp['sub'] = sub_list
    return sp


def main():
    if not os.path.isdir(GUIDE):
        sys.exit('Complete Species Guide not found at ' + GUIDE)
    species, skipped = [], []
    for fn in sorted(os.listdir(GUIDE)):
        if not fn.endswith('.md') or fn.startswith('_'):
            continue
        sp = parse(os.path.join(GUIDE, fn))
        (species.append(sp) if sp else skipped.append(fn))
    species.sort(key=lambda x: x['n'].lower())

    os.makedirs(IMG_OUT, exist_ok=True)
    copied, missing = 0, []
    keep = set()
    for sp in species:
        k = sp.get('k')
        src = os.path.join(GUIDE, 'images', (k or '') + '.png')
        if k and os.path.isfile(src):
            shutil.copyfile(src, os.path.join(IMG_OUT, k + '.png'))
            keep.add(k + '.png')
            copied += 1
        else:
            sp.pop('k', None)
            missing.append(sp['n'])
    for fn in os.listdir(IMG_OUT):          # drop icons whose species left the vault
        if fn.endswith('.png') and fn not in keep:
            os.remove(os.path.join(IMG_OUT, fn))

    body = json.dumps(species, ensure_ascii=False, separators=(',', ':'))
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write('// GENERATED by tools/import-species.py from the fad_core vault — do not edit by hand.\n')
        f.write('const SPECIES = ' + body + ';\n')
    print('species: %d (%d with subspecies), %d icons copied, %d KB' %
          (len(species), sum(1 for s in species if s.get('sub')), copied, os.path.getsize(OUT) // 1024))
    if skipped:
        print('skipped (no stat table):', ', '.join(skipped))
    if missing:
        print('no icon:', ', '.join(missing))


if __name__ == '__main__':
    main()
