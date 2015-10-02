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

#import "OCTestEventState.h"

#import <QuartzCore/QuartzCore.h>

#import "EventGenerator.h"
#import "ReporterEvents.h"

@interface OCTestEventState ()

@property (nonatomic, assign) CFTimeInterval beginTime;
@property (nonatomic, copy) NSMutableString *outputToPublish;
@property (nonatomic, copy) NSMutableString *outputAlreadyPublished;

@end

@implementation OCTestEventState

- (instancetype)initWithInputName:(NSString *)name
                        reporters:(NSArray *)reporters
{
  self = [super initWithReporters:reporters];
  if (self) {
    [self parseInputName:name];
    _outputAlreadyPublished = [[NSMutableString alloc] initWithString:@""];
    _result = @"error";
  }
  return self;
}

- (instancetype)initWithInputName:(NSString *)name
{
  return [self initWithInputName:name reporters:@[]];
}


- (void)parseInputName:(NSString *)name
{
  NSArray *parts = [name componentsSeparatedByString:@"/"];

  NSAssert([parts count] == 2, @"Unable to parse input name `%@`", name);
  _className = [parts[0] copy];
  _methodName = [parts[1] copy];
}

- (NSString *)testName
{
  return [NSString stringWithFormat:@"-[%@ %@]", _className, _methodName];
}

- (BOOL)isRunning
{
  if (_isStarted && !_isFinished) {
    return YES;
  } else {
    return NO;
  }
}

- (void)stateBeginTest
{
  NSAssert(!_isStarted, @"Test should not have started yet.");
  _isStarted = true;
  _beginTime = CACurrentMediaTime();
}

- (void)stateEndTest:(BOOL)successful result:(NSString *)result
{
  [self stateEndTest:successful result:result duration:(CACurrentMediaTime() - _beginTime)];
}

- (void)stateEndTest:(BOOL)successful result:(NSString *)result duration:(double)duration
{
  _isFinished = true;
  _isSuccessful = successful;
  _duration = duration;
  _result = [result copy];
}

- (void)stateTestOutput:(NSString *)output
{
  NSAssert([self isRunning], @"Test is running.");
  [_outputAlreadyPublished appendString:output];
}

- (void)appendOutput:(NSString *)output
{
  if (_outputToPublish) {
    [_outputToPublish appendString:output];
  } else {
    _outputToPublish = [[NSMutableString alloc] initWithString:output];
  }
}

- (void)publishOutput
{
  NSAssert(_isStarted, @"Can't publish output if test hasn't started");
  if (_outputToPublish.length) {
    [self publishWithEvent:
      EventDictionaryWithNameAndContent(kReporter_Events_TestOuput,
        @{kReporter_TestOutput_OutputKey:_outputToPublish})
    ];
    [self stateTestOutput:_outputToPublish];
    _outputToPublish = nil;
  }
}

- (void)publishEvents
{
  if (![self isStarted]) {
    [self stateBeginTest];
    [self publishWithEvent:
      EventDictionaryWithNameAndContent(kReporter_Events_BeginTest, @{
        kReporter_EndTest_TestKey:[self testName],
        kReporter_EndTest_ClassNameKey:_className,
        kReporter_EndTest_MethodNameKey:_methodName,
    })];
    if (!_outputToPublish.length) {
      [self appendOutput:@"Test did not run."];
    }
  }
  if (![self isFinished]) {
    [self publishOutput];
    [self stateEndTest:NO result:@"error"];
    [self publishWithEvent:
      EventDictionaryWithNameAndContent(kReporter_Events_EndTest, @{
        kReporter_EndTest_TestKey:[self testName],
        kReporter_EndTest_ClassNameKey:_className,
        kReporter_EndTest_MethodNameKey:_methodName,
        kReporter_EndTest_SucceededKey:@(_isSuccessful),
        kReporter_EndTest_ResultKey:_result,
        kReporter_EndTest_TotalDurationKey:@(_duration),
        kReporter_EndTest_OutputKey:_outputAlreadyPublished,
    })];
  }
}

- (NSString *)outputAlreadyPublished
{
  return [_outputAlreadyPublished copy];
}

@end
