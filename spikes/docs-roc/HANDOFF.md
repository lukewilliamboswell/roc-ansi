# Documentation renderer handoff for roc-automation

> Superseded baseline: the active integration now uses the released
> `roc-automation tools-0.1.0-rc.1` executable directly on the real AsciiDoc.
> See [ADOPTION.md](ADOPTION.md) for current commands, CI measurements,
> caching and remaining presentation gaps. The implementation and measurements
> below are retained as historical evidence; CI no longer compiles this renderer.

The roc-ansi spike demonstrates that **roc-parser and roc-pdf can render the complete current package manual to HTML and a highlighted PDF without Asciidoctor, Docker, Ruby, Node or a browser at render time**. The compiled Roc executable reads Markdown and writes both outputs. It embeds the fonts and five screenshots needed by this manual.

The next step is to turn that working renderer into a reusable roc-automation facility. **Production has not switched:** roc-ansi's documentation and release workflows still call the existing Docker-based `actions/build-docs`. The spike proves document rendering, not complete compatibility with that action's AsciiDoc, website, diagram and theme interfaces.

## Implementation baseline and results

Use branch `spike/roc-docs` in `lukewilliamboswell/roc-ansi`. The tested implementation is commit [`75df8efb085fb5f5fd90f5909a49dd7f5e364dcc`](https://github.com/lukewilliamboswell/roc-ansi/tree/75df8efb085fb5f5fd90f5909a49dd7f5e364dcc). The handoff and Linux measurements were added afterward without changing that implementation.

[Linux verification run 38864144441](https://github.com/lukewilliamboswell/roc-ansi/actions/runs/38864144441) passed. Its full-manual PDF is byte-identical to the macOS artifact:

| Item | Result |
| --- | --- |
| Included source files | 10: index, six chapters, release notes and two generated includes |
| Headings | 34 |
| Source examples | Eight, with exact original bytes retained in HTML |
| Tables and screenshots | Six tables and all five original PNG screenshots |
| PDF | 14 A4 pages, 149,487 bytes, tagged PDF 2.0 |
| Full PDF SHA-256 | `808baa2c20dc01c0ee1e992ed42bc77f8201af3c730e7bfd0f5c47b84aee30b0` |
| Syntax highlighting | Shared lexical categories and RGB theme in HTML and PDF |
| Rendering platforms tested | macOS arm64 and Linux x86_64 |

The reference document is the **current repository manual**, whose tooling instructions differ from the released 18-page Asciidoctor PDF. Page count and file size are not controlled comparisons against identical Asciidoctor input.

## Repository and artifact paths

All source paths below are relative to the roc-ansi repository root. The original checkout is `/Users/luke/Documents/GitHub/roc-ansi`; do not embed that machine-specific path in automation.

| Path | Purpose |
| --- | --- |
| [`spikes/docs-roc/main.roc`](main.roc) | Working renderer, CLI, Markdown adapter, HTML output, PDF theme and source-block integration |
| [`spikes/docs-roc/SyntaxHighlight.roc`](SyntaxHighlight.roc) | Standalone pure Roc token ranges and replaceable RGB theme; no PDF, HTML, font or platform dependency |
| [`spikes/docs-roc/highlighter-example.roc`](highlighter-example.roc) | Minimal independent consumer and package manifest for the highlighter |
| [`spikes/docs-roc/manual.md`](manual.md) | Complete converted manual used by the renderer |
| [`spikes/docs-roc/manual-coverage.json`](manual-coverage.json) | Source hashes, heading IDs, code hashes, tables, images, generated-input provenance and conversion adaptations |
| [`spikes/docs-roc/convert_manual.py`](convert_manual.py) | Bounded AsciiDoc-to-Markdown adapter for this repository's include tree |
| [`spikes/docs-roc/manual-inputs/generated/`](manual-inputs/generated/) | Snapshots of the production release/API snippets for offline reproduction |
| [`spikes/docs-roc/prepare_image.py`](prepare_image.py) | Stdlib PNG-to-RGB fixture preparation for the five screenshots |
| [`spikes/docs-roc/assets/`](assets/) | Decoded RGB fixtures embedded in the executable |
| [`spikes/docs-roc/fonts/`](fonts/) | Embedded Noto Sans and Source Code Pro faces, with OFL notices |
| [`spikes/docs-roc/verify.py`](verify.py) | Sample, colour, extraction, failure and pagination regression checks; native render measurements |
| [`spikes/docs-roc/verify_manual.py`](verify_manual.py) | Full manual checked against its source inventory |
| [`.github/workflows/docs-spike.yml`](../../.github/workflows/docs-spike.yml) | Isolated CI: build the optimized executable once, then run all fixtures |
| [`spikes/docs-roc/feedback/README.md`](feedback/README.md) | Detailed experience report, probes, upstream issues and historical measurements |
| [`spikes/docs-roc/feedback/rc5-measurements-macos.json`](feedback/rc5-measurements-macos.json) | Current macOS build, sample and full-manual evidence |
| [`spikes/docs-roc/feedback/rc5-measurements-linux.json`](feedback/rc5-measurements-linux.json) | Current Linux build/sample measurements and full-manual identity |
| [`spikes/docs-roc/README.md`](README.md) | Usage, design notes and earlier experiments |

Generated local artifacts are ignored by Git:

- `.roc-ansi-tmp/docs-roc-rc5/manual.pdf` and `index.html`: final macOS outputs.
- `.roc-ansi-tmp/docs-roc-rc5-draft/page-05.png`: reviewed page with the coloured release example.
- `.roc-ansi-tmp/docs-roc-rc5-linux/docs-roc-full-manual/`: downloaded Linux output and `verification.json`.
- `.roc-ansi-tmp/docs-roc-rc5-linux/docs-roc-ci/source-build.log`: Linux build resource measurements.
- `.roc-ansi-tmp/docs-roc-verification/`: generated regression fixtures and measurements.
- `.roc-ansi-tmp/docs-comparison/roc-ansi-0.13.2.pdf`: released Asciidoctor PDF used for visual comparison.

These local directories are convenience artifacts. Reproduce them from source; CI artifacts have seven-day retention.

## Dependencies and compiler

The current consumer header pins these immutable bundles:

```roc
cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.26.0-rc2/Gj3zVDr3qrQa6aTh7Z1zgUfe9NeBE6R76T5ho3xrc8af.tar.zst",
parser: "https://github.com/lukewilliamboswell/roc-parser/releases/download/2.1.0-rc.1/6dvNG3Q2mx53i4YPJN2ZGK98WdXnBMMuceAmDsCq7BEd.tar.zst",
pdf: "https://github.com/lukewilliamboswell/roc-pdf/releases/download/0.1.0-rc5/ANqp54fCvoErcZijX5Dr2cZj5G7ZzW6DYNLPj5GJBz4N.tar.zst",
```

CI uses **`nightly-2026-10-15-38e6c42` with explicit `--opt=speed`**. This exact combination passed on Linux and macOS. The parser candidate's reference compiler is October 15; rc5's reference compiler is October 14. The full renderer was also tested with October 14 dev execution and produced the identical PDF. The spike uses only the new parser's lexer/highlight API, not its full Roc syntax-tree parser.

An earlier rc3/October 15 dev executable aborted during PDF emission with an invalid realloc pointer. That historical result is not evidence that rc5 has the same problem. Retain the validated speed configuration for initial adoption rather than assuming a different compiler or execution mode has equivalent behavior.

The local compilers used were:

- `/Users/luke/roc_nightly-macos_apple_silicon-2026-10-15-38e6c42/roc`
- `/Users/luke/roc_nightly-macos_apple_silicon-2026-10-14-38a3029/roc`

## Rendering architecture

```text
Current AsciiDoc chapters and generated includes
    -> repository-specific conversion and coverage manifest
    -> Markdown
    -> roc-parser Markdown AST
        -> HTML renderer
        -> roc-pdf document, preparation and PDF bytes

Roc fenced source
    -> RocSyntax lexer
    -> SyntaxHighlight categories and RGB theme
        -> HTML spans and CSS
        -> source_block foreground byte ranges
```

The Markdown AST is shared by both outputs. The application prepares the PDF before writing new output files, so unsupported document requests reject before publishing a new manual. Production output publication should additionally stage files and replace the output directory atomically on success.

The compiled renderer has **no render-time dependency** on Nix, Docker, Ruby, Node, Chromium, Python, Poppler or network access. Compiling/downloading packages and preparing the current input fixtures are separate stages. The current Python converter and image preparer remain part of reproduction; they are not a general pure Roc AsciiDoc or PNG implementation.

### Source highlighting and layout

`SyntaxHighlight.roc` supplies original UTF-8 byte ranges, categories, a light theme, category-to-colour lookup and renderer-neutral RGB foregrounds. It uses `RocSyntax.tokenize_str`, so incomplete snippets can be displayed without parsing a complete valid file or typechecking it. Adjacent equal categories are merged, including string delimiters and contents. It performs no whitespace normalization.

The HTML adapter slices and escapes the original text. The PDF adapter converts RGB values to `Color.srgb8` and supplies the original byte ranges to `Pdf.source_block` with a registered monospace face. Roc-pdf owns CRLF normalization, tab stops, Unicode shaping, measured wrapping, foreground validation and page continuation. It retains `P > Code` semantics and canonical source `ActualText`; backgrounds remain artifacts. Code is searchable text rather than a screenshot or a set of decorative labels.

Rc5 replaced the spike's ASCII wrapper, manual tab replacement, per-line paragraphs, measured custom panels and unsplittable code boxes. A 100-line code fixture now continues across pages with every unique line retained once. Non-Roc fences use the native source-block layout without Roc token colours. The current highlighter is lexical, not binding/type aware.

### Fonts and images

The PDF embeds regular, bold, italic and monospace fonts. Preserve their OFL files and provenance when moving them. The renderer uses registered faces rather than depending on host font installation.

All five original PNGs are copied into the HTML output. Their decoded RGB data is embedded for PDF use. `prepare_image.py` supports the screenshots' non-interlaced 8-bit RGB encoding and verifies PNG chunk CRCs. It is not a general PNG decoder: indexed, alpha and other image formats need a deliberate decoding/preparation design. The current executable hardcodes those image names and dimensions, so it is not yet a generic asset loader.

## Reproduce and verify

From the repository root, put the pinned October 15 compiler on PATH. Python 3 is needed for fixture conversion/checking; Poppler provides `pdfinfo`, `pdftotext`, `pdfimages`, `pdftocairo` and optional `pdftoppm` previews. On Ubuntu, install `poppler-utils` for verification.

```sh
python3 spikes/docs-roc/convert_manual.py
python3 spikes/docs-roc/prepare_image.py

roc fmt --check spikes/docs-roc/main.roc spikes/docs-roc/SyntaxHighlight.roc spikes/docs-roc/highlighter-example.roc
roc test spikes/docs-roc/SyntaxHighlight.roc --main=spikes/docs-roc/highlighter-example.roc

mkdir -p .roc-ansi-tmp
roc build spikes/docs-roc/main.roc --opt=speed --no-cache --output=.roc-ansi-tmp/docs-roc-renderer

.roc-ansi-tmp/docs-roc-renderer spikes/docs-roc/manual.md .roc-ansi-tmp/docs-roc-full-manual
python3 spikes/docs-roc/verify.py .roc-ansi-tmp/docs-roc-renderer
python3 spikes/docs-roc/verify_manual.py .roc-ansi-tmp/docs-roc-full-manual
```

Without arguments the executable renders the four-page `chapter.md` fixture. With arguments it accepts exactly an input Markdown path and an output directory. It writes `index.html`, `manual.pdf` and the five PNG assets. It currently does not accept metadata, theme or output-filename arguments.

The converter uses checked-in generated snapshots when `docs/generated/` is absent. If that directory exists, it refreshes the snapshots from those files. To update release-dependent content intentionally, run the existing production task first:

```sh
blueprint run install-snippet
python3 spikes/docs-roc/convert_manual.py
```

That task uses [`scripts/write_install_snippet.roc`](../../scripts/write_install_snippet.roc). Review the resulting snapshots, Markdown and coverage manifest together. Conversion is a bounded adapter for this repository: it follows includes, preserves eight fenced examples byte-for-byte, maps references and records presentation adaptations. It is not a general AsciiDoc parser. HTML-only conditional links are intentionally excluded following the PDF backend path; that exclusion is recorded in the manifest.

For a standalone highlighter demonstration, copy `SyntaxHighlight.roc` and `highlighter-example.roc` into an empty directory and run:

```sh
roc highlighter-example.roc -- 'app [main!] {} # example'
```

This isolated consumer was tested outside the repository with no PDF package, fonts or manual assets.

## Validation evidence

The current checks establish:

- Three deterministic sample PDF renders; exact HTML code; unique/resolved manual anchors; complete tables and original PNGs with alt text.
- Tagged A4 PDF output, source `Code` structure, extractable text, named destinations and correct header/footer page fields.
- A continuing 120-row table with repeated headers and its final row present.
- Blank code lines, tab expansion, a 220-character token, Unicode code, incomplete snippets and a 100-line source block spanning pages without lost or repeated lines.
- Actual PDF token colours checked through Poppler SVG output, alongside source preservation. A monochrome PDF cannot satisfy that colour assertion.
- Unsupported HTML and unknown images reject before new output files are written.
- Full source/snapshot hashes, all 34 headings, eight source-code hashes, six tables, five PNGs, image dimensions and all destinations against `manual-coverage.json`.
- Identical full-manual PDF bytes between macOS and Linux, and between the two tested local compiler configurations.

Roc-pdf rc5's release supplies its own PDF/A-4 and independent-reader evidence. This application-level Poppler suite does not independently establish PDF/A or PDF/UA conformance. Reader copy/extraction behavior can differ; canonical LF/tab-expanded source is the relevant PDF contract, not byte-identical recovery of original tabs and CRLF from every viewer.

## Compilation cost and caching

The large resource cost is still compilation. Separate it from execution when comparing against Docker or planning CI.

| Current rc5 operation | Time | Peak RSS | Scope |
| --- | --- | --- | --- |
| Linux optimized build with `--no-cache` | 130.93 s | 6.25 GB decimal | Compiler cache disabled; some downloaded packages already present |
| Linux already-built sample renderer | 64.65 ms median | About 13.6 MB decimal | Three processes, four-page sample |
| macOS optimized build with `--no-cache` | 123 s reported | Not recorded in this run | Compiler-reported build duration |
| macOS already-built sample renderer | 64.33 ms median | 15.4–19.0 MB decimal | Three processes, four-page sample |
| macOS full 14-page render | 242 ms internal stage time | Not recorded for rc5 full manual | Excludes process startup and output-file writes |

See the two `feedback/rc5-measurements-*.json` files for exact values. `--no-cache` disables compiler/executable caches; it does not erase downloaded packages or flush filesystem caches. These are not cold-network or cold-disk benchmarks. These figures do not establish an end-to-end speedup or bandwidth saving against an identically configured Asciidoctor job. Earlier GB-scale compiler/mode investigations are in the experience report and [roc-lang/roc #12304](https://github.com/roc-lang/roc/issues/12304).

The spike CI builds once, then reuses the executable across every fixture. It does not yet implement a persistent renderer-binary cache or publish reusable renderer releases.

For roc-automation, cache or distribute a verified optimized executable. Include OS/architecture, compiler/platform version, renderer/module sources, immutable dependency URLs, embedded fonts, theme resources and embedded images in the cache key. Markdown content is read at runtime, so prose-only edits should not invalidate a binary whose embedded resources are unchanged. If assets become runtime-loaded, update the key and validation model accordingly.

Keep downloaded package caching separate from compiled-binary caching. Immutable package URLs avoid ambiguous dependency identity, but do not make a compiler invocation free. A reusable released CLI could avoid compiling the renderer in each consumer entirely. Validate cached/released executables against the same output corpus; the older compiler-cache experiments are not a blanket guarantee that every cache/execution mode is interchangeable.

## Preserve the production action contract

The current action is pinned at `7fdb8be46b12da9b119023c3a5aac28a9fdaa72b`:

- [`roc-automation/actions/build-docs/action.yml`](https://github.com/lukewilliamboswell/roc-automation/blob/7fdb8be46b12da9b119023c3a5aac28a9fdaa72b/actions/build-docs/action.yml)
- [`build_docs.py`](https://github.com/lukewilliamboswell/roc-automation/blob/7fdb8be46b12da9b119023c3a5aac28a9fdaa72b/actions/build-docs/build_docs.py)

It builds a Docker image, renders top-level AsciiDoc files to a multi-page HTML site, renders the entrypoint PDF, copies static/theme files and optionally generates API docs. Its diagram support invokes Asciidoctor Diagram/Mermaid tooling. The spike does not implement that diagram path.

| Existing interface | Required migration treatment |
| --- | --- |
| `docs-directory`, `entrypoint` | Choose a supported authoring format and define include/source resolution; the current entrypoint expects `.adoc` |
| `output-directory` | Preserve the site's output layout and workspace path validation |
| `pdf-filename` | Rename/link the PDF consistently; current spike hardcodes `manual.pdf` |
| `docs-version` | Make cover, running headers, HTML/PDF metadata and generated content use supplied metadata; current spike hardcodes `0.13.2` |
| `theme-directory` | Define a new reusable theme contract or explicit migration; current Asciidoctor YAML/CSS/Mermaid configuration is not a Roc theme |
| `api-entrypoint`, `roc-command` | Preserve optional API generation as a separate stage; it is not part of the spike renderer |
| Output `site-directory` | Continue returning the absolute site path |
| Output `pdf-path` | Continue returning the absolute PDF path |

Existing output layout is `.docs-out/site/` plus `.docs-out/<pdf-filename>`, with a copy of the PDF in the site. The spike emits both files into one directory, so an action adapter must restore that layout and correct HTML download links.

In roc-ansi, preserve these callers:

- [`.github/workflows/docs.yml`](../../.github/workflows/docs.yml): generate release snippets, render documentation, add API references, upload the site, then deploy only from the default branch.
- [`.github/workflows/release.yml`](../../.github/workflows/release.yml): versioned release PDF names and main-site documentation builds.
- [`scripts/build_site.roc`](../../scripts/build_site.roc) and [`scripts/src/Site.roc`](../../scripts/src/Site.roc): API reference of main and releases, operating on `.docs-out/site` or `SITE_OUTPUT`.
- [`scripts/package_docs.roc`](../../scripts/package_docs.roc): release API-documentation archives; it is a separate concern from the manual PDF.

Keep PR jobs artifact-only and retain the existing deploy permissions and release ordering. The manual renderer should not take over GitHub release discovery, API archive restoration or Pages deployment.

## Reusable implementation work

1. **Choose the authoring boundary.** Native Markdown is the demonstrated parser input. Either migrate current AsciiDoc authoring deliberately or provide a supported conversion layer. Do not ship this small converter as general AsciiDoc compatibility. Preserve existing HTML-only content, includes and generated release data where required.
2. **Extract a renderer library and CLI.** Separate document/AST adaptation, metadata, theme/fonts, asset resolution, link indexing and output writing from roc-ansi branding. Keep `SyntaxHighlight.roc` independent; adapt its RGB spans at the renderer boundary. Expose title, author, version, language, output names and theme configuration at runtime.
3. **Generalize assets.** Decide on runtime image decoding versus a preparation step, preserve alt text and font licences, and stop compiling five repository-specific screenshots into the reusable engine. Prepare any embedded assets before compilation.
4. **Preserve site URLs.** The spike produces one HTML page, whereas the current action produces multiple pages. Define stable heading IDs, duplicate/Unicode ID handling, cross-page links and redirects before adoption. Preserve API and download links alongside the manual.
5. **Resolve the remaining presentation gaps.** Printed contents page numbers, chapter-aware running headers, AsciiDoc section numbering and source table column weights are not implemented in the spike. Parameterize cover/footer text. Decide which are required for an initial reusable release.
6. **Handle diagrams explicitly.** Inventory Mermaid/AsciiDoc Diagram usage in consuming repositories. Support an agreed renderer or pre-rendered vector/raster assets; do not silently lose diagrams when removing Docker.
7. **Package and cache the executable.** Build once per platform and renderer/resource version, verify integrity, and reuse for changing documents. Keep compiler benchmarking separate from render-time measurements.
8. **Port the acceptance corpus.** Include exact source/anchors/images, Unicode and whitespace, long code/table continuation, actual colours, deterministic bytes, output-path handling and unsupported inputs. Add the multi-page website, metadata/version and action-output cases that the spike does not cover.
9. **Adopt behind an explicit backend choice.** Render representative repositories with both paths, compare the full site and PDF, and switch callers after the new backend satisfies their content/URL requirements. Remove Asciidoctor/Docker dependencies once remaining consumers and diagrams are accounted for.

## Upstream changes enabled by this work

The experience reports led to completed roc-pdf issues:

- [#42](https://github.com/lukewilliamboswell/roc-pdf/issues/42): unusable optional custom-block defaults.
- [#43](https://github.com/lukewilliamboswell/roc-pdf/issues/43): independent header/footer typography.
- [#44](https://github.com/lukewilliamboswell/roc-pdf/issues/44): repeated rich-text segments rejecting ordinary ASCII.
- [#45](https://github.com/lukewilliamboswell/roc-pdf/issues/45): native preformatted source layout and page continuation.
- [#47](https://github.com/lukewilliamboswell/roc-pdf/issues/47): foreground ranges for external syntax highlighters.

Rc5 includes the source and foreground APIs we now use. Our highlighter/module design follows the established separation between lexing, theme choice and document rendering, while leaving language parsers outside roc-pdf. No roc-parser defect was established by this exercise.
