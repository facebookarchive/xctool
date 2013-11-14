#!/bin/bash

# Store build products under Build/...
xcodebuild \
  -project TestProject-App-OSX.xcodeproj \
  -scheme TestProject-App-OSX \
  -IDEBuildLocationStyle=Custom \
  -IDECustomBuildLocationType=RelativeToWorkspace \
  -IDECustomBuildIntermediatesPath=Build/Intermediates \
  -IDECustomBuildProductsPath=Build/Products
