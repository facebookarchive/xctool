#!/bin/bash
#
# Steps for making a new xctool release --
#
# 0.  Run ./make_release.sh to make sure it builds and tests pass; do some
#     QA on the version of xctool that it installs.
# 1.  Run `git status` to make sure you're working on a clean copy of master.
# 2.  Bump the version in xctool/xctool/Version.m; commit your change.
# 3.  Tag the branch; e.g. `git tag v0.1.6`
# 4.  Push the version bump; e.g. `git push origin master`
# 5.  Push the tag; e.g. `git push --tags origin`
# 6.  Run ./make_release.sh again to produce the final binary distribution.
# 7.  Go to https://github.com/facebook/xctool/releases/; find the new tag.
# 8.  Click 'Draft release notes and downloads'.
# 9.  Upload the ZIP file produced from make_release.sh.
# 10. Write some release notes - use the compare view to find what's changed.
#     https://github.com/facebook/xctool/compare/v0.1.5...v0.1.6
# 11. Publish!

set -e

XCTOOL_DIR=$(cd $(dirname $0); pwd)

OUTPUT_DIR=$(mktemp -d -t xctool-release)
BUILD_OUTPUT_DIR="$OUTPUT_DIR"/build
RELEASE_OUTPUT_DIR="$OUTPUT_DIR"/release

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
  OBJROOT="$BUILD_OUTPUT_DIR"/Intermediates \
  SYMROOT="$BUILD_OUTPUT_DIR"/Products \
  SHARED_PRECOMPS_DIR="$BUILD_OUTPUT_DIR"/Intermediates/PrecompiledHeaders \
  XT_IOS_SDK_VERSION="$XT_IOS_SDK_VERSION" \
  XT_IOS_SDK_VERSION_EXPANDED="$XT_IOS_SDK_VERSION_EXPANDED" \
  XT_INSTALL_ROOT="$RELEASE_OUTPUT_DIR" \
  TEST_AFTER_BUILD=YES

if [[ ! -x "$RELEASE_OUTPUT_DIR"/bin/xctool ]]; then
  echo "ERROR: xctool binary is missing."
  exit 1
fi

XCTOOL_VERSION=$("$RELEASE_OUTPUT_DIR"/bin/xctool -version)
ZIP_PATH="$OUTPUT_DIR"/xctool-v$XCTOOL_VERSION.zip

ditto -ckV "$RELEASE_OUTPUT_DIR" "$ZIP_PATH"

echo
echo "Release installed at '$RELEASE_OUTPUT_DIR'."
echo "ZIP available at '$ZIP_PATH'."

