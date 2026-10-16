# roc-pdf experience report: a polished package manual

This experiment replaces the presentation of an Asciidoctor manual with a
renderer written in Roc. It evaluates the published **roc-pdf 0.1.0-rc3**
facade, not private `Kernel*` modules. Production documentation workflows
remain unchanged. The original sample is retained alongside a conversion of the whole current
manual: 10 included inputs, 34 headings, eight code blocks, six tables and five
screenshots. This is the current repository manual, so its content differs
from the released 18-page Asciidoctor PDF.

Tested on macOS arm64 with the published Roc compiler
`nightly-2026-10-14-38a3029`, basic-cli 0.26.0-rc2 and roc-parser 2.0.0.
The dependency URLs are content-locked in `../main.roc` and `probe.roc`.
rc3 was still the newest published roc-pdf release when checked on October 16.
Its annotated release tag resolves to source commit
`d654eca959f9ff536d983ca728f974a23960cf71`.

## What worked through the existing public API

The original plain PDF's visual weaknesses were mostly renderer choices.
The facade already supports registered regular/bold/italic/monospace faces,
per-level headings, coloured and underlined links, table header/body fills,
content-sensitive columns, rules and drawings, bookmarks, named destinations,
page templates, and current/total page fields in headers and footers.

Those features let us add a cover and linked contents, a coherent heading
hierarchy, italic emphasis, styled tables, shaded source panels, and page
furniture without changing roc-pdf. Text stays searchable and the PDF remains
tagged. Repeated table headers and explicit keep constraints are valuable.
`measure_custom_content` provides a public way to size a panel using the same
layout rules as preparation. Fit failures are explicit rather than clipped.

The preparation report is useful for validation: it exposes block paths,
page ranges, layout outcomes, and human-review obligations. A report and
structure tags do not independently prove accessibility or PDF/A conformance.

## Priority feedback

| Priority | Finding | Classification | Effect on the manual |
| --- | --- | --- | --- |
| High | ASCII blank code lines reject with a grapheme-cluster diagnostic | Reproduced defect candidate | A valid-looking sequence of code and line-break inlines is rejected with the default font; the adapter uses one paragraph per code line. |
| High | Preformatted code requires a custom extension | Authoring feature request | We own indentation, blank-line policy, tab expansion, wrapping and panel measurement instead of describing a source block. |
| High | Custom panels cannot fragment across pages | Documented limit | A long code sample needs manual chunking or must fail; a short panel may leave substantial whitespace when moved to the next page. |
| Medium | Local style scopes change colours only | Authoring feature request | Code cannot independently choose its line leading; header/footer text uses the body style. |
| Medium | No ordinary inline presentation span | Authoring feature request | Syntax token colours cannot be expressed independently of semantic roles without dropping to lower-level authoring or misusing emphasis/strong. |
| Medium | Body generated references are unavailable | Documented roadmap item | Linked contents work, but automatic destination page numbers and cross-reference page fields need application-managed layout passes. |
| Medium | Running headers have only first/continuation templates | Authoring feature request | A static document title is easy; the current chapter name requires application-side page planning. |
| Small | Omitting a custom block's optional panel rejects | Reproduced API-default inconsistency to investigate | The facade supplies an empty drawing by default, but preparation rejects that default drawing. |

These are observations of the rc3 public facade. They do not assert that the
underlying PDF format or lower-level package modules cannot represent them.

### Candidate issue: ASCII blank code lines reject as a multi-scalar cluster

This small public facade expression fails with the default packaged font:

```roc
Pdf.rich_paragraph([
    Pdf.code("first"), Pdf.line_break,
    Pdf.code(" "), Pdf.line_break,
    Pdf.code(" "), Pdf.line_break,
    Pdf.code("last"),
])
```

The rejection is `text.unsupported_cluster` at
`contents[0].inlines[4].inlines[0]`, claiming an inline boundary falls inside
an unsupported multi-scalar grapheme cluster. The authored text is ASCII.
A short ordinary two-line control (`xxxx`, line break, `xxxx`) is accepted.
Reproduce with `probe.roc -- blank-breaks`; use `short-ascii-break` for the
accepted control. This requires no external font, parser or custom panel.

The same diagnostic was reproduced using both direct dev source execution
with `--no-cache` and a native `build --opt=speed --no-cache` executable.
This is not isolated to compiler-cache reuse or the dev execution backend.
The exact cause inside the shaper or compiler has not been reduced further;
we report the facade behaviour rather than assert an internal fix.

The first renderer attempt also rejected a long token split across several
`Code` inlines under its registered mono font. The default-font blank case
is the smaller independently confirmed reproduction. The final adapter avoids
this path by placing each visual source line into a separate rich paragraph,
using a space-only code paragraph for an empty line. It sets global
paragraph spacing to zero and adds ordinary body paragraph gaps itself. That workaround passes
blank-run, tab and 220-character token checks, but costs application-level
layout policy and is not a replacement for a code-block primitive.

### Candidate issue: a preformatted source block with fragmentation

Desired behaviour: author a code block from its exact source text, with a
monospace face, local size/leading, preserved indentation and blank lines,
explicit tabs/wrap policy, and optional panel decoration. Long blocks should
continue across pages at line boundaries, with a clear continuation policy.
Optional token styling should affect visual presentation without inventing
semantic emphasis for keywords and strings.

Our final workaround combines per-line `Pdf.code` paragraphs,
`Pdf.measure_custom_content`, a rectangle drawing and `Pdf.custom_block`.
The initial rich-paragraph/line-break approach exposed the rejection above.
The custom block only permits `Unsplittable`. Hard wrapping and tab expansion
are our renderer's choices, not evidence of a package defect. We do not claim
copy-exact source recovery from the PDF; HTML preserves the original source.

The absence of a local size/leading scope makes a source panel's text spacing
depend on the document body style. A generic block presentation scope could
help other extensions as well as code. `Theme.Scope` explicitly limits itself
to fill colours, so this is a request to extend capabilities, not a bug report.

### Candidate issue: custom block's default empty panel rejects

The public `Pdf.CustomBlock` declares
`panel : Scene.Drawing ?? Scene.Drawing.empty`. A small custom block with
valid text and an explicit size, but no panel field, fails with:

```text
layout.custom_block_drawing at contents[0]:
A custom block's panel is not a supported panel drawing: it has no commands.
No PDF bytes were emitted.
```

Reproduce with the `default-empty-panel` mode of `probe.roc`. Its box is
400 × 80 pt with an 8 pt inset; this is not an oversize case. Confirm whether
an undecorated measured block should be supported. Either accept the empty
default as no decoration, or make the mandatory drawing requirement visible
in the public type and documentation.

### Known limit: independently styled header and footer text

The layout-only pass tried to make page furniture smaller and less prominent
than the body. `Pdf.furniture_text` inherits the body text style and has no
independent size/leading parameter. `Scene.Drawing.text` does offer an explicit
label size, but using that drawing with `Pdf.furniture_image` rejects:

```text
layout.furniture_drawing at templates.first.header.start[0]:
A furniture drawing is not a supported decorative drawing:
text labels are not supported in furniture drawings; use furniture text.
```

The standalone `small-furniture-label` probe uses an 8 pt drawing label in an
18 pt header region and reproduces the rejection under dev `--no-cache`.
This is an explicit facade limitation, not a new rendering defect. A typed
furniture text style (face, size, leading and colour), measured with the same
fit checks as body content, would support standard running-head treatments.
The renderer retains ordinary text rather than misusing a `Code` or `Emphasis`
role merely to obtain a smaller visual font.

### Known limit: generated references and running chapter headings

`Pdf.page_number` and `Pdf.total_pages` work in page furniture. Putting a page
field into a body rich paragraph rejects with `document.generated_reference`,
whose diagnostic explicitly schedules body references for Gate 8. This is
expected behaviour, not a newly discovered regression.

For a traditional manual, a useful API would resolve destination page labels
in body content and a contents list, with stable pagination. The preparation
report can inform an application-owned multi-pass workaround, but it exposes
block paths rather than a direct destination-to-page authoring primitive.
Separate from page numbers, chapter-aware running headings would need section
context or per-section page templates; the current facade offers one first
page template and one continuation template.

## Standalone public-API probes

`probe.roc` needs only its public immutable platform/package URLs. It can be
copied into an otherwise empty directory; no fonts, images or parent modules
are required. Run from the repository root with the published compiler:

```sh
roc spikes/docs-roc/feedback/probe.roc -- body-page-field
roc spikes/docs-roc/feedback/probe.roc -- footer-page-field
roc spikes/docs-roc/feedback/probe.roc -- tall-panel
roc spikes/docs-roc/feedback/probe.roc -- default-empty-panel
roc --no-cache spikes/docs-roc/feedback/probe.roc -- small-furniture-label
roc --no-cache spikes/docs-roc/feedback/probe.roc -- blank-breaks
roc --no-cache spikes/docs-roc/feedback/probe.roc -- short-ascii-break

roc build --opt=speed --no-cache spikes/docs-roc/feedback/probe.roc --output=/tmp/roc-pdf-probe
/tmp/roc-pdf-probe blank-breaks
```

| Mode | Observed result |
| --- | --- |
| `body-page-field` | `document.generated_reference` at `contents[0].inlines[1]` |
| `footer-page-field` | Accepted; 11,167 PDF bytes generated |
| `tall-panel` | `layout.oversize_block`: 800 pt panel versus 698 pt page flow |
| `default-empty-panel` | `layout.custom_block_drawing`: the default drawing has no commands |
| `small-furniture-label` | `layout.furniture_drawing`: text labels cannot be used in furniture drawings |
| `blank-breaks` | `text.unsupported_cluster` despite ASCII-only text |
| `short-ascii-break` | Accepted; 8,421 PDF bytes generated |
| `ascii-break` | A word wider than the default body frame gets `pipeline.lines.line_layout.unbreakable`; its diagnostic describes an internal precondition/package defect |

Each probe catches and prints the result so the process exits successfully
even for expected preparation rejection. See `probe-results.json` for the
recorded output, including the original seven cases run using an optimized
executable built with `--no-cache` and the later furniture-label probe run
using dev `--no-cache`. The wide-word diagnostic is a secondary error-reporting
rough edge; the sample does exceed the available line width and we do not
claim it should fit without wrapping. None of the rejection cases emits
partial PDF bytes.

## Image authoring experience

The real manual's terminal screenshots are PNGs. This spike predecodes all
five screenshots once into RGB8; rendering uses `Image.Source.rgb8` and does
not invoke Python or an external renderer. The public image facade also has
an encoded sRGB JPEG constructor, so encoded images are not generally absent.
A documented bridge from a PNG decoder to the RGB8 source would make this
common documentation use case easier. The five-image filename mapping and
fixed dimensions remain adapter limitations.

## First polished artifact and validation

The first reviewed artifact is `.roc-ansi-tmp/docs-roc-polished-final/manual.pdf`:
**four pages, 51,524 bytes**, SHA-256
`a1e82e51ed1d07be662c98c9641bc42e20250e9cf6ac635afaa9f8eaaaf1344b`.
It includes cover/contents, the real Get started explanations, sample screenshot
and examples table, contributor checks, and release/maintenance summary.
The package URL wraps at a path separator before the complete content hash.

The agent's implementation went through four visual review rounds with the
parent reviewer. Both dev and optimized execution produced the same PDF.
The final native executable was built explicitly with `--opt=speed --no-cache`.
Source formatting, checking and two expectations pass. The extended verifier
passes deterministic rendering, exact HTML source code, intact URL characters,
PDF text/tags/destinations, screenshot dimensions, every page's furniture,
120-row table continuation with repeated headers, consecutive blank code
lines, tabs, a 220-character unbroken token, explicit oversized-panel rejection,
and empty/minimal input. The final render still rejects non-ASCII code as an
adapter policy; this does not demonstrate a Unicode limitation in roc-pdf.

On this macOS arm64 machine, the already-built renderer's median wall time
across three processes was **43.2 ms**, with **14.1 MB peak RSS**. Those figures
exclude compilation. Exact values are in `polished-measurements-macos.json`.
Rasterization/text checks use Poppler; no independent conformance validator
was run. The earlier apparent missing furniture/overlap in intermediate PNG
previews did not reproduce when the same PDFs were freshly rasterized; those
preview artifacts are not reported as package defects.

## Second layout pass: fixed wording, larger type and better balance

The next reviewed artifact is `.roc-ansi-tmp/docs-roc-polished-v2/manual.pdf`:
**four pages, 51,774 bytes**, SHA-256
`f9f758be04f259bdbca0e1b9a5bd36a735b6c4b486804affffec7292b75f75bd`.
The first polished PDF remains available for comparison.

This pass changes presentation only. Source Markdown and rendered HTML are
byte-for-byte identical to the first polished edition. Body text is now
11 pt with 15 pt leading, in a 471 pt column instead of 491 pt. The larger
text and narrower measure improve reading comfort. Layout uses a consistent
6/12/18 pt spacing scheme, with an explicit 6 pt gap after headings. Tables
flow onto the last page more evenly, avoiding the earlier dense third page
and sparse fourth page. Mono text stays approximately 9 pt (82% of the body
size); its visual wrapping budget is 83 columns. Code leading still follows
the body because independent per-block leading remains a facade limit.

The PDF chapter headings are now `H1` and subsections `H2`, while the cover
uses `Title`; Contents is a separate `H1`, rather than the apparent parent
of all chapters. Outline depths are adjusted consistently. The verifier now
inspects the recognized heading sequence as well as destinations and text.
Poppler's warnings about the newer PDF 2.0 `Title`, `Strong` and `Em` roles
are not treated as proof of an invalid PDF or a full accessibility verdict.

Two additional visual review rounds checked this pass before an explicit
`--opt=speed --no-cache` build. The full verifier passes, and the dev and
optimized PDFs match byte-for-byte. The larger body makes the 120-row table
probe six pages including its cover; all rows and repeated headers survive.
The native renderer's median runtime is 42.5 ms at 14.1–14.3 MB peak RSS;
compilation is excluded. Exact measurements are in
`layout-pass2-measurements-macos.json`.

The settings are informed by [Butterick's typography guidance](https://practicaltypography.com/typography-in-ten-minutes.html),
which gives useful ranges for body size, leading and line length. They are
layout choices for this manual, not claims of compliance with a formal
publication standard. Smaller independent running-head typography remains
blocked by the furniture limitation reproduced above.

## Fonts and provenance

The renderer's original Noto Sans regular/bold and Source Code Pro regular
fonts retain their original OFL notices under `../fonts/`.
The added static Noto Sans italic font comes from the official Noto archive:

- Source: `notofonts/noto-fonts`, commit
  `ffebf8c1ee449e544955a7e813c54f9b73848eac`,
  `hinted/ttf/NotoSans/NotoSans-Italic.ttf`.
- SHA-256: `36cff144df01309dab648bea71baff9bb074026914afe63aeacc8bc90b67a28b`.
- Its matching license is `../fonts/NotoSans-Italic-OFL.txt`.

## Scope and upstream sharing

The compiler's GB-scale build/check memory is tracked separately in
[roc-lang/roc#12304](https://github.com/roc-lang/roc/issues/12304). It should
not be presented as a roc-pdf runtime leak. The renderer's fixed screenshot mapping, ASCII heading slug policy and bounded
AsciiDoc adapter remain application work rather than package defects.

The findings below have been investigated and reported upstream; see the
issue links in the follow-up section. The existing open
[roc-pdf#40](https://github.com/lukewilliamboswell/roc-pdf/issues/40) concerns
repository/tooling alignment rather than these document-authoring features.


## Whole-manual exercise

The same renderer now handles the complete current AsciiDoc include tree via
an isolated, bounded conversion step. All source wording, fenced-code bytes,
screenshots and internal references are checked against a coverage manifest.
The complete A4 output is 14 pages and 148,022 bytes on macOS. A dedicated cover
and contents page avoid a contents spill. Screenshots are scaled from their
original dimensions at 96 dpi, capped to the available text width.

This larger exercise required no changes to roc-pdf. It reinforces the need
for page-numbered contents, chapter-aware furniture, code fragmentation and
more local typography control. Pagination leaves a sparse final page; the
adapter does not yet implement manual-specific balancing. AsciiDoc table
column weights are recorded but Markdown tables use content-sensitive widths.
The cover contributor credit is retained. Source heading numbering and syntax
highlighting remain presentation gaps. These are migration/authoring gaps,
not newly established package defects. Production workflows remain unchanged.


An explicit `build --opt=speed --no-cache` completed in the compiler-reported
74 seconds. Its first full-manual render took 0.17 seconds wall time and
37,208,064 bytes peak RSS (35.5 MiB); filesystem caches were not flushed.
The native PDF is byte-identical to direct dev source execution. These are
render-time memory measurements, not compiler peak memory. The original
sample's full regression suite still passes unchanged. Machine-readable
coverage and this single-run measurement are in `full-manual-macos.json`.


## Investigated upstream reports — October 16, 2026

Three agents investigated the candidates against current upstream `main`,
release sources, the roadmap, and existing open/closed issues. Current main
was still the rc3 source commit `d654eca959f9ff536d983ca728f974a23960cf71`.
The parent reviewed the reports and independently reran the reduced repeated
text and measured long-panel probes before publishing:

- [#42: CustomBlock optional inset and panel defaults reject](https://github.com/lukewilliamboswell/roc-pdf/issues/42).
  The investigation found **two** independent default inconsistencies:
  an omitted panel with inset 8 rejects, and an omitted inset with a valid
  panel also rejects. Both explicit valid fields produce a PDF. The report
  includes a complete three-case public-API reproduction and validation paths.
- [#43: Independent header/footer typography](https://github.com/lukewilliamboswell/roc-pdf/issues/43).
  A narrow feature request for face, size, leading and colour independent of
  body typography, retaining page-field measurement and artifact ownership.
- [#44: Repeated adjacent line-break segments reject plain ASCII](https://github.com/lukewilliamboswell/roc-pdf/issues/44).
  This supersedes the narrower blank-code-line characterization above:
  three identical ordinary `Pdf.text("a")` lines fail too. Distinct lines
  and nonadjacent repeats pass. Dev and native speed builds with `--no-cache`
  agree. Source investigation suggests segment occurrence identity is being
  conflated with interned text identity; this is a diagnosis, not a validated
  fix. The issue includes a standalone reduced reproduction and controls.
- [#45: Preformatted source blocks and line-based page continuation](https://github.com/lukewilliamboswell/roc-pdf/issues/45).
  A concrete consumer request within the existing Gate 8 fragmentation plan.
  The current eight manual examples fit; a separate measured 60-line panel
  needs 856 pt against a 698 pt frame and correctly rejects as unsplittable.
  Proposed acceptance covers whitespace, local typography, wrapping and
  semantically correct continuation, without requiring a syntax highlighter.

The complete manual also passed the isolated
[Linux source CI run](https://github.com/lukewilliamboswell/roc-ansi/actions/runs/38826522764).
That run validates manual output; it is not a claim that the new standalone
bug probes were run on Linux. No roc-parser defect was established by this
exercise, and no parser issue was filed.


## Parser 2.1.0-rc.1 integration and October 15 compiler

The renderer now consumes the published parser candidate bundle
`6dvNG3Q2mx53i4YPJN2ZGK98WdXnBMMuceAmDsCq7BEd`, using its lexer-only
`RocSyntax` API for HTML Roc highlighting. PDF remains on the same immutable
roc-pdf rc3 bundle; this is not an upgrade to a different PDF implementation.
All eight HTML code blocks remain byte-exact, and the full PDF remains
byte-identical (14 pages, 148,022 bytes). New checks cover token categories,
HTML-sensitive characters, tabs, blank lines and incomplete source strings.

The candidate's required compiler is `nightly-2026-10-15-38e6c42`. Its dev
executable aborts on macOS arm64 in both the full renderer and the unchanged
PDF-only `short-ascii-break` probe, with and without compiler-cache use.
A debugger identifies an invalid pointer passed to host realloc via
`roc_builtins_list_reserve_for_append`, from `KernelTaggedObjects:377`.
This local observation does not establish the precise compiler/package cause.
The isolated new tokenizer runs successfully under the same compiler.

An explicit `build --opt=speed --no-cache` succeeds in compiler-reported
92 seconds and the executable passes the entire verifier plus full-manual
coverage. CI and current run instructions therefore explicitly select speed.
October 14 dev also renders the upgraded tokenizer integration correctly,
but is retained only as a diagnostic control, not the new compiler pin.
The original memory report and timings above remain historical evidence.


## Syntax-highlighted source: precedent and upstream request

An agent investigated established renderers, PDF text painting and current
roc-pdf before a parent review and upstream report. Syntax-highlighted code is
an established document-generation feature: [Asciidoctor PDF](https://docs.asciidoctor.org/pdf-converter/latest/syntax-highlighting/)
uses build-time highlighters; [Pygments](https://pygments.org/docs/quickstart/#architecture)
separates lexer tokens, styles and formatters; [Typst raw](https://typst.app/docs/reference/text/raw/)
provides verbatim code with syntax definitions and themes. PDF supports
coloured real text; an image or embedded editor is unnecessary.

Upstream changed during this exercise: [PR #46](https://github.com/lukewilliamboswell/roc-pdf/pull/46)
merged at `07f71fb1090efc22757a9c1ac3fee17bbea90dfa`, closing #42–#45.
Its new `Pdf.source_block` already supplies source normalization, local
font/size/leading, wrapping and line-based continuation. The published rc3
bundle still used here predates those changes. The new source block has one
foreground colour; per-range colours remain absent from that API.

Filed [#47: foreground colour ranges for external syntax highlighters](https://github.com/lukewilliamboswell/roc-pdf/issues/47).
The bounded request is language-neutral foreground ranges, leaving our pure
Roc module to map `RocSyntax` tokens/categories to a theme. It explicitly
addresses original UTF-8 offsets versus CRLF/tab canonicalization, gaps,
invalid ranges and cluster boundaries, bounded representation, unchanged
measurement and pagination, colour continuation, and existing canonical
`ActualText`/code semantics. Foreground-only support avoids requiring a general
font-style engine or a built-in Roc parser. Visual colour assertions supplement
text extraction and structure checks.

The proposed drawing-label adapter was not implemented: those labels are
artifact text and would require figure alternative text rather than preserving
the existing semantic source-block path. The preferred integration is a
standalone highlighter plus the new source-block API with colour ranges.
No standalone module or coloured PDF adapter has been added yet; the working
HTML tokenization remains in `main.roc` pending extraction.
