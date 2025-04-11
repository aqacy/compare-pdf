#!/bin/bash

# Exit immediately if a pipeline, which may consist of a single simple command,
# a list or a compound command returns a non-zero status.
# https://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html#The-Set-Builtin
set -e
echo "RELEASE-WITH-TESTS-IN-DOCKER: script started"

# Determine the full directory path of the script no matter where it is being
# called from.
# https://stackoverflow.com/a/246128
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

"${SCRIPT_DIR}/run-in-build-env-container.sh" publish.sh
echo "RELEASE-WITH-TESTS-IN-DOCKER: script finished"