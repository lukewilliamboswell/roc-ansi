# Feedback on Blueprint utility caching and roc automation adoption

The roc-ansi migration shows that Blueprint already supplies the download,
verification and local store needed for native shared utilities. Blueprint
explains those mechanisms. roc-automation does not yet connect them into a
complete adoption path for a pure Roc package: installing Blueprint without
Nix, declaring a utility, persisting its downloads in GitHub Actions, and passing
its executable to a shared action.

The package compiler should continue to float. This feedback concerns released
utilities and the fixed compilers used by repository tooling and Blueprint
configuration. It does not propose pinning the package nightly or delaying its
updates to improve cache reuse.

## Published documentation reviewed

Reviewed October 19, 2026, against Blueprint `0.6.0-rc1`
(`7b3965ad96fcb0edef6bd6fb01ca183153bb0d06`) and roc-automation
`tools-0.1.0-rc.1` (`dec2d52a5cb6cd251fd188ad1d797f400ee1bb6e`). Those were
also the remote main revisions at review time. Local roc-automation has
additional development changes; the findings below use the published revision.

| Topic | Published guidance | What adopting roc-ansi required |
| --- | --- | --- |
| Fetch a released executable | Blueprint documents `Fetch`, `File`, `Archive`, system recipes and locking. [Configuration](https://github.com/lukewilliamboswell/roc-blueprint/blob/7b3965ad96fcb0edef6bd6fb01ca183153bb0d06/docs/configuration.adoc#fetch-a-program) | Apply that general recipe to the three roc-docs release asset names; no new download mechanism was needed. |
| Local store and CI trust | Blueprint explicitly says to cache `v1/artifacts` and rebuild trees, with artifact verification on reuse. [Store documentation](https://github.com/lukewilliamboswell/roc-blueprint/blob/7b3965ad96fcb0edef6bd6fb01ca183153bb0d06/docs/without-nix.adoc#the-store-of-downloads) | Turn the prose into a GitHub Actions cache step with the actual path, key, restore/save lifecycle and diagnostics. |
| Install Blueprint without Nix | Blueprint documents its standalone executable and when Nix is required. [Getting started](https://github.com/lukewilliamboswell/roc-blueprint/blob/7b3965ad96fcb0edef6bd6fb01ca183153bb0d06/docs/getting-started.adoc) | Write a local installer: roc-automation's released setup action unconditionally installs Nix. [Action implementation](https://github.com/lukewilliamboswell/roc-automation/blob/dec2d52a5cb6cd251fd188ad1d797f400ee1bb6e/actions/setup-blueprint/action.yml) |
| Install the renderer before using the shared action | roc-automation explicitly delegates installation and verification to the caller. Its example uses `/path/to/verified/roc-docs`. [Shared actions](https://github.com/lukewilliamboswell/roc-automation/blob/dec2d52a5cb6cd251fd188ad1d797f400ee1bb6e/docs/actions.adoc#build-docs) | Supply the missing Blueprint declaration, lock entries, provisioning step and executable handoff. |
| Executable lifetime between steps | Blueprint documents task PATH links and their removal when a step ends. [PATH documentation](https://github.com/lukewilliamboswell/roc-blueprint/blob/7b3965ad96fcb0edef6bd6fb01ca183153bb0d06/docs/without-nix.adoc#what-is-on-path) | Resolve the executable through `realpath` inside the task. A plain `command -v` yielded a path that disappeared before the next action. |
| Migration procedure | roc-automation's environment and adoption chapters still lead through Nix, overlays and `Command`. [Environment](https://github.com/lukewilliamboswell/roc-automation/blob/dec2d52a5cb6cd251fd188ad1d797f400ee1bb6e/docs/environment.adoc), [Adoption](https://github.com/lukewilliamboswell/roc-automation/blob/dec2d52a5cb6cd251fd188ad1d797f400ee1bb6e/docs/adopting.adoc) | Assemble a separate pure-package migration path using `Programs`, `Fetch` and `Expect`. |

The caching and temporary-path behavior were documented, rather than discoveries
of undocumented Blueprint behavior. The missing piece was a tested integration
example in roc-automation. The unconditional Nix installation is also an action
capability gap; changing prose alone cannot remove that cost.

## Integration work carried by roc ansi

The working branch has 175 lines across five local setup and measurement files:

- `.github/actions/setup-blueprint/action.yml`: artifact caching and hit reporting.
- `.github/actions/setup-blueprint/install.sh`: standalone binary installation,
  reviewed checksums and executable setup.
- `.github/actions/setup-docs/action.yml`: resolve the verified renderer and
  expose a persistent executable path to the shared action.
- `.github/actions/setup-docs/render.sh`: renderer process timing and RSS.
- `.github/actions/setup-docs/measure.sh`: separate input, API and release stages.

That count includes diagnostics; it is not all essential installation code.
`Blueprint.roc` and `Blueprint.lock` additionally supply the utility recipe,
docs environment and tasks. Workflows wire those pieces together. Other
repositories should retain their own task declarations and source checks,
while shared setup, cache guidance and diagnostic conventions should be reusable.

Working references are at roc-ansi commit
[`355d5d8`](https://github.com/lukewilliamboswell/roc-ansi/tree/355d5d8):
[setup Blueprint](https://github.com/lukewilliamboswell/roc-ansi/tree/355d5d8/.github/actions/setup-blueprint),
[setup renderer and measurements](https://github.com/lukewilliamboswell/roc-ansi/tree/355d5d8/.github/actions/setup-docs),
[Blueprint declaration](https://github.com/lukewilliamboswell/roc-ansi/blob/355d5d8/Blueprint.roc),
[comparison workflow](https://github.com/lukewilliamboswell/roc-ansi/blob/355d5d8/.github/workflows/docs-spike.yml).
These are reference implementations, not a request to copy all five files into
every repository.

## Changes requested for roc automation

1. Add a pure-package adoption guide covering the whole path: install the
   matching Blueprint release, declare a released utility, update and review
   the lock, restore the artifact cache, run the task, and upload its outputs.
   Link it from `README.md`, `docs/adopting.adoc`, `docs/environment.adoc` and
   the `build-docs` section of `docs/actions.adoc`.
2. Extend the shared setup action to support the Nix-free path, retaining Nix
   for repositories whose requested tools/builds need it. Reuse its existing
   reviewed-release checksum registry and platform-URL version selection;
   downstream repositories should not maintain a second installer and duplicate
   Blueprint version/checksum pins. Describe the behavior in the same change.
3. Publish a concrete cache example or shared setup support. Cover
   `${XDG_CACHE_HOME:-$HOME/.cache}/blueprint/v1/artifacts`, restoring before
   the first Blueprint command, saving after the workload, and verification of
   restored bytes. Do not restore `v1/trees` or `.blueprint/run` as trusted
   executable state.
4. Include the complete `roc-docs` recipe and task example beside `build-docs`.
   Prefer running a utility inside its Blueprint task when sufficient. When
   passing a path to another action, show how to resolve the task symlink
   before it expires, declare the expected host tools, and explain that the
   resulting path is valid within that job. A future stable tool-path output
   could replace this workaround, but should not be shown as an existing API.
5. Standardise lightweight diagnostics: release, verified digest, artifact size,
   exact cache hit/miss, provisioning duration, native process duration/RSS,
   output sizes and separate preparation/API time. Keep independent browser/PDF
   acceptance tooling outside the rendering cost measurement.
6. Update `docs/maintenance.adoc` and `docs/security-model.adoc` alongside the
   setup change: distinguish a pure package from a native platform needing Nix,
   explain how utility/lock updates invalidate cached downloads, and state what
   is verified after restore. Cross-link Blueprint for the detailed store rules.

## Cache details the example must explain

GitHub caches are immutable for a key. If several jobs use one key but fetch
different subsets, a successful job that saves only compilers can leave later
docs jobs restoring a cache without the renderer. That is a design hazard
identified during the integration, not a reproduced cache-corruption bug.

Our key includes OS, architecture, lockfile/installer hash, workflow, job and a
matrix workload suffix. Jobs with different tool sets therefore save separate
caches. This trades cache storage duplication for predictable contents. Other
valid designs could prefetch a complete tool set before saving or split caches
by artifact. Document a tested strategy rather than prescribing our exact key
as the only solution. Ordinary branch/PR cache access and failed-job save
behavior also belong in the example's explanation.

The cache contains downloads for pinned utilities and fixed compiler archives.
It does not pin the latest package compiler, preserve every compiler build
result, or remove all network transfer: restoring a GitHub cache transfers its
bytes from GitHub rather than the original release host. Blueprint's own
installer is a separate bootstrap download in our current implementation.

Roc packages are separate: Blueprint places them in Roc's package cache, not
`v1/artifacts`. Our Actions cache does not separately persist `roc/packages`.
Do not promise that caching Blueprint artifacts also caches all package sources.
[Blueprint documents that distinction](https://github.com/lukewilliamboswell/roc-blueprint/blob/7b3965ad96fcb0edef6bd6fb01ca183153bb0d06/docs/without-nix.adoc#how-a-download-is-made).

## Evidence and acceptance for the next repository

The [final comparison](https://github.com/lukewilliamboswell/roc-ansi/actions/runs/39181249071)
passed for both native and Docker backends. The earlier measured comparison
used the same commit and generated-input hashes: render-action time was
89.275 seconds for Docker versus 0.614 seconds native, plus about two seconds
of cold native provisioning. Docker produced a 3.36 GB image; the Linux native
utility is 21.4 MB. Image disk size is not measured network traffic.

The [warm run](https://github.com/lukewilliamboswell/roc-ansi/actions/runs/39181087922)
restored an exact artifact-cache hit and did not fetch the renderer or locked
compiler archives from their release URLs. Native rendering took 0.40 seconds
at 30,756 KiB RSS. The complete cache transfer was 150,391,895 bytes, mostly
fixed compiler/tool downloads. Full measurements and presentation gaps are in
[ADOPTION.md](ADOPTION.md).

A reusable adoption example should itself be exercised on a fresh runner and
then on a second runner with the same lock. The first should provision verified
assets; the second should report a hit and avoid upstream utility downloads.
A changed utility release should require a reviewed lock update and a suitable
new cache entry. A fixture with different job tool subsets should demonstrate
that neither job blocks the other's tools from being saved.

For each adopting repository, also verify its real manual, stable routes and
anchors, source blocks, tables, figures, release-specific PDF names and API
assembly. Retain a local build path identical to CI. Keep deployment separate
from this validation. The package compiler must still resolve the latest
nightly according to the repository's existing workflow policy.
