# Explainer — Visual HTML Presentations

Produces professional presentation-quality HTML pages with design system tokens, mermaid.js diagrams, and syntax-highlighted code.

## Usage

```bash
# Write JSON data file, then generate HTML
python3 tools/explainer/explainer.py --data /tmp/topic.json --output /tmp/topic.html

# With --no-open to skip auto-opening in browser
python3 tools/explainer/explainer.py --data /tmp/topic.json --output /tmp/topic.html --no-open
```

## JSON Schema

```json
{
  "title": "Topic Title",
  "subtitle": "Optional subtitle",
  "sections": [
    {"type": "hero", "content": {"badge": "Guide", "title": "Main Title", "subtitle": "Subtitle"}},
    {"type": "metrics", "content": {"items": [{"value": "42", "label": "Things"}]}},
    {"type": "text", "heading": "Section", "content": "Paragraph text"},
    {"type": "code", "content": {"language": "typescript", "code": "const x = 1;"}},
    {"type": "diagram", "content": {"nodes": ["A", "B"], "edges": [{"from": 0, "to": 1}]}},
    {"type": "timeline", "content": {"items": [{"title": "Step 1", "description": "..."}]}},
    {"type": "comparison", "content": {"left": {"title": "Do", "items": [...]}, "right": {"title": "Don't", "items": [...]}}},
    {"type": "table", "content": {"headers": ["Col1"], "rows": [["val"]]}},
    {"type": "callout", "content": {"style": "info|warning|success|error", "text": "..."}}
  ]
}
```

## Section Types

| Type | Renders As |
|------|-----------|
| hero | Full-width gradient header |
| metrics | Grid of accent-topped cards with big numbers |
| text | Paragraph with muted color |
| code | Syntax-highlighted block with language badge |
| diagram | Mermaid.js flowchart (auto-layout) |
| timeline | Vertical timeline with glow dots |
| comparison | Two-column do/don't |
| table | Elevated surface with hover rows |
| list | Ordered or unordered list |
| callout | Left-border accent box |

## Design System

Uses `DESIGN.md` (Google Stitch format) for tokens:
- Colors, typography, spacing, elevation, motion
- Dark/light theme auto-toggle
- Entrance animations (fade-up with stagger)

## Excel Variant

For calculations and data flows where users need to tweak numbers:

```python
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill

wb = Workbook()
input_font = Font(color="0000FF")       # Blue = user inputs
formula_font = Font(color="000000")     # Black = formulas
note_font = Font(italic=True, size=9, color="666666")

# Build sheets with live formulas (never hardcode calculated values)
# Save to accessible location
wb.save("/path/to/output.xlsx")
```

## Dependencies

- Python 3.10+ (standard library only for HTML generation)
- openpyxl (for Excel variant): `pip install openpyxl`
- Internet for mermaid.js CDN (diagrams won't render offline)
