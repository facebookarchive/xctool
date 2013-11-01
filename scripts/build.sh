#!/bin/bash

set -e

# We need an absolute path to the dir we're in.
XCTOOL_DIR=$(cd $(dirname $0)/..; pwd)

# Will be a short git hash or just '.' if we're not in a git repo.
REVISION=$( (\
  git --git-dir="${XCTOOL_DIR}/.git" log -n 1 --format=%h 2> /dev/null) || \
  echo ".")

BUILD_OUTPUT_DIR="$XCTOOL_DIR"/build/$REVISION
XCTOOL_PATH="$BUILD_OUTPUT_DIR"/Products/Release/xctool
BUILD_NEEDED_TOOL_PATH="$XCTOOL_DIR"/scripts/build_needed.sh
BUILD_NEEDED=$($BUILD_NEEDED_TOOL_PATH $*)

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

# We're using a hack to trick otest-shim into building as a dylib for the iOS
# simulator.  Part of that hack requires us to specify paths to the SDK dirs
# ourselves and so we need to know the version numbers for the installed SDK.
# Configurations/iOS-Simulator-Dylib.xcconfig has more info.
#
# We choose the oldest available SDK that's >= 5.0 - this way otest-shim is
# most compatible. e.g. if otest-shim targeted iOS 6.1 but a test bundle (or
# test host) targetted 5.0, you'd see errors.  We don't go older than 5.0 since
# we depend on some iOS 5+ APIs.
#
# We need to build universal binaries for otest-query, but iOS versions below
# 7.0 don't have any 64-bit frameworks. To make this work, we're going to figure
# out the lowest possible SDK version that supports 64-bit separately from the
# lowest possible SDK version that supports 32-bit.
#
# 32-bit is minimum iOS 5.0
_XT_IOS_SDK_32=$(xcodebuild -showsdks | grep iphonesimulator | \
  perl -ne '/iphonesimulator(.*?)$/ && $1 >= 5.0 && print' | \
  head -n 1)
XT_IOS_SDK_VERSION_32=$(echo $_XT_IOS_SDK_32 | \
  perl -ne '/iphonesimulator(.*?)$/ && print $1')
XT_IOS_SDK_VERSION_EXPANDED_32=$(echo $_XT_IOS_SDK_32 | \
  perl -ne '/iphonesimulator(\d)\.(\d)$/ && print "${1}${2}000"')
# 64-bit is minimum iOS 7.0
_XT_IOS_SDK_64=$(xcodebuild -showsdks | grep iphonesimulator | \
  perl -ne '/iphonesimulator(.*?)$/ && $1 >= 7.0 && print' | \
  head -n 1)
if [[ $_XT_IOS_SDK_64 ]]; then
  XT_IOS_SDK_VERSION_64=$(echo $_XT_IOS_SDK_64 | \
    perl -ne '/iphonesimulator(.*?)$/ && print $1')
  XT_IOS_SDK_VERSION_EXPANDED_64=$(echo $_XT_IOS_SDK_64 | \
    perl -ne '/iphonesimulator(\d)\.(\d)$/ && print "${1}${2}000"')
else
  XT_IOS_SDK_VERSION_64=UNSUPPORTED
  XT_IOS_SDK_VERSION_EXPANDED_64=UNSUPPORTED
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
    XT_IOS_SDK_VERSION_32="$XT_IOS_SDK_VERSION_32" \
    XT_IOS_SDK_VERSION_EXPANDED_32="$XT_IOS_SDK_VERSION_EXPANDED_32" \
    XT_IOS_SDK_VERSION_64="$XT_IOS_SDK_VERSION_64" \
    XT_IOS_SDK_VERSION_EXPANDED_64="$XT_IOS_SDK_VERSION_EXPANDED_64" \
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
