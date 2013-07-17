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

#import "PhabricatorReporter.h"

#import "ReporterEvents.h"

@implementation PhabricatorReporter

- (id)init
{
  if (self = [super init]) {
    _results = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)dealloc
{
  [_results release];
  [_scheme release];
  [super dealloc];
}

- (void)beginAction:(NSDictionary *)event
{
  _scheme = [event[kReporter_BeginAction_SchemeKey] retain];
}

- (void)endAction:(NSDictionary *)event
{
  [_scheme release];
  _scheme = nil;
}

- (void)beginBuildTarget:(NSDictionary *)event
{
  _currentTargetFailures = [[NSMutableArray alloc] init];
}

- (void)endBuildTarget:(NSDictionary *)event
{
  [_results addObject:@{
   @"name" : [NSString stringWithFormat:@"%@: Build %@:%@",
              _scheme,
              event[kReporter_EndBuildTarget_ProjectKey],
              event[kReporter_EndBuildTarget_TargetKey]],
   @"link" : [NSNull null],
   @"result" : (_currentTargetFailures.count == 0) ? @"pass" : @"broken",
   @"userdata" : [_currentTargetFailures componentsJoinedByString:@"=================================\n"],
   @"coverage" : [NSNull null],
   @"extra" : [NSNull null],
   }];

  [_currentTargetFailures release];
  _currentTargetFailures = nil;
}

- (void)beginBuildCommand:(NSDictionary *)event
{
  _currentBuildCommand = [event retain];
}

- (void)endBuildCommand:(NSDictionary *)event
{
  BOOL succeeded = [event[kReporter_EndBuildCommand_SucceededKey] boolValue];
  if (!succeeded) {
    NSString *commandAndFailure =
      [_currentBuildCommand[kReporter_BeginBuildCommand_CommandKey]
       stringByAppendingString:event[kReporter_EndBuildCommand_EmittedOutputTextKey]];
    [_currentTargetFailures addObject:commandAndFailure];
  }

  [_currentBuildCommand release];
  _currentBuildCommand = nil;
}

- (void)beginXcodebuild:(NSDictionary *)event
{
}

- (void)endXcodebuild:(NSDictionary *)event
{
}

- (void)beginOcunit:(NSDictionary *)event
{
}

- (void)endOcunit:(NSDictionary *)event
{
}

- (void)beginTestSuite:(NSDictionary *)event
{
}

- (void)endTestSuite:(NSDictionary *)event
{
}

- (void)beginTest:(NSDictionary *)event
{
}

- (void)endTest:(NSDictionary *)event
{
  NSMutableString *userdata = [NSMutableString stringWithString:event[kReporter_EndTest_OutputKey]];

  // Include exception, if any.
  NSDictionary *exception = event[kReporter_EndTest_ExceptionKey];
  if (exception) {
    [userdata appendFormat:@"%@:%d: %@: %@",
     exception[kReporter_EndTest_Exception_FilePathInProjectKey],
     [exception[kReporter_EndTest_Exception_LineNumberKey] intValue],
     exception[kReporter_EndTest_Exception_NameKey],
     exception[kReporter_EndTest_Exception_ReasonKey]];
  }

  [_results addObject:@{
   @"name" : [NSString stringWithFormat:@"%@: %@",
              _scheme,
              event[kReporter_EndTest_TestKey]],
   @"link" : [NSNull null],
   @"result" : [event[kReporter_EndTest_SucceededKey] boolValue] ? @"pass" : @"fail",
   @"userdata" : userdata,
   @"coverage" : [NSNull null],
   @"extra" : [NSNull null],
   }];
}

- (void)testOutput:(NSDictionary *)event
{
}

- (void)message:(NSDictionary *)event
{
}

- (NSString *)arcUnitJSON
{
  NSError *error = nil;
  NSData *data =  [NSJSONSerialization dataWithJSONObject:_results
                                                  options:NSJSONWritingPrettyPrinted
                                                    error:&error];
  NSAssert(error == nil, @"Failed while trying to encode as JSON: %@", error);
  return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
}

- (void)didFinishReporting
{
  [_outputHandle writeData:[[[self arcUnitJSON] stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
}

@end
