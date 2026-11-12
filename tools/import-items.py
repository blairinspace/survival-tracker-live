#!/usr/bin/env python3
"""Turn the "Star Wars RPG - Item List" workbook into items.js for the Items tab.

    ./tools/import-items.py "/path/to/Star Wars RPG - Item List.xlsx"   # writes ./items.js

Standard library only (the .xlsx is read as zipped XML), so it runs on a stock Mac.
The workbook stays the source of truth: edit it, re-run this, redeploy.

Layout it expects (what the workbook has today):
  * an "Overview" sheet listing Category / Detail / Item Count for every item sheet,
    in sheet order — that gives the group and sub-category labels;
  * every other sheet: a "< Back to Main Menu >" row, a header row, then one item
    per row, in one of four column layouts (armour, weapon, gear, modification).
Each item becomes a compact record with short keys (see RECORD below).
"""
import json, re, sys, zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

NS = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main',
      'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}

RECORD = """
  n   name                 g  group (Armour, Ranged Weapons, …)   c  sub-category (sheet)
  p   price (number)       pt price text when it isn't a plain number ("1-5", "20,000+")
  r   1 = restricted       ra rarity (number)   rat rarity text when odd ("3 (Arbooine)")
  e   encumbrance          hp hard points
  armour:  def soak        weapon: sk dam crit rng q (qualities)
  gear:    f (features)    mod:    req (other requirement) f (features)
"""

# Overview "Category" → the label the tab shows (and the key the tracker maps to inventory types)
GROUP_LABEL = {
    'Armour': 'Armour', 'Ranged Weapon': 'Ranged Weapons', 'Melee Weapons': 'Melee Weapons',
    'Lightsabers': 'Lightsabers', 'Gear': 'Gear', 'Modifications': 'Modifications',
}
# header name → record key
KEYS = {'Price': 'p', 'Rare': 'ra', 'Enc': 'e', 'HP': 'hp', 'Defense': 'def', 'Soak': 'soak',
        'Skill': 'sk', 'Dam': 'dam', 'Crit': 'crit', 'Range': 'rng', 'Qualities': 'q',
        'Features': 'f', 'Other Req': 'req'}
NUMERIC = {'p', 'ra', 'e', 'hp', 'def', 'soak', 'dam', 'crit'}
NAME_HEADERS = {'Armour', 'Weapon', 'Gear', 'Drug', 'Toxins', 'Games', 'Modification'}


def load(path):
    z = zipfile.ZipFile(path)
    strings = [''.join(t.text or '' for t in si.iter('{%s}t' % NS['m']))
               for si in ET.fromstring(z.read('xl/sharedStrings.xml')).findall('m:si', NS)]
    rels = {r.get('Id'): r.get('Target')
            for r in ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))}
    wb = ET.fromstring(z.read('xl/workbook.xml'))

    def col(ref):
        n = 0
        for ch in re.match(r'[A-Z]+', ref).group(0):
            n = n * 26 + ord(ch) - 64
        return n - 1

    def rows(target):
        out = []
        for row in ET.fromstring(z.read('xl/' + target.lstrip('/').removeprefix('xl/'))).iter('{%s}row' % NS['m']):
            cells = {}
            for c in row.findall('m:c', NS):
                t, v, inl = c.get('t'), c.find('m:v', NS), c.find('m:is', NS)
                if t == 's' and v is not None: val = strings[int(v.text)]
                elif t == 'inlineStr' and inl is not None: val = ''.join(x.text or '' for x in inl.iter('{%s}t' % NS['m']))
                elif v is not None: val = v.text or ''
                else: val = ''
                val = re.sub(r'\s+', ' ', str(val)).strip()   # also folds the odd non-breaking space
                if val: cells[col(c.get('r'))] = val
            if cells: out.append([cells.get(i, '') for i in range(max(cells) + 1)])
        return out

    return [(sh.get('name'), rows(rels[sh.get('{%s}id' % NS['r'])])) for sh in wb.find('m:sheets', NS)]


def num(s):
    """'2.0' → 2, '12.5' → 12.5; anything else → None."""
    m = re.fullmatch(r'-?\d+(?:\.\d+)?', s or '')
    if not m: return None
    f = float(s)
    return int(f) if f == int(f) else f


def convert(sheets):
    overview = next(r for n, r in sheets if n == 'Overview')
    index = [r for r in overview[1:] if len(r) >= 3 and r[0] != 'Category']   # Category, Detail, Count
    item_sheets = [(n, r) for n, r in sheets if n != 'Overview']
    if len(index) != len(item_sheets):
        sys.exit(f'Overview lists {len(index)} sheets but the workbook has {len(item_sheets)} item sheets')

    items, groups, report = [], [], []
    for (cat, detail, count, *_), (sheet, rows) in zip(index, item_sheets):
        group = GROUP_LABEL.get(re.sub(r'\s+', ' ', cat).strip(), cat)
        sub = detail if detail not in ('', '-') else group
        if not any(g['g'] == group for g in groups): groups.append({'g': group, 'subs': []})
        next(g for g in groups if g['g'] == group)['subs'].append(sub)

        body = rows[1:] if rows and rows[0] and rows[0][0].startswith('<') else rows
        header, data = body[0], body[1:]
        if header[0] not in NAME_HEADERS:
            sys.exit(f'{sheet}: unexpected header row {header}')
        n_before = len(items)
        for row in data:
            rec = {'n': row[0], 'g': group, 'c': sub}
            for h, val in zip(header[1:], row[1:]):
                key = KEYS.get(h)
                if key is None: sys.exit(f'{sheet}: unknown column {h!r}')
                if not val or val in ('-', 'N/A'): continue
                if key == 'p':
                    restricted = '(R)' in val
                    clean = val.replace('(R)', '').replace(',', '').strip()
                    if restricted: rec['r'] = 1
                    if num(clean) is not None: rec['p'] = num(clean)
                    else: rec['pt'] = clean
                elif key in NUMERIC:
                    if num(val) is not None: rec[key] = num(val)
                    elif key == 'ra':
                        m = re.match(r'(\d+)', val); rec['ra'] = int(m.group(1)) if m else None; rec['rat'] = val
                        if rec['ra'] is None: del rec['ra']
                    else: rec[key + 't'] = val          # e.g. et:'1-5' for a range of encumbrance
                else:
                    rec[key] = val
            items.append(rec)
        got = len(items) - n_before
        flag = '' if str(got) == str(num(count)) else f'   <-- Overview says {count}'
        report.append(f'  {sheet:<22} {group:<16} {sub:<20} {got:>4}{flag}')
    return items, groups, report


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    src = Path(sys.argv[1]).expanduser()
    out = Path(__file__).resolve().parent.parent / 'items.js'
    items, groups, report = convert(load(src))
    body = ',\n'.join(json.dumps(it, ensure_ascii=False, separators=(',', ':')) for it in items)
    out.write_text(
        f'// GENERATED by tools/import-items.py from "{src.name}" — do not edit; re-run the importer.\n'
        f'// {len(items)} items. Record keys:' + ''.join('\n//' + l for l in RECORD.rstrip().split('\n')) + '\n'
        f'const ITEM_GROUPS = {json.dumps(groups, ensure_ascii=False)};\n'
        f'const ITEMS = [\n{body}\n];\n', encoding='utf-8')
    print('\n'.join(report))
    print(f'\n{len(items)} items in {len(groups)} groups → {out}')


if __name__ == '__main__':
    main()
