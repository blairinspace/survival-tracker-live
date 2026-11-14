#!/usr/bin/env python3
"""Generate adversaries.js from the fad_core vault's "12 - Adversaries" notes.

    python3 tools/import-adversaries.py [vault] [out.js]

Every "### Name [Minion|Rival|Nemesis]" section becomes one NPC template for the GM tab's
NPC builder: characteristics, soak, thresholds, defense, skills, talents, abilities, weapons
and gear. The descriptive paragraph is left in the vault, and talent / ability text longer
than TEXT_MAX is cut with a page reference (the site is public: short text only).

Stdlib only; never hand-edit adversaries.js, re-run this instead.
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VAULT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'fad_core')
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, 'adversaries.js')
SRC = os.path.join(VAULT, '12 - Adversaries')
TEXT_MAX = 240

DICE = {'SU': '✸', 'AD': '▲', 'TR': '✪', 'FA': '✖', 'TH': '▼', 'DE': '⊗', 'LS': '○', 'DS': '●',
        'FO': '⬜', 'BO': '🟦', 'SB': '⬛', 'AB': '🟩', 'DI': '🟪', 'PR': '🟨', 'CH': '🟥'}


def clean(s):
    s = re.sub(r'<!--.*?-->', '', s)
    s = re.sub(r'\[\[[^\]|]*\\?\|([^\]]*)\]\]', r'\1', s)
    s = re.sub(r'\[\[#?([^\]]*)\]\]', r'\1', s)
    s = re.sub(r'\[([A-Z]{2})\]', lambda m: DICE.get(m.group(1), m.group(0)), s)
    s = re.sub(r'\[([A-Za-z][A-Za-z ]*)\]', r'(\1)', s)        # Ranged [Heavy] → Ranged (Heavy)
    s = s.replace('**', '').replace('*', '')
    return re.sub(r'\s+', ' ', s).strip()


def split_top(s, seps):
    """Split on separator characters that are outside parentheses."""
    out, depth, cur = [], 0, ''
    for ch in s:
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth = max(0, depth - 1)
        if ch in seps and depth == 0:
            out.append(cur)
            cur = ''
        else:
            cur += ch
    out.append(cur)
    return [x.strip() for x in out if x.strip()]


def name_and_text(piece, page):
    """'Adversary 2 (upgrade ...)' → ['Adversary 2', 'upgrade ...'] with long text cut."""
    m = re.match(r'^([^(]+?)\s*\((.*)\)\s*\.?$', piece, re.S)
    name, text = (m.group(1).strip(), m.group(2).strip()) if m else (piece.strip(), '')
    if len(text) > TEXT_MAX:
        text = text[:TEXT_MAX].rsplit(' ', 1)[0].rstrip(',;:') + '… (Core Rulebook p.%s)' % page
    return [name, text]


def none(s):
    return s.strip().rstrip('.').lower() in ('', 'none', '—', '-')


def parse_equipment(s, page):
    weapons, gear = [], []
    for piece in split_top(s, ','):
        m = re.match(r'^([^(]+?)\s*\((.*)\)\s*\.?$', piece, re.S)
        if m and re.search(r'Damage\s*\+?\d', m.group(2)):
            parts = [p.strip() for p in m.group(2).split(';')]
            wname = m.group(1).strip()
            if '. ' in wname:                 # "extra reloads. Individuals may instead have …" — the first sentence is gear
                head, wname = wname.split('. ', 1)
                gear.append(head[:1].upper() + head[1:])
            w = {'n': wname[:1].upper() + wname[1:], 'sk': parts[0]}
            extra = []
            for p in parts[1:]:
                d = re.match(r'^Damage\s*(\+?\d+)$', p)
                c = re.match(r'^Critical\s*(\d+|[-—–])$', p)
                r = re.match(r'^Range\s*\(?([A-Za-z]+)\)?$', p)
                if d:
                    w['dam'] = d.group(1)
                elif c:
                    w['crit'] = c.group(1)
                elif r:
                    w['rng'] = r.group(1)
                else:
                    extra.append(p)
            q = '; '.join(extra)
            if len(q) > TEXT_MAX:
                q = q[:TEXT_MAX].rsplit(' ', 1)[0].rstrip(',;:') + '… (Core Rulebook p.%s)' % page
            if q:
                w['q'] = q
            weapons.append(w)
        else:
            gear.append(piece[:1].upper() + piece[1:])
    return weapons, ', '.join(gear)


def parse_file(path):
    text = open(path, encoding='utf-8').read()
    page = (re.search(r'^page:\s*(\d+)', text, re.M) or [None, '398'])[1]
    group = (re.search(r'^# (.+)$', text, re.M) or [None, os.path.basename(path)[:-3]])[1]
    group = re.sub(r'\s*\(Adversaries\)$', '', group.strip())
    out = []
    for m in re.finditer(r'^### (.+?) \[(Minion|Rival|Nemesis)\]\s*\n(.*?)(?=^#{1,3} |\Z)', text, re.M | re.S):
        body = m.group(3)
        row = re.search(r'^\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|', body, re.M)
        soak = re.search(r'\*\*Soak\*\*\s*(\d+)', body)
        wt = re.search(r'\*\*Wound threshold\*\*\s*(\d+)', body)
        st = re.search(r'\*\*Strain threshold\*\*\s*(\d+)', body)
        df = re.search(r'\*\*Defense[^*]*\*\*\s*(\d+)\s*/\s*(\d+)', body)
        if not (row and soak and wt):
            print('skipped (no stat strip):', m.group(1))
            continue
        adv = {'n': m.group(1).strip(), 'type': m.group(2).lower(), 'grp': group, 'pg': int(page),
               'a': [int(x) for x in row.groups()], 'soak': int(soak.group(1)), 'wt': int(wt.group(1)),
               'dm': int(df.group(1)) if df else 0, 'dr': int(df.group(2)) if df else 0}
        if st:
            adv['st'] = int(st.group(1))
        fields = {}
        for b in re.finditer(r'^- \*\*([^*:]+?)(?: \(group only\))?:\*\*\s*(.*)$', body, re.M):
            fields.setdefault(b.group(1).strip().lower(), []).append(clean(b.group(2)))
        skills = []
        for piece in split_top(', '.join(fields.get('skills', [])), ','):
            if none(piece):
                continue
            sm = re.match(r'^(.*?)\s+(\d+)$', piece.rstrip('.'))
            skills.append([sm.group(1), int(sm.group(2))] if sm else [piece.rstrip('.'), 0])
        if skills:
            adv['sk'] = skills
        for key, src in (('tal', 'talents'), ('ab', 'abilities')):
            items = [name_and_text(p, page) for line in fields.get(src, []) if not none(line) for p in split_top(line, ';')]
            if items:
                adv[key] = items
        weapons, gear = [], []
        for line in fields.get('equipment', []):
            if none(line):
                continue
            w, g = parse_equipment(line, page)
            weapons += w
            if g:
                gear.append(g)
        if weapons:
            adv['w'] = weapons
        if gear:
            adv['gear'] = ', '.join(gear)
        out.append(adv)
    return out


def main():
    if not os.path.isdir(SRC):
        sys.exit('Adversaries folder not found at ' + SRC)
    advs = []
    for fn in sorted(os.listdir(SRC)):
        if fn.endswith('.md') and not fn.startswith('_'):
            advs += parse_file(os.path.join(SRC, fn))
    body = json.dumps(advs, ensure_ascii=False, separators=(',', ':'))
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write('// GENERATED by tools/import-adversaries.py from the fad_core vault — do not edit by hand.\n')
        f.write('const ADVERSARIES = ' + body + ';\n')
    kinds = {}
    for a in advs:
        kinds[a['type']] = kinds.get(a['type'], 0) + 1
    print('adversaries: %d (%s), %d KB' % (len(advs), ', '.join('%d %s' % (v, k) for k, v in sorted(kinds.items())), os.path.getsize(OUT) // 1024))


if __name__ == '__main__':
    main()
