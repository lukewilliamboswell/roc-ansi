#!/usr/bin/env bash

# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euxo pipefail

if [ -z "${ROC:-}" ]; then
  echo "INFO: The ROC environment variable is not set."
  export ROC=$(which roc)
fi

EXAMPLES_DIR='./examples'
PACKAGE_DIR='./package'

# roc check
for ROC_FILE in $EXAMPLES_DIR/*.roc; do
    $ROC check $ROC_FILE
done

# roc build
for ROC_FILE in $EXAMPLES_DIR/*.roc; do
    $ROC build $ROC_FILE --linker=legacy
done

# test building docs website
$ROC docs $PACKAGE_DIR/main.roc
