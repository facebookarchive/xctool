#!/bin/bash

set -e
set -x

export JAVA_HOME=$(/usr/libexec/java_home -v 1.7)

# Build xctool with xcodebuild
scripts/build.sh && ./xctool.sh -workspace xctool.xcworkspace -scheme xctool build build-tests run-tests

# Fetch latest upstream Buck version
git clone https://github.com/facebook/buck.git Vendor/buck

# Build xctool with Buck
TERM=dumb PATH=Vendor/buck/bin:$PATH buck build //:xctool-zip
