"""Convert this repository's bounded AsciiDoc manual subset to Markdown.

Run from the repository root. Generated release includes use the checked-in
include snapshots; the script performs no network requests and edits no docs/ files.
Unsupported structural syntax fails rather than silently disappearing.
"""
from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DOCS = ROOT / "docs"
OUTPUT = HERE / "manual.md"
MANIFEST = HERE / "manual-coverage.json"


@dataclass(frozen=True)
class SourceLine:
    text: str
    source: str
    line: int


def slug(text: str) -> str:
    return "".join(c.lower() if "A" <= c <= "Z" else c for c in text if c.isascii() and (c.isalnum() or c in " -")).replace(" ", "-")



class Converter:
    def __init__(self, generated: dict[str, str]):
        self.generated = generated
        self.files = {}
        self.headings = []
        self.images = []
        self.code = []
        self.tables = []
        self.exclusions = []
        self.labels = {}
        self.links = []
        self.attributes = {}

    def expand(self, name="index.adoc", offset=0, stack=()):
        if name in stack:
            raise ValueError(f"Recursive include: {name}")
        if name in self.generated:
            text = self.generated[name]
        else:
            path = DOCS / name
            if not path.resolve().is_relative_to(DOCS.resolve()):
                raise ValueError(f"Escaping include: {name}")
            text = path.read_text()
        self.files[name] = {"source": f"docs/{name}", "generated": name in self.generated, "sha256": hashlib.sha256(text.encode()).hexdigest(), "lines": len(text.splitlines())}
        result = []
        skipping_html = False
        for number, line in enumerate(text.splitlines(), 1):
            if line == "ifdef::backend-html5[]":
                skipping_html = True
                self.exclusions.append({"source": name, "line": number, "reason": "HTML-only download/GitHub links excluded from PDF"})
                continue
            if line == "endif::[]" and skipping_html:
                skipping_html = False
                continue
            if skipping_html:
                continue
            include = re.fullmatch(r"include::([^\[]+)\[(?:leveloffset=\+(\d+))?\]", line)
            if include:
                target = str(Path(name).parent / include[1])
                result.extend(self.expand(target, offset + int(include[2] or 0), stack + (name,)))
                continue
            heading = re.fullmatch(r"(=+) (.+)", line)
            if heading:
                line = "=" * (len(heading[1]) + offset) + " " + heading[2]
                self.headings.append({"source": name, "line": number, "level": len(heading[1]) + offset, "title": heading[2], "id": slug(heading[2])})
            result.append(SourceLine(line, name, number))
        if skipping_html:
            raise ValueError(f"Unclosed conditional in {name}")
        return result

    def inline(self, text):
        # Protect exact inline-code content before converting markup and URLs.
        protected = []
        def protect(match):
            protected.append(match[0])
            return f"\x00{len(protected) - 1}\x00"
        text = re.sub(r"`[^`]+`", protect, text)
        text = re.sub(r"\+\{([^}]+)\}\+", lambda m: "`{" + m[1] + "}`", text)
        def ref(target, label=None):
            if target not in self.labels:
                raise ValueError(f"Unknown manual anchor: {target}")
            self.links.append(target)
            return f"[{label or self.labels[target]}](#{target})"
        text = re.sub(r"xref:[^\s#]+#([\w-]+)\[([^\]]*)\]", lambda m: ref(m[1], m[2]), text)
        text = re.sub(r"<<([\w-]+)(?:,([^>]+))?>>", lambda m: ref(m[1], m[2]), text)
        text = re.sub(r"(https?://[^\s\[]+)\[([^\]]*)\]", lambda m: f"[{m[2] or m[1]}]({m[1]})", text)
        text = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", r"**\1**", text)
        if "xref:" in text or "<<" in text:
            raise ValueError(f"Unconverted reference: {text}")
        return re.sub(r"\x00(\d+)\x00", lambda m: protected[int(m[1])], text)

    def convert(self, lines):
        for heading in self.headings:
            if heading["id"] in self.labels:
                raise ValueError(f"Duplicate heading id: {heading['id']}")
            self.labels[heading["id"]] = heading["title"]
        out = []
        index = 0
        ordered = 0
        list_mode = None
        while index < len(lines):
            item = lines[index]
            line = item.text
            index += 1
            if not line:
                out.append("")
                continue
            attribute = re.fullmatch(r":([\w-]+):\s*(.*)", line)
            if attribute:
                self.attributes[attribute[1]] = attribute[2]
                continue
            if line in ("[.lead]", "****", "+"):
                continue
            heading = re.fullmatch(r"(=+) (.+)", line)
            if heading:
                out.append("#" * len(heading[1]) + " " + heading[2])
                ordered = 0
                list_mode = None
                continue
            source = re.fullmatch(r"\[source,([\w-]+)\]", line)
            if source:
                if lines[index].text != "----":
                    raise ValueError(f"Missing source delimiter: {item}")
                index += 1
                code = []
                while index < len(lines) and lines[index].text != "----":
                    code.append(lines[index].text)
                    index += 1
                if index == len(lines):
                    raise ValueError(f"Unclosed source block: {item}")
                index += 1
                content = "\n".join(code) + "\n"
                self.code.append({"source": item.source, "line": item.line, "language": source[1], "sha256": hashlib.sha256(content.encode()).hexdigest(), "lines": len(code)})
                out.extend(["", f"```{source[1]}", *code, "```", ""])
                continue
            table = re.fullmatch(r'\[cols="([0-9,]+)",options="header"\]', line)
            if table:
                columns = len(table[1].split(","))
                if lines[index].text != "|===":
                    raise ValueError(f"Missing table delimiter: {item}")
                index += 1
                cells = []
                while index < len(lines) and lines[index].text != "|===":
                    row_line = lines[index].text
                    if row_line:
                        if not row_line.startswith("|"):
                            raise ValueError(f"Unsupported table continuation: {lines[index]}")
                        cells.extend(cell.strip() for cell in row_line[1:].split("|"))
                    index += 1
                if index == len(lines) or len(cells) % columns:
                    raise ValueError(f"Unclosed or ragged table: {item}")
                index += 1
                rows = [cells[n:n + columns] for n in range(0, len(cells), columns)]
                self.tables.append({"source": item.source, "line": item.line, "columns": columns, "body_rows": len(rows) - 1, "source_column_weights": table[1]})
                out.append("| " + " | ".join(self.inline(cell) for cell in rows[0]) + " |")
                out.append("| " + " | ".join("---" for _ in range(columns)) + " |")
                out.extend("| " + " | ".join(self.inline(cell) for cell in row) + " |" for row in rows[1:])
                out.append("")
                ordered = 0
                list_mode = None
                continue
            image = re.fullmatch(r"image::([^\[]+)\[([^\]]+)\]", line)
            if image:
                self.images.append({"source": item.source, "line": item.line, "path": image[1], "alt": image[2]})
                out.append(f"![{image[2]}]({image[1]})")
                continue
            if line.startswith(".") and not line.startswith(". "):
                out.extend([f"**{self.inline(line[1:])}**", ""])
                continue
            definition = re.fullmatch(r"(.+?):: (.+)", line)
            if definition:
                out.append(f"- **{self.inline(definition[1])}**: {self.inline(definition[2])}")
                ordered = 0
                list_mode = "definition"
                continue
            if line.startswith("* "):
                out.append("- " + self.inline(line[2:]))
                ordered = 0
                list_mode = "bullet"
                continue
            if line.startswith(". "):
                ordered += 1
                out.append(f"{ordered}. {self.inline(line[2:])}")
                list_mode = "ordered"
                continue
            if line.startswith(("[", "include::", "ifdef::", "endif::", "----", "|===", "[[")):
                raise ValueError(f"Unsupported structural syntax: {item}")
            converted = self.inline(line.strip())
            if line.startswith("  ") and list_mode:
                out.append(("    " if list_mode == "ordered" else "  ") + converted)
            elif list_mode == "definition" and out and out[-1] != "":
                out.append("  " + converted)
            else:
                out.append(converted)
                ordered = 0
                list_mode = None
        return "\n".join(out).rstrip() + "\n"


def main():
    generated = {}
    for name in ["generated/latest-release.adoc", "generated/api-versions.adoc"]:
        source = DOCS / name
        snapshot = HERE / "manual-inputs" / name
        if source.exists():
            snapshot.parent.mkdir(parents=True, exist_ok=True)
            snapshot.write_bytes(source.read_bytes())
        if not snapshot.exists():
            raise ValueError("Run blueprint run install-snippet to generate release includes first")
        generated[name] = snapshot.read_text()
    converter = Converter(generated)
    converted = converter.convert(converter.expand())
    # Check the conversion boundary independently: code whitespace and the
    # document's structural inventory must survive Markdown serialization.
    emitted_code = re.findall(r"^```[^\n]*\n(.*?)^```", converted, re.M | re.S)
    actual_hashes = [hashlib.sha256(code.encode()).hexdigest() for code in emitted_code]
    if actual_hashes != [code["sha256"] for code in converter.code]:
        raise ValueError("Markdown serialization changed source-code bytes")
    if len(re.findall(r"^#{1,6} ", converted, re.M)) != len(converter.headings):
        raise ValueError("Markdown serialization changed heading inventory")
    if len(re.findall(r"^!\[", converted, re.M)) != len(converter.images):
        raise ValueError("Markdown serialization changed image inventory")
    OUTPUT.write_text(converted)
    manifest = {
        "entrypoint": "docs/index.adoc", "output": "spikes/docs-roc/manual.md",
        "generated_snapshots": {name: {"production_source": f"docs/{name}", "snapshot": str((HERE / "manual-inputs" / name).relative_to(ROOT)), "sha256": hashlib.sha256(content.encode()).hexdigest()} for name, content in generated.items()},
        "output_sha256": hashlib.sha256(converted.encode()).hexdigest(),
        "document_attributes": converter.attributes,
        "sources": converter.files, "headings": converter.headings,
        "code_blocks": converter.code, "tables": converter.tables,
        "images": converter.images, "internal_links": sorted(set(converter.links)),
        "exclusions": converter.exclusions,
        "warnings": [
            "HTML-only download/GitHub links intentionally follow the PDF backend conditional.",
            "Description-list terms become bold labels in Markdown bullet lists; wording is retained.",
            "Source block captions become bold paragraphs; screenshot captions retain their source labels.",
            "The continued code block in Make a release separates ordered groups; numbering resumes at 2.",
            "Release-note {package-url} is intentionally literal, matching the current AsciiDoc manual.",
            "AsciiDoc column weights are recorded here; the Markdown renderer currently chooses content widths.",
        ],
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}: {len(converter.files)} sources, {len(converter.headings)} headings, {len(converter.code)} code blocks, {len(converter.tables)} tables, {len(converter.images)} images")


if __name__ == "__main__":
    main()
