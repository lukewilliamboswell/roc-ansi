# The roc-ansi manual

roc-ansi lets a Roc program **colour and style** what it prints, move the cursor,
read key presses and draw simple tables. It is a pure Roc package and works with
any platform that can write to a terminal.

This experimental chapter combines material from the existing manual to test
the features a replacement renderer needs. See [the checks](#run-the-checks)
or the [Roc website](https://www.roc-lang.org/).

## Get started

Add the released package to an application. This example deliberately retains
the full dependency URL, which is the longest kind of line in our manual.

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

### Learn from the examples

Each example demonstrates one capability. The screenshot below is the actual
PNG from the current manual, represented as decoded RGB pixels in the PDF.

![A sentence with three words coloured green, blue and red](animals.png)

| Example | What it demonstrates |
| --- | --- |
| `animals.roc` | Colouring individual words |
| `colors.roc` | Named, 256-colour and RGB colours |
| `styles.roc` | Bold, faint, italic and underlined text |
| `menu.roc` | A menu with its first entry highlighted |
| `piece-table.roc` | Editing a document by inserting and deleting text |

## Run the checks

The repository uses two compilers: `roc-stable` runs the automation and `roc`
checks the package with the latest nightly. *The tooling compiler is pinned.*

```sh
blueprint run check
blueprint shell
blueprint tasks
```

The check performs these steps:

1. Check compiler pins and the automation scripts.
2. Format, check and test the package.
3. Build and run every example, comparing its exact output.
4. Build fuzz targets and replay their committed corpus.
5. Check allocation ceilings and release artifacts.
6. Build and restore the documentation archive.

### Where tests live

| Kind | Where | What it checks |
| --- | --- | --- |
| Unit tests | `package/` | Expectations beside the implementation |
| Examples | `tests/spec.json` | Exact standard output and exit status |
| Properties | `fuzz/` | Replaying previously discovered inputs |
| Allocations | `tests/allocations.json` | Allocation ceilings for editing operations |
| Script logic | `scripts/src/` | Pure automation functions |

### Contributor checklist

- Keep examples short and focused.
- Review changes to recorded output.
- Keep a minimised failing input as a regression test.
- Explain any increase to an allocation ceiling.

## Release and maintain

A release is built once and tested as those exact files before publication.
Its bundle, examples archive, API documentation and PDF manual travel together.

See the [project releases](https://github.com/lukewilliamboswell/roc-ansi/releases)
and return to [Get started](#get-started).
