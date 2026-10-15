# Roc documentation renderer spike

A bounded experiment for replacing the Asciidoctor Docker pipeline with
published roc-parser 2.0.0 and roc-pdf 0.1.0-rc3. Production documentation and
release workflows are unchanged.

`chapter.md` combines representative material from the existing manual:
headings, ordinary paragraphs, bold and emphasis, internal/external links,
fenced Roc and shell code, a full release dependency URL, the actual terminal
screenshot, tables, and ordered/unordered lists. One Markdown AST feeds both
HTML and PDF. The app reads Markdown at runtime: editing the chapter does not
require rebuilding the renderer.

## Run

From the repository root, with published Roc
`nightly-2026-10-14-38a3029` on PATH:

```sh
mkdir -p .roc-ansi-tmp
roc build spikes/docs-roc/main.roc --no-cache --output=.roc-ansi-tmp/docs-roc-renderer
.roc-ansi-tmp/docs-roc-renderer
```

Or run the source directly, avoiding the full native executable build:

```sh
roc spikes/docs-roc/main.roc
```

Open `.roc-ansi-tmp/docs-roc/index.html` or `manual.pdf`. Optional arguments
are an input Markdown file and output directory. The executable embeds its
fonts and screenshot fixture; rendering starts no other programs and needs
no Nix, Docker, Node, browser, Python or network access.

Fonts are copied byte-for-byte from the rc3 release's gallery sources and
retain their OFL notices under `fonts/`.

## Verify and measure

Python 3 and Poppler (`pdfinfo`, `pdftotext`, `pdfimages`) are test tools:

```sh
python3 spikes/docs-roc/verify.py .roc-ansi-tmp/docs-roc-renderer
```

The verifier checks three byte-identical PDF renders, exact HTML code text,
resolved internal anchors, table/image presence, tagged PDF 2.0 metadata,
extractable text, named destinations, original image dimensions, a 120-row
continuing table with repeated headers, and rejection of unsupported content
before output is published. Measurements go into
`.roc-ansi-tmp/docs-roc-verification/measurements.json`.

The isolated `Documentation renderer spike` workflow runs only for this spike
branch or a manual dispatch. It verifies and measures direct source execution
on Linux and uploads the previews and logs. A manual dispatch with `native`
enabled also measures full native compilation. Its Poppler installation is
test overhead, separate from renderer runtime.

## Initial Apple Silicon measurements

Measured on macOS 26.3.1 with the October 14 published compiler, default speed
build (`roc run` defaults to dev), package downloads already present. Individual observations, not an
end-to-end benchmark of the complete manual:

| Operation | Wall time | Peak RSS |
| --- | ---: | ---: |
| Build with `--no-cache` | 72.67 s | 4.13 GB |
| First normal build using compiler caches | 72.52 s | 4.78 GB |
| Direct `roc main.roc`, empty compiler cache, downloaded packages present | 6.39 s | 2.77 GB |
| Direct `roc main.roc`, existing compiler caches | 6.72 s | 2.73 GB |
| Render the two-page sample, median of three processes | 34.9 ms | 13.4–15.1 MB |
| Render the three-page, 120-row table probe | 27.9 ms | 11.9 MB |

The sample PDF is 41,209 bytes and the executable is about 10 MB. Internal
sample timings were 9 ms for lowering/font registration, 5 ms for PDF
preparation, and 14 ms for emission; parsing and HTML generation were below
the whole-millisecond resolution. Reported process wall time includes output
file writes and process startup. Memory values are decimal bytes from
`/usr/bin/time`, not allocation counters or macOS's broader memory-footprint
metric.

**Direct source execution is a plausible simple replacement; a prebuilt
renderer gives the lowest startup time and memory.** Compiling the whole
native executable in every documentation job is expensive, while running
`roc main.roc` took about six seconds on the sample and retained byte-identical
PDF output. A production design can instead build the renderer once for its
source/dependency/font/asset version, then reuse an integrity-verified
executable for changing Markdown inputs.
roc-pdf's own tests use `--no-cache` because the pinned compiler can reuse
procedures whose allocation behaviour depends on previous builds; this spike
does not establish compiler caches as a safe performance solution. Explicit
interpreter mode with `--no-cache` did not complete within a 90-second cap;
it was stopped and is not a supported timing result.

## Linux CI results and memory attribution

Both [native rendering](https://github.com/lukewilliamboswell/roc-ansi/actions/runs/38693005605)
and [direct source execution](https://github.com/lukewilliamboswell/roc-ansi/actions/runs/38693414084)
passed the output verifier on Ubuntu x86_64. The native and direct-source PDF
SHA-256 matches the macOS output exactly.

| Linux operation | Wall time | Peak RSS |
| --- | ---: | ---: |
| Native build, including initial package setup | 127.0 s | 5.67 GB |
| Already-built renderer, median of three processes | 51.6 ms | 12.3 MB |
| Direct source, first invocation on a fresh runner | 18.08 s | 2.84 GB |
| Direct source, subsequent invocations | 9.79–9.98 s | 3.66–3.72 GB |

The GB-scale source-execution numbers include compiler/runner work. They are
not the standalone PDF renderer's memory requirement. On macOS, the same
compiled renderer uses 9 MB for a one-paragraph control and about 16 MB for the
representative chapter; direct source execution uses about 3.5 GB for either
input. `roc check` of the full renderer alone uses about 1.7 GB with existing
compiler caches. `probe_memory.py` reproduces that separation with the chosen
compiler and native renderer executables.

The smaller standalone programs in `repro/` isolate this further using only
published dependencies and no fonts, screenshot, Markdown fixture or repo-local
modules. Each measurement uses a fresh compiler cache while sharing downloaded
package sources; the recorded controls are in `repro/measurements-macos.json`.
The October 14 nightly was still the latest published nightly when checked,
and the binary in `~/roc_nightly-macos_apple_silicon-2026-10-14-38a3029/roc`
matched the tested compiler byte-for-byte.

## Explicit optimization-mode matrix

`roc run` defaults to `--opt=dev`; `roc build` defaults to `--opt=speed`.
The initial build measurements above used **speed**, despite the earlier
incorrect dev label. All new measurements specify the mode explicitly.

Reproduce the two-page chapter comparison with:

```sh
python3 spikes/docs-roc/matrix.py /path/to/roc /path/to/cache/roc/packages
```

Each source invocation and build uses a separate empty compiler cache, sharing
only downloaded package sources. Commands run sequentially. Native execution
runs three times per successful build. Outputs must have identical PDF hashes.
Interpreter mode is source-only because it does not generate a native executable.
Each command has a 180-second cap; a timeout is not a completed timing or RSS
measurement. Results and raw timing/phase logs are under
`.roc-ansi-tmp/docs-roc-matrix/`. These are individual observations of the sample,
not the full manual or a statistical comparison of compiler memory consumption.

Measured with the October 14 published nightly on macOS arm64. RSS values
are decimal; each source/build cell is a single observation. Native wall
measurements have `/usr/bin/time`'s 10 ms resolution; internal render medians
are also shown to distinguish the optimized modes.

| Explicit mode | Source run: wall / RSS | Build: wall / RSS | Native run: wall / RSS | Internal render median |
| --- | ---: | ---: | ---: | ---: |
| dev | 6.47 s / 2.82 GB | 11.35 s / 4.00 GB | 0.79 s / 19.8–22.0 MB | 794 ms |
| speed | 73.21 s / 5.21 GB | 72.18 s / 5.99 GB | 0.03 s / 13.4 MB | 30 ms |
| size | 67.48 s / 5.91 GB | 67.89 s / 5.86 GB | 0.03 s / 13.2–13.6 MB | 32 ms |
| interpreter | 117.74 s / 4.54 GB | N/A | N/A | 112,202 ms (source run) |

Building and then rendering once takes approximately 12.14 s for dev,
72.21 s for speed, and 67.92 s for size. Peak RSS across those sequential
stages is the build peak, **not the sum**. Compiler processes have exited
before native runtime measurements begin. Every successful output PDF has
SHA-256 `317a480f590992f1a41c1c3081d2d83e29647bd0873082fae2f7a5a194a1ec0c`.
Exact measurements are in [results/matrix-macos.json](results/matrix-macos.json),
and build phase logs are alongside it.

The speed build spends 55.42 s in LLVM optimization/emission and 11.88 s in
specialization, including 10.25 s in LIR passes. Its type-checking phase is
0.87 s; shared lowering and compile-time evaluation take 3.29 s. These phase
RSS snapshots use a different sampling mechanism from `/usr/bin/time` and
should not replace the process peak RSS values in the table.

## Deliberate limits and migration work

- This is a representative chapter, not a converted complete manual. It
  does not replace AsciiDoc includes, release attributes, generated release
  snippets, multi-page website navigation, or the existing release-note
  parser. Preserve public URLs/anchors when doing that migration.
- HTML code remains exact and scrolls horizontally. PDF code is monochrome,
  tabs expand to four spaces, each source line is a paragraph, and lines over
  90 ASCII characters are visually wrapped. PDF-extracted code gains line
  boundaries and is not copy-exact. Non-ASCII code is rejected rather than
  split through UTF-8. A production preformatted-code layout needs explicit
  typography, spacing, wrapping and copy/paste policy.
- The only image is `animals.png`. roc-pdf accepts decoded RGB pixels, so
  `assets/animals.rgb` is a one-time lossless conversion of the existing PNG.
  `prepare_image.py` reproduces it with Python's standard library and checks
  the fixed screenshot encoding and chunk CRCs. It is not called by the
  renderer. A general PNG decoder or an authored image-preparation stage is
  still needed for other images.
- Heading IDs use a small ASCII slug policy; duplicate IDs, Unicode IDs and
  cross-chapter link resolution need a complete document-index policy.
- Only the demonstrated Markdown subset is accepted. Unsupported blocks,
  inline HTML, unknown images, task lists and inline strikethrough fail
  explicitly. Link titles, PDF table alignment parity, syntax highlighting,
  an italic font, running headers and visible page numbering are unfinished.
- The PDF uses rc3's default Archive profile. This spike checks tags and
  rendering with Poppler, not independent PDF/A or accessibility conformance.

The next decision is whether to adopt Markdown and direct Roc execution or a
reusable renderer executable. Once that is settled, convert all chapters and generated snippets,
implement the missing layout/indexing/image rules, and measure the complete
manual on Linux before replacing the production action.
