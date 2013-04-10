
#import "LogicTestRunner.h"

#import "PJSONKit.h"
#import "TaskUtil.h"
#import "XcodeToolUtil.h"

@implementation LogicTestRunner

- (NSArray *)otestArgumentsForTestBundle:(NSString *)testBundlePath
{
  // These are the same arguments Xcode would use when invoking otest.  To capture these, we
  // just ran a test case from Xcode that dumped 'argv'.  It's a little tricky to do that outside
  // of the 'main' function, but you can use _NSGetArgc and _NSGetArgv.  See --
  // http://unixjunkie.blogspot.com/2006/07/access-argc-and-argv-from-anywhere.html
  return @[
           // Not sure exactly what this does...
           @"-NSTreatUnknownArgumentsAsOpen", @"NO",
           // Not sure exactly what this does...
           @"-ApplePersistenceIgnoreState", @"YES",
           // SenTest is one of Self, All, None,
           // or TestClassName[/testCaseName][,TestClassName2]
           @"-SenTest", _senTestList,
           // SenTestInvertScope optionally inverts whatever SenTest would normally select.
           @"-SenTestInvertScope", _senTestInvertScope ? @"YES" : @"NO",
           testBundlePath];
}

- (NSTask *)otestTaskForMacOSXWithTestBundle:(NSString *)testBundlePath
{
  NSAssert([_buildSettings[@"SDK_NAME"] hasPrefix:@"macosx"], @"Should be a macosx SDK.");

  // TODO: In Xcode, if you use GCC_ENABLE_OBJC_GC = supported, Xcode will run your test twice
  // with GC on and GC off.  We should eventually do the same.
  BOOL enableGC = ([_buildSettings[@"GCC_ENABLE_OBJC_GC"] isEqualToString:@"supported"] ||
                   [_buildSettings[@"GCC_ENABLE_OBJC_GC"] isEqualToString:@"required"]);

  NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:
                              [[NSProcessInfo processInfo] environment]];
  [env addEntriesFromDictionary:@{
   @"DYLD_INSERT_LIBRARIES" : [PathToFBXcodetoolBinaries() stringByAppendingPathComponent:@"otest-lib-osx.dylib"],
   @"DYLD_FRAMEWORK_PATH" : _buildSettings[@"BUILT_PRODUCTS_DIR"],
   @"DYLD_LIBRARY_PATH" : _buildSettings[@"BUILT_PRODUCTS_DIR"],
   @"DYLD_FALLBACK_FRAMEWORK_PATH" : [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Library/Frameworks"],
   @"NSUnbufferedIO" : @"YES",
   @"OBJC_DISABLE_GC" : !enableGC ? @"YES" : @"NO",
   }];


  NSTask *task = TaskInstance();
  [task setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Tools/otest"]];
  [task setArguments:[@[] arrayByAddingObjectsFromArray:
                      [self otestArgumentsForTestBundle:testBundlePath]]];
  [task setEnvironment:env];

  return task;
}

- (NSTask *)otestTaskForIPhoneSimulatorWithTestBundle:(NSString *)testBundlePath
{
  NSAssert([_buildSettings[@"SDK_NAME"] hasPrefix:@"iphonesimulator"], @"Should be an iphonesimulator SDK.");
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
                                    @"DYLD_INSERT_LIBRARIES" : [PathToFBXcodetoolBinaries() stringByAppendingPathComponent:@"otest-lib-ios.dylib"],
                                    };

  NSArray *taskArguments = @[
                             @"-NSTreatUnknownArgumentsAsOpen", @"NO",
                             @"-ApplePersistenceIgnoreState", @"YES",
                             @"-SenTestInvertScope", _senTestInvertScope ? @"YES" : @"NO",
                             @"-SenTest", _senTestList,
                             testBundlePath,
                             ];

  NSTask *task = TaskInstance();
  [task setLaunchPath:[NSString stringWithFormat:@"%@/Developer/usr/bin/otest", _buildSettings[@"SDKROOT"]]];
  [task setArguments:taskArguments];
  [task setEnvironment:taskEnvironment];
  return task;
}

- (BOOL)runTestsAndFeedOutputTo:(void (^)(NSString *))outputLineBlock error:(NSString **)error
{
  NSString *testBundlePath = [NSString stringWithFormat:@"%@/%@",
                              _buildSettings[@"BUILT_PRODUCTS_DIR"],
                              _buildSettings[@"FULL_PRODUCT_NAME"]
                              ];

  BOOL bundleExists = [[NSFileManager defaultManager] fileExistsAtPath:testBundlePath];

  if ([[[NSProcessInfo processInfo] processName] isEqualToString:@"otest"]) {
    // If we're running under test, pretend the bundle exists even if it doesn't.
    bundleExists = YES;
  }

  if (bundleExists) {
    NSTask *task = nil;
    
    NSString *sdkName = _buildSettings[@"SDK_NAME"];
    if ([sdkName hasPrefix:@"iphonesimulator"]) {
      task = [self otestTaskForIPhoneSimulatorWithTestBundle:testBundlePath];
    } else if ([sdkName hasPrefix:@"macosx"]) {
      task = [self otestTaskForMacOSXWithTestBundle:testBundlePath];
    } else {
      NSAssert(FALSE, @"Unexpected SDK name: %@", sdkName);
    }
    
    LaunchTaskAndFeedOuputLinesToBlock(task, outputLineBlock);
    
    return [task terminationStatus] == 0 ? YES : NO;
  } else {
    *error = [NSString stringWithFormat:@"Test bundle not found at: %@", testBundlePath];
    return NO;
  }
}

@end
