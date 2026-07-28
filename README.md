# Roc ANSI

Helpers for working with ANSI terminal control sequences in Roc.

## Example - Animals

Run with `roc examples/animals.roc`

![example output showing colored animal names](examples/animals.png)

## Example - Colors

Run with `roc examples/colors.roc`

![example output showing colors](examples/colors.png)

## Example - Styles

Run with `roc examples/styles.roc`

![example output showing terminal styles](examples/styles.png)

## Example - TUI Menu

Run with `roc examples/tui-menu.roc`

![example output showing a styled menu preview](examples/tui-menu.png)

## Example - Piece Table

Run with `roc examples/text-editor.roc`

![example output showing a piece table edit preview](examples/text-editor.png)

## Development and CI

The checked-in examples pin an immutable URL for the latest published ANSI release
(currently 0.13.0), alongside their released platform URL. Running an example with
`roc examples/animals.roc` uses those published dependencies.

To test changes to `package/`, use the local scripts with the compiler pinned in
`.roc-version` (set `ROC=/path/to/roc` to select it):

```sh
# Package format, checks, tests, docs, and all examples against local changes:
python3 scripts/all_tests.py

# Run one example against local changes, retaining terminal input/output:
python3 scripts/run_example.py animals

# Test all examples against an already-created bundle:
python3 scripts/test_bundle_examples.py --bundle-path dist/PACKAGE_HASH.tar.zst
```

The local scripts bundle the working tree, serve the archive on a free localhost
port, and rewrite the ANSI URL only in temporary example copies. Checked-in URLs
stay on the published release. The server and temporary copies are cleaned up
when the command exits.

CI deliberately exercises both dependencies:

- `test-examples` runs `scripts/test_published_examples.py`: it checks, tests, runs,
  and builds the examples with their committed published URLs and no URL rewrite.
  A nightly that breaks the released package or platform must fail this check.
- `Build release bundle` validates the working-tree package and local examples;
  `Test default bundle (ubuntu-latest)` validates the exact proposed release
  archive through localhost. These checks cover changes that are not released yet.

Run the published compatibility check locally with:

```sh
python3 scripts/test_published_examples.py
```

A passing local bundle test does not override a failing published-release check.
Diagnose the break and prepare a compatible package/platform release before
accepting the nightly update. CI uses the checked-in release URLs; it does not
silently substitute a newer release or the local package.

## Releasing

After validating package changes, dispatch the **Release** workflow with a new
`release_version`. Its normal publication path:

1. Tests and bundles the working tree, then tests the exact archive through localhost.
2. Publishes the versioned release asset.
3. Rewrites example URLs to that asset and tests the published examples again.
4. Generates docs in ignored build output and uploads a versioned docs archive
   as a GitHub release asset. Pages restores these archives during deployment.
5. Creates a GitHub-signed `release-followup/VERSION` PR updating only example URLs.

Review and merge that follow-up PR so `main` points to the newest working release.
The nightly updater only auto-merges `.roc-version` updates; release follow-ups
remain reviewable PRs. Generated `roc docs` output is never committed. The follow-up creator can reuse an identical signed bot
commit on retry, but refuses to overwrite a branch containing different work.
PR and `nightly_validation` runs only validate; they never publish or deploy.

For maintenance-script changes, also run:

```sh
python3 -m unittest discover -s tests -v
```

## Documentation

See [https://lukewilliamboswell.github.io/roc-ansi/](https://lukewilliamboswell.github.io/roc-ansi/)

To generate versioned docs locally, use:

```sh
ROC=/path/to/roc python3 scripts/generate_docs.py 0.13.0
```

Output goes to `.roc-ansi-tmp/release-docs/0.13.0`, outside the tracked site source.
Generated API docs are not committed. Release workflows upload archives named
`roc-ansi-docs-VERSION.tar.gz` alongside the package assets. Pages deployments
restore those archives and generate fresh `/main/` docs, preserving historical
version URLs without storing their HTML in Git.

To preview the complete site, including released documentation:

```sh
python3 scripts/assemble_www.py --fetch-release-docs
```

This downloads documentation assets from GitHub. The normal local preview below
only generates `/main/` docs and does not need that download. Hand-maintained site
files and vendored highlighting assets remain in `www/`.

Generate the landing page with fresh main-branch API docs, then serve the isolated QA preview:

```sh
./scripts/serve_www.py
```

The preview chooses a free local port and opens it automatically; its landing page links to freshly generated `/main/` API docs. Pass `--no-open` to avoid opening a browser, `--no-serve` to only assemble the preview, or `--port 8000` to choose a fixed port. Set `ROC=/path/to/roc` if `roc` is not on your `PATH`.

The landing page shows a terminal capture for each runnable example, linking to its source on GitHub. The site vendors the Tree-sitter Roc grammar and web runtime for client-side highlighting; see [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) for license details.
