#!/usr/bin/env python3
"""
Explainer HTML Generator v2.0
Professional presentation pages with DESIGN.md token support.
"""
import json, html, argparse, shutil, subprocess, sys, re
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent

def load_design_tokens():
    try:
        import yaml
    except ImportError:
        return None
    for p in [SCRIPT_DIR / "DESIGN.md", SCRIPT_DIR.parent / "DESIGN.md"]:
        if p.exists():
            m = re.match(r'^---\n(.*?)\n---', p.read_text(), re.DOTALL)
            if m:
                try: return yaml.safe_load(m.group(1))
                except: pass
    return None

def get_css(tokens):
    c = (tokens or {}).get('colors', {})
    lc = c.get('light', {})
    el = (tokens or {}).get('elevation', {})
    r = (tokens or {}).get('radius', {})
    def cv(key, default): return c.get(key, default)
    def lv(key, default): return lc.get(key, default)

    return """
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;900&family=JetBrains+Mono:wght@400;500&display=swap');
    :root {
        --bg: """ + cv('background','#1a1a2e') + """; --surface: """ + cv('surface','#16213e') + """;
        --surface-el: """ + cv('surface-elevated','#1f3056') + """;
        --fg: """ + cv('foreground','#e8e6e3') + """; --fg-muted: """ + cv('foreground-muted','#a8a5a0') + """;
        --accent: """ + cv('accent','#4fc3f7') + """; --accent-hover: """ + cv('accent-hover','#81d4fa') + """;
        --accent-subtle: """ + cv('accent-subtle','rgba(79,195,247,0.08)') + """;
        --success: """ + cv('success','#66bb6a') + """; --warning: """ + cv('warning','#ffa726') + """; --error: """ + cv('error','#ef5350') + """;
        --shadow-sm: """ + el.get('sm','0 1px 3px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.08)') + """;
        --shadow-md: """ + el.get('md','0 4px 12px rgba(0,0,0,0.15), 0 2px 4px rgba(0,0,0,0.1)') + """;
        --shadow-lg: """ + el.get('lg','0 12px 40px rgba(0,0,0,0.2), 0 4px 12px rgba(0,0,0,0.1)') + """;
        --radius-sm: """ + str(r.get('sm',6)) + """px; --radius-md: """ + str(r.get('md',12)) + """px; --radius-lg: """ + str(r.get('lg',20)) + """px;
    }
    [data-theme="light"] {
        --bg: """ + lv('background','#faf8f5') + """; --surface: """ + lv('surface','#ffffff') + """;
        --surface-el: """ + lv('surface-elevated','#ffffff') + """;
        --fg: """ + lv('foreground','#1a1817') + """; --fg-muted: """ + lv('foreground-muted','#4d4a47') + """;
        --accent: """ + lv('accent','#0277bd') + """; --accent-hover: """ + lv('accent-hover','#01579b') + """;
        --accent-subtle: """ + lv('accent-subtle','rgba(2,119,189,0.06)') + """;
        --shadow-sm: 0 1px 3px rgba(0,0,0,0.06); --shadow-md: 0 4px 12px rgba(0,0,0,0.08);
        --shadow-lg: 0 12px 40px rgba(0,0,0,0.1);
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: 'Inter', system-ui, sans-serif; font-size: 16px; line-height: 1.7;
        background: var(--bg); color: var(--fg); -webkit-font-smoothing: antialiased; }
    .container { max-width: 900px; margin: 0 auto; padding: 48px 24px 96px; }
    .hero { text-align: center; padding: 96px 32px 80px; margin: -48px -24px 64px;
        background: linear-gradient(135deg, var(--surface) 0%, var(--bg) 100%);
        border-bottom: 1px solid var(--accent-subtle); position: relative; overflow: hidden; }
    .hero::before { content: ''; position: absolute; top: -50%; left: -50%; width: 200%; height: 200%;
        background: radial-gradient(circle at 30% 50%, var(--accent-subtle) 0%, transparent 50%); pointer-events: none; }
    .hero h1 { font-size: clamp(2.5rem, 5vw, 3.5rem); font-weight: 900; letter-spacing: -0.03em;
        line-height: 1.1; color: var(--fg); margin-bottom: 16px; position: relative; }
    .hero .subtitle { font-size: 1.25rem; color: var(--fg-muted); font-weight: 400;
        max-width: 600px; margin: 0 auto; line-height: 1.5; position: relative; }
    .hero .badge { display: inline-block; padding: 6px 16px; background: var(--accent-subtle);
        color: var(--accent); border-radius: 100px; font-size: 0.75rem; font-weight: 600;
        letter-spacing: 0.05em; text-transform: uppercase; margin-bottom: 24px; position: relative; }
    .section { margin-bottom: 64px; opacity: 0; transform: translateY(20px);
        animation: fadeUp 0.6s cubic-bezier(0, 0, 0.2, 1) forwards; }
    .section:nth-child(2) { animation-delay: 0.08s; }
    .section:nth-child(3) { animation-delay: 0.16s; }
    .section:nth-child(4) { animation-delay: 0.24s; }
    .section:nth-child(5) { animation-delay: 0.32s; }
    .section:nth-child(6) { animation-delay: 0.4s; }
    .section:nth-child(7) { animation-delay: 0.48s; }
    .section:nth-child(8) { animation-delay: 0.56s; }
    .section:nth-child(9) { animation-delay: 0.64s; }
    .section:nth-child(10) { animation-delay: 0.72s; }
    .section:nth-child(11) { animation-delay: 0.8s; }
    .section:nth-child(12) { animation-delay: 0.88s; }
    @keyframes fadeUp { to { opacity: 1; transform: translateY(0); } }
    h2 { font-size: 1.5rem; font-weight: 600; letter-spacing: -0.01em; line-height: 1.3; margin-bottom: 16px; }
    h3 { font-size: 1.125rem; font-weight: 600; margin-bottom: 12px; }
    p { color: var(--fg-muted); margin-bottom: 16px; line-height: 1.7; }
    p:last-child { margin-bottom: 0; }
    .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 24px; }
    .metric-card { background: var(--surface); border-radius: var(--radius-md); padding: 28px 20px;
        text-align: center; box-shadow: var(--shadow-sm); border-top: 3px solid var(--accent);
        transition: transform 0.3s cubic-bezier(0.4,0,0.2,1), box-shadow 0.3s cubic-bezier(0.4,0,0.2,1); }
    .metric-card:hover { transform: translateY(-3px); box-shadow: var(--shadow-md); }
    .metric-value { font-size: 2.25rem; font-weight: 900; letter-spacing: -0.02em; color: var(--accent); line-height: 1; margin-bottom: 8px; }
    .metric-label { font-size: 0.8rem; color: var(--fg-muted); font-weight: 500; text-transform: uppercase; letter-spacing: 0.05em; }
    .timeline { position: relative; padding-left: 48px; }
    .timeline::before { content: ''; position: absolute; left: 15px; top: 24px; bottom: 24px; width: 2px;
        background: linear-gradient(to bottom, var(--accent), var(--accent-subtle)); border-radius: 2px; }
    .timeline-item { position: relative; margin-bottom: 40px; padding: 20px 24px; background: var(--surface);
        border-radius: var(--radius-md); box-shadow: var(--shadow-sm);
        transition: transform 0.3s cubic-bezier(0.4,0,0.2,1), box-shadow 0.3s cubic-bezier(0.4,0,0.2,1); }
    .timeline-item:hover { transform: translateX(4px); box-shadow: var(--shadow-md); }
    .timeline-item:last-child { margin-bottom: 0; }
    .timeline-item::before { content: ''; position: absolute; left: -41px; top: 24px; width: 14px; height: 14px;
        border-radius: 50%; background: var(--bg); border: 3px solid var(--accent);
        box-shadow: 0 0 0 4px var(--accent-subtle), 0 0 12px var(--accent-subtle); }
    .timeline-item::after { content: ''; position: absolute; left: -27px; top: 30px; width: 18px; height: 2px;
        background: var(--accent-subtle); }
    .timeline-item h3 { font-size: 1rem; font-weight: 600; margin-bottom: 6px; color: var(--accent); }
    .timeline-item p { font-size: 0.9rem; color: var(--fg-muted); margin: 0; line-height: 1.6; }
    .comparison { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; }
    @media (max-width: 600px) { .comparison { grid-template-columns: 1fr; } }
    .comparison-col { background: var(--surface); border-radius: var(--radius-md); padding: 28px; box-shadow: var(--shadow-sm); }
    .comparison-col h3 { font-size: 0.8rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.08em;
        margin-bottom: 16px; padding-bottom: 12px; border-bottom: 2px solid var(--accent); }
    .comparison-col.negative h3 { border-color: var(--error); }
    .comparison-col ul { list-style: none; padding: 0; }
    .comparison-col li { padding: 8px 0 8px 20px; position: relative; font-size: 0.9rem; color: var(--fg-muted); }
    .comparison-col li::before { content: '\\2713'; position: absolute; left: 0; color: var(--success); font-weight: 700; }
    .comparison-col.negative li::before { content: '\\2717'; color: var(--error); }
    .code-block { position: relative; margin: 16px 0; border-radius: var(--radius-md); overflow: hidden; box-shadow: var(--shadow-sm); }
    .code-lang { position: absolute; top: 12px; right: 12px; background: var(--accent); color: #fff;
        padding: 3px 10px; border-radius: 100px; font-size: 0.7rem; font-weight: 600; letter-spacing: 0.03em; text-transform: uppercase; }
    pre { background: var(--surface); padding: 24px; overflow-x: auto; margin: 0; border: 1px solid var(--accent-subtle); border-radius: var(--radius-md); }
    code { font-family: 'JetBrains Mono', monospace; font-size: 0.85rem; color: var(--fg); line-height: 1.7; }
    code .kw { color: #c792ea; } code .str { color: #c3e88d; } code .num { color: #f78c6c; }
    code .cm { color: #546e7a; font-style: italic; } code .fn { color: #82aaff; }
    code .op { color: #89ddff; } code .type { color: #ffcb6b; } code .attr { color: #4fc3f7; }
    [data-theme="light"] code .kw { color: #7c4dff; } [data-theme="light"] code .str { color: #2e7d32; }
    [data-theme="light"] code .num { color: #e65100; } [data-theme="light"] code .cm { color: #90a4ae; }
    [data-theme="light"] code .fn { color: #1565c0; } [data-theme="light"] code .op { color: #0277bd; }
    [data-theme="light"] code .type { color: #f57f17; } [data-theme="light"] code .attr { color: #00838f; }
    table { width: 100%; border-collapse: collapse; margin: 16px 0; font-size: 0.9rem;
        border-radius: var(--radius-md); overflow: hidden; box-shadow: var(--shadow-sm); }
    th, td { padding: 14px 18px; text-align: left; }
    th { background: var(--surface-el); font-weight: 600; font-size: 0.8rem; text-transform: uppercase;
        letter-spacing: 0.05em; color: var(--fg-muted); border-bottom: 2px solid var(--accent-subtle); }
    td { background: var(--surface); border-bottom: 1px solid var(--accent-subtle); color: var(--fg-muted); }
    tr:last-child td { border-bottom: none; }
    tr:hover td { background: var(--accent-subtle); }
    .callout { padding: 20px 24px; border-radius: var(--radius-md); border-left: 4px solid;
        background: var(--surface); box-shadow: var(--shadow-sm); }
    .callout-info { border-color: var(--accent); }
    .callout-warning { border-color: var(--warning); }
    .callout-success { border-color: var(--success); }
    .callout-error { border-color: var(--error); }
    .callout p { margin: 0; font-size: 0.9rem; }
    ul, ol { padding-left: 24px; color: var(--fg-muted); }
    li { margin: 8px 0; line-height: 1.6; }
    .diagram-container { background: var(--surface); border-radius: var(--radius-lg); padding: 48px 32px;
        box-shadow: var(--shadow-md); text-align: center; border: 1px solid var(--accent-subtle); overflow-x: auto; }
    .diagram-container .mermaid { display: flex; justify-content: center; }
    .diagram-container .mermaid svg { max-width: 100%; height: auto; }
    pre.mermaid { background: none !important; border: none !important; padding: 0 !important; box-shadow: none !important; }
    .mermaid .node rect, .mermaid .node polygon { rx: 12; ry: 12; }
    .mermaid .edgeLabel { font-size: 12px; }
    .highlighted > rect, .highlighted > polygon { stroke-width: 3px !important; filter: drop-shadow(0 0 8px var(--accent)); }
    svg { max-width: 100%; height: auto; }
    pre.mermaid { background: none !important; border: none !important; padding: 0 !important; box-shadow: none !important; }
    .theme-toggle { position: fixed; top: 20px; right: 20px; background: var(--surface);
        border: 1px solid var(--accent-subtle); color: var(--fg); width: 40px; height: 40px;
        border-radius: 50%; cursor: pointer; font-size: 1.1rem; display: flex; align-items: center;
        justify-content: center; box-shadow: var(--shadow-sm); transition: transform 0.2s, box-shadow 0.2s; z-index: 100; }
    .theme-toggle:hover { transform: scale(1.1); box-shadow: var(--shadow-md); }
    """

def render_svg_diagram(content):
    """Convert diagram data to Mermaid syntax for client-side rendering"""
    nodes = content.get('nodes', [])
    edges = content.get('edges', [])
    hl_nodes = set(content.get('highlight_nodes', []))
    if not nodes:
        return '<p>No diagram data</p>'

    # Build mermaid flowchart syntax
    # Direction: always LR (left-to-right) — layout is handled by mermaid's dagre engine
    lines = ['graph LR']

    # Define nodes with shapes
    for i, n in enumerate(nodes):
        if isinstance(n, dict):
            label = n.get('label', '')
            subtitle = n.get('subtitle', '')
            display = f"{label}<br/>{subtitle}" if subtitle else label
        else:
            display = str(n)

        node_id = f"N{i}"
        # Use stadium shape for highlighted, rounded for normal
        if i in hl_nodes:
            lines.append(f'    {node_id}(["{display}"])')
        else:
            lines.append(f'    {node_id}["{display}"]')

    # Define edges
    for e in edges:
        fi, ti = e.get('from', 0), e.get('to', 0)
        label = e.get('label', '')
        if fi >= len(nodes) or ti >= len(nodes):
            continue
        if label:
            lines.append(f'    N{fi} -->|"{label}"| N{ti}')
        else:
            lines.append(f'    N{fi} --> N{ti}')

    # Add class definitions for highlighted nodes
    if hl_nodes:
        hl_list = ','.join(f'N{i}' for i in hl_nodes if i < len(nodes))
        lines.append(f'    class {hl_list} highlighted')

    mermaid_code = '\n'.join(lines)
    escaped = mermaid_code
    return f'<div class="diagram-container"><pre class="mermaid">{escaped}</pre></div>'




def _highlight_code(code, lang):
    """Syntax highlighting using token-based regex on raw code before HTML escaping"""
    import re
    if not lang:
        return html.escape(code)

    # Build pattern based on language
    parts = []
    if lang in ('yaml', 'yml'):
        parts.append(r'(?P<comment>#[^\n]*)')
        parts.append(r'(?P<string>"[^"]*")')
        parts.append(r'(?P<attr>^\s*[\w][\w.-]*(?=\s*:))')
        parts.append(r'(?P<num>\b\d+\.?\d*\b)')
        flags = re.MULTILINE
    elif lang in ('python', 'py'):
        parts.append(r'(?P<comment>#[^\n]*)')
        parts.append(r'(?P<string>"[^"\n]*"|' + r"'[^'\n]*')")
        parts.append(r'(?P<kw>\b(?:def|class|import|from|return|if|elif|else|for|while|with|as|try|except|finally|raise|yield|lambda|pass|break|continue|and|or|not|in|is|None|True|False|self)\b)')
        parts.append(r'(?P<fn>\b[a-zA-Z_]\w*(?=\())')
        parts.append(r'(?P<num>\b\d+\.?\d*\b)')
        flags = 0
    elif lang in ('javascript', 'js', 'typescript', 'ts'):
        parts.append(r'(?P<comment>//[^\n]*)')
        parts.append(r'(?P<string>`[^`]*`|"[^"\n]*"|' + r"'[^'\n]*')")
        parts.append(r'(?P<kw>\b(?:const|let|var|function|return|if|else|for|while|class|import|export|from|async|await|new|this|true|false|null|undefined|typeof|instanceof)\b)')
        parts.append(r'(?P<fn>\b[a-zA-Z_]\w*(?=\())')
        parts.append(r'(?P<num>\b\d+\.?\d*\b)')
        flags = 0
    elif lang in ('bash', 'sh', 'shell'):
        parts.append(r'(?P<comment>#[^\n]*)')
        parts.append(r'(?P<string>"[^"]*"|' + r"'[^']*')")
        parts.append(r'(?P<kw>\b(?:if|then|else|fi|for|do|done|while|case|esac|function|return|export|local|echo|exit|cd|mkdir|cp|ln)\b)')
        parts.append(r'(?P<num>\b\d+\b)')
        flags = 0
    else:
        parts.append(r'(?P<comment>#[^\n]*|//[^\n]*)')
        parts.append(r'(?P<string>"[^"\n]*"|' + r"'[^'\n]*')")
        parts.append(r'(?P<kw>\b(?:def|class|function|return|import|export|const|let|var|if|else|for|while|true|false|null|None)\b)')
        parts.append(r'(?P<fn>\b[a-zA-Z_]\w*(?=\())')
        parts.append(r'(?P<num>\b\d+\.?\d*\b)')
        flags = 0

    pattern = re.compile('|'.join(parts), flags)
    cls_map = {'comment': 'cm', 'string': 'str', 'kw': 'kw', 'fn': 'fn', 'num': 'num', 'attr': 'attr'}

    result = []
    last = 0
    for m in pattern.finditer(code):
        if m.start() > last:
            result.append(html.escape(code[last:m.start()]))
        name = m.lastgroup
        cls = cls_map.get(name, name)
        result.append(f'<span class="{cls}">{html.escape(m.group())}</span>')
        last = m.end()
    if last < len(code):
        result.append(html.escape(code[last:]))
    return ''.join(result)


def render_section(section):
    t = section.get('type', 'text')
    heading = section.get('heading', '')
    content = section.get('content', '')
    parts = []
    if heading and t != 'hero':
        parts.append(f'<h2>{html.escape(heading)}</h2>')

    if t == 'text':
        parts.append(f'<p>{html.escape(str(content))}</p>')
    elif t == 'code':
        lang = content.get('language','') if isinstance(content, dict) else ''
        code_text = content.get('code','') if isinstance(content, dict) else str(content)
        badge = f'<span class="code-lang">{html.escape(lang)}</span>' if lang else ''
        highlighted = _highlight_code(code_text, lang)
        parts.append(f'<div class="code-block">{badge}<pre><code>{highlighted}</code></pre></div>')
    elif t == 'diagram':
        parts.append(render_svg_diagram(content))
    elif t == 'table':
        headers, rows = content.get('headers',[]), content.get('rows',[])
        h = '<thead><tr>' + ''.join(f'<th>{html.escape(str(x))}</th>' for x in headers) + '</tr></thead>' if headers else ''
        b = '<tbody>' + ''.join('<tr>' + ''.join(f'<td>{html.escape(str(c))}</td>' for c in row) + '</tr>' for row in rows) + '</tbody>'
        parts.append(f'<table>{h}{b}</table>')
    elif t == 'list':
        ordered = content.get('ordered', False)
        items = content.get('items', [])
        tag = 'ol' if ordered else 'ul'
        parts.append(f'<{tag}>' + ''.join(f'<li>{html.escape(str(i))}</li>' for i in items) + f'</{tag}>')
    elif t == 'callout':
        style = content.get('style','info')
        text = content.get('text','')
        parts.append(f'<div class="callout callout-{style}"><p>{html.escape(text)}</p></div>')
    elif t == 'hero':
        badge_text = content.get('badge','') if isinstance(content, dict) else ''
        title = content.get('title','') if isinstance(content, dict) else str(content)
        sub = content.get('subtitle','') if isinstance(content, dict) else ''
        badge_html = f'<div class="badge">{html.escape(badge_text)}</div>' if badge_text else ''
        sub_html = f'<div class="subtitle">{html.escape(sub)}</div>' if sub else ''
        return f'<div class="hero">{badge_html}<h1>{html.escape(title)}</h1>{sub_html}</div>'
    elif t == 'metrics':
        items = content.get('items', []) if isinstance(content, dict) else []
        cards = ''.join(f'<div class="metric-card"><div class="metric-value">{html.escape(str(m.get("value","")))}</div><div class="metric-label">{html.escape(str(m.get("label","")))}</div></div>' for m in items)
        parts.append(f'<div class="metrics">{cards}</div>')
    elif t == 'timeline':
        items = content.get('items', []) if isinstance(content, dict) else []
        tl = ''.join(f'<div class="timeline-item"><h3>{html.escape(str(i.get("title","")))}</h3><p>{html.escape(str(i.get("description","")))}</p></div>' for i in items)
        parts.append(f'<div class="timeline">{tl}</div>')
    elif t == 'comparison':
        left = content.get('left', {}) if isinstance(content, dict) else {}
        right = content.get('right', {}) if isinstance(content, dict) else {}
        def col(data, cls=''):
            h = html.escape(str(data.get('title','')))
            items_html = ''.join(f'<li>{html.escape(str(i))}</li>' for i in data.get('items',[]))
            return f'<div class="comparison-col {cls}"><h3>{h}</h3><ul>{items_html}</ul></div>'
        parts.append(f'<div class="comparison">{col(left)}{col(right, "negative")}</div>')

    return f'<div class="section">{"".join(parts)}</div>'

def generate_html(data, tokens):
    title = html.escape(data.get('title', 'Explainer'))
    subtitle = data.get('subtitle', '')
    sections = data.get('sections', [])
    css = get_css(tokens)

    has_hero = sections and sections[0].get('type') == 'hero'
    sections_html = ''.join(render_section(s) for s in sections)

    header = ''
    if not has_hero:
        sub_html = f'<div class="subtitle">{html.escape(subtitle)}</div>' if subtitle else ''
        header = f'<div class="hero"><h1>{title}</h1>{sub_html}</div>'

    theme_js = """<script>
function toggleTheme(){var c=localStorage.getItem('devkit-theme-pref')||'auto';var n=c==='auto'?'light':(c==='light'?'dark':'auto');localStorage.setItem('devkit-theme-pref',n);var h=new Date().getHours();var t=n==='auto'?((h>=6&&h<20)?'light':'dark'):n;document.documentElement.setAttribute('data-theme',t);document.querySelector('.theme-toggle').textContent=n==='auto'?'\\u{1f504}':(n==='light'?'\\u2600\\ufe0f':'\\u{1f319}');if(window.__reRenderMermaid)window.__reRenderMermaid(t!=='light');}
document.querySelector('.theme-toggle').textContent=(localStorage.getItem('devkit-theme-pref')||'auto')==='auto'?'\\u{1f504}':((localStorage.getItem('devkit-theme-pref')==='light')?'\\u2600\\ufe0f':'\\u{1f319}');
</script>"""

    init_js = """<script>(function(){var p=localStorage.getItem('devkit-theme-pref')||'auto';var h=new Date().getHours();var t=p==='auto'?((h>=6&&h<20)?'light':'dark'):p;document.documentElement.setAttribute('data-theme',t);})();</script>"""

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
{init_js}
<meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{title}</title>
<style>{css}</style>
</head>
<body>
<button class="theme-toggle" onclick="toggleTheme()" aria-label="Toggle theme">&#127769;</button>
<div class="container">{header}{sections_html}</div>
{theme_js}
<script type="module">
import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
const darkVars = {{
    primaryColor: '#1f3056',
    primaryTextColor: '#e8e6e3',
    primaryBorderColor: '#4fc3f7',
    lineColor: '#4fc3f7',
    secondaryColor: '#16213e',
    tertiaryColor: '#1a1a2e',
    background: '#16213e',
    mainBkg: '#1f3056',
    nodeBorder: '#4fc3f7',
    clusterBkg: '#1a1a2e',
    titleColor: '#e8e6e3',
    edgeLabelBackground: '#1a1a2e',
    fontFamily: 'Inter, system-ui, sans-serif',
    fontSize: '14px'
}};
const lightVars = {{
    primaryColor: '#e3f2fd',
    primaryTextColor: '#1a1817',
    primaryBorderColor: '#0277bd',
    lineColor: '#0277bd',
    secondaryColor: '#ffffff',
    tertiaryColor: '#faf8f5',
    background: '#ffffff',
    mainBkg: '#e3f2fd',
    nodeBorder: '#0277bd',
    clusterBkg: '#faf8f5',
    titleColor: '#1a1817',
    edgeLabelBackground: '#faf8f5',
    fontFamily: 'Inter, system-ui, sans-serif',
    fontSize: '14px'
}};
const isDark = document.documentElement.getAttribute('data-theme') !== 'light';
// Store original source before mermaid replaces content
document.querySelectorAll('pre.mermaid').forEach(el => el.setAttribute('data-mermaid-src', el.textContent));
mermaid.initialize({{ startOnLoad: true, theme: 'base', themeVariables: isDark ? darkVars : lightVars }});
window.__reRenderMermaid = async function(dark) {{
  mermaid.initialize({{ startOnLoad: false, theme: 'base', themeVariables: dark ? darkVars : lightVars }});
  document.querySelectorAll('pre.mermaid, .mermaid[data-processed]').forEach(el => {{
    const src = el.getAttribute('data-mermaid-src');
    if (!src) return;
    el.removeAttribute('data-processed');
    el.innerHTML = src;
  }});
  await mermaid.run();
}};
</script>
</body></html>"""

def main():
    parser = argparse.ArgumentParser(description='Generate professional HTML explainer from JSON data')
    parser.add_argument('--data', required=True, help='Path to JSON data file')
    parser.add_argument('--output', required=True, help='Path to output HTML file')
    parser.add_argument('--no-open', action='store_true', help='Skip opening in browser')
    args = parser.parse_args()

    try:
        data = json.loads(Path(args.data).read_text())
        tokens = load_design_tokens()
        html_content = generate_html(data, tokens)
        Path(args.output).write_text(html_content)
        print(args.output)

        if not args.no_open:
            import tempfile
            fname = Path(args.output).name
            tmp_dir = Path(tempfile.gettempdir())
            tmp_file = tmp_dir / fname
            shutil.copy2(args.output, tmp_file)
            # Try to open with system default handler
            if sys.platform == "win32":
                subprocess.Popen(["cmd.exe", "/c", "start", "", str(tmp_file)],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            elif sys.platform == "darwin":
                subprocess.Popen(["open", str(tmp_file)],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            else:
                subprocess.Popen(["xdg-open", str(tmp_file)],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
    return 0

if __name__ == '__main__':
    sys.exit(main())
