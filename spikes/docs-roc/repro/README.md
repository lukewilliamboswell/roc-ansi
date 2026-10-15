# Small compiler memory controls

These are standalone apps: copy any `.roc` file into an empty directory and
use the published `nightly-2026-10-14-38a3029` compiler. They need only their
pinned public package/platform dependencies. No parent-repository source,
assets, custom fonts, Python, or PDF tools are required to reproduce the apps.

On macOS, measure the compiler with:

```sh
/usr/bin/time -l /path/to/roc check import-only.roc
/usr/bin/time -l /path/to/roc import-only.roc
```

On Linux use `/usr/bin/time -v`. macOS reports maximum resident set size in
bytes; Linux reports KiB. This is process peak RSS, not requested allocation
bytes and not macOS's broader peak-memory-footprint metric.

`import-only.roc` is the smallest useful case: call `Pdf.paragraph`, discard
the block, print hello. It never calls the PDF preparation/emission API.
`pdf.roc` creates a one-paragraph document; `runtime-pdf.roc` makes its text
depend on runtime arguments to separate the case from constant-only document
generation. `hello.roc` and `markdown.roc` are dependency controls.

## Measured on Apple Silicon, macOS 26.3.1

| App | `roc check` peak RSS | `roc app.roc` peak RSS |
| --- | ---: | ---: |
| Hello world, basic-cli only | 165 MB | 160 MB |
| Parse one Markdown heading | 515 MB | 510 MB |
| Pdf paragraph constructor only | 2,246 MB | 786 MB |
| Generate a constant one-paragraph PDF | 3,515 MB | 3,569 MB |
| Generate a PDF with runtime-dependent text | 2,909 MB | 2,726 MB |

See `measurements-macos.json` for exact values and output. This points to
compiler/checker/runner overhead for the imported API; it does not identify
the responsible compiler phase or establish a memory leak. Checking can also
perform compile-time evaluation, so checking is not assumed to be pure parsing.

## Reproduce the comparison

From the repository root, after the package sources have been downloaded once:

```sh
python3 spikes/docs-roc/repro/measure.py /path/to/roc /path/to/cache/roc/packages
```

The Python harness uses a separate empty compiler cache for every app/mode,
symlinking only the downloaded package-source directory. This excludes package
downloads and avoids sharing compiler cache state between controls. Results
are written under `.roc-ansi-tmp/docs-roc-repro/`.

Optional trailing app names select particular controls. The harness itself is
not needed for a single-file reproduction.
