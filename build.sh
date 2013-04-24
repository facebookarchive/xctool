#!/bin/bash

set -e

# We need an absolute path to the dir we're in.
XCTOOL_DIR=$(cd $(dirname $0); pwd)

# Will be a short git hash or just '.' if we're not in a git repo.
REVISION=$(\
  (cd "$XCTOOL_DIR" && git rev-parse --short HEAD 2> /dev/null) || echo ".")

# If we're in a git repo, figure out if any changes have been made to xctool.
if [[ "$REVISION" != "." ]]; then
  NUM_CHANGES=$(\
    (cd "$XCTOOL_DIR" && git status --porcelain "$XCTOOL_DIR") | wc -l)
  HAS_GIT_CHANGES=$([[ $NUM_CHANGES -gt 0 ]] && echo YES || echo NO)
else
  HAS_GIT_CHANGES=NO
fi

BUILD_OUTPUT_DIR="$XCTOOL_DIR"/build/$REVISION
XCTOOL_PATH="$BUILD_OUTPUT_DIR"/Products/Release/xctool

# Skip building if we already have the latest build.  If we already have a
# build for the latest revision, and we're in a git repo, and if there have
# been no file changes to the xctool code, then skip building.
#
# If we're being told to test, we should always build.
if [[ -e "$XCTOOL_PATH" && $REVISION != "." && $HAS_GIT_CHANGES == "NO" && \
      "$1" != "TEST_AFTER_BUILD=YES" ]];
then
  echo -n "Skipping build since product already exists at '$XCTOOL_PATH' and "
  echo    "no file changes have been made on top of the last commit."
  exit 0
fi

# We're using a hack to trick otest-lib into building as a dylib for the iOS
# simulator.  Part of that hack requires us to specify paths to the SDK dirs
# ourselves and so we need to know the version numbers for the installed SDK.
# Configurations/iOS-Simulator-Dylib.xcconfig has more info.
#
# We choose the oldest available SDK here - this way otest-shim is most
# compatible. e.g. if otest-shim targeted iOS 6.1 but a test bundle (or test
# host) targetted 5.0, you'd see errors.
XT_IOS_SDK_VERSION=$(xcodebuild -showsdks | grep iphonesimulator | \
  head -n 1 | perl -ne '/iphonesimulator(.*?)$/ && print $1')
XT_IOS_SDK_VERSION_EXPANDED=$(xcodebuild -showsdks | grep iphonesimulator | \
  head -n 1 | perl -ne '/iphonesimulator(\d)\.(\d)$/ && print "${1}${2}000"')

# We pass OBJROOT, SYMROOT, and SHARED_PRECOMPS_DIR so that we can be sure
# no build output ends up in DerivedData.
xcodebuild \
  -workspace "$XCTOOL_DIR"/xctool.xcworkspace \
  -scheme xctool \
  -configuration Release \
  OBJROOT="$BUILD_OUTPUT_DIR"/Intermediates \
  SYMROOT="$BUILD_OUTPUT_DIR"/Products \
  SHARED_PRECOMPS_DIR="$BUILD_OUTPUT_DIR"/Intermediates/PrecompiledHeaders \
  XT_IOS_SDK_VERSION="$XT_IOS_SDK_VERSION" \
  XT_IOS_SDK_VERSION_EXPANDED="$XT_IOS_SDK_VERSION_EXPANDED" \
  $@

# vim: set tabstop=2 shiftwidth=2 filetype=sh:
