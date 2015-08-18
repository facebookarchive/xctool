// Copyright 2004-present Facebook. All Rights Reserved.

#import "TeamCityReporter.h"

#import "ReporterEvents.h"
#import "TeamCityStatusMessageGenerator.h"

#pragma mark Private Interface
@interface TeamCityReporter ()

@property (nonatomic, assign) int totalTests;
@property (nonatomic, assign) BOOL testShouldRun;

@end

#pragma mark Implementation
@implementation TeamCityReporter

#pragma mark Memory Management
- (instancetype)init
{
  if (self = [super init]) {
    _totalTests = 0;
    _testShouldRun = NO;
  }
  return self;
}


#pragma mark Reporter

- (NSString *)condensedBuildCommandTitle:(NSString *)title {
  NSMutableArray *parts = [NSMutableArray array];
  NSRange pathRange = [title rangeOfString:@"/"];
  if (pathRange.location != NSNotFound) {
    NSString *command = [[title substringToIndex:pathRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *path = [title substringFromIndex:pathRange.location];
    [parts addObject:command ?: @""];
    [parts addObject:[path lastPathComponent] ?: @""];
  } else {
    [parts addObject:title];
  }

  return [parts componentsJoinedByString:@" "];
}

- (NSString *)condensedBuildCommandOutput:(NSString *)output {
  if ([[output substringToIndex:1] isEqualToString:@"/"]) {
    NSRange pathRange = [output rangeOfString:@":"];
    if (pathRange.location != NSNotFound) {
      NSString *fileName = [[output substringToIndex:pathRange.location] lastPathComponent];
      NSString *path = [output substringFromIndex:pathRange.location];
      if (fileName.length > 0 && path.length > 0) {
        return [NSString stringWithFormat:@"%@%@",fileName, path];
      }
    }
  }

  return output;
}

-(void)beginBuildCommand:(NSDictionary *)event {
  if (event[kReporter_BeginBuildCommand_TitleKey]) {
    NSLog(@"##teamcity[progressStart '%@']",[TeamCityStatusMessageGenerator escapeCharacter:[self condensedBuildCommandTitle:event[kReporter_BeginBuildCommand_TitleKey]]]);
  }
}

-(void)endBuildCommand:(NSDictionary *)event {
  BOOL succeeded = [event[kReporter_EndBuildCommand_SucceededKey] boolValue];

  if (!succeeded) {
    NSString *outputText = [event[kReporter_EndBuildCommand_EmittedOutputTextKey]
                            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (outputText.length > 0) {
      NSLog(@"##teamcity[buildStatus status='FAILURE' text='%@']",[TeamCityStatusMessageGenerator escapeCharacter:[self condensedBuildCommandOutput:outputText]]);
    }
    else {
      NSLog(@"##teamcity[buildStatus status='FAILURE' text='Build failed']");
    }
  }

  if (event[kReporter_EndBuildCommand_TitleKey]) {
    NSLog(@"##teamcity[progressFinish '%@']",[TeamCityStatusMessageGenerator escapeCharacter:[self condensedBuildCommandTitle:event[kReporter_BeginBuildCommand_TitleKey]]]);
  }
}

-(void)beginStatus:(NSDictionary *)event {
  if (event[kReporter_BeginStatus_MessageKey]) {
    NSLog(@"##teamcity[progressStart '%@']",[TeamCityStatusMessageGenerator escapeCharacter:event[kReporter_BeginStatus_MessageKey]]);
  }
}

-(void)endStatus:(NSDictionary *)event {
  if (event[kReporter_EndStatus_MessageKey]) {
    NSLog(@"##teamcity[progressFinish '%@']",[TeamCityStatusMessageGenerator escapeCharacter:event[kReporter_EndStatus_MessageKey]]);
  }
}

-(void)beginAction:(NSDictionary *)event {
  if ([event[kReporter_BeginAction_NameKey] isEqualTo:@"test"]) {
    _testShouldRun = YES;
  }
}

- (void)beginTestSuite:(NSDictionary *)event
{
  _testShouldRun = YES;
  NSLog(@"##teamcity[testSuiteStarted name='%@']", event[kReporter_EndTestSuite_SuiteKey]);
}

- (void)beginTest:(NSDictionary *)event
{
  _totalTests += 1;
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
  if (_testShouldRun && _totalTests == 0) {
    NSLog(@"##teamcity[buildStatus status='FAILURE' text='No test in test suite executed.']");
  }
  _totalTests = 0;
}

@end
