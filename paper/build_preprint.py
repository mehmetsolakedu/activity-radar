#!/usr/bin/env python3
"""Build the AiWingman technical report as a searchable, submission-ready PDF."""

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
    Flowable,
    Frame,
    KeepTogether,
    ListFlowable,
    ListItem,
    PageBreak,
    PageTemplate,
    Paragraph,
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
            fontSize=20.5,
            leading=23.5,
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
        "draft": ParagraphStyle(
            "Draft",
            fontName="SansBold",
            fontSize=8.1,
            leading=10.5,
            textColor=AMBER,
            spaceBefore=5,
            spaceAfter=10,
        ),
        "h1": ParagraphStyle(
            "H1",
            fontName="SansBold",
            fontSize=13.2,
            leading=16,
            textColor=INK,
            spaceBefore=12,
            spaceAfter=5,
            keepWithNext=True,
        ),
        "h2": ParagraphStyle(
            "H2",
            fontName="SansBold",
            fontSize=10.7,
            leading=13,
            textColor=BLUE,
            spaceBefore=9,
            spaceAfter=3.5,
            keepWithNext=True,
        ),
        "body": ParagraphStyle(
            "Body",
            fontName="Body",
            fontSize=9.35,
            leading=12.05,
            alignment=TA_JUSTIFY,
            textColor=INK,
            spaceAfter=5.5,
            allowWidows=0,
            allowOrphans=0,
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
            keepWithNext=True,
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
            fontSize=8.15,
            leading=10.3,
            alignment=TA_LEFT,
            leftIndent=12,
            firstLineIndent=-12,
            textColor=INK,
            spaceAfter=4,
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
    height = 220
    d = Drawing(width, height)
    d.add(Rect(0, 0, width, height, rx=10, ry=10, fillColor=PAPER, strokeColor=RULE))
    d.add(String(14, 202, "ORDINARY LOCAL PATH", fontName="SansBold", fontSize=7.3, fillColor=TEAL))
    d.add(String(14, 96, "OPTIONAL REMOTE REVIEW", fontName="SansBold", fontSize=7.3, fillColor=AMBER))

    box(d, 14, 124, 105, 60, PALE_BLUE, "Codex local state", ["SQLite + JSONL", "external, read-only input"])
    box(d, 143, 124, 105, 60, PALE_TEAL, "ActivityRadarCore", ["bounded reduction", "signals + abstention"])
    box(d, 272, 124, 105, 60, PALE_BLUE, "Local interface", ["triage + continuity", "explicit lifecycle"])
    box(d, 401, 124, 78, 60, PALE_TEAL, "Return", ["codex:// link", "after user action"])
    arrow(d, 119, 154, 143, 154, TEAL)
    arrow(d, 248, 154, 272, 154, TEAL)
    arrow(d, 377, 154, 401, 154, TEAL)

    box(d, 75, 28, 112, 54, PALE_AMBER, "Exact packet preview", ["bounded + redacted", "one-shot consent"])
    box(d, 215, 28, 105, 54, PALE_AMBER, "Ephemeral CLI", ["no shell", "read-only sandbox"])
    box(d, 348, 28, 112, 54, PALE_RED, "Remote review", ["schema-constrained", "external service boundary"], border=HexColor("#F2B8B5"))
    arrow(d, 195, 124, 131, 82, AMBER, dashed=True)
    arrow(d, 187, 55, 215, 55, AMBER, dashed=True)
    arrow(d, 320, 55, 348, 55, RED, dashed=True)
    d.add(
        String(
            14,
            10,
            "Residual boundary: read-only blocks writes; it does not prove sole-context local read isolation.",
            fontName="SansItalic",
            fontSize=6.6,
            fillColor=RED,
        )
    )
    return d


def triage_figure(width: float) -> Drawing:
    height = 166
    d = Drawing(width, height)
    d.add(Rect(0, 0, width, height, rx=10, ry=10, fillColor=PAPER, strokeColor=RULE))
    box(d, 14, 86, 110, 60, PALE_BLUE, "Observed evidence", ["input, result, blocker", "activity, partial history"])
    box(d, 150, 86, 126, 60, PALE_TEAL, "Evidence gate", ["complete enough?", "strong and distinct?"])
    box(d, 302, 100, 90, 46, PALE_BLUE, "Rank", ["up to 3", "show why now"])
    box(d, 302, 38, 90, 46, PALE_AMBER, "Abstain", ["show no ranking", "retain uncertainty"])
    box(d, 418, 70, 62, 64, PALE_TEAL, "User", ["open", "snooze", "label"])
    arrow(d, 124, 116, 150, 116, TEAL)
    arrow(d, 276, 122, 302, 122, BLUE)
    arrow(d, 276, 103, 302, 61, AMBER)
    arrow(d, 392, 123, 418, 108, TEAL)
    arrow(d, 392, 61, 418, 91, TEAL)
    d.add(String(281, 133, "PASS", fontName="SansBold", fontSize=6.2, fillColor=BLUE))
    d.add(String(280, 72, "FAIL", fontName="SansBold", fontSize=6.2, fillColor=AMBER))
    d.add(
        String(
            14,
            16,
            "Silence does not cross the gate as evidence of running, completion, obsolete status, or abandonment.",
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
        canvas.setSubject("AiWingman software architecture and open technical evaluation protocol")
        canvas.setKeywords("coding agents, work continuity, privacy engineering, software artifact, abstention")
        page_width, page_height = A4
        if doc.page > 1:
            canvas.setStrokeColor(RULE)
            canvas.setLineWidth(0.5)
            canvas.line(self.leftMargin, page_height - 25 * mm, page_width - self.rightMargin, page_height - 25 * mm)
            canvas.setFont("Sans", 6.8)
            canvas.setFillColor(MUTED)
            canvas.drawString(self.leftMargin, page_height - 21.2 * mm, "AIWINGMAN TECHNICAL REPORT")
            canvas.drawRightString(page_width - self.rightMargin, page_height - 21.2 * mm, "DRAFT 0.1 - AUTHOR CONFIRMATION REQUIRED")
        canvas.setStrokeColor(RULE)
        canvas.setLineWidth(0.5)
        canvas.line(self.leftMargin, 17 * mm, page_width - self.rightMargin, 17 * mm)
        canvas.setFont("Sans", 6.7)
        canvas.setFillColor(MUTED)
        canvas.drawString(self.leftMargin, 12.2 * mm, "AiWingman v1.2.0-beta.2 | 23 August 2026")
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
        else:
            weights = [0.22, 0.26, 0.24, 0.28]
    elif col_count == 3:
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


def build_story(markdown: str, style_map, width):
    lines = markdown.splitlines()
    nonempty = [idx for idx, line in enumerate(lines) if line.strip()]
    if len(nonempty) < 6 or not lines[nonempty[0]].startswith("# "):
        raise ValueError("Unexpected manuscript front matter")

    title_idx = nonempty[0]
    author_idx, affiliation_idx, orcid_idx, draft_idx = nonempty[1:5]
    title = lines[title_idx][2:].strip()
    story = [
        AccentRule(width),
        Spacer(1, 10),
        Paragraph(inline_markup(title), style_map["title"]),
        Paragraph(inline_markup(lines[author_idx]), style_map["author"]),
        Paragraph(inline_markup(lines[affiliation_idx]), style_map["affiliation"]),
        Paragraph(inline_markup(lines[orcid_idx]), style_map["affiliation"]),
        Paragraph(inline_markup(lines[draft_idx]), style_map["draft"]),
    ]

    i = draft_idx + 1
    in_abstract = False
    while i < len(lines):
        line = lines[i].strip()
        if not line:
            i += 1
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
                story.append(KeepTogether([caption, table_flowable, Spacer(1, 3)]))
            else:
                story.extend([Spacer(1, 3), table_flowable, Spacer(1, 3)])
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

        paragraph_lines = [line]
        i += 1
        while i < len(lines):
            nxt = lines[i].strip()
            if not nxt or nxt.startswith(("## ", "### ", "- ", "| ", "<!-- FIGURE:")):
                break
            paragraph_lines.append(nxt)
            i += 1
        text = " ".join(paragraph_lines)

        if text.startswith(("Figure ", "Table ")):
            caption_style = style_map["table_caption"] if text.startswith("Table ") else style_map["caption"]
            story.append(Paragraph(inline_markup(text), caption_style))
        elif text.startswith("Keywords:"):
            story.append(Paragraph(inline_markup(text), style_map["keywords"]))
        elif re.match(r"^\[\d+\] ", text):
            story.append(Paragraph(inline_markup(text), style_map["reference"]))
        elif re.fullmatch(r"https?://\S+", text):
            link = html.escape(text)
            story.append(Paragraph(f'<a href="{link}" color="#2563EB">{link}</a>', style_map["url"]))
        elif in_abstract:
            abstract_table = Table(
                [[Paragraph(inline_markup(text), style_map["abstract"]) ]],
                colWidths=[width],
                hAlign="LEFT",
            )
            abstract_table.setStyle(
                TableStyle(
                    [
                        ("BACKGROUND", (0, 0), (-1, -1), PALE_BLUE),
                        ("BOX", (0, 0), (-1, -1), 0.8, HexColor("#B8CDF6")),
                        ("LEFTPADDING", (0, 0), (-1, -1), 12),
                        ("RIGHTPADDING", (0, 0), (-1, -1), 12),
                        ("TOPPADDING", (0, 0), (-1, -1), 10),
                        ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
                    ]
                )
            )
            story.append(abstract_table)
            in_abstract = False
        else:
            story.append(Paragraph(inline_markup(text), style_map["body"]))

    return title, story


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=Path(__file__).with_name("aiwingman_technical_report.md"))
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "output/pdf/aiwingman-technical-report-draft.pdf",
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
