//
// Copyright 2004-present Facebook. All Rights Reserved.
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

#import "JUnitReporter.h"

#import "ReporterEvents.h"

#pragma mark Constants
#define kJUnitReporter_Suite_Event @"event"
#define kJUnitReporter_Suite_Results @"results"

#pragma mark Private Interface
@interface JUnitReporter ()

@property (nonatomic, copy) NSMutableArray *testSuites;
@property (nonatomic, copy) NSMutableArray *testResults;
@property (nonatomic, strong) NSDateFormatter *formatter;
@property (nonatomic, assign) int totalTests;
@property (nonatomic, assign) int totalFailures;
@property (nonatomic, assign) int totalErrors;
@property (nonatomic, assign) double totalTime;

@end

#pragma mark Implementation
@implementation JUnitReporter

#pragma mark Memory Management
- (instancetype)init
{
  if (self = [super init]) {
    _formatter = [[NSDateFormatter alloc] init];
    [_formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZ"];

    _testSuites = [[NSMutableArray alloc] init];
    _totalTests = 0;
    _totalFailures = 0;
    _totalErrors = 0;
    _totalTime = 0.0;
  }
  return self;
}


#pragma mark Reporter

- (void)beginTestSuite:(NSDictionary *)event
{
  _testResults = [[NSMutableArray alloc] init];
}

- (void)endTest:(NSDictionary *)event
{
  [_testResults addObject:event];
}

- (void)endTestSuite:(NSDictionary *)event
{
  if (_testResults) { // Prevents nested suites
    _totalTests += [event[kReporter_EndTestSuite_TestCaseCountKey] intValue];
    _totalFailures += [event[kReporter_EndTestSuite_TotalFailureCountKey] intValue];
    _totalErrors += [event[kReporter_EndTestSuite_UnexpectedExceptionCountKey] intValue];
    _totalTime += [event[kReporter_EndTestSuite_TotalDurationKey] doubleValue];
    [_testSuites addObject:@{
      kJUnitReporter_Suite_Event: event,
      kJUnitReporter_Suite_Results: _testResults
    }];
    _testResults = nil;
  }
}

- (void)didFinishReporting
{
  NSXMLElement *testsuitesElement = [NSXMLElement elementWithName:@"testsuites"];
  [testsuitesElement setAttributes:@[[NSXMLNode attributeWithName:@"name"
                                                      stringValue:@"AllTestUnits"],
                                     [NSXMLNode attributeWithName:@"tests"
                                                      stringValue:[NSString stringWithFormat:@"%d", _totalTests]],
                                     [NSXMLNode attributeWithName:@"failures"
                                                      stringValue:[NSString stringWithFormat:@"%d", _totalFailures]],
                                     [NSXMLNode attributeWithName:@"errors"
                                                      stringValue:[NSString stringWithFormat:@"%d", _totalErrors]],
                                     [NSXMLNode attributeWithName:@"time"
                                                      stringValue:[NSString stringWithFormat:@"%f", _totalTime]]]];

  // Make a dictionary of names already encountered to decide to merge nodes or not
  NSMutableDictionary *nameToTestSuiteDictionary = [NSMutableDictionary dictionary];

  // testSuite has two elements in it, NSDictionary testSuite and NSArray suiteResults
  for (NSDictionary *testSuite in _testSuites) {
    NSDictionary *suiteEvent = testSuite[kJUnitReporter_Suite_Event];
    NSArray *suiteResults = testSuite[kJUnitReporter_Suite_Results];

    // This is the NSXMLElement being added to NSXMLElement testsuites
    NSXMLElement *testsuite = nil;

    NSString *name = suiteEvent[kReporter_EndTestSuite_SuiteKey];
    NSXMLElement *existingTestSuite = nameToTestSuiteDictionary[name];

    if (existingTestSuite) { // If found, update attributes of testsuite and re-enter
      int tests = ([suiteEvent[kReporter_EndTestSuite_TestCaseCountKey] intValue] +
                   [[[existingTestSuite attributeForName:@"tests"] objectValue] intValue]);
      int failures = ([suiteEvent[kReporter_EndTestSuite_TotalFailureCountKey] intValue] +
                      [[[existingTestSuite attributeForName:@"failures"] objectValue] intValue]);
      int errors = ([suiteEvent[kReporter_EndTestSuite_UnexpectedExceptionCountKey] intValue] +
                    [[[existingTestSuite attributeForName:@"errors"] objectValue] intValue]);
      double time = ([suiteEvent[kReporter_EndTestSuite_TotalDurationKey] doubleValue] +
                    [[[existingTestSuite attributeForName:@"time"] objectValue] doubleValue]);

      NSArray *attributes = @[[NSXMLNode attributeWithName:@"tests"
                                               stringValue:[NSString stringWithFormat:@"%d", tests]],
                              [NSXMLNode attributeWithName:@"failures"
                                               stringValue:[NSString stringWithFormat:@"%d", failures]],
                              [NSXMLNode attributeWithName:@"errors"
                                               stringValue:[NSString stringWithFormat:@"%d", errors]],
                              [NSXMLNode attributeWithName:@"time"
                                               stringValue:[NSString stringWithFormat:@"%f", time]],
                              [NSXMLNode attributeWithName:@"timestamp"
                                               stringValue:[_formatter stringFromDate:[NSDate date]]],
                              [NSXMLNode attributeWithName:@"name"
                                               stringValue:suiteEvent[kReporter_EndTestSuite_SuiteKey]]];
      [existingTestSuite setAttributes:attributes];
      testsuite = existingTestSuite;
    } else { // else, create new attributes to add to testsuite then update dictionary
      testsuite = [NSXMLElement elementWithName:@"testsuite"];
      [testsuite setAttributes:@[[NSXMLNode attributeWithName:@"tests"
                                                  stringValue:[NSString stringWithFormat:@"%d",
                                                               [suiteEvent[kReporter_EndTestSuite_TestCaseCountKey] intValue]]],
                                 [NSXMLNode attributeWithName:@"failures"
                                                  stringValue:[NSString stringWithFormat:@"%d",
                                                               [suiteEvent[kReporter_EndTestSuite_TotalFailureCountKey] intValue]]],
                                 [NSXMLNode attributeWithName:@"errors"
                                                  stringValue:[NSString stringWithFormat:@"%d",
                                                               [suiteEvent[kReporter_EndTestSuite_UnexpectedExceptionCountKey] intValue]]],
                                 [NSXMLNode attributeWithName:@"time"
                                                  stringValue:[NSString stringWithFormat:@"%f",
                                                               [suiteEvent[kReporter_EndTestSuite_TotalDurationKey] doubleValue]]],
                                 [NSXMLNode attributeWithName:@"timestamp"
                                                  stringValue:[_formatter stringFromDate:[NSDate date]]],
                                 [NSXMLNode attributeWithName:@"name"
                                                  stringValue:suiteEvent[kReporter_EndTestSuite_SuiteKey]]]];
    }

    for (NSDictionary *testResult in suiteResults) {
      // Creating a proper NSXMLElement testcase with attributes
      NSXMLElement *testcaseElement = [NSXMLElement elementWithName:@"testcase"];
      [testcaseElement setAttributes:@[[NSXMLNode attributeWithName:@"classname"
                                                        stringValue:testResult[kReporter_EndTest_ClassNameKey]],
                                       [NSXMLNode attributeWithName:@"name"
                                                        stringValue:testResult[kReporter_EndTest_MethodNameKey]],
                                       [NSXMLNode attributeWithName:@"time"
                                                        stringValue:[NSString stringWithFormat:@"%f",
                                                                     [testResult[kReporter_EndTest_TotalDurationKey] doubleValue]]]]];

      if (![testResult[kReporter_EndTest_SucceededKey] boolValue]) {
        for (NSDictionary *exception in testResult[kReporter_EndTest_ExceptionsKey]) {
          NSString *failureValue = [NSString stringWithFormat:@"%@:%d",
                                    exception[kReporter_EndTest_Exception_FilePathInProjectKey],
                                    [exception[kReporter_EndTest_Exception_LineNumberKey] intValue]];
          NSXMLElement *failureElement = [NSXMLElement elementWithName:@"failure"
                                                           stringValue:failureValue];
          [failureElement setAttributes:@[[NSXMLNode attributeWithName:@"type"
                                                           stringValue:@"Failure"],
                                          [NSXMLNode attributeWithName:@"message"
                                                           stringValue:exception[kReporter_EndTest_Exception_ReasonKey]]]];
          [testcaseElement addChild:failureElement];
        }

        if ([testResult[kReporter_EndTest_ResultKey] isEqualToString:@"error"]) {
          NSXMLElement *errorElement = [NSXMLElement elementWithName:@"error"
                                                           stringValue:@""];
          [errorElement setAttributes:@[[NSXMLNode attributeWithName:@"type"
                                                           stringValue:@"Error"]]];
          [testcaseElement addChild:errorElement];
        }
      }

      NSString *output = testResult[kReporter_EndTest_OutputKey];
      if (output && output.length > 0) {
        // make sure we don't create an invalid junit.xml when stdout contains invalid UTF-8
        NSData *outputData = [output dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
        [testcaseElement addChild:[NSXMLElement elementWithName:@"system-out"
                                                    stringValue:[[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding]]];
      }

      // Adding NSXMLElement testcase to NSXMLElement testsuite
      [testsuite addChild:testcaseElement];
    }

    // After updating properties and adding test cases, add testsuite back into dictionary
    nameToTestSuiteDictionary[name] = testsuite;
  }

  // Add all unique NSXMLElement testsuite objects into testsuites.
  for (NSString *key in nameToTestSuiteDictionary) {
    NSXMLElement *lastTestSuite = nameToTestSuiteDictionary[key];
    [testsuitesElement addChild:lastTestSuite];
  }

  NSXMLDocument *doc = [NSXMLDocument documentWithRootElement:testsuitesElement];
  [doc setVersion:@"1.0"];
  [doc setStandalone:YES];
  [doc setCharacterEncoding:@"UTF-8"];
  [_outputHandle writeData:[doc XMLDataWithOptions:NSXMLNodePrettyPrint]];

  _testSuites = nil;
}

@end
