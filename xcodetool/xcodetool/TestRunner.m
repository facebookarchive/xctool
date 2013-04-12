
#import "TestRunner.h"

#import <QuartzCore/QuartzCore.h>

#import "OCUnitCrashFilter.h"
#import "PJSONKit.h"

@implementation TestRunner

- (id)initWithBuildSettings:(NSDictionary *)buildSettings
                senTestList:(NSString *)senTestList
         senTestInvertScope:(BOOL)senTestInvertScope
             standardOutput:(NSFileHandle *)standardOutput
              standardError:(NSFileHandle *)standardError
                  reporters:(NSArray *)reporters
{
  if (self = [super init]) {
    _buildSettings = [buildSettings retain];
    _senTestList = [senTestList retain];
    _senTestInvertScope = senTestInvertScope;
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

- (NSArray *)allCrashReports
{
  NSError *error = nil;
  NSArray *allContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[@"~/Library/Logs/DiagnosticReports" stringByStandardizingPath]
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
    NSDictionary *event = [line XT_objectFromJSONStringWithParseOptions:XT_JKParseOptionNone error:&parseError];

    if (parseError) {
      [NSException raise:NSGenericException format:@"Failed to parse test output: %@", [parseError localizedFailureReason]];
    }

    [_reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:event];
    [crashFilter handleEvent:event];
    didReceiveTestEvents = YES;
  };
  
  NSSet *crashReportsAtStart = [NSSet setWithArray:[self allCrashReports]];

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
    NSSet *crashReportsAtEnd = [NSSet setWithArray:[self allCrashReports]];
    CFTimeInterval start = CACurrentMediaTime();
    while ([crashReportsAtEnd isEqualToSet:crashReportsAtStart] && (CACurrentMediaTime() - start < 10.0)) {
      [NSThread sleepForTimeInterval:0.25];
      crashReportsAtEnd = [NSSet setWithArray:[self allCrashReports]];
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

@end
