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
  
  NSMutableDictionary *nameToTestSuiteHashTable = [[NSMutableDictionary alloc] init];
  // testSuite has two elements in it, NSDictionary testSuite and NSArray suiteResults
  for (NSDictionary *testSuite in self.testSuites) {
    NSDictionary *suiteEvent = testSuite[kJUnitReporter_Suite_Event];
    NSArray *suiteResults = testSuite[kJUnitReporter_Suite_Results];
    
    // This is the NSXMLElement being added to NSXMLElement testsuites
    NSXMLElement *testsuite = [[NSXMLElement alloc] initWithName:@"testsuite"];
    
    // Make a hash set of names already encountered to decide to merge nodes or not
    NSString *name = suiteEvent[kReporter_EndTestSuite_SuiteKey];
    NSXMLElement *existingTestSuite = [nameToTestSuiteHashTable objectForKey:name];
    
    if (existingTestSuite) { // If found, update attributes of testsuite and re-enter
      // add the attributes: tests, failures, errors and time: in the else clause to this NSXMLElement
      int tests = [suiteEvent[kReporter_EndTestSuite_TestCaseCountKey] intValue] + [[[existingTestSuite attributeForName:@"tests"] stringValue] intValue];
      // tests: stringValue:[NSString stringWithFormat:@"%d", [suiteEvent[kReporter_EndTestSuite_TestCaseCountKey] intValue]]
      
      int failures = [suiteEvent[kReporter_EndTestSuite_TotalFailureCountKey] intValue] + [[[existingTestSuite attributeForName:@"failures"] stringValue] intValue];
      // failures: stringValue:[NSString stringWithFormat:@"%d",[suiteEvent[kReporter_EndTestSuite_TotalFailureCountKey] intValue]]
      
      int errors = [suiteEvent[kReporter_EndTestSuite_UnexpectedExceptionCountKey] intValue] + [[[existingTestSuite attributeForName:@"errors"] stringValue] intValue];
      // errors: stringValue:[NSString stringWithFormat:@"%d", [suiteEvent[kReporter_EndTestSuite_UnexpectedExceptionCountKey] intValue]]
      
      float time = [suiteEvent[kReporter_EndTestSuite_TotalDurationKey] floatValue] + [[[existingTestSuite attributeForName:@"time"] stringValue] floatValue];
      // time: stringValue:[NSString stringWithFormat:@"%f", [suiteEvent[kReporter_EndTestSuite_TotalDurationKey] floatValue]]
      
      NSArray *attributes = @[[NSXMLNode attributeWithName:@"tests" stringValue:[NSString stringWithFormat:@"%d", tests]],
                              [NSXMLNode attributeWithName:@"failures" stringValue:[NSString stringWithFormat:@"%d", failures]],
                              [NSXMLNode attributeWithName:@"errors" stringValue:[NSString stringWithFormat:@"%d", errors]],
                              [NSXMLNode attributeWithName:@"time" stringValue:[NSString stringWithFormat:@"%f", time]],
                              [NSXMLNode attributeWithName:@"timestamp" stringValue:[self.formatter stringFromDate:[NSDate date]]],
                              [NSXMLNode attributeWithName:@"name" stringValue:suiteEvent[kReporter_EndTestSuite_SuiteKey]]];
      [existingTestSuite setAttributes:attributes];
      
      NSXMLElement *ptr = testsuite;
      testsuite = existingTestSuite;
      [ptr release];
    } else { // else, create new attributes to add to testsuite then update hashtable
      // Adding attributes to NSXMLElement testsuite
      NSArray *attributes = @[[NSXMLNode attributeWithName:@"tests" stringValue:[NSString stringWithFormat:@"%d", [suiteEvent[kReporter_EndTestSuite_TestCaseCountKey] intValue]]],
                              [NSXMLNode attributeWithName:@"failures" stringValue:[NSString stringWithFormat:@"%d",[suiteEvent[kReporter_EndTestSuite_TotalFailureCountKey] intValue]]],
                              [NSXMLNode attributeWithName:@"errors" stringValue:[NSString stringWithFormat:@"%d", [suiteEvent[kReporter_EndTestSuite_UnexpectedExceptionCountKey] intValue]]],
                              [NSXMLNode attributeWithName:@"time" stringValue:[NSString stringWithFormat:@"%f", [suiteEvent[kReporter_EndTestSuite_TotalDurationKey] floatValue]]],
                              [NSXMLNode attributeWithName:@"timestamp" stringValue:[self.formatter stringFromDate:[NSDate date]]],
                              [NSXMLNode attributeWithName:@"name" stringValue:suiteEvent[kReporter_EndTestSuite_SuiteKey]]];
      [testsuite setAttributes:attributes];
    }
    
    for (NSDictionary *testResult in suiteResults) {
      
      // Creating a proper NSXMLElement testcase with attributes
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
      
      // Adding NSXMLElement testcase to NSXMLElement testsuite
      [testsuite addChild:testcase];
      [testcase release];
    }
    
    // After updating properties and adding test cases, add testsuite back into hashtable
    [nameToTestSuiteHashTable setObject:testsuite forKey:name];
    
  }
  
  // Add all unique NSXMLElement testsuite objects into testsuites.
  for (id key in nameToTestSuiteHashTable) {
    NSXMLElement *lastTestSuite = [nameToTestSuiteHashTable objectForKey:key];
    [testsuites addChild:lastTestSuite];
    [lastTestSuite release];
  }
  [nameToTestSuiteHashTable release];
  
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
