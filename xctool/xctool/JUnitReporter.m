#import "JUnitReporter.h"

#pragma mark Private Interface
@interface JUnitReporter ()

@property (nonatomic, retain) NSMutableArray *testSuites;
@property (nonatomic, retain) NSMutableArray *testResults;
@property (nonatomic, retain) NSDateFormatter *formatter;
@property (nonatomic) int totalTests;
@property (nonatomic) int totalFailures;
@property (nonatomic) int totalErrors;
@property (nonatomic) float totalTime;

- (void)write:(NSString *)string;
- (void)writeWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);
- (NSString *)xmlEscape:(NSString *)string;

@end

#pragma mark Implementation
@implementation JUnitReporter

#pragma mark Memory Management
- (id)init
{
  if (self = [super init]) {
    _formatter = [[NSDateFormatter alloc] init];
    [_formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZ"];
  }
  return self;
}

- (void)dealloc
{
  self.testSuites = nil;
  self.testResults = nil;
  self.formatter = nil;
  [super dealloc];
}

#pragma mark Reporter
- (void)beginOcunit:(NSDictionary *)event
{
  self.testSuites = [NSMutableArray array];
  self.totalTests = 0;
  self.totalFailures = 0;
  self.totalErrors = 0;
  self.totalTime = 0.0;
}

- (void)beginTestSuite:(NSDictionary *)event
{
  self.testResults = [NSMutableArray array];
}

- (void)endTest:(NSDictionary *)event
{
  [self.testResults addObject:event];
}

- (void)endTestSuite:(NSDictionary *)event
{
  if (self.testResults) { // Prevents nested suites
    self.totalTests += [event[kReporter_EndTestSuite_TestCaseCountKey] intValue];
    self.totalFailures += [event[kReporter_EndTestSuite_TotalFailureCountKey] intValue];
    self.totalErrors += [event[kReporter_EndTestSuite_UnexpectedExceptionCountKey] intValue];
    self.totalTime += [event[kReporter_EndTestSuite_TotalDurationKey] floatValue];
    [self.testSuites addObject:@{
      @"event": event,
      @"results": self.testResults
    }];
    self.testResults = nil;
  }
}

- (void)endOcunit:(NSDictionary *)event
{
  [self write:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"];
  [self writeWithFormat:
   @"<testsuites name=\"%@\" tests=\"%d\" failures=\"%d\" errors=\"%d\" time=\"%f\">\n",
   [self xmlEscape:event[kReporter_EndOCUnit_BundleNameKey]],
   self.totalTests, self.totalFailures, self.totalErrors, self.totalTime];

  for (NSDictionary *testSuite in self.testSuites) {
    NSDictionary *suiteEvent = testSuite[@"event"];
    NSArray *suiteResults = testSuite[@"results"];
    [self writeWithFormat:
     @"\t<testsuite name=\"%@\" tests=\"%d\" failures=\"%d\" errors=\"%d\" "
     @"time=\"%f\" timestamp=\"%@\">\n",
     [self xmlEscape:suiteEvent[kReporter_EndTestSuite_SuiteKey]],
     [suiteEvent[kReporter_EndTestSuite_TestCaseCountKey] intValue],
     [suiteEvent[kReporter_EndTestSuite_TotalFailureCountKey] intValue],
     [suiteEvent[kReporter_EndTestSuite_UnexpectedExceptionCountKey] intValue],
     [suiteEvent[kReporter_EndTestSuite_TotalDurationKey] floatValue],
     [self.formatter stringFromDate:[NSDate date]]];
    for (NSDictionary *testResult in suiteResults) {
      [self writeWithFormat:
       @"\t\t<testcase classname=\"%@\" name=\"%@\" time=\"%f\">\n",
       [self xmlEscape:testResult[kReporter_EndTest_ClassNameKey]],
       [self xmlEscape:testResult[kReporter_EndTest_MethodNameKey]],
       [testResult[kReporter_EndTest_TotalDurationKey] floatValue]];

      if (![testResult[kReporter_EndTest_SucceededKey] boolValue]) {
        NSDictionary *exception = testResult[kReporter_EndTest_ExceptionKey];
        [self writeWithFormat:
         @"\t\t\t<failure message=\"%@\" type=\"Failure\">%@:%d</failure>\n",
         [self xmlEscape:exception[kReporter_EndTest_Exception_ReasonKey]],
         [self xmlEscape:exception[kReporter_EndTest_Exception_FilePathInProjectKey]],
         [exception[kReporter_EndTest_Exception_LineNumberKey] intValue]];
      }

      NSString *output = testResult[kReporter_EndTest_OutputKey];
      if (output && output.length > 0) {
        [self writeWithFormat:@"\t\t\t<system-out>%@</system-out>\n", [self xmlEscape:output]];
      }
      [self write:@"\t\t</testcase>\n"];
    }
    [self write:@"\t</testsuite>\n"];
  }
  [self write:@"</testsuites>\n"];
  self.testSuites = nil;
}

#pragma mark Private Methods
- (void)write:(NSString *)string
{
  [self.outputHandle writeData:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)writeWithFormat:(NSString *)format, ...
{
  va_list args;
  va_start(args, format);
  NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
  [self write:msg];
  [msg release];
  msg = nil;
  va_end(args);
}

- (NSString *)xmlEscape:(NSString *)string
{
  NSAssert(string != nil, @"Should have non-nil string.");
  NSString *xmlStr = (NSString *)CFXMLCreateStringByEscapingEntities(kCFAllocatorDefault, (CFStringRef)string, NULL);
  return [xmlStr autorelease];
}

@end
