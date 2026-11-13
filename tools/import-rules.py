#!/usr/bin/env python3
"""Build rules.js (talent trees, Force powers, signature abilities, talent effects) from the
Obsidian vault in fad_core/.

    python3 tools/import-rules.py            # reads ./fad_core, writes ./rules.js
    python3 tools/import-rules.py VAULT OUT

Every tree note carries a fenced ```yaml block whose first key is `specialization:`, `power:` or
`signature_ability:`, followed by one `- {id: ..., name: ..., cost: ..., connects: [...], effect: "..."}` line per
node. Talent effects come from "Talent Trees/Master Talent Catalog.md" and, for Core Rulebook
talents, "04 - Talents/Talent Descriptions.md".

rules.js is published on a public site, so effect text is kept SHORT: anything longer than
EFFECT_MAX characters is cut at a sentence end. To give a talent a hand-written one-liner instead,
add it to tools/talent-summaries.json as {"Talent Name": "summary"}.

Output (short keys, like items.js):
  Homebrew: notes in ./homebrew use the same format (trees anywhere under it, talents in
  homebrew/Talents.md) and come out flagged hb 1.

  RULES.trees[]  id · n name · k kind (spec|power|sig) · book · career · skills[] (spec) ·
                 fr Force rating needed (power) · basic text (power) · rows · nodes[]
  node           id · n name · c XP cost · x,y,w grid cell (4 columns wide; y 0 is the top row) ·
                 to[] connected node ids · root 1 if it can be bought first ·
                 t activation · f 1 Force talent · r 1 ranked · e effect (power upgrades only)
  RULES.talents  name -> { a activation, r 1 ranked, f 1 Force talent, e effect, core 1 }
"""
import itertools, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VAULT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'fad_core')
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, 'rules.js')
SUMMARIES = os.path.join(ROOT, 'tools', 'talent-summaries.json')
EFFECT_MAX = 240
HOMEBREW = os.path.join(ROOT, 'homebrew')   # the group's own trees and talents, same note format, tracked in the repo
SKIP_DIRS = ('_tmp_delete_me', '_tools', '.obsidian', '.trash')

DICE = {'SU': '✸', 'AD': '▲', 'TR': '✪', 'FA': '✖', 'TH': '▼', 'DE': '⊗', 'LS': '○', 'DS': '●',
        'FO': '⬜', 'BO': '🟦', 'SB': '⬛', 'AB': '🟩', 'DI': '🟪', 'PR': '🟨', 'CH': '🟥'}


def clean(s):
    s = re.sub(r'<!--.*?-->', '', s)
    s = re.sub(r'\[\[[^\]|]*\\?\|([^\]]*)\]\]', r'\1', s)
    s = re.sub(r'\[\[#?([^\]]*)\]\]', r'\1', s)
    s = re.sub(r'\[([A-Z]{2})\]', lambda m: DICE.get(m.group(1), m.group(0)), s)
    s = s.replace('**', '').replace('*', '')
    return re.sub(r'\s+', ' ', s).strip()


def short(s, n=EFFECT_MAX):
    s = clean(s)
    if len(s) <= n:
        return s
    out = ''
    for sent in re.split(r'(?<=[.!?])\s+', s):
        if out and len(out) + len(sent) + 1 > n:
            break
        out = (out + ' ' + sent).strip()
    if len(out) > n:
        out = out[:n].rsplit(' ', 1)[0]
    return out + ' …'


def slug(s):
    return re.sub(r'[^a-z0-9]+', '-', s.lower()).strip('-')


def frontmatter(text):
    m = re.match(r'---\n(.*?)\n---\n', text, re.S)
    fm = {}
    if m:
        for line in m.group(1).split('\n'):
            k, _, v = line.partition(':')
            fm[k.strip()] = v.strip().strip('"')
    return fm


def field(line, key):
    m = re.search(r'\b' + key + r': *("([^"]*)"|\[[^\]]*\]|[^,}]*(?:\([^)]*\))?[^,}]*)', line)
    if not m:
        return None
    return m.group(2) if m.group(2) is not None else m.group(1).strip()


def parse_nodes(block):
    nodes = []
    for line in block.split('\n'):
        if not line.strip().startswith('- {'):
            continue
        conn = field(line, 'connects') or '[]'
        nodes.append({
            'id': field(line, 'id'),
            'n': field(line, 'name'),
            'type': field(line, 'type') or '',
            'f': field(line, 'force_talent') == 'true',
            'r': field(line, 'ranked'),
            'c': int(field(line, 'cost') or 0),
            'e': field(line, 'effect') or '',
            'to': [x.strip() for x in conn.strip('[]').split(',') if x.strip()],
        })
    return nodes


def symmetrize(nodes, where):
    by = {n['id']: n for n in nodes}
    if len(by) != len(nodes):
        print('  ! duplicate node ids in', where)
    for n in nodes:
        for t in list(n['to']):
            if t not in by:
                print('  ! %s: %s connects to unknown %s' % (where, n['id'], t))
                n['to'].remove(t)
            elif n['id'] not in by[t]['to']:
                by[t]['to'].append(n['id'])
    return by


PLACEMENTS = {}
RC = re.compile(r'^(?:s\d+)?r(\d+)c(\d+)$')


def layout_grid(nodes, by, top):
    """Nodes carry r<row>c<col> ids. `top` is the id of a full-width box above the grid, or None."""
    occ = {}
    for n in nodes:
        m = RC.match(n['id'])
        if m:
            n['y'] = int(m.group(1)) - (0 if top else 1)
            n['x'] = int(m.group(2)) - 1
            n['w'] = 1
            occ[(n['y'], n['x'])] = n
    for n in nodes:
        if n['id'] == top:
            n['x'], n['y'], n['w'] = 0, 0, 4
        elif 'y' not in n:
            raise ValueError('no grid position for ' + n['id'])
    if top:   # a wide upgrade box uses the column of its left edge: stretch it under/over its neighbours
        for n in nodes:
            if n['id'] == top:
                continue
            while n['x'] + n['w'] < 4 and (n['y'], n['x'] + n['w']) not in occ and any(
                    by[t].get('y') in (n['y'] - 1, n['y'] + 1) and by[t]['id'] != top
                    and by[t]['x'] >= n['x'] + n['w'] for t in n['to']):
                n['w'] += 1


def layout_free(nodes, by, top):
    """Nodes with no grid ids (the Core Rulebook power notes): the book's layout is not recorded, so
    draw a tidy one — row = number of purchases from the basic power, column = under its parents."""
    depth = {top: 0}
    queue = [top]
    while queue:
        cur = queue.pop(0)
        for t in by[cur]['to']:
            if t not in depth:
                depth[t] = depth[cur] + 1
                queue.append(t)
    rest = [n for n in nodes if n['id'] != top]
    rows = [depth.get(n['id'], 1) for n in rest]
    by[top].update(x=0, y=0, w=4)
    groups = {}
    for n, r in zip(rest, rows):
        n['y'] = r
        groups.setdefault(r, []).append(n)
    for r, g in groups.items():   # start evenly spread
        if len(g) > 4:
            print('  ! more than 4 boxes in a row:', [n['id'] for n in g])
        for i, n in enumerate(g):
            n['x'], n['w'] = min(i, 3), 1

    def placements(k):
        if k not in PLACEMENTS:
            out = []
            for widths in itertools.product((1, 2, 3, 4), repeat=k):
                if sum(widths) > 4:
                    continue
                for gaps in itertools.product(range(0, 5 - sum(widths)), repeat=k):
                    x, cells = 0, []
                    for w, gp in zip(widths, gaps):
                        x += gp
                        cells.append((x, w))
                        x += w
                    if x <= 4:
                        out.append(cells)
            PLACEMENTS[k] = out
        return PLACEMENTS[k]

    for _ in range(4):
        for r in sorted(groups):
            g = groups[r][:4]
            best, best_score = None, None
            for cells in placements(len(g)):
                score = 0
                for n, (x, w) in zip(g, cells):
                    centre = x + w / 2
                    for t in n['to']:
                        o = by[t]
                        if o['id'] == top or o['y'] == r:
                            continue
                        oc = o['x'] + o['w'] / 2
                        score += max(0, abs(centre - oc) - (w - 1) / 2) ** 2
                    score += 0.3 * (w - 1)
                score += 0.05 * sum(x for x, w in cells)
                if best_score is None or score < best_score - 1e-9:
                    best, best_score = cells, score
            for n, (x, w) in zip(g, best):
                n['x'], n['w'] = x, w


def talent_entries(path, start=None):
    text = open(path, encoding='utf-8').read()
    if start and start in text:
        text = text[text.index(start):]
    out = {}
    for part in re.split(r'^### ', text, flags=re.M)[1:]:
        head, _, body = part.partition('\n')
        body = re.split(r'^## ', body, flags=re.M)[0]
        get = lambda k: (re.search(r'\*\*' + k + r'\*\*: *(.*)', body) or [None, None])[1]
        out[head.strip()] = {'a': get('Activation'), 'r': get('Ranked'), 'f': get('Force talent'),
                                   'e': get('Effect'), 'src': get('Source')}
    return out


def creation_data():
    """Species and careers for guided character creation, from '02 - Character Creation'."""
    base = os.path.join(VAULT, '02 - Character Creation')
    keys = {'Brawn': 'br', 'Agility': 'ag', 'Intellect': 'int', 'Cunning': 'cun', 'Willpower': 'wil', 'Presence': 'pr'}
    species, careers = [], []
    sdir = os.path.join(base, 'Species')
    for fn in sorted(os.listdir(sdir)) if os.path.isdir(sdir) else []:
        if not fn.endswith('.md'):
            continue
        text = open(os.path.join(sdir, fn), encoding='utf-8').read()
        if '## Species Abilities' not in text:
            continue
        sec = text.split('## Species Abilities', 1)[1].split('\n## ', 1)[0]
        row = lambda k: (re.search(r'\| *' + k + r' *\| *(\d+)', sec) or [0, 0])[1]
        sp = {'n': fn[:-3], 'attr': {v: int(row(k)) for k, v in keys.items()},
              'wt': int(row('Wound Threshold')), 'st': int(row('Strain Threshold')), 'xp': int(row('Starting XP')), 'ab': []}
        for m in re.finditer(r'^- \*\*(.+?):\*\* *(.+)', sec, re.M):
            name, body = m.group(1), m.group(2)
            if name == 'Starting Skill Ranks':
                links = [clean(x) for x in re.findall(r'\[\[[^\]]*\]\]', body)]
                if 'non-career' in body:
                    sp['free'] = {'n': 2, 'of': 'noncareer'}
                elif links:
                    sp['free'] = {'n': 1 if 'either' in body else len(links), 'of': links}
            sp['ab'].append({'n': name, 'e': short(body, 320)})
        species.append(sp)
    cdir = os.path.join(base, 'Careers')
    for name in sorted(os.listdir(cdir)) if os.path.isdir(cdir) else []:
        path = os.path.join(cdir, name, name + ' Overview.md')
        if not os.path.exists(path):
            continue
        text = open(path, encoding='utf-8').read()
        sk = re.search(r'## Career Skills\s*\n+(.+)', text)
        specs = re.findall(r'^- \[\[([^\]|]+)', text.split('## Specializations', 1)[1].split('\n## ', 1)[0], re.M) if '## Specializations' in text else []
        careers.append({'n': name, 'skills': [x.strip() for x in clean(sk.group(1)).split(',')] if sk else [],
                        'specs': specs, 'free': 3, 'fr': 1 if 'Force rating 1' in text else 0})
    return species, careers


def main():
    trees, seen = [], {}
    sources = [(VAULT, False)] + ([(HOMEBREW, True)] if os.path.isdir(HOMEBREW) else [])
    walk = ((base, hb, w) for base, hb in sources for w in os.walk(base))
    for base, hb, (dirpath, dirs, files) in walk:
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
        for fn in sorted(files):
            if not fn.endswith('.md'):
                continue
            path = os.path.join(dirpath, fn)
            text = open(path, encoding='utf-8').read()
            if '```yaml' not in text:
                continue
            fm = frontmatter(text)
            rel = os.path.relpath(path, base)
            core = not hb and not rel.startswith('Talent Trees')
            for m in re.finditer(r'```yaml\n(.*?)```', text, re.S):
                block = m.group(1)
                head = block.split('\n', 1)[0]
                kind_key, _, name = head.partition(':')
                name = name.strip().strip('"')
                kind = {'specialization': 'spec', 'power': 'power', 'signature_ability': 'sig'}.get(kind_key.strip())
                if not kind:
                    continue
                nodes = parse_nodes(block)
                by = symmetrize(nodes, rel)
                tree = {'k': kind, 'book': fm.get('book') or ('Force and Destiny' if core or kind == 'power' else '')}
                if kind == 'spec':
                    tree['n'] = re.sub(r' - [^-]+$', '', name)
                    tree['career'] = fm.get('career', '')
                    sk = re.search(r'\*\*Additional career skills:\*\* *(.+)', text) or \
                        re.search(r'## Additional Career Skills\s*\n+(.+)', text)
                    tree['skills'] = [s.strip() for s in clean(sk.group(1)).split(',')] if sk else []
                    layout_grid(nodes, by, None)
                    for n in nodes:
                        if n['y'] == 0:
                            n['root'] = 1
                elif kind == 'power':
                    tree['n'] = name
                    tree['book'] = 'Force Powers'
                    pre = re.search(r'Force Rating (\d+)', fm.get('prerequisite', '') or text[:1500])
                    tree['fr'] = int(pre.group(1)) if pre else 1
                    basic = re.search(r'\*\*Basic Power:\*\* *(.+)', text)
                    if basic:
                        basic = basic.group(1)
                    elif '## Basic Power' in text:
                        basic = text.split('## Basic Power', 1)[1].split('\n## ', 1)[0].replace('\n- ', ' ')
                    tree['basic'] = short(by['basic'].get('e') or basic or '', 760)
                    if all(RC.match(n['id']) for n in nodes if n['id'] != 'basic'):
                        layout_grid(nodes, by, 'basic')
                    else:
                        layout_free(nodes, by, 'basic')
                    by['basic']['root'] = 1
                    ups = {}   # "## Upgrades" bullets of the Core Rulebook notes: "- **Control — hurl:** text"
                    for u in re.finditer(r'^- \*\*([^*]+?):?\*\*:? *(.+)', text, re.M):
                        ups[u.group(1).strip().rstrip(':').lower()] = u.group(2)
                    for n in nodes:
                        nm = n['n'].lower()
                        if n['id'] == 'basic':
                            n['e'] = ''
                            continue
                        if n['e']:   # the node's own effect: wins over the prose bullets
                            n['e'] = short(n['e'], 460)
                            continue
                        hit = ups.get(nm)
                        if not hit:
                            base, _, par = nm.partition(' (')
                            words = set(re.findall(r'[a-z]+', par))
                            for key, val in ups.items():
                                kb, _, ks = re.sub(r'\s*[—–-]\s*', '|', key, 1).partition('|')
                                if kb == base and ks and set(re.findall(r'[a-z]+', ks)) & words:
                                    hit = val
                                    break
                        if hit:
                            n['e'] = short(hit)
                else:
                    tree['n'] = name
                    tree['career'] = fm.get('career', '')
                    top = next(n['id'] for n in nodes if not RC.match(n['id']))
                    layout_grid(nodes, by, top)
                    by[top]['root'] = 1
                    for n in nodes:
                        n['e'] = short(n['e'], 700 if n['id'] == top else 460) if n['e'] else ''
                tree['id'] = slug(('sig ' if kind == 'sig' else 'fp ' if kind == 'power' else '') + tree['n'] +
                                  (' ' + tree['career'] if kind == 'spec' and not core else ''))
                if tree['id'] in seen:
                    print('  ! duplicate tree id', tree['id'], '-', rel, 'and', seen[tree['id']])
                    continue
                seen[tree['id']] = rel
                if hb:
                    tree['hb'] = 1
                    if kind != 'power':
                        tree['book'] = 'Homebrew'
                tree['rows'] = max(n['y'] for n in nodes) + 1
                tree['nodes'] = []
                for n in nodes:
                    o = {'id': n['id'], 'n': n['n'], 'c': n['c'], 'x': n['x'], 'y': n['y'], 'w': n['w'], 'to': n['to']}
                    if n.get('root'):
                        o['root'] = 1
                    if kind == 'spec':
                        o['t'] = n['type']
                        if n['f']:
                            o['f'] = 1
                    if n.get('e'):
                        o['e'] = n['e']
                    tree['nodes'].append(o)
                trees.append(tree)

    summaries = json.load(open(SUMMARIES, encoding='utf-8')) if os.path.exists(SUMMARIES) else {}
    core = talent_entries(os.path.join(VAULT, '04 - Talents', 'Talent Descriptions.md'), '## Talent List')
    cat = talent_entries(os.path.join(VAULT, 'Talent Trees', 'Master Talent Catalog.md'))
    hb_path = os.path.join(HOMEBREW, 'Talents.md')   # homebrew talents: same '### Name' entries; they win over the books
    hb_tal = talent_entries(hb_path) if os.path.exists(hb_path) else {}
    cat.update(hb_tal)
    for name in hb_tal:
        core.pop(name, None)
    talents = {}
    for name in sorted(set(core) | set(cat)):
        c, k = core.get(name), cat.get(name, {})
        src = c or k
        eff = summaries.get(name) or (c or {}).get('e') or k.get('e') or ''
        eff = re.sub(r'^Force talent\.\s*', '', eff)
        t = {'a': src.get('a') or k.get('a') or '', 'e': short(eff)}
        if (src.get('r') or k.get('r') or '').lower().startswith('y'):
            t['r'] = 1
        if (src.get('f') or k.get('f') or '').lower().startswith('y'):
            t['f'] = 1
        if c:
            t['core'] = 1
        if name in hb_tal:
            t['hb'] = 1
        talents[name] = t

    missing = sorted({n['n'] for t in trees if t['k'] == 'spec' for n in t['nodes'] if n['n'] not in talents})
    for t in trees:   # a talent is a Force talent / ranked if any tree marks it so
        if t['k'] == 'spec':
            for n in t['nodes']:
                if n.get('f') and n['n'] in talents:
                    talents[n['n']]['f'] = 1
    if missing:
        print('  ! %d tree talents have no catalog entry: %s' % (len(missing), ', '.join(missing[:25])))

    order = {'spec': 0, 'sig': 1, 'power': 2}
    trees.sort(key=lambda t: (order[t['k']], t['book'], t.get('career', ''), t['n']))
    species, careers = creation_data()
    body = json.dumps({'trees': trees, 'talents': talents, 'species': species, 'careers': careers}, ensure_ascii=False, separators=(',', ':'))
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write('// GENERATED by tools/import-rules.py from the fad_core vault — do not edit by hand.\n')
        f.write('const RULES = ' + body + ';\n')
    print('creation: %d species, %d careers' % (len(species), len(careers)))
    kinds = {k: sum(1 for t in trees if t['k'] == k) for k in order}
    print('rules.js: %d specializations, %d signature abilities, %d Force powers, %d talents, %d KB' % (
        kinds['spec'], kinds['sig'], kinds['power'], len(talents), os.path.getsize(OUT) // 1024))


if __name__ == '__main__':
    main()
