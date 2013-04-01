#!/bin/bash
#
# Compile xcodetool on-demand so we don't have to check-in binaries.
#

XCODETOOL_DIR=$(cd $(dirname $0); pwd)

TEMP_PATH=$(/usr/bin/mktemp -t xcodetool-build)
trap "rm -f $TEMP_PATH" EXIT

"$XCODETOOL_DIR"/build.sh > $TEMP_PATH 2>&1

if [[ $? -ne 0 ]]; then
  echo "ERROR: Failed to build xcodetool:"
  cat $TEMP_PATH
  exit 1
fi

"$XCODETOOL_DIR"/build/xcodetool "$@"
