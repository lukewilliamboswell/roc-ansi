#!/usr/bin/env bash
set -euo pipefail

# Keep these pins in step with the platform URL in Blueprint.roc.
# Reviewed against the release's blueprint.sha256 and GitHub asset digests.
version=0.6.0-rc1
case "${RUNNER_OS:-$(uname -s)}-${RUNNER_ARCH:-$(uname -m)}" in
  Linux-X64|Linux-x86_64)
    system=x86_64-linux
    sha256=995dc7f40aa2aa7d56ecdf180555602e66c40e34d84cf00d96051fa3688183bb
    ;;
  Linux-ARM64|Linux-aarch64)
    system=aarch64-linux
    sha256=0421082a2ec428cb5e0a1a87275e8ba732fbc6362e8471910fa09e38efa384ef
    ;;
  macOS-ARM64|Darwin-arm64)
    system=aarch64-darwin
    sha256=e4e17c51ed1213c61118eb0e0098c30c5bbb238b282504aaeff7126abf5096de
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
