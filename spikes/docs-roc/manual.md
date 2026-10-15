# The roc-ansi manual

roc-ansi lets a Roc program colour and style what it prints, move the cursor,
read key presses and draw simple tables, by writing the ANSI escape sequences a
terminal understands for you.


**How to use this manual**

- **Deciding whether to use roc-ansi**: Start with [What roc-ansi is](#what-roc-ansi-is).
- **Using it for the first time**: Follow [Get started](#get-started).
- **Looking for code to adapt**: Browse [Learn from the examples](#learn-from-the-examples).
- **Changing roc-ansi itself**: Read [Contribute](#contribute).
- **Releasing or looking after the repository**: Read [Maintain and release](#maintain-and-release).
- **Upgrading**: See [Release notes](#release-notes).

## What roc-ansi is

A terminal changes colour, moves its cursor and reports key presses through
short byte sequences called ANSI escape codes. They are easy to get wrong and
unpleasant to read: `\u(001b)[38;5;208m` means "orange text". roc-ansi is a Roc
package that gives each of them a typed name, so a program says
`ANSI.color("hello", { fg: C256(208), bg: Default })` and gets the right bytes.

It is a pure Roc package. It has no platform of its own and works wherever Roc
does, with any platform that can write to a terminal.

### What it covers

| Module | What it is for |
| --- | --- |
| `ANSI` | The entry point: colour and style text, turn any escape into a string, parse raw key presses, and draw to a screen buffer |
| `Color`, `C16`, `C256`, `Rgb` | The four ways to name a colour: the terminal default, the 16 named colours, the 256-colour palette, and 24-bit RGB |
| `Style` | Bold, faint, italic, underline, strikethrough and inverted text |
| `Control` | Cursor movement, clearing the screen or a line, and scrolling |
| `Layout`, `Spacing` | Bordered grids and tables, padding and margins |
| `PieceTable` | A piece table, the structure a text editor keeps its buffer in |


### What it looks like

![A sentence with three words coloured green, blue and red](images/animals.png)

![Lines of text in the 16 named colours, 256-colour and RGB](images/colors.png)

![Lines of bold, faint, italic, strikethrough, underlined and inverted text](images/styles.png)

Each picture is the output of one of the programs in
[Learn from the examples](#learn-from-the-examples).

### What it does not do

- It does not put the terminal into raw mode or read from standard input. Your
  platform does that; roc-ansi parses the bytes it hands you.
- It does not detect what a terminal supports. A program that must work
  everywhere should keep to the 16 named colours.

### Compatibility

Roc has no stable release yet, so a roc-ansi release is built and tested with
one nightly compiler, named in its release notes. The latest release is tested
against the latest nightly every day, and a failure is fixed by a patch
release. Use the latest release with a current
[nightly](https://github.com/roc-lang/nightlies/releases).

### Where to ask and report

- Bugs and requests: [GitHub issues](https://github.com/lukewilliamboswell/roc-ansi/issues).
- Vulnerabilities: privately, as described in
  [SECURITY.md](https://github.com/lukewilliamboswell/roc-ansi/blob/main/SECURITY.md).
- roc-ansi is open source under the
  [Universal Permissive License 1.0](https://github.com/lukewilliamboswell/roc-ansi/blob/main/LICENSE).

## Get started

This chapter takes you from nothing to a program that prints coloured text. You
need a current Roc [nightly](https://github.com/roc-lang/nightlies/releases)
installed as `roc`.

### Add the package

A Roc application names its packages in its header, each by the URL of a
release. Save this as `hello.roc`:

**The latest release is 0.13.2**


```roc
app [main!] {
	ansi: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.13.2/7yixATpLmwqtNujvYk1sKvZHmgFBMm7B9y7amxVZAhAn.tar.zst",
}

import ansi.ANSI

main! = |_args| {
	echo!(ANSI.color("hello", { fg: Standard(Green), bg: Default }))
	Ok({})
}
```


For release 0.13.2:

- [API reference](https://lukewilliamboswell.github.io/roc-ansi/0.13.2/)
- [Examples](https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.13.2/roc-ansi-examples-0.13.2.zip), each depending on this release
- [Release notes](https://github.com/lukewilliamboswell/roc-ansi/releases/tag/0.13.2)

The URL ends in a hash of the package's contents. Roc checks what it downloads
against that hash, so the URL can only ever mean one thing.

### Run it


```sh
roc hello.roc
```


The word `hello` is printed in green. `ANSI.color` wrapped it in the escape
codes that switch the colour on, and a reset that switches it off again.

### Where to go next

- [Learn from the examples](#learn-from-the-examples) has a
  short program for each part of the package.
- The API reference linked above lists every function of every module.

### API reference for every version

Each release keeps its own API reference, so the pages for the version you
depend on never change under you.

- [main](https://lukewilliamboswell.github.io/roc-ansi/main/), which is not released yet
- [0.13.2](https://lukewilliamboswell.github.io/roc-ansi/0.13.2/)
- [0.13.1](https://lukewilliamboswell.github.io/roc-ansi/0.13.1/)
- [0.13.0](https://lukewilliamboswell.github.io/roc-ansi/0.13.0/)
- [0.12.0](https://lukewilliamboswell.github.io/roc-ansi/0.12.0/)
- [0.11.0](https://lukewilliamboswell.github.io/roc-ansi/0.11.0/)
- [0.10.0](https://lukewilliamboswell.github.io/roc-ansi/0.10.0/)
- [0.8.0](https://lukewilliamboswell.github.io/roc-ansi/0.8.0/)

## Learn from the examples

Each example is a short, complete program that shows one thing, with comments
that walk through it. Read them top to bottom, or copy one as a starting point.

| Example | What it shows |
| --- | --- |
| [`animals.roc`](https://github.com/lukewilliamboswell/roc-ansi/blob/main/examples/animals.roc) | Colouring a few words inside a sentence with `ANSI.color` |
| [`colors.roc`](https://github.com/lukewilliamboswell/roc-ansi/blob/main/examples/colors.roc) | Every way of naming a colour, from the most portable to the least |
| [`styles.roc`](https://github.com/lukewilliamboswell/roc-ansi/blob/main/examples/styles.roc) | Bold, faint, italic and the other text styles, and how to switch them off |
| [`menu.roc`](https://github.com/lukewilliamboswell/roc-ansi/blob/main/examples/menu.roc) | Combining colours and styles to draw a menu with one highlighted entry |
| [`piece-table.roc`](https://github.com/lukewilliamboswell/roc-ansi/blob/main/examples/piece-table.roc) | Editing text with a piece table |


### Which copy to use

The examples exist in two places, and they are not the same.

- **The examples for a release**: Each release attaches an archive,
  `roc-ansi-examples-<version>.zip`, linked from
  [Add the package](#add-the-package). Its examples depend
  on that release's package URL and never change. Use these to start a project.

- **The examples in the repository**: These depend on the package beside them,
  `ansi: "../package/main.roc"`, so they always match the unreleased code on
  `main`. They may use something no release has yet. Use these when you are
  changing roc-ansi.

### What the output looks like

**`menu.roc`**

![A menu with a bold title and its first entry highlighted in green](images/menu.png)

**`piece-table.roc`**

![One line of text showing a document after an insertion and a deletion](images/piece-table.png)

The archive also holds `spec.json`, which records exactly what each example
printed when the release was made.

## Contribute

This chapter is for someone changing roc-ansi: what to install, how to run the
checks a pull request must pass, and where each kind of test lives.

Use [issues](https://github.com/lukewilliamboswell/roc-ansi/issues) for bugs and
design discussion, and pull requests for changes. Say what behaviour changes
and how you checked it. A bug fix or a new behaviour comes with a test.

### Set up

You need three things:

- The `blueprint` command from
  [roc-blueprint](https://github.com/lukewilliamboswell/roc-blueprint), at the
  release named by the platform URL at the top of `Blueprint.roc`. Download the
  binary for your system from that release and check it against the release's
  `blueprint.sha256`, make it executable and put it on `PATH`.
- A current Roc [nightly](https://github.com/roc-lang/nightlies/releases) on your
  `PATH` as `roc`.
- The host tools listed in `Expect` in `Blueprint.roc`: `chmod`, `gh`, `git`,
  `gzip`, `shasum`, `tar`, `touch`, `unzip` and `zip`.

Nix is not needed. The file and archive tools supplied by Linux and macOS
work; GNU coreutils is not required. Install GitHub CLI (`gh`) separately.
Blueprint downloads the pinned tooling compiler and its Roc packages on first
use. Run `blueprint update` after changing its declarations, and commit the
lock file. A checkout already has the lock it needs.

### Two compilers

| Command | Chosen by | Used for |
| --- | --- | --- |
| `roc` | You: the latest nightly | Checking, testing, bundling and running the package and its examples |
| `roc-stable` | The release named in `Blueprint.roc` | Running the scripts under `scripts/` |


The package is always tested with the newest compiler, because that is what its
users install. `roc-stable` exists so the repository's own tooling keeps
working on the day a nightly breaks something. It never checks or builds the
package, and it only exists inside `blueprint run` and `blueprint shell`.

Nothing pins a compiler for the package or the examples. Each script names
`roc-stable`'s release in its `roc` header field, so that running one with a
different compiler says why it misbehaves.

### Run the checks


```sh
blueprint run check      # everything a pull request must pass
blueprint shell          # or enter the environment and run scripts directly
blueprint tasks          # list every task
```


`blueprint run check` runs `scripts/check_all.roc`, which:

1. Fails if a compiler pin appears outside `scripts/`, or a script's pin differs
    from `Blueprint.roc`.
2. Tests, checks and formats the scripts with `roc-stable`.
3. Formats, checks and tests the package with `roc`.
4. Builds every example against the working tree, runs it, and compares its
    output with `tests/spec.json`.
5. Builds each fuzz target and replays its committed corpus.
6. Counts allocations and compares them with `tests/allocations.json`.
7. Bundles the package, builds the examples archive, and runs the archived
    examples, unchanged, against that bundle.
8. Builds the API documentation and its archive.

A pull request can fail because a new nightly arrived, with no fault in the
change. Compare with the latest run of the nightly workflow and with `main`
before treating a failure as yours.

### Where tests live

| Kind | Where | How to add one |
| --- | --- | --- |
| Unit tests | `expect` beside the code in `package/` | Write an `expect` in the module. `roc test package/main.roc` runs them all. |
| Example output | `tests/spec.json` | Add a case to the example's entry, then record its output; see [Change an example](#change-an-example). |
| Properties | `fuzz/<name>/main.roc` | A [roc-fuzz](https://lukewilliamboswell.github.io/roc-fuzz/) target with a small `corpus/`; see [Search for inputs nobody thought of](#search-for-inputs-nobody-thought-of). |
| Allocations | `tests/allocations.json` | Add a case and its ceiling; see [Keep allocations from creeping up](#keep-allocations-from-creeping-up). |
| Script logic | `expect` in the modules under `scripts/src/` | Keep effects out of the module, and add it to the list in `check_scripts!`. |


### Change an example

An example's exact output is recorded, so a change to what it prints must be
recorded too:


```sh
blueprint shell
scripts/test_examples.roc -- --update
```


That rewrites `tests/spec.json` from what the examples print now. Review the
diff like any other change. An example that cannot run for a reason outside
this repository is skipped in the specification with a `reason` and an `issue`
link; a skip without both is rejected.

Examples are for users of the package. Keep each one short, about one thing,
and commented for someone reading it with no other context. A test belongs in
`package/` or `tests/`, not in `examples/`.

### Search for inputs nobody thought of

`fuzz/piece-table` states a rule that must hold for every document and index,
and [roc-fuzz](https://lukewilliamboswell.github.io/roc-fuzz/) searches for an
input that breaks it. Every pull request only builds the target and replays its
committed corpus. To search:


```sh
roc build --fuzz fuzz/piece-table/main.roc --output=piece-table
./piece-table run fuzz/piece-table/corpus --time=60
```


When it finds a failure, fix the bug and keep the minimised input as an
ordinary `expect` in the package.

### Keep allocations from creeping up

A change can make an in-place update copy a whole list on every call, and
every test still passes. `tests/allocations.json` records the most allocations
each listed case may make, and the check fails above that.

- A count below its ceiling passes, and the check says what to lower the
  ceiling to. Lower it in the same pull request, so the gain cannot be lost.
- Raising a ceiling needs a reason in the pull request. It is not a way to make
  a red build green.

The counts come from `tests/allocations/main.roc`, built on the roc-fuzz
platform because its host counts allocations. Nothing is fuzzed there.

### Build this manual

The manual is the AsciiDoc under `docs/`, one chapter per file, rendered by the
shared [build-docs](https://lukewilliamboswell.github.io/roc-automation/#build-docs)
action. Every pull request builds it, and the site can be downloaded from the
`Documentation` workflow run. To build it yourself you need Docker and a
checkout of roc-automation:


```sh
blueprint run install-snippet
python3 ../roc-automation/actions/build-docs/build_docs.py --workspace . --pdf-filename roc-ansi.pdf
blueprint run serve
```


The first command writes the parts of the manual that depend on what has been
released into `docs/generated/`, which needs `gh` to be authenticated. The
second renders the site and the PDF into `.docs-out/site`. The last adds the
API reference for `main` and serves the site on a free port, or the one named
by `SITE_PORT`; with `FETCH_RELEASE_DOCS=1` it also restores the API reference
of every release.

## Maintain and release

This chapter is for a maintainer: what each workflow shows, how the tooling is
updated, and how a release is made. The repository follows the
[roc-automation manual](https://lukewilliamboswell.github.io/roc-automation/),
which gives the reasons behind each practice.

### What each workflow shows

| Workflow | Runs on | What it shows |
| --- | --- | --- |
| `ci.yml` | Pull requests, pushes to `main` | The working tree passes `blueprint run check` on the latest nightly |
| `release.yml` | Manual dispatch; pull requests as a dry run | The exact bundle, examples archive and documentation proposed for publication work |
| `nightly.yml` | Daily | The latest release's examples archive still works on the latest nightly |
| `docs.yml` | Pull requests, pushes to `main` | The manual and site build; `main` deploys them |


The package is pure Roc, so every job runs on Linux only. Blueprint fetches
its tooling compiler directly; no workflow installs Nix. The local setup action
caches only Blueprint's downloaded artifacts, keyed on the lock and installer.
Extracted trees are rebuilt from verified artifacts. CI checks that every task
reports no package provider and runs with no `nix` on `PATH`.

`nightly.yml` keeps one tracking issue: opened on the first failure, updated by
later failures, and closed by the next pass. A failure there means the latest
release needs a patch release. A published archive is never edited. A run that
fails before any example ran, such as a failed download, opens no issue.

To re-run a past combination, dispatch `nightly.yml` with a `nightly_tag`, a
`release_tag`, or both. Left empty, they mean the latest nightly and the latest
full release.

### Update the tooling

Nothing updates the tooling automatically. Each of these is a pull request.

- **Refresh the lock**: Run `blueprint update` and commit `Blueprint.lock`.
- **Change the tooling compiler**: Change the tag in `Fetch("roc-stable", Recipes.roc_nightly(...))` in
  `Blueprint.roc` and the `roc` field of every script to the same nightly. The
  check fails until they agree. Run `blueprint update roc-stable` and fix any
  script the new compiler breaks.
- **Upgrade Blueprint**: Change the platform URL at the top of `Blueprint.roc`, and
  the version and reviewed checksums in `.github/actions/setup-blueprint/install.sh`
  from the same roc-blueprint release. Run `blueprint update` and review the new lock.
- **Update a script dependency**: Change its URL in every script header and under
  `RocPackages` in `Blueprint.roc`. Task-only Roc bundles are content-addressed
  and are not recorded in the lock.

### Make a release

1. Choose the version. `roc bump` compares the package with the latest release
    and says how far the version must move:

```sh
roc bump --old <latest release bundle URL> package/main.roc
```

2. Write the notes in `docs/releases/<version>.adoc`, add them to the top of
    `docs/releases.adoc`, and merge that pull request. Write them for someone
    deciding whether and how to upgrade. Use `+{package-url}+` wherever the
    release's bundle URL belongs.
3. Dispatch the **Release** workflow from `main` with that version.

The workflow then:

1. Rejects a version that already exists, one with no notes, and one that
    `roc bump --expect` says understates the change.
2. Runs `blueprint run check`.
3. Builds the bundle, the examples archive, the documentation archive and this
    manual as a PDF, and renders the notes with the real bundle URL and the
    versions of `roc` and `roc-stable` it used. That record replaces a header
    pin as the statement of what the release was built and tested with.
4. Tests the examples archive, unchanged, against the bundle.
5. Publishes. A separate job, which checks out nothing and runs no code from
    the repository, creates a draft release at the tested commit, uploads every
    asset, downloads each back and compares it with the tested file, and only
    then publishes.
6. Rebuilds and deploys the site, unless the version is a release candidate.

A release holds:

| Asset | Purpose |
| --- | --- |
| `<hash>.tar.zst` | The bundle users depend on. Its name is its content hash. |
| `roc-ansi-examples-<version>.zip` | The examples, depending on this bundle, with the output they printed |
| `roc-ansi-docs-<version>.zip` | The API reference for this version, which the site restores |
| `roc-ansi-<version>.pdf` | This manual |


No follow-up pull request is needed, because nothing on `main` names its own
release. A published release is never changed: if one is wrong, publish a new
version.

On a pull request the workflow builds and tests the same things under the
version `0.0.1-dry-run`, renders the newest notes, and publishes nothing.

A release candidate, such as `0.14.0-rc1`, goes through the same workflow. It
is marked as a prerelease, is never the latest release, and needs its own
notes file.

### How the site is put together

The site is this manual, rendered by the shared build-docs action, with the
API reference added beside it by `blueprint run site`:

- `main/` holds fresh API documentation for the working tree.
- Each release's API documentation sits under its version, such as `0.13.1/`,
  restored from the archive that release attached. Its address keeps working
  without its HTML being stored in Git, and generated documentation is never
  committed.

The manual leads with the latest release: its first program, its API reference
and its examples archive. Those parts are written by
`blueprint run install-snippet` before the manual is rendered, because a bundle
URL holds a hash nobody can write by hand.

`docs.yml` builds the site on every pull request and deploys it from `main`.
`release.yml` rebuilds and deploys it after publishing, since a release changes
which one is the latest.

## Release notes

Each release has its notes in `docs/releases/`, newest first. Releases before
0.13.2 have theirs on the
[releases page](https://github.com/lukewilliamboswell/roc-ansi/releases).

### roc-ansi 0.13.2

This release changes nothing in the package's API. It is the first whose
examples archive records what each example prints, so the daily compatibility
check compares output as well as building and running.

#### Use this release


```roc
app [main!] {
	ansi: "{package-url}",
}
```


#### Examples

- `text-editor.roc` is now `piece-table.roc` and `tui-menu.roc` is now
  `menu.roc`. Each prints one frame, and its name now says so.
- Every example carries comments that walk through it.
- The archive `roc-ansi-examples-0.13.2.zip` holds `spec.json`, the exact
  output each example printed when this release was made.

#### Documentation

- The project now has a manual, published as a site and attached to each
  release as a PDF.
- The documentation archive is `roc-ansi-docs-0.13.2.zip`. Earlier releases
  attached a `.tar.gz`.
