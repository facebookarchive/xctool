#!/bin/bash

CURRENT_DIR=$(cd $(dirname $0); pwd)
XCTOOL_DIR=$(cd $(dirname $0)/..; pwd)

BUILD_OUTPUT_DIR="$CURRENT_DIR"/build
PRODUCTS_DIR="$BUILD_OUTPUT_DIR"/Products

xcodebuild \
  build-for-testing \
  -workspace "$XCTOOL_DIR"/xctool.xcworkspace \
  -scheme xctool \
  -configuration Debug \
  -IDEBuildLocationStyle=Custom \
  -IDECustomBuildLocationType=Absolute \
  -IDECustomBuildProductsPath="$BUILD_OUTPUT_DIR/Products" \
  -IDECustomBuildIntermediatesPath="$BUILD_OUTPUT_DIR/Intermediates"

XT_INSTALL_ROOT="$PRODUCTS_DIR/Debug" \
"$PRODUCTS_DIR/Debug/bin/xctool" \
  -sdk macosx \
  run-tests \
  -logicTest "$BUILD_OUTPUT_DIR/Products"/Debug/xctool-tests.xctest \
  -bucketBy class \
  -logicTestBucketSize 1
