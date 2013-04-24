
## xcodebuild-shim

__xcodebuild-shim__ tricks _xcodebuild_ into writing all of its output
as structured JSON rather than plain text.  It does this by swizzling a
few methods in a class called `Xcode3CommandLineBuildLogRecorder` to
capture the build log events when they're still in structured form.

Instead of outputing text like this:

```
=== CLEAN NATIVE TARGET TestProject-Library OF PROJECT
TestProject-Library WITH CONFIGURATION Debug ===
Check dependencies

Clean.Remove clean
DerivedData/TestProject-Library/Build/Intermediates/TestProject-Library.build/Debug-iphoneos/TestProject-Library.build
    builtin-rm -rf
/Users/fpotter/fb/git/fbobjc/Tools/xctool/xctool/xctool-tests/TestData/TestProject-Library/DerivedData/TestProject-Library/Build/Intermediates/TestProject-Library.build/Debug-iphoneos/TestProject-Library.build

Clean.Remove clean
DerivedData/TestProject-Library/Build/Products/Debug-iphoneos/libTestProject-Library.a
    builtin-rm -rf
/Users/fpotter/fb/git/fbobjc/Tools/xctool/xctool/xctool-tests/TestData/TestProject-Library/DerivedData/TestProject-Library/Build/Products/Debug-iphoneos/libTestProject-Library.a


** CLEAN SUCCEEDED **
```

It outputs events in JSON form, one-per-line:

```
{"configuration":"Debug","project":"TestProject-Library","event":"begin-build-target","target":"TestProject-Library"}
{"event":"begin-build-command","title":"Check dependencies","command":"Check dependencies"}
{"succeeded":true,"emittedOutputText":"","title":"Check dependencies","event":"end-build-command","duration":0.04405003786087036}
{"event":"begin-build-command","title":"Remove \/Users\/fpotter\/fb\/git\/fbobjc\/Tools\/xctool\/xctool\/xctool-tests\/TestData\/TestProject-Library\/DerivedData\/TestProject-Library\/Build\/Intermediates\/TestProject-Library.build\/Debug-iphoneos\/TestProject-Library.build","command":"Clean.Remove clean DerivedData\/TestProject-Library\/Build\/Intermediates\/TestProject-Library.build\/Debug-iphoneos\/TestProject-Library.build\n    builtin-rm -rf \/Users\/fpotter\/fb\/git\/fbobjc\/Tools\/xctool\/xctool\/xctool-tests\/TestData\/TestProject-Library\/DerivedData\/TestProject-Library\/Build\/Intermediates\/TestProject-Library.build\/Debug-iphoneos\/TestProject-Library.build\n"}
{"succeeded":true,"emittedOutputText":"","title":"Remove \/Users\/fpotter\/fb\/git\/fbobjc\/Tools\/xctool\/xctool\/xctool-tests\/TestData\/TestProject-Library\/DerivedData\/TestProject-Library\/Build\/Intermediates\/TestProject-Library.build\/Debug-iphoneos\/TestProject-Library.build","event":"end-build-command","duration":0.0009080171585083008}
{"event":"begin-build-command","title":"Remove \/Users\/fpotter\/fb\/git\/fbobjc\/Tools\/xctool\/xctool\/xctool-tests\/TestData\/TestProject-Library\/DerivedData\/TestProject-Library\/Build\/Products\/Debug-iphoneos\/libTestProject-Library.a","command":"Clean.Remove clean DerivedData\/TestProject-Library\/Build\/Products\/Debug-iphoneos\/libTestProject-Library.a\n    builtin-rm -rf \/Users\/fpotter\/fb\/git\/fbobjc\/Tools\/xctool\/xctool\/xctool-tests\/TestData\/TestProject-Library\/DerivedData\/TestProject-Library\/Build\/Products\/Debug-iphoneos\/libTestProject-Library.a\n"}
{"succeeded":true,"emittedOutputText":"","title":"Remove \/Users\/fpotter\/fb\/git\/fbobjc\/Tools\/xctool\/xctool\/xctool-tests\/TestData\/TestProject-Library\/DerivedData\/TestProject-Library\/Build\/Products\/Debug-iphoneos\/libTestProject-Library.a","event":"end-build-command","duration":0.001096010208129883}
{"configuration":"Debug","project":"TestProject-Library","event":"end-build-target","target":"TestProject-Library"}
```

### Usage

```
DYLD_INSERT_LIBRARIES=path/to/xcodebuild-shim.dylib \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SomeProject.xcodeproj \
  -scheme SomeScheme
```

NOTE: It must be used with the _xcodebuild_ binary under _Xcode.app_
rather than _/usr/bin/xcodebuild_.


## xcodebuild-fastsettings-shim

__xcodebuild-fastsettings-shim__ makes _xcodebuild's_
`-showBuildSettings` option work faster by limiting its scope.  

_showBuildSettings_ normally dumps build settings for the main target as
well as all dependencies.  If you have a large app with many
dependencies, _showBuildSettings_ can be very expensive.  For some
large apps, we've seen this shim make `-showBuildSettings` twice as
fast.


You can make `-showBuildSettings` output settings for only a specific
target:

```
DYLD_INSERT_LIBRARIES=path/to/xcodebuild-fastsettings-shim.dylib \
  SHOW_ONLY_BUILD_SETTINGS_FOR_TARGET=SomeTarget \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SomeProject.xcodeproj \
  -scheme SomeScheme \
  -showBuildSettings 
```

Or, you can make it just output setings for the first target it sees and
skip all the rest:

```
DYLD_INSERT_LIBRARIES=path/to/xcodebuild-fastsettings-shim.dylib \
  SHOW_ONLY_BUILD_SETTINGS_FOR_FIRST_BUILDABLE=YES \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project SomeProject.xcodeproj \
  -scheme SomeScheme \
  -showBuildSettings 
```

