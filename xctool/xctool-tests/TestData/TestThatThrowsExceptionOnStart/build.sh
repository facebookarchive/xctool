#!/bin/bash

# Store build products under Build/...
xcodebuild \
  -project TestThatThrowsExceptionOnStart.xcodeproj \
  -scheme TestThatThrowsExceptionOnStart \
  -IDEBuildLocationStyle=Custom \
  -IDECustomBuildLocationType=RelativeToWorkspace \
  -IDECustomBuildIntermediatesPath=Build/Intermediates \
  -IDECustomBuildProductsPath=Build/Products

xcodebuild \
  -project TestThatThrowsExceptionOnStart.xcodeproj \
  -scheme TestThatThrowsExceptionOnStart \
  -IDEBuildLocationStyle=Custom \
  -IDECustomBuildLocationType=RelativeToWorkspace \
  -IDECustomBuildIntermediatesPath=Build/Intermediates \
  -IDECustomBuildProductsPath=Build/Products \
  -showBuildSettings > TestThatThrowsExceptionOnStart-showBuildSettings.txt
