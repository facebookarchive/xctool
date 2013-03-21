#!/bin/bash
#
# Compile xcodetool on-demand so we don't have to check-in binaries.
#

set -e

XCODETOOL_DIR=$(cd $(dirname $0); pwd)

pushd $XCODETOOL_DIR > /dev/null
(xcodebuild \
  -workspace xcodetool.xcworkspace \
  -scheme xcodetool \
  CONFIGURATION_BUILD_DIR=`pwd`/build 2>&1) > /dev/null

if [[ $? -ne 0 ]]; then
  echo "\
Failed to build xcodetool.  Try to build xcodetool.xcworkspace to \
get more info on the error."
  exit 1
fi
popd > /dev/null

$XCODETOOL_DIR/build/xcodetool "$@"
