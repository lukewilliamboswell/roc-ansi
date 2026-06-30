#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

ROC_BIN="${ROC:-roc}"

if [ -n "${ROC_ANSI_TMPDIR:-}" ]; then
    tmp_base="$ROC_ANSI_TMPDIR"
else
    tmp_base="$root_dir/.roc-ansi-tmp"
fi
export ROC_ANSI_TMPDIR="$tmp_base"
export ROC="$ROC_BIN"

tmp_dir="$tmp_base/roc-ansi-ci"
docs_dir="$tmp_dir/docs"
bundle_dir="$tmp_dir/bundle"

rm -rf "$tmp_dir"
mkdir -p "$docs_dir" "$bundle_dir"

echo "$("$ROC_BIN" version)"

echo ""
echo "Checking format..."
"$ROC_BIN" fmt --check package examples

echo ""
echo "Checking package..."
"$ROC_BIN" check package/main.roc

echo ""
echo "Running package tests..."
"$ROC_BIN" test package/main.roc

echo ""
echo "Generating package docs..."
"$ROC_BIN" docs package/main.roc --output="$docs_dir"

case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*)
        echo ""
        echo "Skipping package bundling on Windows."
        exit 0
        ;;
esac

echo ""
echo "Bundling package..."
scripts/bundle.sh --output-dir "$bundle_dir"

echo ""
echo "Testing examples against localhost bundle..."
python3 ci/test_bundle_examples.py
