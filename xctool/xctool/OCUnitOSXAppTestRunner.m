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
#import "SimulatorLauncher.h"
#import "TaskUtil.h"
#import "XCToolUtil.h"

@implementation OCUnitOSXAppTestRunner

- (BOOL)runTestsAndFeedOutputTo:(void (^)(NSString *))outputLineBlock error:(NSString **)error
{
  NSString *sdkName = _buildSettings[@"SDK_NAME"];
  NSAssert([sdkName hasPrefix:@"macosx"], @"Unexpected SDK: %@", sdkName);

  NSString *testHostPath = _buildSettings[@"TEST_HOST"];

  NSArray *libraries = @[[PathToXCToolBinaries() stringByAppendingPathComponent:@"otest-shim-osx.dylib"],
                         [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Library/PrivateFrameworks/IDEBundleInjection.framework/IDEBundleInjection"],
                         ];

  NSTask *task = [[[NSTask alloc] init] autorelease];
  [task setLaunchPath:testHostPath];
  [task setArguments:[self otestArguments]];
  [task setEnvironment:@{
   @"DYLD_INSERT_LIBRARIES" : [libraries componentsJoinedByString:@":"],
   @"DYLD_FRAMEWORK_PATH" : _buildSettings[@"BUILT_PRODUCTS_DIR"],
   @"DYLD_LIBRARY_PATH" : _buildSettings[@"BUILT_PRODUCTS_DIR"],
   @"DYLD_FALLBACK_FRAMEWORK_PATH" : [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Library/Frameworks"],
   @"NSUnbufferedIO" : @"YES",
   @"OBJC_DISABLE_GC" : !_garbageCollection ? @"YES" : @"NO",
   @"XCInjectBundle" : [_buildSettings[@"BUILT_PRODUCTS_DIR"] stringByAppendingPathComponent:_buildSettings[@"FULL_PRODUCT_NAME"]],
   @"XCInjectBundleInto" : testHostPath,
   }];

  LaunchTaskAndFeedOuputLinesToBlock(task, outputLineBlock);

  return [task terminationStatus] == 0;
}

@end
