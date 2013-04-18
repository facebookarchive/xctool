// Copyright 2004-present Facebook. All Rights Reserved.


#import "OCUnitIOSLogicTestRunner.h"

#import "TaskUtil.h"
#import "XCToolUtil.h"

@implementation OCUnitIOSLogicTestRunner

- (NSTask *)otestTaskWithTestBundle:(NSString *)testBundlePath
{
  NSString *version = [_buildSettings[@"SDK_NAME"] stringByReplacingOccurrencesOfString:@"iphonesimulator" withString:@""];
  NSString *simulatorHome = [NSString stringWithFormat:@"%@/Library/Application Support/iPhone Simulator/%@", NSHomeDirectory(), version];

  NSDictionary *taskEnvironment = @{
                                    @"CFFIXED_USER_HOME" : simulatorHome,
                                    @"HOME" : simulatorHome,
                                    @"IPHONE_SHARED_RESOURCES_DIRECTORY" : simulatorHome,
                                    @"DYLD_FALLBACK_FRAMEWORK_PATH" : @"/Developer/Library/Frameworks",
                                    @"DYLD_FRAMEWORK_PATH" : _buildSettings[@"BUILT_PRODUCTS_DIR"],
                                    @"DYLD_LIBRARY_PATH" : _buildSettings[@"BUILT_PRODUCTS_DIR"],
                                    @"DYLD_ROOT_PATH" : _buildSettings[@"SDKROOT"],
                                    @"IPHONE_SIMULATOR_ROOT" : _buildSettings[@"SDKROOT"],
                                    @"IPHONE_SIMULATOR_VERSIONS" : @"iPhone Simulator (external launch) , iPhone OS 6.0 (unknown/10A403)",
                                    @"NSUnbufferedIO" : @"YES",
                                    @"DYLD_INSERT_LIBRARIES" : [PathToXCToolBinaries() stringByAppendingPathComponent:@"otest-shim-ios.dylib"],
                                    };

  NSTask *task = TaskInstance();
  [task setLaunchPath:[NSString stringWithFormat:@"%@/Developer/usr/bin/otest", _buildSettings[@"SDKROOT"]]];
  [task setArguments:[[self otestArguments] arrayByAddingObject:testBundlePath]];
  [task setEnvironment:taskEnvironment];
  return task;
}

- (BOOL)runTestsAndFeedOutputTo:(void (^)(NSString *))outputLineBlock error:(NSString **)error
{
  NSString *sdkName = _buildSettings[@"SDK_NAME"];
  NSAssert([sdkName hasPrefix:@"iphonesimulator"], @"Unexpected SDK name: %@", sdkName);

  NSString *testBundlePath = [self testBundlePath];
  BOOL bundleExists = [[NSFileManager defaultManager] fileExistsAtPath:testBundlePath];

  if ([[[NSProcessInfo processInfo] processName] isEqualToString:@"otest"]) {
    // If we're running under test, pretend the bundle exists even if it doesn't.
    bundleExists = YES;
  }

  if (bundleExists) {
    NSTask *task = [self otestTaskWithTestBundle:testBundlePath];

    LaunchTaskAndFeedOuputLinesToBlock(task, outputLineBlock);

    return [task terminationStatus] == 0 ? YES : NO;
  } else {
    *error = [NSString stringWithFormat:@"Test bundle not found at: %@", testBundlePath];
    return NO;
  }
}

@end
