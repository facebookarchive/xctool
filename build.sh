#!/bin/bash

set -e

XCTOOL_DIR=$(cd $(dirname $0); echo $(pwd))
BUILD_OUTPUT_DIR="$XCTOOL_DIR"/build

# We're using a hack to trick otest-lib into building as a dylib for the iOS
# simulator.  Part of that hack requires us to specify paths to the SDK dirs
# ourselves and so we need to know the version numbers for the installed SDK.
# Configurations/iOS-Simulator-Dylib.xcconfig has more info.
#
# We choose the oldest available SDK here - this way otest-lib is most
# compatible. e.g. if otest-lib targeted iOS 6.1 but a test bundle (or test
# host) targetted 5.0, you'd see errors.
XT_IOS_SDK_VERSION=$(xcodebuild -showsdks | grep iphonesimulator | \
  head -n 1 | perl -ne '/iphonesimulator(.*?)$/ && print $1')
XT_IOS_SDK_VERSION_EXPANDED=$(xcodebuild -showsdks | grep iphonesimulator | \
  head -n 1 | perl -ne '/iphonesimulator(\d)\.(\d)$/ && print "${1}${2}000"')

xcodebuild \
  -workspace "$XCTOOL_DIR"/xctool.xcworkspace \
  -scheme xctool \
  -configuration Release \
  CONFIGURATION_BUILD_DIR="$BUILD_OUTPUT_DIR" \
  XT_IOS_SDK_VERSION="$XT_IOS_SDK_VERSION" \
  XT_IOS_SDK_VERSION_EXPANDED="$XT_IOS_SDK_VERSION_EXPANDED" \
  $@
