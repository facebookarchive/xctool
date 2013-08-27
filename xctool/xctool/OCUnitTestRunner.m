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

#import <QuartzCore/QuartzCore.h>

#import "OCUnitCrashFilter.h"
#import "ReportStatus.h"
#import "XCToolUtil.h"

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

+ (NSString *)reduceSenTestListToBroadestForm:(NSArray *)senTestList
                                 allTestCases:(NSArray *)allTestCases
{
  senTestList = [senTestList sortedArrayUsingSelector:@selector(compare:)];
  allTestCases = [allTestCases sortedArrayUsingSelector:@selector(compare:)];

  NSDictionary *(^testCasesGroupedByClass)(NSSet *) = ^(NSSet *testCaseSet) {
    NSMutableDictionary *testCasesByClass = [NSMutableDictionary dictionary];

    for (NSString *classAndMethod in testCaseSet) {
      NSString *className = [classAndMethod componentsSeparatedByString:@"/"][0];

      if (testCasesByClass[className] == nil) {
        testCasesByClass[className] = [NSMutableSet set];
      }

      [testCasesByClass[className] addObject:classAndMethod];
    }

    return testCasesByClass;
  };

  NSMutableSet *senTestListSet = [NSMutableSet setWithArray:senTestList];
  NSSet *allTestCasesSet = [NSSet setWithArray:allTestCases];
  NSAssert([senTestListSet isSubsetOfSet:allTestCasesSet],
           @"senTestList should be a subset of allTestCases");


  if ([senTestListSet isEqualToSet:allTestCasesSet]) {
    return @"All";
  } else if ([senTestListSet count] == 0) {
    return @"None";
  } else {
    NSDictionary *senTestListCasesGroupedByClass = testCasesGroupedByClass(senTestListSet);
    NSDictionary *allTestCasesGroupedByClass = testCasesGroupedByClass(allTestCasesSet);

    NSMutableArray *result = [NSMutableArray array];

    for (NSString *className in [senTestListCasesGroupedByClass allKeys]) {
      NSSet *testCasesForThisClass = senTestListCasesGroupedByClass[className];
      NSSet *allTestCasesForThisClass = allTestCasesGroupedByClass[className];

      BOOL hasAllTestsInClass = [testCasesForThisClass isEqualToSet:allTestCasesForThisClass];

      if (hasAllTestsInClass) {
        // Just emit the class name, and otest will run all tests in that class.
        [result addObject:className];
      } else {
        [result addObjectsFromArray:[testCasesForThisClass allObjects]];
      }
    }

    [result sortUsingSelector:@selector(compare:)];

    return [result componentsJoinedByString:@","];
  }
}

- (id)initWithBuildSettings:(NSDictionary *)buildSettings
                senTestList:(NSString *)senTestList
                  arguments:(NSArray *)arguments
                environment:(NSDictionary *)environment
          garbageCollection:(BOOL)garbageCollection
             freshSimulator:(BOOL)freshSimulator
               freshInstall:(BOOL)freshInstall
              simulatorType:(NSString *)simulatorType
                  reporters:(NSArray *)reporters
{
  if (self = [super init]) {
    _buildSettings = [buildSettings retain];
    _senTestList = [senTestList retain];
    _arguments = [arguments retain];
    _environment = [environment retain];
    _garbageCollection = garbageCollection;
    _freshSimulator = freshSimulator;
    _freshInstall = freshInstall;
    _simulatorType = [simulatorType retain];
    _reporters = [reporters retain];
  }
  return self;
}

- (void)dealloc
{
  [_buildSettings release];
  [_senTestList release];
  [_arguments release];
  [_environment release];
  [_simulatorType release];
  [_reporters release];
  [super dealloc];
}

- (BOOL)runTestsAndFeedOutputTo:(void (^)(NSString *))outputLineBlock
              gotUncaughtSignal:(BOOL *)gotUncaughtSignal
                          error:(NSString **)error
{
  // Subclasses will override this method.
  return NO;
}

- (NSArray *)collectCrashReportPaths
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *diagnosticReportsPath = [@"~/Library/Logs/DiagnosticReports" stringByStandardizingPath];

  BOOL isDirectory = NO;
  BOOL fileExists = [fm fileExistsAtPath:diagnosticReportsPath
                             isDirectory:&isDirectory];
  if (!fileExists || !isDirectory) {
    return @[];
  }

  NSError *error = nil;
  NSArray *allContents = [fm contentsOfDirectoryAtPath:diagnosticReportsPath
                                                 error:&error];
  NSAssert(error == nil, @"Failed getting contents of directory: %@", error);

  NSMutableArray *matchingContents = [NSMutableArray array];

  for (NSString *path in allContents) {
    if ([[path pathExtension] isEqualToString:@"crash"]) {
      NSString *fullPath = [[@"~/Library/Logs/DiagnosticReports" stringByAppendingPathComponent:path] stringByStandardizingPath];
      [matchingContents addObject:fullPath];
    }
  }

  return matchingContents;
}

- (NSString *)concatenatedCrashReports:(NSArray *)reports
{
  NSMutableString *buffer = [NSMutableString string];

  for (NSString *path in reports) {
    NSString *crashReportText = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    // Throw out everything below "Binary Images" - we mostly just care about the thread backtraces.
    NSString *minimalCrashReportText = [crashReportText substringToIndex:[crashReportText rangeOfString:@"\nBinary Images:"].location];

    [buffer appendFormat:@"CRASH REPORT: %@\n\n", [path lastPathComponent]];
    [buffer appendString:minimalCrashReportText];
    [buffer appendString:@"\n"];
  }

  return buffer;
}

- (BOOL)runTestsWithError:(NSString **)error {
  OCUnitCrashFilter *crashFilter = [[[OCUnitCrashFilter alloc] init] autorelease];
  __block BOOL didReceiveTestEvents = NO;

  void (^feedOutputToBlock)(NSString *) = ^(NSString *line) {
    NSData *lineData = [line dataUsingEncoding:NSUTF8StringEncoding];

    [crashFilter publishDataForEvent:lineData];
    [_reporters makeObjectsPerformSelector:@selector(publishDataForEvent:) withObject:lineData];

    didReceiveTestEvents = YES;
  };

  NSSet *crashReportsAtStart = [NSSet setWithArray:[self collectCrashReportPaths]];

  NSString *runTestsError = nil;
  BOOL didTerminateWithUncaughtSignal = NO;

  BOOL succeeded = [self runTestsAndFeedOutputTo:feedOutputToBlock
                                 gotUncaughtSignal:&didTerminateWithUncaughtSignal
                                             error:&runTestsError];
  if (runTestsError) {
    *error = runTestsError;
  }

  if (!succeeded && runTestsError == nil && !didReceiveTestEvents) {
    // otest failed but clearly no tests ran.  We've seen this when a test target had no
    // source files.  In that case, xcodebuild generated the test bundle, but didn't build the
    // actual mach-o bundle/binary (because of no source files!)
    //
    // e.g., Xcode would generate...
    //   DerivedData/Something-ejutnghaswljrqdalvadkusmnhdc/Build/Products/Debug-iphonesimulator/SomeTests.octest
    //
    // but, you would not have...
    //   DerivedData/Something-ejutnghaswljrqdalvadkusmnhdc/Build/Products/Debug-iphonesimulator/SomeTests.octest/SomeTests
    //
    // otest would then exit immediately with...
    //   The executable for the test bundle at /path/to/Something/Facebook-ejutnghaswljrqdalvadkusmnhdc/Build/Products/
    //     Debug-iphonesimulator/SomeTests.octest could not be found.
    //
    // Xcode (via Cmd-U) just counts this as a pass even though the exit code from otest was non-zero.
    // That seems a little wrong, but we'll do the same.
    succeeded = YES;
  }

  if ([crashFilter testRunWasUnfinished] || didTerminateWithUncaughtSignal) {
    // The test runner must have crashed.

    // Wait for a moment to see if a crash report shows up.
    NSSet *crashReportsAtEnd = [NSSet setWithArray:[self collectCrashReportPaths]];
    CFTimeInterval start = CACurrentMediaTime();
    while ([crashReportsAtEnd isEqualToSet:crashReportsAtStart] && (CACurrentMediaTime() - start < 10.0)) {
      [NSThread sleepForTimeInterval:0.25];
      crashReportsAtEnd = [NSSet setWithArray:[self collectCrashReportPaths]];
    }

    NSMutableSet *crashReportsGenerated = [NSMutableSet setWithSet:crashReportsAtEnd];
    [crashReportsGenerated minusSet:crashReportsAtStart];
    NSString *concatenatedCrashReports = [self concatenatedCrashReports:[crashReportsGenerated allObjects]];

    [crashFilter fireEventsToSimulateTestRunFinishing:_reporters
                                      fullProductName:_buildSettings[@"FULL_PRODUCT_NAME"]
                             concatenatedCrashReports:concatenatedCrashReports];
  }

  return succeeded;
}

- (NSArray *)otestArguments
{
  // These are the same arguments Xcode would use when invoking otest.  To capture these, we
  // just ran a test case from Xcode that dumped 'argv'.  It's a little tricky to do that outside
  // of the 'main' function, but you can use _NSGetArgc and _NSGetArgv.  See --
  // http://unixjunkie.blogspot.com/2006/07/access-argc-and-argv-from-anywhere.html
  NSMutableArray *args = [NSMutableArray arrayWithArray:@[
           // Not sure exactly what this does...
           @"-NSTreatUnknownArgumentsAsOpen", @"NO",
           // Not sure exactly what this does...
           @"-ApplePersistenceIgnoreState", @"YES",
           // SenTest is one of Self, All, None,
           // or TestClassName[/testCaseName][,TestClassName2]
           @"-SenTest", _senTestList,
           // SenTestInvertScope optionally inverts whatever SenTest would normally select.
           // We never invert, since we always pass the exact list of test cases
           // to be run.
           @"-SenTestInvertScope", @"NO",
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
      if ([key isEqualToString:@"DYLD_INSERT_LIBRARIES"]) {
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
          _buildSettings[@"BUILT_PRODUCTS_DIR"],
          _buildSettings[@"FULL_PRODUCT_NAME"]
          ];
}

@end
