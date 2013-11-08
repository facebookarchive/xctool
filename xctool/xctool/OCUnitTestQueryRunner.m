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

#import "OCUnitTestQueryRunner.h"

#import "TaskUtil.h"
#import "XCToolUtil.h"

@implementation OCUnitTestQueryRunner

// Designated initializer.
- (instancetype)initWithBuildSettings:(NSDictionary *)buildSettings
                          withCpuType:(cpu_type_t)cpuType
{
  if (self = [super init]) {
    _buildSettings = [buildSettings retain];
    _cpuType = cpuType;
  }
  return self;
}

- (void)dealloc
{
  [_buildSettings release];
  [super dealloc];
}

- (NSString *)bundlePath
{
  NSString *builtProductsDir = _buildSettings[@"BUILT_PRODUCTS_DIR"];
  NSString *fullProductName = _buildSettings[@"FULL_PRODUCT_NAME"];
  NSString *bundlePath = [builtProductsDir stringByAppendingPathComponent:fullProductName];
  return bundlePath;
}

- (NSString *)testHostPath
{
  // TEST_HOST will sometimes be wrapped in "quotes".
  NSString *testHost = [_buildSettings[@"TEST_HOST"]
                        stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
  return testHost;
}

- (NSTask *)createTaskForQuery NS_RETURNS_RETAINED
{
  return nil;
}

- (NSArray *)runQueryWithError:(NSString **)error
{
  BOOL bundleIsDir = NO;
  BOOL bundleExists = [[NSFileManager defaultManager] fileExistsAtPath:[self bundlePath] isDirectory:&bundleIsDir];
  if (!IsRunningUnderTest() && !(bundleExists && bundleIsDir)) {
    *error = [NSString stringWithFormat:@"Test bundle not found at: %@", [self bundlePath]];
    return nil;
  }

  if ([self testHostPath]) {
    if (![[NSFileManager defaultManager] isExecutableFileAtPath:[self testHostPath]]) {
      *error = [NSString stringWithFormat:@"The test host executable is missing: '%@'", [self testHostPath]];
      return nil;
    }
  }

  NSTask *task = [self createTaskForQuery];

  // Override CFFIXED_USER_HOME so that it's impossible for otest-query to
  // write or read any .plist preference files in the standard (permanent)
  // locations.
  //
  // This fixes a bug where otest-query will output empty test results like the
  // following instead of returning the list of tests --
  //
  //   Test Suite 'All tests' started at 2013-11-07 23:47:46 +0000
  //   Test Suite 'All tests' finished at 2013-11-07 23:47:46 +0000.
  //   Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
  //
  // The problem was caused by a `otest-query-ios.plist` preferences file at --
  //   ~/Library/Application Support/iPhone Simulator/7.0/Library/Preferences/otest-query-ios.plist
  //
  // That contained one dictionary that looked like --
  //   Dict {
  //     SenTest = All
  //   }
  //
  // That presence of that one "SenTest" key causes all the trouble.  When dyld
  // loads SenTestingKit.framework, '+[SenTestProbe initialize]' is triggered.
  // If the initializer sees that the 'SenTest' preference is set, it goes ahead
  // and runs tests.  But, since it hasn't even loaded the test bundle, there
  // are no tests and we only see the empty 'All tests' suite.
  //
  // NOTE: The reason `SenTest` gets set at all is because otest-query sets it
  // as part of its necessary trickery.
  //
  // Overriding CFFIXED_USER_HOME should have no consequences, since otest-query
  // doesn't really run any app code or test code.
  NSString *tempHome = MakeTemporaryDirectory(@"otest-query-CFFIXED_USER_HOME-XXXXXX");
  NSMutableDictionary *newEnv = [NSMutableDictionary dictionaryWithDictionary:task.environment];
  newEnv[@"CFFIXED_USER_HOME"] = tempHome;
  [task setEnvironment:newEnv];

  NSDictionary *output = LaunchTaskAndCaptureOutput(task, @"running otest-query");

  NSError *removeError = nil;
  BOOL removeSucceeded = [[NSFileManager defaultManager] removeItemAtPath:tempHome
                                                                    error:&removeError];
  NSAssert(removeSucceeded, @"Failed to remove temp dir: %@", [removeError localizedFailureReason]);

  int terminationStatus = [task terminationStatus];
  [task release];
  task = nil;

  if (terminationStatus != 0) {
    *error = output[@"stderr"];
    return nil;
  } else {
    NSString *jsonOutput = output[@"stdout"];

    NSError *parseError = nil;
    NSArray *list = [NSJSONSerialization JSONObjectWithData:[jsonOutput dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:0
                                                      error:&parseError];
    if (list) {
      return list;
    } else {
      *error = [NSString stringWithFormat:@"Error while parsing JSON: %@: %@",
                [parseError localizedFailureReason],
                jsonOutput];
      return nil;
    }
  }
}

@end
