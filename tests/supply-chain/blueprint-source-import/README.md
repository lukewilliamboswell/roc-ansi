# Source supplier SBOM cannot be imported into native consumer inventory

The root-level supplier document is the generated roc-ansi 0.13.3 dry-run source-bundle SPDX 2.3 document, unchanged. `Spec` and `Lock` are inert, minimal wire-format inputs for a consumer that pins that supplier archive by SHA-256. `composition.json` binds the supplied SPDX 2.3 document to that exact pin.

Use the Blueprint 0.7 released standalone app (not a sibling checkout):

```sh
TOOL=https://github.com/lukewilliamboswell/roc-blueprint/releases/download/0.7.0/roc-blueprint-sbom-2pLqc6Kr6KE3fw5JE4z17TMnhKYP3npqDMBTVm9K2oKP.tar.zst
roc run "$TOOL" -- inspect Spec Lock composition.json source source-inventory.json
roc run "$TOOL" -- inspect Spec Lock composition.json x86_64-linux native-inventory.json
```

Use compiler nightly-2026-10-21-5349569, the app's declared compiler. Outputs are write-once; remove generated inventories before repeating.

Expected: source import succeeds and the same source graph can be bound into a native inventory without claiming that source archives are native executable code.

The native inventory should retain the supplier subject/component target `source`, exact archive digest, producer namespace and graph. A source archive is architecture-independent and the downstream executable's target is a separate identity. `dependsOn` with build scope in this fixture models an input to compilation rather than distributing the archive inside the final executable.

Relevant 0.7 implementation locations:

- `blueprint-core/Sbom.roc:918`: import target must equal consumer target, except when consumer itself is source.
- `blueprint-core/Sbom.roc:229`: component target must equal inventory target; imported components preserve their source target.
- `blueprint-core/Sbom.roc:439`: final binding repeats component-vs-subject target check.
- `blueprint-core/Sbom.roc:948` and `:955`: supplier metadata/component identity checks must remain strict; never relabel the supplier as native merely to pass these guards.

A narrow fix should admit architecture-independent `source` inputs/components in native inventories at all three gates, while continuing to reject native `aarch64-linux` inputs in an `x86_64-linux` inventory. Keep subject and source identities intact, and preserve the composition edge's meaning. A broader future model may need explicit transform/derivation relationships, but is not needed to demonstrate this rejection.

Integrity controls were also exercised with the actual roc-ansi supplier, using consumer target `source` to avoid masking their results with the native-target rejection:

| Input | Change | Observed rejection (exit 1) |
| --- | --- | --- |
| `tamper-document-digest.json` | Imported document SHA-256 replaced by 64 zeroes | `imported SBOM content digest mismatch` |
| `tamper-artifact-digest.json` | Bound subject SHA-256 replaced by 64 zeroes | `import subject filename/version/SHA256 mismatch` |
| `tamper-artifact-version.json` | Bound subject version replaced by `999.0.0` | `import subject filename/version/SHA256 mismatch` |

To repeat an integrity refusal, use the same released tool invocation above, replacing `composition.json` with that input and keeping target `source`; choose a fresh output filename. Create these variants from composition.json with jq or any JSON editor; the recorded diagnostics above came from actual runs. No supplier URLs are fetched: its exact bytes are already embedded in each inert composition. The Roc compiler can fetch/cache the pinned reporting app and its platform/core packages.

This is an inert regression/repro fixture, not evidence that package 0.13.3 has been published. It records the candidate source bundle at commit 48048bc. The importer does not download or execute the supplier artifact.
