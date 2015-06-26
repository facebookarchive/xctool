//
// Copyright 2004-present Facebook. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import <Foundation/Foundation.h>

#import "XCTool.h"
#import "XCToolUtil.h"

int main(int argc, const char * argv[])
{
  @autoreleasepool {
    // xctool depends on CoreSimulator.framework which is private framework for
    // interacting with the simulator that come bundled with Xcode 6 and better.
    //
    // Since xctool can work with multiple verstions of Xcode and since each of
    // Xcode versions might live at different paths, we don't want to strongly
    // link this and other frameworks.  e.g., if we linked to
    // `/Applications/Xcode.app/.../.../CoreSimulator.framework`
    // but Xcode was installed elsewhere, xctool would fail to run.
    //
    // To workaround this, we weak link the framework and at startup, we tweak
    // the DYLD_FALLBACK_FRAMEWORK_PATH so that it points to the correct paths
    // for whatever the current version of Xcode is.
    if (getenv("XT_DID_SET_DYLD_FALLBACK_FRAMEWORK_PATH") == NULL) {

      NSString *developerDirPath = XcodeDeveloperDirPath();

      if (developerDirPath == nil) {
        fprintf(stderr, "ERROR: Unable to get the path to the active Xcode installation.\n"
                        "       Run `xcode-select --switch` to set the path to Xcode.app,\n"
                        "       or set the DEVELOPER_DIR environment variable.");
        exit(1);
      }

      const char *dyldFallbackFrameworkPathKey = "DYLD_FALLBACK_FRAMEWORK_PATH";

      NSMutableArray *fallbackFrameworkPaths = [@[] mutableCopy];
      if (getenv(dyldFallbackFrameworkPathKey)) {
        [fallbackFrameworkPaths addObject:@(getenv(dyldFallbackFrameworkPathKey))];
      } else {
        // If unset, this variable takes on an implicit default (see `man dyld`).
        [fallbackFrameworkPaths addObjectsFromArray:@[
          @"/Library/Frameworks",
          @"/Network/Library/Frameworks",
          @"/System/Library/Frameworks",
        ]];
      }

      [fallbackFrameworkPaths addObjectsFromArray:@[
        // Path to CoreSimulator.framework for Xcode 6 and better.
        [developerDirPath stringByAppendingPathComponent:@"Library/PrivateFrameworks"],
        // Path to XCTest.framework for Xcode 7 and better.
        [developerDirPath stringByAppendingPathComponent:@"Platforms/MacOSX.platform/Developer/Library/Frameworks"],
        // Paths to other dependencies
        [developerDirPath stringByAppendingPathComponent:@"Platforms/iPhoneSimulator.platform/Developer/Library/PrivateFrameworks"],
        [developerDirPath stringByAppendingPathComponent:@"../OtherFrameworks"],
        [developerDirPath stringByAppendingPathComponent:@"../SharedFrameworks"],
      ]];

      NSString *fallbackFrameworkPath = [fallbackFrameworkPaths componentsJoinedByString:@":"];
      setenv(dyldFallbackFrameworkPathKey, [fallbackFrameworkPath UTF8String], 1);

      // Don't do this setup again...
      setenv("XT_DID_SET_DYLD_FALLBACK_FRAMEWORK_PATH", "YES", 1);

      execv([AbsoluteExecutablePath() UTF8String], (char *const *)argv);
    }

    NSArray *arguments = [[NSProcessInfo processInfo] arguments];

    XCTool *tool = [[XCTool alloc] init];
    tool.arguments = [arguments subarrayWithRange:NSMakeRange(1, arguments.count - 1)];
    tool.standardOutput = [NSFileHandle fileHandleWithStandardOutput];
    tool.standardError = [NSFileHandle fileHandleWithStandardError];

    [tool run];

    return tool.exitStatus;
  }
  return 0;
}
