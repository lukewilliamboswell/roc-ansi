The unmodified SPDX 2.3.1 JSON Schema comes from `spdx/spdx-spec` tag `v2.3.1`,
`schemas/spdx-schema.json`, copied from the released Blueprint 0.7.0 source.
SHA-256: `4126dc29f15e92feec92e9622f4939131ad58b125d6f578aa93e980a6e6f3212`.

This is a test-only input, licensed CC BY 3.0 by the SPDX project contributors;
see LICENSE.spdx-schema. It is not included in the roc-ansi source bundle.
The schema has no external references. CI validates the SPDX compatibility
sidecar offline using the independently maintained check-jsonschema CLI, whose
packages and wheel hashes are pinned in ../validator-requirements.txt.
Blueprint's separate checks validate artifact hashes, inventory and cross-format
graph agreement for all three renderings. These are different validation layers.
