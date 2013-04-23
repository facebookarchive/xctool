#!/bin/bash
#
# Compile xctool on-demand so we don't have to check-in binaries.
#

XCTOOL_DIR=$(cd $(dirname $0); pwd)

TEMP_PATH=$(/usr/bin/mktemp -t xctool-build)
trap "rm -f $TEMP_PATH" EXIT

"$XCTOOL_DIR"/build.sh > $TEMP_PATH 2>&1

if [[ $? -ne 0 ]]; then
  echo "ERROR: Failed to build xctool:"
  cat $TEMP_PATH
  exit 1
fi

# Will be a short git hash or just '.' if we're not in a git repo.
REVISION=$(git rev-parse --short HEAD 2> /dev/null || echo ".")

"$XCTOOL_DIR"/build/$REVISION/Products/Release/xctool "$@"
