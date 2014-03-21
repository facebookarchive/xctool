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

#import "OCUnitTestRunner.h"
#import "OCUnitTestRunnerInternal.h"

#import <QuartzCore/QuartzCore.h>

#import "ReportStatus.h"
#import "TestRunState.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"

@implementation OCUnitTestRunner

+ (NSArray *)filterTestCases:(NSArray *)testCases
             withSenTestList:(NSString *)senTestList
          senTestInvertScope:(BOOL)senTestInvertScope
{
  NSSet *originalSet = [NSSet setWithArray:testCases];

  // Come up with a set of test cases that match the senTestList pattern.
  NSMutableSet *matchingSet = [NSMutableSet set];

  if ([senTestList isEqualToString:@"All"]) {
    [matchingSet addObjectsFromArray:testCases];
  } else if ([senTestList isEqualToString:@"None"]) {
    // None, we don't add anything to the set.
  } else {
    for (NSString *specifier in [senTestList componentsSeparatedByString:@","]) {
      // If we have a slash, assume it's int he form of "SomeClass/testMethod"
      BOOL hasClassAndMethod = [specifier rangeOfString:@"/"].length > 0;

      if (hasClassAndMethod) {
        if ([originalSet containsObject:specifier]) {
          [matchingSet addObject:specifier];
        }
      } else {
        NSString *matchingPrefix = [specifier stringByAppendingString:@"/"];
        for (NSString *testCase in testCases) {
          if ([testCase hasPrefix:matchingPrefix]) {
            [matchingSet addObject:testCase];
          }
        }
      }
    }
  }

  NSMutableArray *result = [NSMutableArray array];

  if (!senTestInvertScope) {
    [result addObjectsFromArray:[matchingSet allObjects]];
  } else {
    NSMutableSet *invertedSet = [[originalSet mutableCopy] autorelease];
    [invertedSet minusSet:matchingSet];
    [result addObjectsFromArray:[invertedSet allObjects]];
  }

  [result sortUsingSelector:@selector(compare:)];
  return result;
}

- (id)initWithBuildSettings:(NSDictionary *)buildSettings
           focusedTestCases:(NSArray *)focusedTestCases
               allTestCases:(NSArray *)allTestCases
                  arguments:(NSArray *)arguments
                environment:(NSDictionary *)environment
             freshSimulator:(BOOL)freshSimulator
               freshInstall:(BOOL)freshInstall
              simulatorType:(NSString *)simulatorType
                  reporters:(NSArray *)reporters
{
  if (self = [super init]) {
    _buildSettings = [buildSettings retain];
    _focusedTestCases = [focusedTestCases retain];
    _allTestCases = [allTestCases retain];
    _arguments = [arguments retain];
    _environment = [environment retain];
    _freshSimulator = freshSimulator;
    _freshInstall = freshInstall;
    _simulatorType = [simulatorType retain];
    _reporters = [reporters retain];
    _framework = [FrameworkInfoForTestBundleAtPath([self testBundlePath]) retain];
    _cpuType = CPU_TYPE_ANY;
  }
  return self;
}

- (void)dealloc
{
  [_buildSettings release];
  [_focusedTestCases release];
  [_allTestCases release];
  [_arguments release];
  [_environment release];
  [_simulatorType release];
  [_reporters release];
  [_framework release];
  [super dealloc];
}

- (void)runTestsAndFeedOutputTo:(void (^)(NSString *))outputLineBlock
                   startupError:(NSString **)startupError
{
  // Subclasses will override this method.
}

- (BOOL)runTests
{
  TestRunState *testRunState = [[[TestRunState alloc] initWithTests:_focusedTestCases reporters:_reporters] autorelease];

  void (^feedOutputToBlock)(NSString *) = ^(NSString *line) {
    NSData *lineData = [line dataUsingEncoding:NSUTF8StringEncoding];

    [testRunState parseAndHandleEvent:line];
    [_reporters makeObjectsPerformSelector:@selector(publishDataForEvent:) withObject:lineData];
  };

  NSString *runTestsError = nil;

  [testRunState prepareToRun];

  [self runTestsAndFeedOutputTo:feedOutputToBlock
                   startupError:&runTestsError];

  [testRunState didFinishRunWithStartupError:runTestsError];

  return [testRunState allTestsPassed];
}

- (NSArray *)testArguments
{
  NSSet *focusedSet = [NSSet setWithArray:_focusedTestCases];
  NSSet *allSet = [NSSet setWithArray:_allTestCases];

  NSString *testSpecifier = nil;
  BOOL invertScope = NO;

  if ([focusedSet isEqualToSet:allSet]) {

    if (TestableSettingsIndicatesApplicationTest(_buildSettings)) {
      // Xcode.app will always pass 'All' when running all tests in an
      // application test bundle.
      testSpecifier = @"All";
    } else {
      // Xcode.app will always pass 'Self' when running all tests in an
      // logic test bundle.
      testSpecifier = @"Self";
    }

    invertScope = NO;
  } else {
    // When running a specific subset of tests, Xcode.app will always pass the
    // the list of excluded tests and enable the InvertScope option.
    //
    // There are two ways to make SenTestingKit or XCTest run a specific test.
    // Suppose you have a test bundle with 2 tests: 'Cls1/testA', 'Cls2/testB'.
    //
    // If you only wanted to run 'Cls1/testA', you could express that in 2 ways:
    //
    //   1) otest ... -SenTest Cls1/testA -SenTestInvertScope NO
    //   2) otest ... -SenTest Cls1/testB -SenTestInvertScope YES
    //
    // Xcode itself always uses #2.  And, for some reason, when using the Kiwi
    // testing framework, option #2 is the _ONLY_ way to run specific tests.
    //
    NSMutableSet *invertedSet = [NSMutableSet setWithSet:allSet];
    [invertedSet minusSet:focusedSet];

    NSArray *invertedTestCases = [[invertedSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    testSpecifier = [invertedTestCases componentsJoinedByString:@","];

    invertScope = YES;
  }

  // These are the same arguments Xcode would use when invoking otest.  To capture these, we
  // just ran a test case from Xcode that dumped 'argv'.  It's a little tricky to do that outside
  // of the 'main' function, but you can use _NSGetArgc and _NSGetArgv.  See --
  // http://unixjunkie.blogspot.com/2006/07/access-argc-and-argv-from-anywhere.html
  NSMutableArray *args = [NSMutableArray arrayWithArray:@[
           // Not sure exactly what this does...
           @"-NSTreatUnknownArgumentsAsOpen", @"NO",
           // Not sure exactly what this does...
           @"-ApplePersistenceIgnoreState", @"YES",
           // SenTest / XCTest is one of Self, All, None,
           // or TestClassName[/testCaseName][,TestClassName2]
           [@"-" stringByAppendingString:_framework[kTestingFrameworkFilterTestArgsKey]], testSpecifier,
           // SenTestInvertScope / XCTestInvertScope optionally inverts whatever
           // SenTest would normally select. We never invert, since we always
           // pass the exact list of test cases to be run.
           [@"-" stringByAppendingString:_framework[kTestingFrameworkInvertScopeKey]], invertScope ? @"YES" : @"NO",
           ]];

  // Add any argments that might have been specifed in the scheme.
  [args addObjectsFromArray:_arguments];

  return args;
}

- (NSDictionary *)otestEnvironmentWithOverrides:(NSDictionary *)overrides
{
  NSMutableDictionary *env = [NSMutableDictionary dictionary];

  NSArray *layers = @[
                      // Xcode will let your regular environment pass-thru to
                      // the test.
                      [[NSProcessInfo processInfo] environment],
                      // Any special environment vars set in the scheme.
                      _environment,
                      // Whatever values we need to make the test run at all for
                      // ios/mac or logic/application tests.
                      overrides,
                      ];
  for (NSDictionary *layer in layers) {
    [layer enumerateKeysAndObjectsUsingBlock:^(id key, id val, BOOL *stop){
      if ([key isEqualToString:@"DYLD_INSERT_LIBRARIES"] ||
          [key isEqualToString:@"DYLD_FALLBACK_FRAMEWORK_PATH"]) {
        // It's possible that the scheme (or regular host environment) has its
        // own value for DYLD_INSERT_LIBRARIES.  In that case, we don't want to
        // stomp on it when insert otest-shim.
        NSString *existingVal = env[key];
        if (existingVal) {
          env[key] = [existingVal stringByAppendingFormat:@":%@", val];
        } else {
          env[key] = val;
        }
      } else {
        env[key] = val;
      }
    }];
  }

  return env;
}

- (NSString *)testBundlePath
{
  return [NSString stringWithFormat:@"%@/%@",
          _buildSettings[Xcode_BUILT_PRODUCTS_DIR],
          _buildSettings[Xcode_FULL_PRODUCT_NAME]
          ];
}

@end
