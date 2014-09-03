#!/bin/bash

set -e

# We need an absolute path to the dir we're in.
XCTOOL_DIR="$(cd "$(dirname "$0")"/..; pwd)"

# Will be a short git hash or just '.' if we're not in a git repo.
REVISION=$( (\
  git --git-dir="${XCTOOL_DIR}/.git" log -n 1 --format=%h 2> /dev/null) || \
  echo ".")

XCODEBUILD_VERSION=$(xcodebuild -version)
XCODEBUILD_VERSION=`expr "$XCODEBUILD_VERSION" : '^.*Build version \(.*\)'`

BUILD_OUTPUT_DIR="$XCTOOL_DIR"/build/$REVISION/$XCODEBUILD_VERSION
XCTOOL_PATH="$BUILD_OUTPUT_DIR"/Products/Release/xctool
BUILD_NEEDED_TOOL_PATH="$XCTOOL_DIR"/scripts/build_needed.sh
BUILD_NEEDED=$("$BUILD_NEEDED_TOOL_PATH" $*)

# Skip building if we already have the latest build.  If we already have a
# build for the latest revision, and we're in a git repo, and if there have
# been no file changes to the xctool code, then skip building.
#
# If we're being told to test, we should always build.
if [ "$BUILD_NEEDED" -eq 0 ]
then
  echo -n "Skipping build since product already exists at '$XCTOOL_PATH' and "
  echo    "no file changes have been made on top of the last commit."
  exit 0
fi

# xcodebuild intermittently crashes while building xctool.
#
# With Xcode 4, the crash was "Exception: Collection ... was mutated while
# being enumerated." (https://gist.github.com/fpotter/6440435).  With Xcode 5,
# we're seeing intermittent seg faults (EXC_BAD_ACCESS).
#
# To workaround these problems, let's retry the build if we don't see the
# typical "BUILD SUCCEEDED" or "BUILD FAILED" banners in the xcodebuild output.

BUILD_OUTPUT_PATH=$(/usr/bin/mktemp -t xctool-build)
trap "rm -f $BUILD_OUTPUT_PATH" EXIT
ATTEMPTS=0

while true; do
  ATTEMPTS=$((ATTEMPTS + 1))

  xcodebuild \
    -workspace "$XCTOOL_DIR"/xctool.xcworkspace \
    -scheme xctool \
    -configuration Release \
    -IDEBuildLocationStyle=Custom \
    -IDECustomBuildLocationType=Absolute \
    -IDECustomBuildProductsPath="$BUILD_OUTPUT_DIR/Products" \
    -IDECustomBuildIntermediatesPath="$BUILD_OUTPUT_DIR/Intermediates" \
    "$@" 2>&1 | /usr/bin/tee "$BUILD_OUTPUT_PATH"
  BUILD_RESULT=${PIPESTATUS[0]}

  if ! grep -q -E '(BUILD|CLEAN) (SUCCEEDED|FAILED)' "$BUILD_OUTPUT_PATH"; then
    # Assume xcodebuild crashed since we didn't get the typical 'BUILD
    # SUCCEEDED' or 'BUILD FAILED' banner in the output.

    if [[ $ATTEMPTS -le 10 ]]; then
      echo
      echo -n "xcodebuild appears to have crashed while building xctool; "
      echo    "retrying..."
      echo
      continue
    else
      echo
      echo -n "xcodebuild crashed while building xctool; giving up "
      echo    "after 10 tries."
      echo
      exit 1
    fi
  fi

  exit $BUILD_RESULT
done

# vim: set tabstop=2 shiftwidth=2 filetype=sh:
