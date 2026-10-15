"""Verify the spike's output and measure the already-built renderer.

Run from the repository root; needs Poppler's pdfinfo/pdftotext/pdfimages.
Python and Poppler are verification tools, not renderer dependencies.
"""

import hashlib
import json
import platform
import re
import statistics
import subprocess
import sys
import time
from html.parser import HTMLParser
from pathlib import Path


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = []
        self.links = []
        self.code = []
        self.in_pre = False
        self.tables = 0
        self.images = []

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if "id" in attrs:
            self.ids.append(attrs["id"])
        if tag == "a":
            self.links.append(attrs["href"])
        if tag == "pre":
            self.in_pre = True
            self.code.append("")
        if tag == "table":
            self.tables += 1
        if tag == "img":
            self.images.append(attrs)

    def handle_endtag(self, tag):
        if tag == "pre":
            self.in_pre = False

    def handle_data(self, data):
        if self.in_pre:
            self.code[-1] += data


binary = str(Path(sys.argv[1]).resolve())
root = Path(".roc-ansi-tmp/docs-roc-verification")
root.mkdir(parents=True, exist_ok=True)
source = Path("spikes/docs-roc/chapter.md")
records = []


def run(input_path, directory):
    timer = ["/usr/bin/time", "-l" if platform.system() == "Darwin" else "-v"]
    start = time.monotonic()
    result = subprocess.run(
        timer + [binary, str(input_path), str(directory)],
        capture_output=True,
        text=True,
        check=True,
    )
    wall = time.monotonic() - start
    if platform.system() == "Darwin":
        rss = int(re.search(r"(\d+)\s+maximum resident set size", result.stderr)[1])
    else:
        rss = int(re.search(r"Maximum resident set size \(kbytes\):\s*(\d+)", result.stderr)[1]) * 1024
    stages = {key: int(value) for key, value in re.findall(r"(\w+)=(\d+)ms", result.stdout)}
    pages = int(re.search(r"pages=(\d+)", result.stdout)[1])
    record = {"wall_seconds": wall, "peak_rss_bytes": rss, "pages": pages, "stages_ms": stages}
    records.append(record)
    return directory / "manual.pdf"


pdfs = [run(source, root / f"run-{index}") for index in range(3)]
assert len({hashlib.sha256(pdf.read_bytes()).hexdigest() for pdf in pdfs}) == 1
page = Page()
page.feed((root / "run-0/index.html").read_text())
assert len(page.ids) == len(set(page.ids))
assert all(link[1:] in page.ids for link in page.links if link.startswith("#"))
expected_code = re.findall(r"```[^\n]*\n(.*?)```", source.read_text(), re.S)
assert page.code == expected_code, "HTML must preserve source code exactly"
assert page.tables == 2 and len(page.images) == 1 and page.images[0]["alt"]
assert (root / "run-0/animals.png").read_bytes() == Path("docs/images/animals.png").read_bytes()
info = subprocess.check_output(["pdfinfo", str(pdfs[0])], text=True)
assert "PDF version:     2.0" in info
assert "Tagged:          yes" in info
text = subprocess.check_output(["pdftotext", "-layout", str(pdfs[0]), "-"], text=True)
for expected in ["Get started", "Run the checks", "Where tests live", "Release and maintain"]:
    assert expected in text, expected
pages_text = [page for page in text.split("\f") if page.strip()]
assert text.count("The roc-ansi manual") == 1, "Cover title must not repeat in body"
package_url = re.search(r'ansi: "(https://[^"\n]+)"', source.read_text())[1]
url_prefix, url_hash = package_url.rsplit("/", 1)
assert re.search(re.escape(url_prefix + "/") + r"\s+" + re.escape(url_hash), text), "Package URL should wrap before its complete hash"
assert package_url in re.sub(r"\s+", "", text), "Visual wrapping must retain every URL character"
for index, page_text in enumerate(pages_text):
    assert "Roc documentation experiment" in page_text, f"Missing footer on page {index + 1}"
    assert re.search(rf"{index + 1}\s*/\s*{len(pages_text)}", page_text), "Incorrect page field"
    if index:
        assert "roc-ansi / Manual" in page_text and "0.13.2" in page_text, "Missing continuation header"
images = subprocess.check_output(["pdfimages", "-list", str(pdfs[0])], text=True)
assert re.search(r"\b658\s+102\b", images), "Screenshot must be embedded at original pixel dimensions"
destinations = subprocess.check_output(["pdfinfo", "-dests", str(pdfs[0])], text=True)
assert '"get-started"' in destinations and '"run-the-checks"' in destinations
# The visible cover title is PDF 2.0 Title, not an extra heading level.
# Poppler versions predating those new roles warn about Title/Strong/Em;
# inspect their recognized heading hierarchy without treating that as validity.
structure = subprocess.run(["pdfinfo", "-struct-text", str(pdfs[0])], capture_output=True, text=True, check=True)
h1 = re.findall(r'  H1 \(block\)\n    "([^"]+)"', structure.stdout)
h2 = re.findall(r'  H2 \(block\)\n    "([^"]+)"', structure.stdout)
assert h1 == ["Contents", "Get started", "Run the checks", "Release and maintain"], h1
assert "Add the package" in h2 and "Where tests live" in h2, h2
assert "  H3 (block)" not in structure.stdout
print("PASS deterministic PDF, exact HTML code, local anchors, tables, screenshot, PDF tags/text/destinations")

stress = root / "pagination.md"
stress.write_text(
    "# Pagination probe\n\n| Unique repeated header | Value |\n| --- | --- |\n"
    + "".join(f"| Row {index} | Checked item {index} |\n" for index in range(120))
)
stress_pdf = run(stress, root / "pagination")
stress_text = subprocess.check_output(["pdftotext", "-layout", str(stress_pdf), "-"], text=True)
assert records[-1]["pages"] > 1
assert stress_text.count("Unique repeated header") >= records[-1]["pages"] - 1
assert "Row 119" in stress_text
print(f"PASS continuing table: {records[-1]['pages']} pages with repeated headers and final row retained")

for name, content in [
    ("html", "# Bad input\n\n<script>alert(1)</script>\n"),
    ("image", "# Bad input\n\n![Unknown](missing.png)\n"),
    ("unicode-code", "# Bad input\n\n```\nλ\n```\n"),
]:
    input_path = root / f"rejected-{name}.md"
    input_path.write_text(content)
    output = root / f"rejected-{name}"
    result = subprocess.run([binary, str(input_path), str(output)], capture_output=True, text=True)
    assert result.returncode != 0
    assert not (output / "manual.pdf").exists()
print("PASS unsupported HTML, unknown images and non-ASCII code fail without publishing output")

# Preformatted text keeps authored blank lines and tabs expanded to four spaces.
# Long tokens wrap visually; the HTML remains byte-for-byte faithful to source.
preformatted = root / "preformatted.md"
code = "first\n\n\n\tindented\n" + "x" * 220 + "\nlast\n"
preformatted.write_text("# Code probe\n\n```text\n" + code + "```\n")
code_pdf = run(preformatted, root / "preformatted")
code_page = Page()
code_page.feed((root / "preformatted/index.html").read_text())
assert code_page.code == [code]
code_text = subprocess.check_output(["pdftotext", "-layout", str(code_pdf), "-"], text=True)
assert "indented" in code_text and "last" in code_text
assert sum(len(token) for token in re.findall(r"x{2,}", code_text)) == 220

# Public custom blocks are unsplittable: reject a code block taller than a page.
long_code = root / "oversize-code.md"
long_code.write_text("# Long code\n\n```\n" + "line\n" * 100 + "```\n")
oversize_output = root / "oversize-code"
oversize_result = subprocess.run([binary, str(long_code), str(oversize_output)], capture_output=True, text=True)
assert oversize_result.returncode != 0 and "layout.oversize_block" in oversize_result.stdout + oversize_result.stderr
assert not (oversize_output / "manual.pdf").exists()

for name, content in [("empty", ""), ("minimal", "A minimal paragraph.\n")]:
    fixture = root / f"{name}.md"
    fixture.write_text(content)
    minimal_pdf = run(fixture, root / name)
    assert minimal_pdf.read_bytes().startswith(b"%PDF-")
print("PASS blank code lines, tabs, long token, explicit oversize rejection, empty and minimal inputs")

summary = {
    "platform": platform.platform(),
    "compiler": "nightly-2026-10-14-38a3029",
    "representative_runs": records[:3],
    "representative_median_wall_seconds": statistics.median(r["wall_seconds"] for r in records[:3]),
    "pagination_run": records[3],
    "pdf_sha256": hashlib.sha256(pdfs[0].read_bytes()).hexdigest(),
    "pdf_bytes": pdfs[0].stat().st_size,
}
(root / "measurements.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps(summary, indent=2))
