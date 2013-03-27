
#import "TestRunner.h"
#import "PJSONKit.h"
#import "OCUnitCrashFilter.h"

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

- (BOOL)runTestsWithError:(NSString **)error {
  OCUnitCrashFilter *crashFilter = [[[OCUnitCrashFilter alloc] init] autorelease];

  void (^feedOutputToBlock)(NSString *) = ^(NSString *line) {
    NSError *parseError = nil;
    NSDictionary *event = [line XT_objectFromJSONStringWithParseOptions:XT_JKParseOptionNone error:&parseError];

    if (parseError) {
      [NSException raise:NSGenericException format:@"Failed to parse test output: %@", [parseError localizedFailureReason]];
    }

    [_reporters makeObjectsPerformSelector:@selector(handleEvent:) withObject:event];
    [crashFilter handleEvent:event];
  };

  BOOL succeeded = [self runTestsAndFeedOutputTo:feedOutputToBlock error:error];

  if (crashFilter.currentTestEvent != nil) {
    [crashFilter fireEventsToSimulateTestRunFinishing:_reporters];
  }

  return succeeded;
}

@end
