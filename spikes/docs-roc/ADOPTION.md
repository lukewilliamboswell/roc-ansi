# Released documentation tools adoption

The active spike uses `roc-automation tools-0.1.0-rc.1` to render the real
`docs/index.adoc` include tree. The documentation and release workflows on this
branch use its native backend. Main/Pages have not been deployed from this spike.
The old Markdown converter and renderer remain historical research, outside CI.

## Versions and entry points

- Blueprint platform and installer: `0.6.0-rc1`, still the newest published
  Blueprint candidate when checked October 19. No newer upgrade was needed.
- Shared action: `lukewilliamboswell/roc-automation/actions/build-docs` at
  `dec2d52a5cb6cd251fd188ad1d797f400ee1bb6e` (`tools-0.1.0-rc.1`).
- Renderer assets and SHA-256 digests are locked in `Blueprint.lock` for
  x86_64 Linux, aarch64 Linux and aarch64 Darwin. The Linux x86_64 executable
  is 21,383,904 bytes; the Darwin executable is 17,261,216 bytes.
- The release embeds roc-parser 2.1.0-rc.3, roc-pdf 0.1.0-rc6, highlighting,
  fonts and PNG decoding. It reads AsciiDoc directly; our old conversion script,
  predecoded screenshots and custom highlighting module are no longer needed.

```sh
blueprint run install-snippet
blueprint run docs -- --docs-version main
SITE_OUTPUT=.docs-out/site FETCH_RELEASE_DOCS=1 blueprint run site
blueprint run serve
```

The package/API compiler remains the latest nightly on PATH. Local checks used
`~/roc_nightly-macos_apple_silicon-2026-10-18-1df370f/roc`. Blueprint also uses its
own October 13 configuration compiler and the locked October 9 compiler for
repository automation scripts. Native rendering invokes none of those compilers.

`Blueprint.roc` has a separate `docs` environment and a `docs-path` task.
The latter resolves the permanent store path with `realpath`: Blueprint's
short-lived task PATH symlink disappears when the task exits. The local
`setup-docs` action gives the shared action a timing wrapper around that binary.

## CI cost visibility

`.github/actions/setup-docs/measure.sh` reports elapsed/user/system time, peak
RSS and exit status for input generation, API assembly, and release build stages.
`render.sh` measures the native executable separately from tool provisioning.
Both propagate failures, print grouped logs, save raw measurements under
`.roc-ansi-tmp/ci-metrics/` and append to the GitHub job summary. Documentation
and release jobs upload those measurements even on failure and report output
sizes. The job's individual Actions steps show checkout, Blueprint install,
cache transfer, latest compiler setup and artifact upload durations separately.

Renderer setup logs its release, binary size, verified store path and SHA-256.
Provisioning time includes verification and any missing artifact download.
The cache step reports exact hit/miss, transfer size and duration. This is
**download caching**, not a claim that rendering reuses compiler caches.

Blueprint caches verified downloaded artifact bytes, not extracted executables
or compiler build state. Keys include OS, architecture, lockfile/installer hash,
workflow, job and optional matrix workload suffix. This prevents a checks-only
job claiming an immutable key before the renderer is downloaded. Subsequent
runs of the same workload can restore the renderer and locked compiler archives;
Blueprint still verifies them and recreates its store trees. A lockfile change
starts a new cache. Different jobs intentionally have separate caches. Blueprint's
installer itself still downloads its small verified executable each run; the
floating package compiler is managed separately by `setup-roc`. Inspection of
that pinned action confirmed it has no cache: it downloads and extracts the
nightly again in each job. Compiler caching by resolved nightly tag is a
remaining opportunity, separate from the renderer migration.

The `Documentation renderer spike` workflow now consumes the released utility,
with no renderer source compilation. A manual dispatch with `compare_legacy`
enabled also runs the same release's Docker backend on a separate fresh runner:

```sh
gh workflow run docs-spike.yml --ref spike/roc-docs -f compare_legacy=true
```

Both jobs print generated input hashes and commit, render-action wall time,
Docker image inventories, output sizes and stage measurements. Compare cold
runs separately from warm cache hits. Runner hardware, network and Docker's
preinstalled layers can vary. Docker image disk size is not network transfer;
Docker-client RSS is not whole-container memory. Native `/usr/bin/time` RSS
is process memory, not the renderer's broader system memory footprint.
The test-only Poppler installation is a separate step, outside rendering time.

## Local end-to-end evidence

On macOS arm64, October 19, using the downloaded/verified release executable:

| Stage | Wall time | Peak RSS |
| --- | ---: | ---: |
| Entire manual: native AsciiDoc to HTML and PDF | 0.45 s | 60.6 MB |
| API assembly, including fetching seven published API archives | 13.67 s | 168.5 MB |

These are individual local observations, not a measured Linux/Docker speedup.
They exclude binary provisioning. No `--no-cache` compiler comparison applies
to the native rendering stage: it does not start a compiler. The first native
render after downloading the utility is still a normal OS/filesystem-cache run.

`blueprint run check` passed against the October 18 package compiler, including
package, examples, fuzz/allocation checks, reproducible release artifacts and
site assembly. Two allocation-test comparisons needed parentheses required by
the latest formatter; test semantics and allocation budgets did not change.

`verify_native.py` independently checks seven manual routes, existing chapter
anchors, local link/image targets, eight exact source blocks, six tables, five
screenshots, API presence, identical website/download PDF copies, and tagged
PDF/text through Poppler. `check_native_browser.mjs` checks all seven pages in
Chrome: desktop/mobile overflow, persistent desktop navigation, nested contents,
mobile collapse/expand, dark mode, loaded local fonts and syntax highlighting.
Node, Chrome, Python and Poppler are verification tools, not renderer dependencies.

A versioned release render also passed: `roc-ansi-0.0.1-dry-run.pdf` exists and
both HTML download links correctly target that filename. Outputs are under
`.docs-out/`; local comparison inputs/screenshots are under
`.roc-ansi-tmp/automation-adoption/`. The current manual PDF is 13 pages,
150,705 bytes, tagged PDF 2.0. API assembly restored 88 reference pages across
main and seven releases.

## Linux CI measurements

[First comparison, run 39180976642](https://github.com/lukewilliamboswell/roc-ansi/actions/runs/39180976642)
used the same commit and generated-input hashes on separate fresh Ubuntu runners.
[Warm native run 39181087922](https://github.com/lukewilliamboswell/roc-ansi/actions/runs/39181087922)
passed with an exact download-cache hit. Each native job finished in 51 seconds,
including independent PDF verification installation and artifact upload.

| Stage | Native, cold artifacts | Native, restored artifacts | Docker backend |
| --- | ---: | ---: | ---: |
| Generate inputs, including Blueprint compiler/tool bootstrap | 18.61 s | 14.85 s | about 19 s |
| Provision native renderer | about 2 s | about 1 s | included below |
| Complete render action | 0.614 s | 0.630 s | 89.275 s |
| Native renderer process, inside action | 0.48 s / 29,948 KiB RSS | 0.40 s / 30,756 KiB RSS | not measured |
| API generation and seven archive downloads | 7.48 s | 6.90 s | 6.59 s |

The Docker action spent 34.5 seconds obtaining/extracting its base image,
37.3 seconds installing Chromium/Node/npm/Python/Mermaid, and 10 seconds exporting
the image. The remainder includes manual rendering and orchestration. The image
was 3.36 GB on disk; the native executable is 21.4 MB. Image size is not measured
network transfer. The render-action reduction was about 99.3%; even adding cold
native provisioning leaves roughly 2.6 seconds versus 89.3 seconds. These are
single observations, not controlled statistical benchmarks.

The restored Blueprint cache was 150,391,895 bytes (about 143 MiB), covering the
configuration compiler, stable scripting compiler and renderer. Roc packages
use a separate cache and are not covered by this Actions cache. No
renderer or locked compiler fetch appeared in the warm-run log. Restoring a
cache still transfers bytes from GitHub's cache service; it avoids upstream
asset downloads, not all network use. Verification/re-extraction and compiler
configuration work still happen. The latest package compiler remains a separate
71,984,136-byte download per job with the pinned setup action. Published API
archives also remain fetched on each site build. Those are remaining bandwidth
opportunities; this change does not claim zero-download PRs.

The first Docker render succeeded but its strict acceptance step exposed two
existing links to a missing `examples.html#learn-from-the-examples` title anchor.
The validator now reports those gaps for the legacy comparison and requires
all native anchors to resolve. Both saved outputs passed the adjusted validator
locally; no native link requirement was relaxed. Thus the first comparison run
has a failed baseline-validation status despite usable rendering measurements.

## Comparison with current live Asciidoctor output

The baseline was downloaded October 19 from the existing Pages site. Its PDF
was generated October 12 by Asciidoctor PDF and has 18 pages. Page count alone
is not a quality metric: the native theme packs the content differently.

The native website retains all existing IDs in the combined manual, the seven
chapter routes, six tables, five original screenshots and eight code examples.
The contents is nested, persistent on desktop and collapsible on mobile;
it no longer displaces the whole document with a large flat list. HTML honours
the authored table weights and preserves description lists/sidebar structure.
The shared utility improves on our earlier handoff's presentation gaps.

Remaining PDF differences worth reviewing before deployment:

- The cover and nested contents share a page, rather than the separate spacious
  cover and numbered contents in Asciidoctor. Contents links work, but printed
  page references are absent.
- Printed contents includes three levels despite this manual's `toclevels: 2`.
- The native PDF does not honour table column weights or reproduce HTML sidebar
  styling. Those are explicit limitations of this utility candidate.
- PDF body headings omit the source section numbering, and the book title repeats
  at the start of the body. HTML section numbering is retained.
- Running headers use the book title rather than the current chapter. Pagination,
  typefaces and spacing differ; theme parity is not established.

These are candidate adoption/utility issues; do not mistake them for lost manual
content or claim complete Asciidoctor compatibility. The release's documentation
also explicitly disclaims printed contents page references, chapter headers and
PDF table column weights.

## Feedback for shared adoption guidance

[Blueprint and roc-automation documentation feedback](UPSTREAM-DOCS-FEEDBACK.md)
separates published guidance from the integration glue this repository supplied,
and lists concrete shared documentation/action improvements for later migrations.
