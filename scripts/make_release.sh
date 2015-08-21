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

XCTOOL_DIR=$(cd $(dirname $0)/..; pwd)

OUTPUT_DIR=$(mktemp -d -t xctool-release)
BUILD_OUTPUT_DIR="$OUTPUT_DIR"/build
RELEASE_OUTPUT_DIR="$OUTPUT_DIR"/release

xcodebuild \
  -workspace "$XCTOOL_DIR"/xctool.xcworkspace \
  -scheme xctool \
  -configuration Release \
  -IDEBuildLocationStyle=Custom \
  -IDECustomBuildLocationType=Absolute \
  -IDECustomBuildProductsPath="$BUILD_OUTPUT_DIR/Products" \
  -IDECustomBuildIntermediatesPath="$BUILD_OUTPUT_DIR/Intermediates" \
  XT_INSTALL_ROOT="$RELEASE_OUTPUT_DIR"

if [[ ! -x "$RELEASE_OUTPUT_DIR"/bin/xctool ]]; then
  echo "ERROR: xctool binary is missing."
  exit 1
fi

"$RELEASE_OUTPUT_DIR"/bin/xctool \
  -workspace "$XCTOOL_DIR"/xctool.xcworkspace \
  -scheme xctool \
  -configuration Release \
  test

XCTOOL_VERSION=$("$RELEASE_OUTPUT_DIR"/bin/xctool -version)
ZIP_PATH="$OUTPUT_DIR"/xctool-v$XCTOOL_VERSION.zip

ditto -ckV "$RELEASE_OUTPUT_DIR" "$ZIP_PATH"

echo
echo "Release installed at '$RELEASE_OUTPUT_DIR'."
echo "ZIP available at '$ZIP_PATH'."

