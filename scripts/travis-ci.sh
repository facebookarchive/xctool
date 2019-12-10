#!/bin/bash

set -e

OUTPUT_DIR=$(mktemp -d -t xctool-release)
BUILD_OUTPUT_DIR="$OUTPUT_DIR"/build
RELEASE_OUTPUT_DIR="$OUTPUT_DIR"/release
XCTOOL_DIR=$(cd $(dirname $0)/..; pwd)

[[ -n "${TRAVIS}" ]] && echo "travis_fold:start:build_xctool_tests"
[[ -n "${TRAVIS}" ]] && echo "Build xctool and tests"

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

[[ -n "${TRAVIS}" ]] && echo "travis_fold:end:build_xctool_tests"

if [[ ! -x "$RELEASE_OUTPUT_DIR"/bin/xctool ]]; then
  echo "ERROR: xctool binary is missing."
  exit 1
fi

XT_INSTALL_ROOT="$RELEASE_OUTPUT_DIR" \
"$RELEASE_OUTPUT_DIR"/bin/xctool \
  -sdk macosx \
  run-tests \
  -logicTest "$BUILD_OUTPUT_DIR/Products"/Debug/xctool-tests.xctest \
  -bucketBy class \
  -logicTestBucketSize 1
