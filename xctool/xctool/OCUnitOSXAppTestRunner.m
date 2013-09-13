//
// Copyright 2013 Facebook
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

#import "OCUnitOSXAppTestRunner.h"

#import "LineReader.h"
#import "ReportStatus.h"
#import "SimulatorLauncher.h"
#import "TaskUtil.h"
#import "XCToolUtil.h"

@implementation OCUnitOSXAppTestRunner

- (BOOL)runTestsAndFeedOutputTo:(void (^)(NSString *))outputLineBlock
              gotUncaughtSignal:(BOOL *)gotUncaughtSignal
                          error:(NSString **)error
{
  NSString *sdkName = _buildSettings[@"SDK_NAME"];
  NSAssert([sdkName hasPrefix:@"macosx"], @"Unexpected SDK: %@", sdkName);

  NSString *testHostPath = _buildSettings[@"TEST_HOST"];
  if (![[NSFileManager defaultManager] isExecutableFileAtPath:testHostPath]) {
    // It's conceivable that isExecutableFileAtPath is wrong; for example, maybe we're on
    // a wonky FS, or running as root, or running with differing real/effective UIDs.
    // Unfortunately, there's no way to be sure without actually running TEST_HOST, and
    // NSTask throws an exception if the execve fails, and that's a nasty failure mode for
    // us. It's better to fail usefully for obviously wrong TEST_HOSTs than support
    // incredibly odd configs.
    ReportStatusMessage(_reporters, REPORTER_MESSAGE_ERROR,
                        @"Your TEST_HOST '%@' does not appear to be an executable.", testHostPath);
    *error = @"TEST_HOST not executable.";
    return NO;
  }

  NSArray *libraries = @[[XCToolLibPath() stringByAppendingPathComponent:@"otest-shim-osx.dylib"],
                         [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Library/PrivateFrameworks/IDEBundleInjection.framework/IDEBundleInjection"],
                         ];

  NSTask *task = CreateTaskInSameProcessGroup();
  [task setLaunchPath:testHostPath];
  [task setArguments:[self otestArguments]];
  [task setEnvironment:[self otestEnvironmentWithOverrides:@{
                        @"DYLD_INSERT_LIBRARIES" : [libraries componentsJoinedByString:@":"],
                        @"DYLD_FRAMEWORK_PATH" : _buildSettings[@"BUILT_PRODUCTS_DIR"],
                        @"DYLD_LIBRARY_PATH" : _buildSettings[@"BUILT_PRODUCTS_DIR"],
                        @"DYLD_FALLBACK_FRAMEWORK_PATH" : [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Library/Frameworks"],
                        @"NSUnbufferedIO" : @"YES",
                        @"OBJC_DISABLE_GC" : !_garbageCollection ? @"YES" : @"NO",
                        @"XCInjectBundle" : [_buildSettings[@"BUILT_PRODUCTS_DIR"] stringByAppendingPathComponent:_buildSettings[@"FULL_PRODUCT_NAME"]],
                        @"XCInjectBundleInto" : testHostPath,
                        }]];
  // For OSX test bundles only, Xcode will chdir to the project's directory.
  [task setCurrentDirectoryPath:_buildSettings[@"PROJECT_DIR"]];

  LaunchTaskAndFeedOuputLinesToBlock(task, outputLineBlock);

  *gotUncaughtSignal = task.terminationReason == NSTaskTerminationReasonUncaughtSignal;
  int terminationStatus = task.terminationStatus;
  [task release];
  return terminationStatus == 0;
}

@end
