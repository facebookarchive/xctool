#!/bin/bash

set -e

# We need an absolute path to the dir we're in.
XCTOOL_DIR=$(cd $(dirname $0); pwd)

# Will be a short git hash or just '.' if we're not in a git repo.
REVISION=$((\
  git --git-dir="${XCTOOL_DIR}/.git" log -n 1 --format=%h 2> /dev/null) || \
  echo ".")

BUILD_OUTPUT_DIR="$XCTOOL_DIR"/build/$REVISION
XCTOOL_PATH="$BUILD_OUTPUT_DIR"/Products/Release/xctool
BUILD_NEEDED_TOOL_PATH="$XCTOOL_DIR"/build_needed.sh
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
XT_IOS_SDK_VERSION=$(xcodebuild -showsdks | grep iphonesimulator | \
  perl -ne '/iphonesimulator(.*?)$/ && $1 >= 5.0 && print' | \
  head -n 1 | \
  perl -ne '/iphonesimulator(.*?)$/ && print $1')
XT_IOS_SDK_VERSION_EXPANDED=$(xcodebuild -showsdks | grep iphonesimulator | \
  perl -ne '/iphonesimulator(\d)\.(\d)$/ && $1 >= 5 && print' | \
  head -n 1 | \
  perl -ne '/iphonesimulator(\d)\.(\d)$/ && print "${1}${2}000"')

# We pass OBJROOT, SYMROOT, and SHARED_PRECOMPS_DIR so that we can be sure
# no build output ends up in DerivedData.
xcodebuild \
  -workspace "$XCTOOL_DIR"/xctool.xcworkspace \
  -scheme xctool \
  -configuration Release \
  -IDEBuildLocationStyle=Custom \
  -IDECustomBuildLocationType=Absolute \
  -IDECustomBuildProductsPath="$BUILD_OUTPUT_DIR/Products" \
  -IDECustomBuildIntermediatesPath="$BUILD_OUTPUT_DIR/Intermediates" \
  XT_IOS_SDK_VERSION="$XT_IOS_SDK_VERSION" \
  XT_IOS_SDK_VERSION_EXPANDED="$XT_IOS_SDK_VERSION_EXPANDED" \
  $@

# vim: set tabstop=2 shiftwidth=2 filetype=sh:
