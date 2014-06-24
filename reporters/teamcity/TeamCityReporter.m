// Copyright 2014-present AutoScout24. All Rights Reserved.

#import "TeamCityReporter.h"

#import "ReporterEvents.h"

#pragma mark Constants
#define kJUnitReporter_Suite_Event @"event"
#define kJUnitReporter_Suite_Results @"results"

#pragma mark Private Interface
@interface TeamCityReporter ()

@property (nonatomic, assign) int totalTests;

@end

#pragma mark Implementation
@implementation TeamCityReporter

#pragma mark Memory Management
- (id)init
{
  if (self = [super init]) {
    self.totalTests = 0;
  }
  return self;
}

- (void)dealloc
{
  [super dealloc];
}

#pragma mark Reporter

- (void)beginTestSuite:(NSDictionary *)event
{
  NSLog(@"##teamcity[testSuiteStarted name='%@']", event[kReporter_EndTestSuite_SuiteKey]);
}

- (void)beginTest:(NSDictionary *)event
{
  self.totalTests += 1;
  NSString *testNameWithMethodName = [NSString stringWithFormat:@"%@.%@",event[kReporter_EndTest_ClassNameKey],event[kReporter_EndTest_MethodNameKey]];
  NSLog(@"##teamcity[testStarted name='%@']",testNameWithMethodName);
}

- (void)endTest:(NSDictionary *)event
{
  NSString *testNameWithMethodName = [NSString stringWithFormat:@"%@.%@",event[kReporter_EndTest_ClassNameKey],event[kReporter_EndTest_MethodNameKey]];
    
  if (![event[kReporter_EndTest_SucceededKey] boolValue]) {
    NSArray *exceptions = event[kReporter_EndTest_ExceptionsKey];
     
    if ([exceptions count] > 0) {
      NSDictionary *exception = exceptions[0];
     
      NSString *failureValue = [NSString stringWithFormat:@"%@:%d",
      exception[kReporter_EndTest_Exception_FilePathInProjectKey],
      [exception[kReporter_EndTest_Exception_LineNumberKey] intValue]];
     
      NSLog(@"##teamcity[testFailed name='%@' message='%@' details='%@ \n %@']",testNameWithMethodName, exception[kReporter_EndTest_Exception_ReasonKey], failureValue, event[kReporter_EndTest_Exception_ReasonKey] ? event[kReporter_EndTest_Exception_ReasonKey] : @"");
    }
     
  }
    
  NSLog(@"##teamcity[testFinished name='%@' duration='%d']",testNameWithMethodName, (int)ceil([event[kReporter_EndTest_TotalDurationKey] doubleValue] * 1000));
}

- (void)endTestSuite:(NSDictionary *)event
{
  NSLog(@"##teamcity[testSuiteFinished name='%@']", event[kReporter_EndTestSuite_SuiteKey]);
}

- (void)didFinishReporting
{
    
  if (self.totalTests == 0) {
    NSLog(@"##teamcity[buildStatus status='FAILURE' text='No tests suites executed.']");
  }
  self.totalTests = 0;
}

@end
