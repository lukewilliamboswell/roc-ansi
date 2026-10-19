#!/usr/bin/env bash
# Measure only native rendering, keeping provisioning and API generation separate.
set -euo pipefail
binary=${ROC_ANSI_DOCS_BINARY:?ROC_ANSI_DOCS_BINARY must name the verified renderer}
metrics=${ROC_ANSI_DOCS_METRICS:?ROC_ANSI_DOCS_METRICS must name the metrics directory}
mkdir -p "$metrics"
file=$(mktemp "$metrics/render.XXXXXX")
case $(uname -s) in
  Linux) time_options=(-v -o "$file") ;;
  Darwin) time_options=(-l) ;;
  *) echo "Unsupported timing host" >&2; exit 1 ;;
esac
echo "::group::Native roc-docs rendering"
printf 'Renderer command:'; printf ' %q' "$binary" "$@"; printf '\n'
set +e
if [[ $(uname -s) == Darwin ]]; then
  /usr/bin/time "${time_options[@]}" "$binary" "$@" 2> "$file"
else
  /usr/bin/time "${time_options[@]}" "$binary" "$@"
fi
status=$?
set -e
cat "$file"
echo "Native renderer exit status: $status"
echo "::endgroup::"
if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then
  {
    printf '\n### Native documentation rendering\n\n'
    printf 'Renderer: `tools-0.1.0-rc.1`; exit status: `%s`. Compiler and Docker are not invoked by this step.\n\n' "$status"
    printf '```text\n'; cat "$file"; printf '\n```\n'
  } >> "$GITHUB_STEP_SUMMARY"
fi
exit "$status"
