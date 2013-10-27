#!/bin/bash

# Store build products under Build/...
xcodebuild \
  -workspace KiwiTests.xcworkspace \
  -scheme KiwiTests \
  -sdk iphonesimulator \
  -IDEBuildLocationStyle=Custom \
  -IDECustomBuildLocationType=RelativeToWorkspace \
  -IDECustomBuildIntermediatesPath=Build/Intermediates \
  -IDECustomBuildProductsPath=Build/Products
