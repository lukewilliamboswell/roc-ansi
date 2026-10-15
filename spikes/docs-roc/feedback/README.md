# roc-pdf experience report: a polished package manual

This experiment replaces the presentation of an Asciidoctor manual with a
renderer written in Roc. It evaluates the published **roc-pdf 0.1.0-rc3**
facade, not private `Kernel*` modules. Production documentation workflows
remain unchanged. The source is a representative Markdown chapter, not a
complete conversion of the released 18-page manual.

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
| `blank-breaks` | `text.unsupported_cluster` despite ASCII-only text |
| `short-ascii-break` | Accepted; 8,421 PDF bytes generated |
| `ascii-break` | A word wider than the default body frame gets `pipeline.lines.line_layout.unbreakable`; its diagnostic describes an internal precondition/package defect |

Each probe catches and prints the result so the process exits successfully
even for expected preparation rejection. See `probe-results.json` for the
recorded output, including all cases run using an optimized executable built
with `--no-cache`. The wide-word diagnostic is a secondary error-reporting
rough edge; the sample does exceed the available line width and we do not
claim it should fit without wrapping. None of the rejection cases emits
partial PDF bytes.

## Image authoring experience

The real manual's terminal screenshots are PNGs. This spike predecodes its
single screenshot once into RGB8; rendering uses `Image.Source.rgb8` and does
not invoke Python or an external renderer. The public image facade also has
an encoded sRGB JPEG constructor, so encoded images are not generally absent.
A documented bridge from a PNG decoder to the RGB8 source would make this
common documentation use case easier. Our one-image filename mapping and
fixed dimensions remain adapter limitations.

## Final artifact and validation

The reviewed artifact is `.roc-ansi-tmp/docs-roc-polished-final/manual.pdf`:
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
not be presented as a roc-pdf runtime leak. The renderer's single hardcoded
screenshot, sample-only front matter, ASCII heading slug policy and incomplete
manual conversion remain application work rather than package defects.

This is a local experience report and issue-drafting material. New roc-pdf
issues have not been filed as part of this experiment. The existing open
[roc-pdf#40](https://github.com/lukewilliamboswell/roc-pdf/issues/40) concerns
repository/tooling alignment rather than these document-authoring features.
