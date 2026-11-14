#!/usr/bin/env python3
"""Build lore.js (the Lore tab) from the campaign vault in lore_book/Through Darkness.

    python3 tools/import-lore.py            # reads ./lore_book/Through Darkness, writes ./lore.js

lore.js is PUBLIC (the tracker is a public site), so this importer is also the privacy filter:
  * the Archive (verbatim session logs), Inbox, Templates, tools and the Vault Guide are never exported
  * `player` and `real_dates` properties are dropped
  * players' real names and Discord handles (read from the Vault Guide's "Who's who" table) are
    replaced wherever they appear, and the run FAILS if any of them survives in the output
Links to notes that are not exported become plain text.

Output:  LORE = { home, sections[] { n, groups[] { n, ids[] } }, notes{ id: { t title, type, sec, grp,
                  fm{…}, h html, back[] ids that link here } } }
"""
import html, json, os, re, shutil, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VAULT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'lore_book', 'Through Darkness')
OUT = os.path.join(ROOT, 'lore.js')
IMG_OUT = os.path.join(ROOT, 'img', 'lore')
SKIP_DIRS = {'Archive', 'Inbox', 'Templates', '_tools', '_attachments', '.obsidian', '.trash'}
SKIP_FILES = {'Vault Guide.md'}
DROP_KEYS = {'player', 'real_dates', 'cssclasses', 'tags', 'aliases'}
ALLOWED_TAGS = 'p|ul|ol|li|strong|em|b|i|br|table|thead|tbody|tr|th|td|colgroup|col'


def slug(s):
    return re.sub(r'[^a-z0-9]+', '-', s.lower()).strip('-') or 'note'


def parse_frontmatter(text):
    m = re.match(r'---\n(.*?)\n---\n?', text, re.S)
    if not m:
        return {}, text
    fm = {}
    for line in m.group(1).split('\n'):
        if not line.strip() or line.startswith(' ') or ':' not in line:
            continue
        k, _, v = line.partition(':')
        v = v.strip()
        if v.startswith('[') and v.endswith(']') and not v.startswith('[['):
            v = [x.strip().strip('"\'') for x in re.findall(r'"[^"]*"|\'[^\']*\'|[^,\[\]]+', v[1:-1]) if x.strip()]
        else:
            v = v.strip('"\'').replace('\\"', '"')
        fm[k.strip()] = v
    return fm, text[m.end():]


def who_is_who():
    """Real names and handles from the Vault Guide table → what to call them in public."""
    path = os.path.join(VAULT, 'Vault Guide.md')
    subs = {}
    if not os.path.exists(path):
        return subs
    text = open(path, encoding='utf-8').read()
    if "Who's who" not in text:
        return subs
    for line in text.split("Who's who", 1)[1].split('\n'):
        cells = [c.strip() for c in line.strip().strip('|').split('|')]
        if len(cells) < 3 or set(cells[0]) <= set('-: ') or cells[0].lower().startswith('discord'):
            continue
        handle, player, chars = cells[0], cells[1], cells[2]
        names = re.findall(r'\[\[([^\]|]+)', chars)
        gm = 'GM' in player or 'GM' in chars
        label = 'the GM' if gm else (' and '.join(names) + "'s player" if names else 'a player')
        for raw in (handle, re.sub(r'\(.*?\)', '', player)):
            raw = raw.strip()
            if raw and raw != '—' and len(raw) > 2:
                subs[raw] = label
    return subs


class Converter:
    def __init__(self, ids, scrub):
        self.ids = ids          # basename (lower) -> id
        self.scrub = scrub
        self.links = set()

    def clean(self, s):
        for raw, label in self.scrub.items():
            s = re.sub(r'(?i)\b' + re.escape(raw) + r'\b(\s*\([^)]*\))?', label, s)
        return s

    def link(self, target, text=None):
        note, _, head = target.partition('#')
        note = note.strip()
        shown = (text or (head if not note else note)).strip()
        nid = self.ids.get(note.lower())
        if not nid:
            return html.escape(shown)
        self.links.add(nid)
        return '<a class="ll" onclick="loreGo(\'%s\')">%s</a>' % (nid, html.escape(shown))

    def inline(self, s):
        s = self.clean(s)
        keep = []

        def stash(x):
            keep.append(x)
            return '\x00%d\x00' % (len(keep) - 1)

        s = re.sub(r'!\[\[([^\]|#]+\.(?:png|jpg|jpeg|webp|gif))(?:\|(\d+))?\]\]', lambda m: stash(self.image(m.group(1), m.group(2))), s)
        s = re.sub(r'!\[\[([^\]]+)\]\]', lambda m: stash('<span class="lsee">see ' + self.link(m.group(1).split('|')[0]) + '</span>'), s)
        s = re.sub(r'\[\[([^\]|]+)(?:\\?\|([^\]]*))?\]\]', lambda m: stash(self.link(m.group(1), m.group(2))), s)
        s = re.sub(r'\[([^\]]+)\]\((https?://[^)\s]+)\)', lambda m: stash('<a href="%s" target="_blank" rel="noopener">%s</a>' % (html.escape(m.group(2)), html.escape(m.group(1)))), s)
        s = re.sub(r'`([^`]+)`', lambda m: stash('<code>' + html.escape(m.group(1)) + '</code>'), s)
        s = re.sub(r'</?(?:%s)(?:\s[^<>]*)?>' % ALLOWED_TAGS, lambda m: stash(re.sub(r'\s(on\w+|style|class|id)\s*=\s*("[^"]*"|\'[^\']*\'|\S+)', '', m.group(0))), s)
        s = html.escape(s, quote=False)
        s = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', s)
        s = re.sub(r'(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])', r'<i>\1</i>', s)
        s = re.sub(r'==(.+?)==', r'<mark>\1</mark>', s)
        s = re.sub(r'~~(.+?)~~', r'<s>\1</s>', s)
        return re.sub(r'\x00(\d+)\x00', lambda m: keep[int(m.group(1))], s)

    def image(self, name, width):
        src = os.path.join(VAULT, '_attachments', name)
        if not os.path.exists(src):
            return ''
        os.makedirs(IMG_OUT, exist_ok=True)
        out = slug(os.path.splitext(name)[0]) + os.path.splitext(name)[1].lower()
        shutil.copyfile(src, os.path.join(IMG_OUT, out))
        return '<img class="limg" src="img/lore/%s" alt="%s" style="max-width:min(100%%,%spx)">' % (out, html.escape(name), width or 480)

    def blocks(self, text, notes_meta=None):
        lines = text.replace('\r', '').split('\n')
        out, i = [], 0

        def flush_para(buf):
            if buf:
                out.append('<p>' + '<br>'.join(self.inline(x) for x in buf) + '</p>')
                buf.clear()

        para = []
        while i < len(lines):
            line = lines[i]
            st = line.strip()
            if st.startswith('```'):
                flush_para(para)
                lang = st[3:].strip()
                j = i + 1
                body = []
                while j < len(lines) and not lines[j].strip().startswith('```'):
                    body.append(lines[j])
                    j += 1
                i = j + 1
                if lang == 'base':
                    out.append(self.base(body, notes_meta))
                elif lang not in ('dataview', 'dataviewjs'):
                    out.append('<pre>' + html.escape(self.clean('\n'.join(body))) + '</pre>')
                continue
            if not st:
                flush_para(para)
                i += 1
                continue
            if re.match(r'^(-{3,}|\*{3,})$', st):
                flush_para(para)
                out.append('<hr>')
                i += 1
                continue
            m = re.match(r'^(#{1,6})\s+(.*)', st)
            if m:
                flush_para(para)
                lvl = min(5, len(m.group(1)) + 1)
                out.append('<h%d>%s</h%d>' % (lvl, self.inline(m.group(2)), lvl))
                i += 1
                continue
            if st.startswith('>'):
                flush_para(para)
                q = []
                while i < len(lines) and lines[i].strip().startswith('>'):
                    q.append(re.sub(r'^\s*>\s?', '', lines[i]))
                    i += 1
                cm = re.match(r'\[!(\w+)\][+-]?\s*(.*)', q[0]) if q else None
                if cm:
                    title = self.inline(cm.group(2)) if cm.group(2) else cm.group(1).capitalize()
                    out.append('<div class="callout c-%s"><div class="ct">%s</div>%s</div>' % (cm.group(1).lower(), title, self.blocks('\n'.join(q[1:]), notes_meta)))
                else:
                    out.append('<blockquote>' + self.blocks('\n'.join(q), notes_meta) + '</blockquote>')
                continue
            if st.startswith('|') and i + 1 < len(lines) and re.match(r'^\s*\|?\s*:?-{2,}', lines[i + 1]):
                flush_para(para)
                rows = []
                while i < len(lines) and lines[i].strip().startswith('|'):
                    cells = [c.replace('\x01', '|').strip() for c in lines[i].strip().replace('\\|', '\x01').strip('|').split('|')]
                    rows.append(cells)
                    i += 1
                head, body = rows[0], rows[2:]
                out.append('<table><tr>' + ''.join('<th>%s</th>' % self.inline(c) for c in head) + '</tr>' +
                           ''.join('<tr>' + ''.join('<td>%s</td>' % self.inline(c) for c in r) + '</tr>' for r in body) + '</table>')
                continue
            lm = re.match(r'^(\s*)([-*+]|\d+[.)])\s+(.*)', line)
            if lm:
                flush_para(para)
                items = []
                while i < len(lines):
                    lm = re.match(r'^(\s*)([-*+]|\d+[.)])\s+(.*)', lines[i])
                    if lm:
                        items.append([len(lm.group(1).replace('\t', '  ')), lm.group(2)[0].isdigit(), lm.group(3)])
                        i += 1
                    elif lines[i].strip() and lines[i].startswith((' ', '\t')) and items:
                        items[-1][2] += ' ' + lines[i].strip()
                        i += 1
                    else:
                        break
                out.append(self.list_html(items))
                continue
            para.append(st)
            i += 1
        flush_para(para)
        return ''.join(out)

    def list_html(self, items):
        res, stack = [], []
        for indent, ordered, text in items:
            if text.strip() in ('', '-'):
                continue
            text = re.sub(r'^\[ \]\s*', '☐ ', text)
            text = re.sub(r'^\[[xX]\]\s*', '☑ ', text)
            while stack and indent < stack[-1][0]:
                res.append('</li></%s>' % stack.pop()[1])
            if not stack or indent > stack[-1][0]:
                tag = 'ol' if ordered else 'ul'
                res.append('<%s>' % tag)
                stack.append((indent, tag))
            else:
                res.append('</li>')
            res.append('<li>' + self.inline(text))
        while stack:
            res.append('</li></%s>' % stack.pop()[1])
        return ''.join(res)

    def base(self, body, notes_meta):
        """An Obsidian Base block: list the notes its filters match (properties compared as text)."""
        if not notes_meta:
            return ''
        exprs = [m.group(1) for m in (re.match(r"\s*-\s*'(.+)'\s*$", x) for x in body) if m]
        if not exprs:
            return ''

        def test(fm, expr):
            py = re.sub(r'\|\|', ' or ', expr)
            py = re.sub(r'&&', ' and ', py)
            py = re.sub(r'\b(?:note\.)?([A-Za-z_]+)\s*(==|!=)\s*"([^"]*)"', lambda m: '(F.get(%r,"") %s %r)' % (m.group(1), m.group(2), m.group(3)), py)
            if re.search(r'[^()\sFgetandor.,"\'=!\w-]', py) or 'F.get' not in py:
                raise ValueError(expr)
            return eval(py, {'__builtins__': {}}, {'F': fm})

        try:
            hits = [n for n in notes_meta if all(test(n['fm'], e) for e in exprs)]
        except Exception:
            return ''
        if not hits:
            return '<p class="lempty">Nothing here right now.</p>'
        hits.sort(key=lambda n: n['t'])
        rows = ''.join('<li>%s%s</li>' % (self.link(n['base']), (' <span class="lst s-%s">%s</span>' % (slug(str(n['fm'].get('status'))), html.escape(str(n['fm']['status']))) if n['fm'].get('status') else '')) for n in hits)
        return '<ul class="lbase">' + rows + '</ul>'


def main():
    scrub = who_is_who()
    files = []
    for dirpath, dirs, fns in os.walk(VAULT):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
        for fn in sorted(fns):
            if fn.endswith('.md') and fn not in SKIP_FILES:
                files.append(os.path.join(dirpath, fn))
    ids, metas = {}, []
    for path in files:
        base = os.path.basename(path)[:-3]
        fm, body = parse_frontmatter(open(path, encoding='utf-8').read())
        if fm.get('type') in ('archive', 'guide'):
            continue
        nid = slug(base)
        while nid in {m['id'] for m in metas}:
            nid += '-2'
        rel = os.path.relpath(path, VAULT).split(os.sep)
        strip = lambda s: re.sub(r'^\d+\s+', '', s)
        meta = {'id': nid, 'base': base, 't': base, 'fm': fm, 'body': body,
                'sec': strip(rel[0]) if len(rel) > 1 else '', 'grp': strip(rel[1]) if len(rel) > 2 else '', 'order': rel}
        ids[base.lower()] = nid
        for a in fm.get('aliases', []) if isinstance(fm.get('aliases'), list) else []:
            ids.setdefault(a.lower(), nid)
        metas.append(meta)

    notes, back = {}, {}
    for m in metas:
        cv = Converter(ids, scrub)
        body = re.sub(r'^\s*#\s+.*\n', '', m['body'], count=1)                               # the H1 repeats the title
        body = re.sub(r'(?m)^\s*(?:---\s*\n)?\*?Original log:?\*?:?.*$', '', body)           # points into the Archive
        h = cv.blocks(body, metas)
        fm = {}
        for k, v in m['fm'].items():
            if k in DROP_KEYS or k == 'type' or v in ('', [], None):
                continue
            vals = v if isinstance(v, list) else [v]
            fm[k] = ' · '.join(cv.inline(str(x)) for x in vals)
        notes[m['id']] = {'t': cv.clean(m['t']), 'type': str(m['fm'].get('type', '')), 'sec': m['sec'], 'grp': m['grp'], 'fm': fm, 'h': h}
        for target in cv.links:
            if target != m['id']:
                back.setdefault(target, []).append(m['id'])
    for nid, n in notes.items():
        if back.get(nid):
            n['back'] = sorted(set(back[nid]), key=lambda x: notes[x]['t'])

    sections, seen = [], {}
    for m in metas:
        if not m['sec']:
            continue
        sec = seen.get(m['sec'])
        if sec is None:
            sec = seen[m['sec']] = {'n': m['sec'], 'groups': []}
            sections.append(sec)
        grp = next((g for g in sec['groups'] if g['n'] == m['grp']), None)
        if grp is None:
            grp = {'n': m['grp'], 'ids': []}
            sec['groups'].append(grp)
        grp['ids'].append(m['id'])

    body = json.dumps({'home': ids.get('home', ''), 'sections': sections, 'notes': notes}, ensure_ascii=False, separators=(',', ':'))
    leaks = [raw for raw in scrub if re.search(r'(?i)\b' + re.escape(raw) + r'\b', body)]
    for marker in ('real_dates', 'Discord export', '"player"'):
        if marker in body:
            leaks.append(marker)
    if leaks:
        sys.exit('REFUSING to write lore.js — private text survived the filter: ' + ', '.join(leaks))
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write('// GENERATED by tools/import-lore.py from the campaign vault — do not edit by hand.\n')
        f.write('// Public file: the Archive, real names and Discord handles are filtered out by the importer.\n')
        f.write('const LORE = ' + body + ';\n')
    print('lore.js: %d notes in %d sections, %d KB · %d names/handles filtered · no private markers found' % (
        len(notes), len(sections), os.path.getsize(OUT) // 1024, len(scrub)))


if __name__ == '__main__':
    main()
