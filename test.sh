#!/bin/bash

set -e

XCTOOL_DIR=$(cd $(dirname $0); pwd)

# `mktemp -d -t xctool-debug`
OUTPUT_DIR=/var/folders/8p/n028bzz51m52b38w37wb0pbn2tm091/T/xctool-debug.znTTuka7
BUILD_OUTPUT_DIR="$OUTPUT_DIR"/build
DEBUG_OUTPUT_DIR="$OUTPUT_DIR"/debug

xcodebuild \
  build-for-testing \
  -workspace "$XCTOOL_DIR"/xctool.xcworkspace \
  -scheme xctool \
  -configuration Debug \
  -IDEBuildLocationStyle=Custom \
  -IDECustomBuildLocationType=Absolute \
  -IDECustomBuildProductsPath="$BUILD_OUTPUT_DIR/Products" \
  -IDECustomBuildIntermediatesPath="$BUILD_OUTPUT_DIR/Intermediates" \
  XT_INSTALL_ROOT="$DEBUG_OUTPUT_DIR"

XT_INSTALL_ROOT="$DEBUG_OUTPUT_DIR" \
"$DEBUG_OUTPUT_DIR"/bin/xctool \
  -sdk macosx \
  run-tests \
  -logicTest "$BUILD_OUTPUT_DIR/Products"/Debug/xctool-tests.xctest \
  -parallelize \
  -bucketBy class \
  -logicTestBucketSize 1 \
  -showTasks

# -only "$BUILD_OUTPUT_DIR/Products"/Debug/xctool-tests.xctest:OTestQueryTests

# -[OTestQueryTests testCanQueryXCTestClassesFromIOSBundle]
# -[OTestShimTests testXCTestExceptionIsThrownWhenSuiteTimeoutIsHitInSetup]
