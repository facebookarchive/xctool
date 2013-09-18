#!/bin/bash

DYLD_FRAMEWORK_PATH=/Users/ryanrhee/xctool/xctool/xctool-tests/TestData/otest-query-tests-osx-test-bundle \
DYLD_LIBRARY_PATH=/Users/ryanrhee/xctool/xctool/xctool-tests/TestData/otest-query-tests-osx-test-bundle \
NSUnbufferedIO=YES \
DYLD_FALLBACK_FRAMEWORK_PATH=/Applications/Xcode5-DP6.app/Contents/Developer/Library/Frameworks \
OBJC_DISABLE_GC=YES \
/Users/ryanrhee/Library/Developer/Xcode/DerivedData/xctool-eylfzzvqxtaoihhetyxeqouhndug/Build/Products/Debug/libexec/otest-query-osx \
/Users/ryanrhee/xctool/xctool/xctool-tests/TestData/otest-query-tests-osx-test-bundle/TestProject-Library-XCTest-OSXTests.xctest \
XCTestCase \
xct_allSubclasses
