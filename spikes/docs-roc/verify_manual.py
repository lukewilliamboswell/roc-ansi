"""Verify a rendered full manual against its checked conversion inventory.

Usage: python3 spikes/docs-roc/verify_manual.py OUTPUT_DIRECTORY
Requires Poppler's pdfinfo, pdftotext and pdfimages. No renderer execution or
network access occurs; verification.json is written beside the checked output.
"""

import argparse
import hashlib
import json
import re
import struct
import subprocess
from collections import Counter
from html.parser import HTMLParser
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def normalized(text):
    return " ".join(text.split())


def poppler(command, *arguments):
    result = subprocess.run([command, *map(str, arguments)], capture_output=True, text=True, check=True)
    return result.stdout


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = []
        self.links = []
        self.images = []
        self.code = []
        self.tables = 0
        self.headings = []
        self.in_pre = False
        self.heading = None

    def handle_starttag(self, tag, attributes):
        attributes = dict(attributes)
        if "id" in attributes:
            self.ids.append(attributes["id"])
        if tag == "a":
            self.links.append(attributes.get("href", ""))
        if tag == "img":
            self.images.append(attributes)
        if tag == "table":
            self.tables += 1
        if tag == "pre":
            self.in_pre = True
            self.code.append("")
        if re.fullmatch(r"h[1-6]", tag):
            self.heading = {"level": int(tag[1]), "id": attributes.get("id"), "title": ""}

    def handle_endtag(self, tag):
        if tag == "pre":
            self.in_pre = False
        if re.fullmatch(r"h[1-6]", tag) and self.heading is not None:
            self.headings.append(self.heading)
            self.heading = None

    def handle_data(self, text):
        if self.in_pre:
            self.code[-1] += text
        if self.heading is not None:
            self.heading["title"] += text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    output = parser.parse_args().output.resolve()
    manifest = json.loads((HERE / "manual-coverage.json").read_text())
    markdown = (ROOT / manifest["output"]).read_bytes()
    assert sha(markdown) == manifest["output_sha256"], "Markdown changed since conversion"

    for source in manifest["sources"].values():
        if source["generated"]:
            name = Path(source["source"]).relative_to("docs").as_posix()
            snapshot = ROOT / manifest["generated_snapshots"][name]["snapshot"]
            assert sha(snapshot.read_bytes()) == source["sha256"], snapshot
            production = ROOT / source["source"]
            if production.exists():
                assert sha(production.read_bytes()) == source["sha256"], production
        else:
            path = ROOT / source["source"]
            assert sha(path.read_bytes()) == source["sha256"], f"Source changed: {path}"

    expected_code = [block["sha256"] for block in manifest["code_blocks"]]
    markdown_code = re.findall(r"^```[^\n]*\n(.*?)^```", markdown.decode(), re.M | re.S)
    assert [sha(code.encode()) for code in markdown_code] == expected_code
    assert len(manifest["headings"]) == 34
    assert len(expected_code) == 8
    assert len(manifest["tables"]) == 6
    assert len(manifest["images"]) == 5

    page = Page()
    page.feed((output / "index.html").read_text())
    expected_headings = [{key: item[key] for key in ("level", "id", "title")} for item in manifest["headings"]]
    assert page.headings == expected_headings, "HTML heading inventory/order changed"
    assert len(page.ids) == len(set(page.ids)) == 34, "Missing or duplicate HTML anchors"
    assert [sha(code.encode()) for code in page.code] == expected_code, "HTML code changed source bytes"
    assert page.tables == 6
    assert len(page.images) == 5
    assert all(link[1:] in page.ids for link in page.links if link.startswith("#")), "Broken internal link"

    dimensions = []
    for image, source in zip(page.images, manifest["images"]):
        original = ROOT / "docs" / source["path"]
        data = original.read_bytes()
        assert data.startswith(b"\x89PNG\r\n\x1a\n")
        dimensions.append(struct.unpack(">II", data[16:24]))
        assert image["src"] == Path(source["path"]).name
        assert image["alt"] == source["alt"] and image["alt"].strip()
        assert (output / image["src"]).read_bytes() == data, "Output PNG differs from source"
    print("PASS current source/snapshot hashes, 34 headings/anchors, 8 exact code blocks, 6 tables, 5 original PNGs, alt text and internal links")

    pdf = output / "manual.pdf"
    info = poppler("pdfinfo", pdf)
    assert re.search(r"^Tagged:\s+yes$", info, re.M), "PDF is not tagged"
    assert re.search(r"^PDF version:\s+2\.0$", info, re.M)
    pages = int(re.search(r"^Pages:\s+(\d+)$", info, re.M)[1])
    page_info = poppler("pdfinfo", "-f", "1", "-l", pages, pdf)
    sizes = re.findall(r"^Page\s+\d+ size:\s+([\d.]+) x ([\d.]+) pts", page_info, re.M)
    assert len(sizes) == pages and all(float(width) == 595 and float(height) == 842 for width, height in sizes), "Every page must be A4"

    text = poppler("pdftotext", "-layout", pdf, "-")
    full_text = normalized(text)
    for heading in manifest["headings"]:
        assert normalized(heading["title"]) in full_text, f"Missing PDF heading: {heading['title']}"
    destinations = poppler("pdfinfo", "-dests", pdf)
    for heading in manifest["headings"]:
        assert f'"{heading["id"]}"' in destinations, f"Missing PDF destination: {heading['id']}"

    page_texts = [text for text in text.split("\f") if text.strip()]
    assert len(page_texts) == pages
    release = re.search(r"\.The latest release is ([^\n]+)", (HERE / "manual-inputs/generated/latest-release.adoc").read_text())[1]
    for number, text in enumerate(page_texts, 1):
        assert "Roc documentation experiment" in text, f"Missing footer: page {number}"
        assert re.search(rf"\b{number}\s*/\s*{pages}\b", text), f"Incorrect page field: page {number}"
        if number > 1:
            assert "roc-ansi / Manual" in text and release in text, f"Missing continuation header: page {number}"

    image_listing = poppler("pdfimages", "-list", pdf)
    embedded = []
    for line in image_listing.splitlines():
        fields = line.split()
        if len(fields) >= 5 and fields[0].isdigit() and fields[2] == "image":
            embedded.append((int(fields[3]), int(fields[4])))
    assert Counter(embedded) == Counter(dimensions), f"Wrong embedded image inventory: {embedded}"
    print(f"PASS {pages} tagged A4 PDF pages, every heading/destination, all 5 image dimensions and furniture on every page")

    summary = {
        "pdf_sha256": sha(pdf.read_bytes()), "pdf_bytes": pdf.stat().st_size,
        "pages": pages, "headings": len(page.headings), "code_blocks": len(page.code),
        "tables": page.tables, "images": len(page.images), "image_dimensions": dimensions,
        "markdown_sha256": sha(markdown), "source_inputs": len(manifest["sources"]),
    }
    (output / "verification.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
