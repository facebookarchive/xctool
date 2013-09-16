#!/bin/bash

#DYLD_INSERT_LIBRARIES=/Users/ryanrhee/Library/Developer/Xcode/DerivedData/xctool-eylfzzvqxtaoihhetyxeqouhndug/Build/Products/Debug/otest-shim-osx.dylib  \
#OBJC_DISABLE_GC=YES \
#  DYLD_LIBRARY_PATH=/Users/ryanrhee/Library/Developer/Xcode/DerivedData/TestProject-Library-XCTest-OSX-batsoojjkpqshzfuesruqqvzfxcl/Build/Products/Debug \
#  /Applications/Xcode.app/Contents/Developer/usr/bin/xctest \
#  -XCTest Self \
#  /Users/ryanrhee/Library/Developer/Xcode/DerivedData/TestProject-Library-XCTest-OSX-batsoojjkpqshzfuesruqqvzfxcl/Build/Products/Debug/TestProject-Library-XCTest-OSXTests.xctest 

DYLD_INSERT_LIBRARIES=/Users/ryanrhee/Library/Developer/Xcode/DerivedData/xctool-eylfzzvqxtaoihhetyxeqouhndug/Build/Products/Debug/otest-shim-osx.dylib  \
  OBJC_DISABLE_GC=YES \
  DYLD_LIBRARY_PATH=/Users/ryanrhee/Library/Developer/Xcode/DerivedData/TestProject-Library-OSX-faaljnjustqueiglzznsfbozwuwl/Build/Products/Debug \
  /Applications/Xcode.app/Contents/Developer/Tools/otest \
  -SenTest Self \
  -SenTestInvertScope YES \
  /Users/ryanrhee/Library/Developer/Xcode/DerivedData/TestProject-Library-OSX-faaljnjustqueiglzznsfbozwuwl/Build/Products/Debug/TestProject-Library-OSXTests.octest 
