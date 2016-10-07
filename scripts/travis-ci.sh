#!/bin/bash

set -e
set -x

export JAVA_HOME=$(/usr/libexec/java_home -v 1.7)

OUTPUT_DIR=$(mktemp -d -t xctool-release)
BUILD_OUTPUT_DIR="$OUTPUT_DIR"/build
RELEASE_OUTPUT_DIR="$OUTPUT_DIR"/release
XCTOOL_DIR=$(cd $(dirname $0)/..; pwd)

# Build xctool with xcodebuild
xcodebuild \
  build-for-testing \
  -workspace "$XCTOOL_DIR"/xctool.xcworkspace \
  -scheme xctool \
  -configuration Debug \
  -IDEBuildLocationStyle=Custom \
  -IDECustomBuildLocationType=Absolute \
  -IDECustomBuildProductsPath="$BUILD_OUTPUT_DIR/Products" \
  -IDECustomBuildIntermediatesPath="$BUILD_OUTPUT_DIR/Intermediates" \
  XT_INSTALL_ROOT="$RELEASE_OUTPUT_DIR"

if [[ ! -x "$RELEASE_OUTPUT_DIR"/bin/xctool ]]; then
  echo "ERROR: xctool binary is missing."
  exit 1
fi

XT_INSTALL_ROOT="$RELEASE_OUTPUT_DIR" \
"$RELEASE_OUTPUT_DIR"/bin/xctool \
  -sdk macosx \
  run-tests \
  -logicTest "$BUILD_OUTPUT_DIR/Products"/Debug/xctool-tests.xctest \
  -parallelize \
  -bucketBy class \
  -logicTestBucketSize 1

# Fetch latest upstream Buck version
git clone https://github.com/facebook/buck.git Vendor/buck

# Build xctool with Buck
TERM=dumb PATH=Vendor/buck/bin:$PATH buck build //:xctool-zip
