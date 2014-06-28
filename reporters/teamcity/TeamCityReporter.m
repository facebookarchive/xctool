// Copyright 2014-present Facebook

#import "TeamCityReporter.h"

#import "ReporterEvents.h"
#import "TeamCityStatusMessageGenerator.h"

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
  NSLog(@"##teamcity[testStarted name='%@']",[TeamCityStatusMessageGenerator escapeCharacter:testNameWithMethodName]);
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
     
      NSLog(@"##teamcity[testFailed name='%@' message='%@' details='%@ %@']",[TeamCityStatusMessageGenerator escapeCharacter:testNameWithMethodName], [TeamCityStatusMessageGenerator escapeCharacter:exception[kReporter_EndTest_Exception_ReasonKey]], [TeamCityStatusMessageGenerator escapeCharacter:failureValue], event[kReporter_EndTest_Exception_ReasonKey] ? [TeamCityStatusMessageGenerator escapeCharacter:event[kReporter_EndTest_Exception_ReasonKey]] : @"");
    }
     
  }
    
  NSLog(@"##teamcity[testFinished name='%@' duration='%d']",[TeamCityStatusMessageGenerator escapeCharacter:testNameWithMethodName], (int)ceil([event[kReporter_EndTest_TotalDurationKey] doubleValue] * 1000));
}

- (void)endTestSuite:(NSDictionary *)event
{
  NSLog(@"##teamcity[testSuiteFinished name='%@']", [TeamCityStatusMessageGenerator escapeCharacter:event[kReporter_EndTestSuite_SuiteKey]]);
}

- (void)didFinishReporting
{
    
  if (self.totalTests == 0) {
    NSLog(@"##teamcity[buildStatus status='FAILURE' text='No tests suites executed.']");
  }
  self.totalTests = 0;
}

@end
