#!/usr/bin/env python3
"""Build the AiWingman technical report as a searchable review PDF."""

from __future__ import annotations

import argparse
import html
import re
from pathlib import Path

from reportlab.graphics.shapes import Drawing, Line, Polygon, Rect, String
import reportlab
from reportlab.lib import colors
from reportlab.lib.colors import HexColor
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    BaseDocTemplate,
    CondPageBreak,
    Flowable,
    Frame,
    KeepTogether,
    ListFlowable,
    ListItem,
    PageBreak,
    PageTemplate,
    Paragraph,
    Preformatted,
    Spacer,
    Table,
    TableStyle,
)


INK = HexColor("#102A43")
MUTED = HexColor("#52667A")
BLUE = HexColor("#2563EB")
TEAL = HexColor("#0F8B8D")
AMBER = HexColor("#C76A00")
RED = HexColor("#B42318")
PALE_BLUE = HexColor("#EAF2FF")
PALE_TEAL = HexColor("#E7F7F5")
PALE_AMBER = HexColor("#FFF4E5")
PALE_RED = HexColor("#FDECEC")
PAPER = HexColor("#FBFCFE")
RULE = HexColor("#D5DEE8")


BUNDLED_FONT_ROOT = Path(reportlab.__file__).resolve().parent / "fonts"
MACOS_FONT_ROOT = Path("/System/Library/Fonts/Supplemental")


def font_path(macos_name: str, bundled_name: str) -> Path:
    macos_path = MACOS_FONT_ROOT / macos_name
    return macos_path if macos_path.exists() else BUNDLED_FONT_ROOT / bundled_name


def register_fonts() -> None:
    faces = {
        "Body": font_path("Times New Roman.ttf", "Vera.ttf"),
        "BodyBold": font_path("Times New Roman Bold.ttf", "VeraBd.ttf"),
        "BodyItalic": font_path("Times New Roman Italic.ttf", "VeraIt.ttf"),
        "Sans": font_path("Arial.ttf", "Vera.ttf"),
        "SansBold": font_path("Arial Bold.ttf", "VeraBd.ttf"),
        "SansItalic": font_path("Arial Italic.ttf", "VeraIt.ttf"),
    }
    for name, path in faces.items():
        if not path.exists():
            raise FileNotFoundError(f"Required font not found: {path}")
        pdfmetrics.registerFont(TTFont(name, str(path)))


def inline_markup(text: str) -> str:
    """Convert the small Markdown subset used by the manuscript to ReportLab XML."""
    escaped = html.escape(text, quote=False)
    escaped = re.sub(
        r"`([^`]+)`",
        lambda m: f'<font name="Courier" size="8.1">{m.group(1)}</font>',
        escaped,
    )
    escaped = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", escaped)
    escaped = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", r"<i>\1</i>", escaped)
    escaped = re.sub(
        r"\[([^\]]+)\]\((https?://[^)]+)\)",
        r'<a href="\2" color="#2563EB">\1</a>',
        escaped,
    )
    return escaped


def styles():
    base = getSampleStyleSheet()
    result = {
        "title": ParagraphStyle(
            "Title",
            parent=base["Title"],
            fontName="SansBold",
            fontSize=19,
            leading=22,
            textColor=INK,
            alignment=TA_LEFT,
            spaceAfter=8,
        ),
        "author": ParagraphStyle(
            "Author",
            fontName="SansBold",
            fontSize=11.2,
            leading=14,
            textColor=INK,
            spaceAfter=2,
        ),
        "affiliation": ParagraphStyle(
            "Affiliation",
            fontName="Sans",
            fontSize=8.7,
            leading=11.2,
            textColor=MUTED,
            spaceAfter=1,
        ),
        "version": ParagraphStyle(
            "Version",
            fontName="SansBold",
            fontSize=8.1,
            leading=10.5,
            textColor=MUTED,
            spaceBefore=5,
            spaceAfter=10,
        ),
        "h1": ParagraphStyle(
            "H1",
            fontName="SansBold",
            fontSize=13.2,
            leading=16,
            textColor=INK,
            spaceBefore=10,
            spaceAfter=4.5,
            keepWithNext=True,
        ),
        "h2": ParagraphStyle(
            "H2",
            fontName="SansBold",
            fontSize=10.7,
            leading=13,
            textColor=BLUE,
            spaceBefore=7.5,
            spaceAfter=3,
            keepWithNext=True,
        ),
        "body": ParagraphStyle(
            "Body",
            fontName="Body",
            fontSize=9.35,
            leading=11.9,
            alignment=TA_LEFT,
            textColor=INK,
            spaceAfter=5,
            allowWidows=0,
            allowOrphans=0,
        ),
        "code": ParagraphStyle(
            "CodeBlock",
            fontName="Courier",
            fontSize=7.4,
            leading=9.4,
            alignment=TA_LEFT,
            textColor=INK,
            spaceBefore=0,
            spaceAfter=0,
        ),
        "bullet": ParagraphStyle(
            "Bullet",
            fontName="Body",
            fontSize=9.15,
            leading=11.7,
            textColor=INK,
            leftIndent=1,
            spaceAfter=2,
        ),
        "abstract": ParagraphStyle(
            "Abstract",
            fontName="Body",
            fontSize=9.25,
            leading=12,
            alignment=TA_JUSTIFY,
            textColor=INK,
            spaceAfter=5.5,
        ),
        "keywords": ParagraphStyle(
            "Keywords",
            fontName="Sans",
            fontSize=8.15,
            leading=10.4,
            textColor=MUTED,
            spaceBefore=5,
            spaceAfter=5,
        ),
        "caption": ParagraphStyle(
            "Caption",
            fontName="Sans",
            fontSize=7.75,
            leading=10,
            textColor=MUTED,
            spaceBefore=3,
            spaceAfter=8,
        ),
        "table_caption": ParagraphStyle(
            "TableCaption",
            fontName="Sans",
            fontSize=7.75,
            leading=10,
            textColor=MUTED,
            spaceBefore=5,
            spaceAfter=4,
            keepWithNext=False,
        ),
        "table": ParagraphStyle(
            "TableCell",
            fontName="Sans",
            fontSize=7.2,
            leading=9,
            textColor=INK,
        ),
        "table_head": ParagraphStyle(
            "TableHead",
            fontName="SansBold",
            fontSize=7.1,
            leading=8.8,
            textColor=colors.white,
        ),
        "reference": ParagraphStyle(
            "Reference",
            fontName="Body",
            fontSize=7.3,
            leading=8.55,
            alignment=TA_LEFT,
            leftIndent=12,
            firstLineIndent=-12,
            textColor=INK,
            spaceAfter=0.5,
        ),
        "url": ParagraphStyle(
            "URL",
            fontName="Courier",
            fontSize=7.1,
            leading=9.4,
            textColor=BLUE,
            leftIndent=8,
            rightIndent=8,
            spaceAfter=5,
            wordWrap="CJK",
        ),
        "footer": ParagraphStyle(
            "Footer",
            fontName="Sans",
            fontSize=6.8,
            leading=8,
            textColor=MUTED,
        ),
    }
    return result


class AccentRule(Flowable):
    def __init__(self, width: float, height: float = 4.0):
        super().__init__()
        self.width = width
        self.height = height

    def draw(self):
        self.canv.setFillColor(BLUE)
        self.canv.roundRect(0, 0, 54, self.height, self.height / 2, fill=1, stroke=0)
        self.canv.setFillColor(TEAL)
        self.canv.roundRect(58, 0, 28, self.height, self.height / 2, fill=1, stroke=0)
        self.canv.setFillColor(RULE)
        self.canv.rect(90, 1.4, max(0, self.width - 90), 1, fill=1, stroke=0)


def arrow(drawing: Drawing, x1, y1, x2, y2, color=BLUE, dashed=False):
    line = Line(x1, y1, x2, y2, strokeColor=color, strokeWidth=1.5)
    if dashed:
        line.strokeDashArray = [4, 3]
    drawing.add(line)
    angle = 5
    if abs(x2 - x1) >= abs(y2 - y1):
        sign = 1 if x2 >= x1 else -1
        drawing.add(
            Polygon(
                [x2, y2, x2 - sign * 7, y2 + angle, x2 - sign * 7, y2 - angle],
                fillColor=color,
                strokeColor=color,
            )
        )
    else:
        sign = 1 if y2 >= y1 else -1
        drawing.add(
            Polygon(
                [x2, y2, x2 - angle, y2 - sign * 7, x2 + angle, y2 - sign * 7],
                fillColor=color,
                strokeColor=color,
            )
        )


def box(drawing: Drawing, x, y, w, h, fill, title, lines, border=RULE):
    drawing.add(Rect(x, y, w, h, rx=8, ry=8, fillColor=fill, strokeColor=border, strokeWidth=1))
    drawing.add(String(x + 9, y + h - 16, title, fontName="SansBold", fontSize=7.8, fillColor=INK))
    for idx, line in enumerate(lines):
        drawing.add(
            String(
                x + 9,
                y + h - 30 - idx * 11,
                line,
                fontName="Sans",
                fontSize=6.4,
                fillColor=MUTED,
            )
        )


def architecture_figure(width: float) -> Drawing:
    height = 236
    d = Drawing(width, height)
    d.add(Rect(0, 0, width, height, rx=10, ry=10, fillColor=PAPER, strokeColor=RULE))
    d.add(String(14, 218, "ORDINARY DASHBOARD PIPELINE", fontName="SansBold", fontSize=7.3, fillColor=TEAL))
    d.add(String(14, 111, "OPTIONAL WINGMAN PIPELINE", fontName="SansBold", fontSize=7.3, fillColor=AMBER))

    box(d, 14, 139, 102, 60, PALE_BLUE, "Codex local state", ["candidate task rows", "each row's own rollout"])
    box(d, 135, 139, 102, 60, PALE_TEAL, "Ordinary reader", ["query-only SQL", "bounded rollout"])
    box(d, 256, 139, 102, 60, PALE_BLUE, "Continuity policy", ["per-item evidence", "ranking suppression"])
    box(d, 377, 139, 102, 60, PALE_TEAL, "Local interface", ["lifecycle controls", "codex:// deep link"])
    arrow(d, 116, 169, 135, 169, TEAL)
    arrow(d, 237, 169, 256, 169, TEAL)
    arrow(d, 358, 169, 377, 169, TEAL)

    box(d, 14, 31, 102, 60, PALE_BLUE, "Codex local state", ["root + child rows", "rollout tails"])
    box(d, 135, 31, 102, 60, PALE_AMBER, "Wingman reader", ["task-tree graph", "bounded evidence"])
    box(d, 256, 31, 102, 60, PALE_AMBER, "Preview + consent", ["bounded packet", "one-shot approval"])
    box(d, 377, 31, 102, 60, PALE_RED, "External CLI", ["--ephemeral request", "service boundary"], border=HexColor("#F2B8B5"))
    arrow(d, 116, 61, 135, 61, AMBER, dashed=True)
    arrow(d, 237, 61, 256, 61, AMBER, dashed=True)
    arrow(d, 358, 61, 377, 61, RED, dashed=True)
    d.add(
        String(
            14,
            13,
            "The pipelines are separate. Requested read-only CLI mode is not OS isolation or a sole-context proof.",
            fontName="SansItalic",
            fontSize=6.6,
            fillColor=RED,
        )
    )
    return d


def triage_figure(width: float) -> Drawing:
    height = 174
    d = Drawing(width, height)
    d.add(Rect(0, 0, width, height, rx=10, ry=10, fillColor=PAPER, strokeColor=RULE))
    box(d, 14, 92, 105, 60, PALE_BLUE, "Eligibility", ["not deferred", "complete history"])
    box(d, 138, 92, 105, 60, PALE_TEAL, "Fixed score", ["integer weights", "ID tie-break"])
    box(d, 262, 92, 105, 60, PALE_BLUE, "Decision gate", ["top score >= 30", "lead >= 10 if runner-up"])
    box(d, 386, 106, 93, 46, PALE_TEAL, "Recommend", ["bounded by input limit", "show reasons"])
    box(d, 386, 40, 93, 46, PALE_AMBER, "Suppress ranking", ["no eligible item", "weak/close scores"])
    arrow(d, 119, 122, 138, 122, TEAL)
    arrow(d, 243, 122, 262, 122, TEAL)
    arrow(d, 367, 128, 386, 128, BLUE)
    arrow(d, 367, 108, 386, 63, AMBER)
    d.add(String(370, 138, "PASS", fontName="SansBold", fontSize=6.2, fillColor=BLUE))
    # Keep the label left of the descending arrow so the stroke does not
    # obscure the final letters in rendered PDFs.
    d.add(String(346, 73, "FAIL", fontName="SansBold", fontSize=6.2, fillColor=AMBER))
    d.add(
        String(
            14,
            18,
            "An incomplete item is excluded; it does not suppress a supported recommendation from another complete item.",
            fontName="SansItalic",
            fontSize=6.7,
            fillColor=MUTED,
        )
    )
    return d


class ReportDocTemplate(BaseDocTemplate):
    def __init__(self, filename: str, manuscript_title: str, **kwargs):
        self.manuscript_title = manuscript_title
        super().__init__(filename, **kwargs)
        frame = Frame(
            self.leftMargin,
            self.bottomMargin,
            self.width,
            self.height,
            id="body",
            leftPadding=0,
            rightPadding=0,
            topPadding=0,
            bottomPadding=0,
        )
        self.addPageTemplates(PageTemplate(id="main", frames=[frame], onPage=self.decorate_page))

    def decorate_page(self, canvas, doc):
        canvas.saveState()
        canvas.setTitle(self.manuscript_title)
        canvas.setAuthor("Mehmet Solak")
        canvas.setSubject(
            "AiWingman local continuity overlay and retrospective policy-layer conformance study"
        )
        canvas.setKeywords("coding agents, work continuity, local-first software, deterministic ranking suppression, specification-based testing, human oversight")
        page_width, page_height = A4
        if doc.page > 1:
            canvas.setStrokeColor(RULE)
            canvas.setLineWidth(0.5)
            canvas.line(self.leftMargin, page_height - 25 * mm, page_width - self.rightMargin, page_height - 25 * mm)
            canvas.setFont("Sans", 6.8)
            canvas.setFillColor(MUTED)
            canvas.drawString(self.leftMargin, page_height - 21.2 * mm, "AIWINGMAN TECHNICAL NOTE")
            canvas.drawRightString(page_width - self.rightMargin, page_height - 21.2 * mm, "SUBMISSION VERSION 1.0")
        canvas.setStrokeColor(RULE)
        canvas.setLineWidth(0.5)
        canvas.line(self.leftMargin, 17 * mm, page_width - self.rightMargin, 17 * mm)
        canvas.setFont("Sans", 6.7)
        canvas.setFillColor(MUTED)
        canvas.drawString(self.leftMargin, 12.2 * mm, "AiWingman Technical Note | Submission version 1.0 | 24 August 2026")
        canvas.drawRightString(page_width - self.rightMargin, 12.2 * mm, str(doc.page))
        canvas.restoreState()


def parse_table(lines, style_map, width):
    raw_rows = []
    for line in lines:
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        raw_rows.append(cells)
    if len(raw_rows) >= 2 and all(re.fullmatch(r":?-{3,}:?", c) for c in raw_rows[1]):
        raw_rows.pop(1)
    col_count = max(len(row) for row in raw_rows)
    normalized = [row + [""] * (col_count - len(row)) for row in raw_rows]
    data = []
    for row_idx, row in enumerate(normalized):
        cell_style = style_map["table_head"] if row_idx == 0 else style_map["table"]
        data.append([Paragraph(inline_markup(cell), cell_style) for cell in row])

    if col_count == 4:
        if normalized[0][0].startswith("Evidence"):
            weights = [0.26, 0.17, 0.20, 0.37]
        elif normalized[0][0].startswith("Axis"):
            weights = [0.15, 0.29, 0.27, 0.29]
        elif normalized[0][0].startswith("Order"):
            # The score table has compact ordinal/weight columns and two
            # text-heavy columns. Give reason identifiers enough room to avoid
            # splitting a final character onto its own line.
            weights = [0.08, 0.39, 0.38, 0.15]
        else:
            weights = [0.22, 0.26, 0.24, 0.28]
    elif col_count == 3:
        if normalized[0][0].startswith("Pipeline"):
            weights = [0.22, 0.32, 0.46]
        else:
            weights = [0.26, 0.24, 0.50]
    else:
        weights = [1 / col_count] * col_count
    col_widths = [width * weight for weight in weights]

    table = Table(data, colWidths=col_widths, repeatRows=1, hAlign="LEFT", splitByRow=1)
    commands = [
        ("BACKGROUND", (0, 0), (-1, 0), INK),
        ("BOX", (0, 0), (-1, -1), 0.7, RULE),
        ("INNERGRID", (0, 0), (-1, -1), 0.35, RULE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 4.5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4.5),
    ]
    for row_idx in range(1, len(data)):
        commands.append(("BACKGROUND", (0, row_idx), (-1, row_idx), colors.white if row_idx % 2 else PAPER))
    table.setStyle(TableStyle(commands))
    return table


FENCE_OPEN_RE = re.compile(r"^(?P<marker>`{3,}|~{3,})(?:[ \t]*(?P<info>.*))?$")


def fenced_code_start(line: str):
    """Return the fence marker and optional info string for a Markdown code block."""
    match = FENCE_OPEN_RE.fullmatch(line.strip())
    if match is None:
        return None
    return match.group("marker"), (match.group("info") or "").strip()


def fenced_code_end(line: str, marker: str) -> bool:
    """Recognize a closing fence of the same character and at least the same length."""
    candidate = line.strip()
    return (
        len(candidate) >= len(marker)
        and candidate[0] == marker[0]
        and candidate == candidate[0] * len(candidate)
    )


def read_fenced_code(lines, start):
    opening = fenced_code_start(lines[start])
    if opening is None:
        raise ValueError(f"Expected fenced code block at line {start + 1}")
    marker, info = opening
    code_lines = []
    i = start + 1
    while i < len(lines):
        if fenced_code_end(lines[i], marker):
            return code_lines, info, i + 1
        code_lines.append(lines[i].expandtabs(4))
        i += 1
    raise ValueError(f"Unclosed fenced code block at line {start + 1}")


def code_block_flowable(code_lines, style_map, width):
    """Create a bounded preformatted block without exposing Markdown fence markers."""
    inner_width = width - 20
    character_width = pdfmetrics.stringWidth("M", "Courier", style_map["code"].fontSize)
    max_line_length = max(20, int(inner_width / character_width))
    code_text = "\n".join(code_lines) if code_lines else " "
    preformatted = Preformatted(
        code_text,
        style_map["code"],
        maxLineLength=max_line_length,
        splitChars="[{( ,.;:/\\-=",
        newLineChars="  ",
    )
    block = Table([[preformatted]], colWidths=[width], hAlign="LEFT")
    block.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), HexColor("#F4F6F9")),
                ("BOX", (0, 0), (-1, -1), 0.65, RULE),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("RIGHTPADDING", (0, 0), (-1, -1), 10),
                ("TOPPADDING", (0, 0), (-1, -1), 7),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ]
        )
    )
    return block


def build_story(markdown: str, style_map, width):
    lines = markdown.splitlines()
    nonempty = [idx for idx, line in enumerate(lines) if line.strip()]
    if len(nonempty) < 6 or not lines[nonempty[0]].startswith("# "):
        raise ValueError("Unexpected manuscript front matter")

    title_idx = nonempty[0]
    author_idx, affiliation_idx, orcid_idx, version_idx = nonempty[1:5]
    title = lines[title_idx][2:].strip()
    story = [
        AccentRule(width),
        Spacer(1, 10),
        Paragraph(inline_markup(title), style_map["title"]),
        Paragraph(inline_markup(lines[author_idx]), style_map["author"]),
        Paragraph(inline_markup(lines[affiliation_idx]), style_map["affiliation"]),
        Paragraph(inline_markup(lines[orcid_idx]), style_map["affiliation"]),
        Paragraph(inline_markup(lines[version_idx]), style_map["version"]),
    ]

    i = version_idx + 1
    in_abstract = False
    while i < len(lines):
        line = lines[i].strip()
        if not line:
            i += 1
            continue
        if fenced_code_start(lines[i]) is not None:
            code_lines, _language, i = read_fenced_code(lines, i)
            code_block = code_block_flowable(code_lines, style_map, width)
            code_group = [Spacer(1, 3), code_block, Spacer(1, 6)]
            if (
                story
                and isinstance(story[-1], Paragraph)
                and story[-1].getPlainText().rstrip().endswith(":")
            ):
                introduction = story.pop()
                code_group = [introduction, *code_group]
                if (
                    story
                    and isinstance(story[-1], Paragraph)
                    and story[-1].style.name in {"H1", "H2"}
                ):
                    code_group.insert(0, story.pop())
                story.append(KeepTogether(code_group))
            else:
                story.extend(code_group)
            continue
        if line.startswith("<!-- FIGURE:"):
            key = line[len("<!-- FIGURE:") :].split("-->")[0].strip()
            story.append(Spacer(1, 4))
            if key == "architecture":
                story.append(architecture_figure(width))
            elif key == "triage":
                story.append(triage_figure(width))
            else:
                raise ValueError(f"Unknown figure: {key}")
            i += 1
            continue
        if line.startswith("## "):
            heading = line[3:].strip()
            in_abstract = heading == "Abstract"
            story.append(Paragraph(inline_markup(heading), style_map["h1"]))
            i += 1
            continue
        if line.startswith("### "):
            in_abstract = False
            story.append(Paragraph(inline_markup(line[4:].strip()), style_map["h2"]))
            i += 1
            continue
        if line.startswith("| "):
            table_lines = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                table_lines.append(lines[i].strip())
                i += 1
            table_flowable = parse_table(table_lines, style_map, width)
            if story and isinstance(story[-1], Paragraph) and story[-1].style.name == "TableCaption":
                caption = story.pop()
                # Require enough space for the caption, header, and at least
                # one data row. Keeping the caption with the entire Table would
                # disable useful row splitting and leave a large blank area.
                story.extend([CondPageBreak(52), caption, table_flowable, Spacer(1, 3)])
            else:
                story.extend([CondPageBreak(40), Spacer(1, 3), table_flowable, Spacer(1, 3)])
            continue
        if line.startswith("- "):
            bullets = []
            while i < len(lines) and lines[i].strip().startswith("- "):
                bullets.append(
                    ListItem(
                        Paragraph(inline_markup(lines[i].strip()[2:].strip()), style_map["bullet"]),
                        leftIndent=12,
                    )
                )
                i += 1
            story.append(
                ListFlowable(
                    bullets,
                    bulletType="bullet",
                    start="circle",
                    leftIndent=18,
                    bulletFontName="Sans",
                    bulletFontSize=6,
                    bulletColor=BLUE,
                    spaceBefore=1,
                    spaceAfter=5,
                )
            )
            continue
        if re.match(r"^\d+\. ", line):
            numbered_items = []
            start_number = int(line.split(".", 1)[0])
            while i < len(lines) and re.match(r"^\d+\. ", lines[i].strip()):
                item_text = re.sub(r"^\d+\.\s+", "", lines[i].strip())
                numbered_items.append(
                    ListItem(
                        Paragraph(inline_markup(item_text), style_map["bullet"]),
                        leftIndent=15,
                    )
                )
                i += 1
            story.append(
                ListFlowable(
                    numbered_items,
                    bulletType="1",
                    start=start_number,
                    leftIndent=22,
                    bulletFontName="Sans",
                    bulletFontSize=8.2,
                    bulletColor=BLUE,
                    spaceBefore=1,
                    spaceAfter=5,
                )
            )
            continue

        paragraph_lines = [line]
        i += 1
        while i < len(lines):
            nxt = lines[i].strip()
            if (
                not nxt
                or nxt.startswith(("## ", "### ", "- ", "| ", "<!-- FIGURE:"))
                or re.match(r"^\d+\. ", nxt)
                or fenced_code_start(lines[i]) is not None
            ):
                break
            paragraph_lines.append(nxt)
            i += 1
        text = " ".join(paragraph_lines)

        if text.startswith(("Figure ", "Table ")):
            caption_style = style_map["table_caption"] if text.startswith("Table ") else style_map["caption"]
            caption = Paragraph(inline_markup(text), caption_style)
            if (
                text.startswith("Figure ")
                and len(story) >= 2
                and isinstance(story[-1], Drawing)
                and isinstance(story[-2], Spacer)
            ):
                figure = story.pop()
                spacer = story.pop()
                story.append(KeepTogether([spacer, figure, caption, Spacer(1, 3)]))
            else:
                story.append(caption)
        elif text.startswith("Keywords:"):
            story.append(Paragraph(inline_markup(text), style_map["keywords"]))
            in_abstract = False
        elif re.match(r"^\[\d+\] ", text):
            story.append(KeepTogether([Paragraph(inline_markup(text), style_map["reference"])]))
        elif re.fullmatch(r"https?://\S+", text):
            link = html.escape(text)
            link_paragraph = Paragraph(
                f'<a href="{link}" color="#2563EB">{link}</a>',
                style_map["url"],
            )
            if (
                story
                and isinstance(story[-1], Paragraph)
                and story[-1].getPlainText().rstrip().endswith(":")
            ):
                introduction = story.pop()
                story.append(KeepTogether([introduction, link_paragraph]))
            else:
                story.append(link_paragraph)
        elif in_abstract:
            # Keep every paragraph between Abstract and Keywords in one
            # consistent typographic treatment. Boxing only the first
            # paragraph made the remainder look like accidental overflow.
            story.append(Paragraph(inline_markup(text), style_map["abstract"]))
        else:
            paragraph = Paragraph(inline_markup(text), style_map["body"])
            if text.startswith("The `git rev-parse` HEAD command must report"):
                story.append(KeepTogether([paragraph]))
            else:
                story.append(paragraph)

    return title, story


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=Path(__file__).with_name("aiwingman_technical_report.md"))
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "output/pdf/aiwingman-technical-note-v1.pdf",
    )
    args = parser.parse_args()

    register_fonts()
    manuscript = args.source.read_text(encoding="utf-8")
    args.output.parent.mkdir(parents=True, exist_ok=True)

    page_width, _ = A4
    left = right = 18 * mm
    top = 29 * mm
    bottom = 22 * mm
    text_width = page_width - left - right
    style_map = styles()
    title, story = build_story(manuscript, style_map, text_width)

    doc = ReportDocTemplate(
        str(args.output),
        manuscript_title=title,
        pagesize=A4,
        leftMargin=left,
        rightMargin=right,
        topMargin=top,
        bottomMargin=bottom,
        title=title,
        author="Mehmet Solak",
    )
    doc.build(story)
    print(args.output.resolve())


if __name__ == "__main__":
    main()
