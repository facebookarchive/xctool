// Copyright 2004-present Facebook. All Rights Reserved.


#import "OCUnitOSXAppTestRunner.h"

#import "LineReader.h"
#import "PJSONKit.h"
#import "SimulatorLauncher.h"
#import "TaskUtil.h"
#import "XcodeToolUtil.h"

@implementation OCUnitOSXAppTestRunner

- (BOOL)runTestsAndFeedOutputTo:(void (^)(NSString *))outputLineBlock error:(NSString **)error
{
  NSString *sdkName = _buildSettings[@"SDK_NAME"];
  NSAssert([sdkName hasPrefix:@"macosx"], @"Unexpected SDK: %@", sdkName);

  NSString *testHostPath = _buildSettings[@"TEST_HOST"];

  NSArray *libraries = @[[PathToFBXcodetoolBinaries() stringByAppendingPathComponent:@"otest-lib-osx.dylib"],
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
