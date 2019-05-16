#!/bin/bash

# We need an absolute path to the dir we're in.
CURRENT_DIR="$(cd "$(dirname "$0")"; pwd)"

# Store build products under Build/...
xcodebuild \
  -project "$CURRENT_DIR"/TestProject-UITests.xcodeproj \
  -scheme TestProject-UITests \
  -sdk iphonesimulator \
  build-for-testing \
  -IDEBuildLocationStyle=Custom \
  -IDECustomBuildLocationType=RelativeToWorkspace \
  -IDECustomBuildIntermediatesPath=Build/Intermediates \
  -IDECustomBuildProductsPath=Build/Products
