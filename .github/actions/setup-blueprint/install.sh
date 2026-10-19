#!/usr/bin/env bash
set -euo pipefail

# Keep these pins in step with the platform URL in Blueprint.roc.
# Reviewed against the release's blueprint.sha256 and GitHub asset digests.
version=0.6.0
case "${RUNNER_OS:-$(uname -s)}-${RUNNER_ARCH:-$(uname -m)}" in
  Linux-X64|Linux-x86_64)
    system=x86_64-linux
    sha256=027b2c4d48084d7f6a49b60a378b14dc19920de78c245db3ddffb1db034c74e0
    ;;
  Linux-ARM64|Linux-aarch64)
    system=aarch64-linux
    sha256=f328879d0121f97bce52456dacd9a52a3f50f8dde68056797bb0163d02180a43
    ;;
  macOS-ARM64|Darwin-arm64)
    system=aarch64-darwin
    sha256=a8dc735d1f022ba80eb835b31888149cd7ac9ec4c9e8d085ba94bfcb5d128857
    ;;
  *) echo "No supported Blueprint binary for this runner" >&2; exit 1 ;;
esac

directory="${RUNNER_TEMP:?RUNNER_TEMP must be set}/roc-ansi-blueprint"
mkdir -p "$directory"
candidate=$(mktemp "$directory/blueprint.XXXXXX")
trap 'rm -f "$candidate"' EXIT
curl --fail --silent --show-error --location --retry 3 \
  --proto '=https' --proto-redir '=https' \
  "https://github.com/lukewilliamboswell/roc-blueprint/releases/download/$version/blueprint-$system" \
  --output "$candidate"
printf '%s  %s\n' "$sha256" "$candidate" | shasum -a 256 --check -
chmod 755 "$candidate"
mv "$candidate" "$directory/blueprint"
printf '%s\n' "$directory" >> "${GITHUB_PATH:?GITHUB_PATH must be set}"
echo "Installed Blueprint $version for $system; SHA-256 verified"
