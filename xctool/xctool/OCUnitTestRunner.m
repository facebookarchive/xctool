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

@implementation OCUnitTestRunner

- (id)initWithBuildSettings:(NSDictionary *)buildSettings
                senTestList:(NSString *)senTestList
         senTestInvertScope:(BOOL)senTestInvertScope
          garbageCollection:(BOOL)garbageCollection
             freshSimulator:(BOOL)freshSimulator
               freshInstall:(BOOL)freshInstall
             standardOutput:(NSFileHandle *)standardOutput
              standardError:(NSFileHandle *)standardError
                  reporters:(NSArray *)reporters
{
  if (self = [super init]) {
    _buildSettings = [buildSettings retain];
    _senTestList = [senTestList retain];
    _senTestInvertScope = senTestInvertScope;
    _garbageCollection = garbageCollection;
    _freshSimulator = freshSimulator;
    _freshInstall = freshInstall;
    _standardOutput = [standardOutput retain];
    _standardError = [standardError retain];
    _reporters = [reporters retain];
  }
  return self;
}

- (void)dealloc
{
  [_buildSettings release];
  [_senTestList release];
  [_standardOutput release];
  [_standardError release];
  [_reporters release];
  [super dealloc];
}

- (BOOL)runTestsAndFeedOutputTo:(void (^)(NSString *))outputLineBlock error:(NSString **)error
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
    NSError *parseError = nil;
    NSDictionary *event = [NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding]
                                                          options:0
                                                            error:&parseError];
    if (parseError) {
      [NSException raise:NSGenericException
                  format:@"Failed to parse test output '%@' with error '%@'.",
       line,
       [parseError localizedFailureReason]];
    }

    [_reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:event];
    [crashFilter handleEvent:event];
    didReceiveTestEvents = YES;
  };

  NSSet *crashReportsAtStart = [NSSet setWithArray:[self collectCrashReportPaths]];

  BOOL succeeded = [self runTestsAndFeedOutputTo:feedOutputToBlock error:error];

  if (!succeeded && !didReceiveTestEvents) {
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

  if ([crashFilter testRunWasUnfinished]) {
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
           ];
}

- (NSString *)testBundlePath
{
  return [NSString stringWithFormat:@"%@/%@",
          _buildSettings[@"BUILT_PRODUCTS_DIR"],
          _buildSettings[@"FULL_PRODUCT_NAME"]
          ];
}

@end
