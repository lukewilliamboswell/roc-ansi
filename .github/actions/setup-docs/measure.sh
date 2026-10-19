#!/usr/bin/env bash
# Stage timings exclude GitHub action startup/cache transfer; those have their
# own timed steps in the Actions UI. Keep logs even when the command fails.
set -euo pipefail
stage=${1:?A stage name is required}
shift
metrics=${ROC_ANSI_DOCS_METRICS:-.roc-ansi-tmp/ci-metrics}
mkdir -p "$metrics"
file=$(mktemp "$metrics/stage.XXXXXX")
echo "::group::$stage"
printf 'Command:'; printf ' %q' "$@"; printf '\n'
set +e
if [[ $(uname -s) == Linux ]]; then
  /usr/bin/time -v -o "$file" "$@"
else
  /usr/bin/time -l "$@" 2> "$file"
fi
status=$?
set -e
cat "$file"
echo "Exit status: $status"
echo '::endgroup::'
if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then
  {
    printf '\n### %s\n\nExit status: `%s`\n\n```text\n' "$stage" "$status"
    cat "$file"
    printf '\n```\n'
  } >> "$GITHUB_STEP_SUMMARY"
fi
exit "$status"
