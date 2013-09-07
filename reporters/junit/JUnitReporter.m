#import "JUnitReporter.h"

#import "ReporterEvents.h"

#pragma mark Constants
#define kJUnitReporter_Suite_Event @"event"
#define kJUnitReporter_Suite_Results @"results"

#pragma mark Private Interface
@interface JUnitReporter ()

@property (nonatomic, retain) NSMutableArray *testSuites;
@property (nonatomic, retain) NSMutableArray *testResults;
@property (nonatomic, retain) NSDateFormatter *formatter;
@property (nonatomic) int totalTests;
@property (nonatomic) int totalFailures;
@property (nonatomic) int totalErrors;
@property (nonatomic) float totalTime;

@end

#pragma mark Implementation
@implementation JUnitReporter

#pragma mark Memory Management
- (id)init
{
  if (self = [super init]) {
    _formatter = [[NSDateFormatter alloc] init];
    [_formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZ"];
    self.testSuites = [NSMutableArray array];
    self.totalTests = 0;
    self.totalFailures = 0;
    self.totalErrors = 0;
    self.totalTime = 0.0;
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
      kJUnitReporter_Suite_Event: event,
      kJUnitReporter_Suite_Results: self.testResults
    }];
    self.testResults = nil;
  }
}

- (void)didFinishReporting
{
  NSXMLElement *testsuites = [[NSXMLElement alloc] initWithName:@"testsuites"];
  [testsuites setAttributes:@[[NSXMLNode attributeWithName:@"name" stringValue:@"AllTestUnits"],
                              [NSXMLNode attributeWithName:@"tests" stringValue:[NSString stringWithFormat:@"%d", self.totalTests]],
                              [NSXMLNode attributeWithName:@"failures" stringValue:[NSString stringWithFormat:@"%d", self.totalFailures]],
                              [NSXMLNode attributeWithName:@"errors" stringValue:[NSString stringWithFormat:@"%d", self.totalErrors]],
                              [NSXMLNode attributeWithName:@"time" stringValue:[NSString stringWithFormat:@"%f", self.totalTime]]]];

  for (NSDictionary *testSuite in self.testSuites) {
    NSDictionary *suiteEvent = testSuite[kJUnitReporter_Suite_Event];
    NSArray *suiteResults = testSuite[kJUnitReporter_Suite_Results];
    NSXMLElement *testsuite = [[NSXMLElement alloc] initWithName:@"testsuite"];
    NSArray *attributes = @[[NSXMLNode attributeWithName:@"tests" stringValue:[NSString stringWithFormat:@"%d", [suiteEvent[kReporter_EndTestSuite_TestCaseCountKey] intValue]]],
                            [NSXMLNode attributeWithName:@"failures" stringValue:[NSString stringWithFormat:@"%d",[suiteEvent[kReporter_EndTestSuite_TotalFailureCountKey] intValue]]],
                            [NSXMLNode attributeWithName:@"errors" stringValue:[NSString stringWithFormat:@"%d", [suiteEvent[kReporter_EndTestSuite_UnexpectedExceptionCountKey] intValue]]],
                            [NSXMLNode attributeWithName:@"time" stringValue:[NSString stringWithFormat:@"%f", [suiteEvent[kReporter_EndTestSuite_TotalDurationKey] floatValue]]],
                            [NSXMLNode attributeWithName:@"timestamp" stringValue:[self.formatter stringFromDate:[NSDate date]]],
                            [NSXMLNode attributeWithName:@"name" stringValue:suiteEvent[kReporter_EndTestSuite_SuiteKey]]];
    [testsuite setAttributes:attributes];

    for (NSDictionary *testResult in suiteResults) {
      NSXMLElement *testcase = [[NSXMLElement alloc] initWithName:@"testcase"];
      NSMutableDictionary *attributes = [[NSMutableDictionary alloc] initWithCapacity:3];
      [testcase setAttributes:@[[NSXMLNode attributeWithName:@"classname" stringValue:testResult[kReporter_EndTest_ClassNameKey]],
                                [NSXMLNode attributeWithName:@"name" stringValue:testResult[kReporter_EndTest_MethodNameKey]],
                                [NSXMLNode attributeWithName:@"time" stringValue:[NSString stringWithFormat:@"%f", [testResult[kReporter_EndTest_TotalDurationKey] floatValue]]]]];
      [attributes release];

      if (![testResult[kReporter_EndTest_SucceededKey] boolValue]) {
        NSDictionary *exception = testResult[kReporter_EndTest_ExceptionKey];
        NSString *failureValue = [[NSString alloc] initWithFormat:@"%@:%d", exception[kReporter_EndTest_Exception_FilePathInProjectKey],
                                  [exception[kReporter_EndTest_Exception_LineNumberKey] intValue]];
        NSXMLElement *failure = [[NSXMLElement alloc] initWithName:@"failure" stringValue:failureValue];
        [failure setAttributes:@[[NSXMLNode attributeWithName:@"type" stringValue:@"Failure"],
                                 [NSXMLNode attributeWithName:@"message" stringValue:exception[kReporter_EndTest_Exception_ReasonKey]]]];
        [testcase addChild:failure];
        [failureValue release];
        [failure release];
      }


      NSString *output = testResult[kReporter_EndTest_OutputKey];
      if (output && output.length > 0) {
        NSXMLElement *systemOutput = [[NSXMLElement alloc] initWithName:@"system-out" stringValue:output];
        [testcase addChild:systemOutput];
        [systemOutput release];
      }
      [testsuite addChild:testcase];

      [testcase release];
    }
    [testsuites addChild:testsuite];
    [testsuite release];
  }
  NSXMLDocument *doc = [[NSXMLDocument alloc] initWithRootElement:testsuites];
  doc.version = @"1.0";
  [doc setStandalone:YES];
  doc.characterEncoding = @"UTF-8";
  [_outputHandle writeData:[doc XMLDataWithOptions:NSXMLNodePrettyPrint]];

  [testsuites release];
  [doc release];

  self.testSuites = nil;
}

@end
