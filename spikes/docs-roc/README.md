# Roc documentation renderer spike

> Superseded baseline: the active integration now uses the released
> `roc-automation tools-0.1.0-rc.1` executable directly on the real AsciiDoc.
> See [ADOPTION.md](ADOPTION.md) for current commands, CI measurements,
> caching and remaining presentation gaps. The implementation and measurements
> below are retained as historical evidence; CI no longer compiles this renderer.

A bounded experiment for replacing the Asciidoctor Docker pipeline with
published roc-parser 2.1.0-rc.1 and roc-pdf 0.1.0-rc5. Production documentation and
release workflows are unchanged.

`chapter.md` combines representative material from the existing manual:
headings, ordinary paragraphs, bold and emphasis, internal/external links,
fenced Roc and shell code, a full release dependency URL, the actual terminal
screenshot, tables, and ordered/unordered lists. One Markdown AST feeds both
HTML and PDF. The app reads Markdown at runtime: editing the chapter does not
require rebuilding the renderer.

For roc-automation adoption, start with the [implementation handoff](HANDOFF.md). It includes the tested baseline, paths, dependency pins, commands, CI evidence, caching guidance and the production migration work.

## Shared highlighting and native source blocks

[`SyntaxHighlight.roc`](SyntaxHighlight.roc) is a standalone pure Roc module.
It depends only on the caller's `parser.RocSyntax` package, not HTML, PDF,
fonts, a platform or document layout. Copy it into another app declaring the
same parser dependency to reuse it. Its API provides:

- `highlight(source)` — sorted UTF-8 byte ranges covering the original text,
  with adjacent equal lexical categories merged; partial snippets are allowed.
- `text(source, span)` — original span text for an HTML adapter.
- `light` and `color(theme, category)` — a replaceable RGB theme.
- `foregrounds(theme, spans)` — non-trivia byte ranges with RGB colours.

The renderer maps those RGB values to `Color.srgb8` and passes the ranges to
rc5's `Pdf.source_block`. Both outputs use the same palette. Keywords, strings,
comments, names, types and numbers are coloured in the PDF as real tagged code
text. HTML retains exact source bytes. PDF source layout owns tab stops, CRLF
normalization, blank lines, measured wrapping and continuation across pages;
our old ASCII wrapper, per-line paragraphs and custom panel sizing are gone.
Shell/text fences use the same source layout without Roc token colours.

```roc
spans = SyntaxHighlight.highlight(source)
foregrounds = SyntaxHighlight.foregrounds(SyntaxHighlight.light, spans)
Pdf.source_block({
    text: source,
    face: mono_face,
    foregrounds: foregrounds.map(|span| {
        start: span.start, end: span.end, color: Color.srgb8(span.color),
    }),
})
```

The parser candidate's reference compiler is October 15; rc5's is October 14.
This consumer keeps `nightly-2026-10-15-38e6c42` and explicit **`--opt=speed`**
for verification. The earlier rc3/October 15 dev invalid-free observation is
recorded in the feedback report; it has not been re-established for rc5.
The full rc5 renderer also works under the PDF release's October 14 dev
compiler. Standalone highlighter properties can be checked with:

```sh
roc test spikes/docs-roc/SyntaxHighlight.roc --main=spikes/docs-roc/highlighter-example.roc
```

Rendering requires no JavaScript, compiler parser or external highlighter.
Historical measurements below describe their original dependency versions.

## Whole real manual

`manual.md` assembles the current `docs/index.adoc` include tree: all six
chapters, release 0.13.2, and both generated release/API includes. The bounded
stdlib converter preserves wording and exact fenced-code bytes. It records
source hashes, structural coverage and presentation adaptations in
`manual-coverage.json`; it fails on unsupported structure or unresolved links.
Generated includes are snapshotted under `manual-inputs/` for offline reproduction.
When `docs/generated/` exists, conversion refreshes those snapshots from the
production Blueprint task's output.

```sh
python3 spikes/docs-roc/convert_manual.py
roc spikes/docs-roc/main.roc --opt=speed -- spikes/docs-roc/manual.md .roc-ansi-tmp/docs-roc-full-manual
python3 spikes/docs-roc/verify_manual.py .roc-ansi-tmp/docs-roc-full-manual
```

Coverage: 10 input files, 34 headings, eight code blocks, six tables and all
five original screenshots. The full PDF has a separate cover and linked
contents page. This remains a spike; production uses the existing Asciidoctor
workflow. Conversion changes presentation constructs such as description lists
and captions, not the source wording. The manifest documents those choices.

## Run

From the repository root, with published Roc
`nightly-2026-10-15-38e6c42` on PATH:

```sh
mkdir -p .roc-ansi-tmp
roc build spikes/docs-roc/main.roc --opt=speed --no-cache --output=.roc-ansi-tmp/docs-roc-renderer
.roc-ansi-tmp/docs-roc-renderer
```

Or let Roc build/cache and execute the optimized source application:

```sh
roc spikes/docs-roc/main.roc --opt=speed
```

Open `.roc-ansi-tmp/docs-roc/index.html` or `manual.pdf`. Optional arguments
are an input Markdown file and output directory. The executable embeds its
fonts and all five screenshot fixtures; rendering starts no other programs and needs
no Nix, Docker, Node, browser, Python or network access.

The original fonts are copied byte-for-byte from the rc3 release's gallery
sources and retain their OFL notices under `fonts/`. The polished edition adds
a static Noto Sans italic font from an immutable official Noto source; its
matching license and provenance are recorded in [the feedback report](feedback/README.md).

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
branch or a manual dispatch. It compiles the optimized renderer once, then verifies and measures rendering
on Linux and uploads the previews and logs. A manual dispatch with `native`
enabled also measures full native compilation. Its Poppler installation is
test overhead, separate from renderer runtime.

## Polished manual experiment, October 16

The current renderer adds a cover with linked contents, differentiated
headings, an italic face, visible underlined links, measured shaded code
panels, full-width styled tables, and running headers/footers with current
and total page numbers. The fixture now includes the real Get started
explanations and run command. It is a four-page representative sample, not
the complete released manual.

The latest reviewed artifact is `.roc-ansi-tmp/docs-roc-polished-v2/manual.pdf`.
The second layout pass uses 11/15 pt body text, a narrower 471 pt measure,
consistent heading spacing and corrected PDF H1/H2 semantics. The first
polished version remains in `.roc-ansi-tmp/docs-roc-polished-final/`. Source
wording and generated HTML are unchanged between those layout passes.
[The roc-pdf experience report](feedback/README.md) separates features already
supported by rc3 from application work, documented package limits, reproduced
rough edges and candidate upstream issue material. `feedback/probe.roc` is a
small public-API reproduction file with no parent assets or fonts.

Code panels use one paragraph per visual line, with document paragraph spacing
set to zero and ordinary body paragraph gaps authored explicitly. This avoids
a reproduced rich-paragraph blank-line rejection while retaining code roles.
Long panels fail explicitly rather than clipping; native splitting is not
available for custom blocks. The verifier exercises consecutive blank lines,
tabs, long tokens, oversize panels, empty/minimal documents and page furniture
as well as the original content checks.

All timing tables and profiles below describe the **earlier two-page renderer**
at their linked commits. They are historical baselines, not measurements of
this polished edition.

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
it was stopped and is not a supported timing result. The later explicit-mode
matrix below completed interpreter execution with a longer cap.

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

## Samply hotspot investigation

Samply 0.12.0 captured all threads at 500 Hz. The published nightly lacks
Roc debug symbols, so the exact source revision
`38a3029aa71b239c79b380adab7e90d4a848df96` was downloaded into a temporary
checkout and rebuilt with Zig 0.17.0:

```sh
zig build roc -Doptimize=ReleaseFast -Dstrip=false \
  -Dcompiler-version=profile-nightly-2026-10-14-38a3029
python3 spikes/docs-roc/profile.py /path/to/symbolized/roc /path/to/cache/roc/packages
python3 spikes/docs-roc/summarize_profile.py .roc-ansi-tmp/docs-roc-profiles/check-import.json.gz
python3 spikes/docs-roc/summarize_profile.py .roc-ansi-tmp/docs-roc-profiles/build-speed.json.gz
```

The compiler rebuild took roughly 18 minutes locally, including preparation;
this is investigation overhead and is excluded from the renderer matrix.
These CPU profiles use fresh compiler caches with downloaded packages shared.
They are separate from benchmark measurements. Percentages below weight all
threads' samples by `threadCPUDelta` and deduplicate recursive occurrences of
the same function within a stack. Inclusive ancestor/descendant percentages
overlap and must not be added together.

| Capture | Stack/function | Inclusive sampled CPU |
| --- | --- | ---: |
| Tiny paragraph-only `roc check` | `monotype.lower.Builder.runSpecJobTask` | 23.56% |
| Same | `dev.ProcArtifact.extractPrepared` | 16.20% (16.13% self) |
| Same | `Check.checkFileInternal` | 10.17% |
| Full renderer, speed build | `ZigLLVMTargetMachineEmitToFile` | 58.56% |
| Same | `llvm::ModuleInlinerWrapperPass::run` | 25.11% |
| Same | `proc_passes.TaskContext.run` | 25.66% |
| Same | `range_prove.runProcWithScratch` | 9.31% |
| Same | `LirStore.getCFStmt` | 6.01% self |

The separately captured **published binary** agrees on LLVM dominating the
speed build (56.88% inclusive CPU), despite having unnamed Roc functions.
That published-binary profile overlapped the symbolized compiler rebuild;
use it as a CPU-stack cross-check, not an uncontended timing measurement.
The symbolized captures ran after that rebuild completed.

The small check case already performs substantial Monotype specialization and
dev-backend work for compile-time evaluation. Procedure-artifact extraction
is a concrete CPU target: its source loops over each code region and scans
unwind entries, references, relocations and line entries for that region.
Indexing these by region is a candidate to investigate, not a validated fix.
For the speed build, LLVM optimization and Roc LIR passes are distinct targets.

**CPU sampling does not identify the allocations responsible for peak RSS.**
The results do not prove a leak or that artifact extraction owns the GB-scale
memory. Allocation/live-heap measurements around checking, shared lowering,
compile-time evaluation and procedure passes are still needed. The speed build
phase log shows substantial RSS growth during specialization before LLVM starts.

The `results/` directory includes CPU summaries, profiling metadata and two
portable named profiles. To browse interactively without rebuilding the compiler:

```sh
samply load spikes/docs-roc/results/profile-check-import-named.json.gz
samply load spikes/docs-roc/results/profile-build-speed-named.json.gz
```

Portable profiles retain sampled frame structure; inlined function names are
joined within their frame. Original captures remain in `.roc-ansi-tmp/` for
full re-symbolication with the compiler binary. The renderer produced during
the symbolized capture passes the complete output verifier, including the
same byte-identical PDF and three-page table continuation probe.

## Deliberate limits and migration work

- The full current manual uses a bounded repository-specific AsciiDoc adapter.
  Multi-page website navigation, stable public URLs/anchors and production
  release integration still need migration work.
- HTML preserves code exactly. PDF retains rc5's canonical source policy:
  CRLF becomes LF, tabs expand at four-column stops, and visual wrapping/page
  continuation are handled by roc-pdf. PDF reader extraction behavior varies;
  we do not promise original tab/CRLF byte recovery from every viewer.
- The five screenshots use predecoded RGB fixtures. Other image encodings need
  a decoder or preparation stage. The renderer embeds its fonts/assets.
- Heading IDs use an ASCII slug policy; duplicate and Unicode IDs need a more
  general document-index policy. Unsupported Markdown still fails explicitly.
- Syntax highlighting is lexical rather than binding/type aware and currently
  applies to `roc` fences only. The PDF validates the resulting foreground
  ranges, including its extended-grapheme-boundary rules.
- Printed contents page references, chapter-aware headers, original AsciiDoc
  section numbering and table column weights remain presentation gaps.
- This spike validates tagged output, text, images, colour and pagination with
  Poppler; it does not independently establish PDF/A or accessibility conformance.

Production still uses Asciidoctor. The next integration step is to review the
whole manual's new source layout on Linux before replacing that workflow.
