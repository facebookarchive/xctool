## clang-as-ios-dylib

__clang-as-ios-dylib__ is a workaround for building iOS dynamic libraries from Xcode.  Most importantly, it lets Xcode build iOS dylibs without requiring any modifications to the Xcode installation.

It works by tricking Xcode into building an OS X dynamic library as if it were an iOS dynamic library.  By overriding  __CC__ and __LD__, we make Xcode call a wrapper script instead of directly calling __clang__, and our wrapper swaps  the OS X compile flags for iOS flags.

_Only iphonesimulator dylibs are supported now, but it would be possible to add device support if needed._

## Usage

1. Copy the __clang-as-ios-dylib__ code into your repo:
 
  ```sh
cd Vendor
mkdir clang-as-ios-dylib
cd clang-as-ios-dylib
curl https://github.com/facebook/clang-as-ios-dylib/archive/master.tar.gz | tar zxvf - --strip-components=1
  ```


1. In Xcode, create a new __OS X Cocoa Library__ target.

1. In the project, create a new __Configuration Settings File (.xcconfig)__ file with the following contents:
  ```sh
  // The following can be one of 'latest', 'earliest', or a specific
  // SDK version like '7.0', or '6.1'.
  CAID_BASE_SDK_VERSION = latest
  CAID_IPHONEOS_DEPLOYMENT_TARGET = latest
  
  CAID_LINKS_PATH = $(PROJECT_DIR)/../Vendor/clang-as-ios-dylib/links
  
  LD = $(CAID_LINKS_PATH)/ld-iphonesimulator-$(CAID_BASE_SDK_VERSION)-targeting-$(CAID_IPHONEOS_DEPLOYMENT_TARGET)
  CC = $(CAID_LINKS_PATH)/cc-iphonesimulator-$(CAID_BASE_SDK_VERSION)-targeting-$(CAID_IPHONEOS_DEPLOYMENT_TARGET)
  ```

1. In your project’s __Info__ settings panel, for each build configuration, select the xcconfig file created in #2 for your target.

1. Change references to __Cocoa.framework__ to __Foundation.framework__:

  * In your __.pch__ file, change `#import <Cocoa/Cocoa.h>` to `#import <Foundation/Foundation.h>`.
  * In your target's __Build Phases__ panel, under __Link Binary With Libraries__, remove __Cocoa.framework__ and add __Foundation.framework__.

## Alternatives

The other possibility is modifying some of Xcode’s internal configuration files so that Xcode understands iOS dylibs again.  Internally, Xcode already knows how to build iOS dylibs - it’s just that Apple strips some configuration items to prevent it.

See:  <http://sumgroup.wikispaces.com/iPhone_Dynamic_Library>

The downside to this approach is that everyone on your team must also modify their Xcode installation.

## License

```
BSD License

clang-as-ios-dylib
Copyright (c) 2013, Facebook, Inc.  All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

```


