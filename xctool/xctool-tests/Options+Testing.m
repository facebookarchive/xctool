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

#import "Options+Testing.h"

#import "FakeTask.h"
#import "FakeTaskManager.h"
#import "LaunchHandlers.h"
#import "ReporterTask.h"
#import "XCToolUtil.h"
#import "XcodeSubjectInfo.h"

@implementation Options (Testing)

+ (Options *)optionsFrom:(NSArray *)arguments
{
  Options *options = [[Options alloc] init];

  NSString *errorMessage = nil;
  [options consumeArguments:[NSMutableArray arrayWithArray:arguments]
               errorMessage:&errorMessage];

  if (errorMessage != nil) {
    [NSException raise:NSGenericException
                format:@"Failed to parse options: %@", errorMessage];
  }

  return options;
}

- (Options *)assertReporterOptionsValidate
{
  NSString *errorMessage = nil;
  BOOL valid = [self validateReporterOptions:&errorMessage];

  if (!valid) {
    [NSException raise:NSGenericException
                format:@"Failed to validate reporter options: %@", errorMessage];
  }

  return self;
}

- (void)assertReporterOptionsFailToValidateWithError:(NSString *)message
{
  NSString *errorMessage = nil;
  BOOL valid = [self validateReporterOptions:&errorMessage];

  if (valid) {
    [NSException raise:NSGenericException
                format:@"Expected reporter validation to failed, but passed."];
  } else if (!valid && ![message isEqualToString:errorMessage]) {
    [NSException raise:NSGenericException
                format:
     @"Expected reporter validation to fail with message '%@' but "
     @"instead failed with '%@'", message, errorMessage];
  }
}


- (void)assertOptionsFailToValidateWithError:(NSString *)message
{
  NSString *errorMessage = nil;
  XcodeSubjectInfo *xcodeSubjectInfo;
  BOOL valid = [self validateAndReturnXcodeSubjectInfo:&xcodeSubjectInfo
                                          errorMessage:&errorMessage];

  if (valid) {
    [NSException raise:NSGenericException
                format:@"Expected validation to failed, but passed."];
  } else if (!valid && ![message isEqualToString:errorMessage]) {
    [NSException raise:NSGenericException
                format:
     @"Expected validation to fail with message '%@' but instead failed "
     @"with '%@'", message, errorMessage];
  }
}

- (void)evaluateOptionsWithBuildSettingsFromFile:(NSString *)path
                                           valid:(BOOL *)validOut
                                           error:(NSString **)errorOut
{
  NSString *contents = [NSString stringWithContentsOfFile:path
                                                 encoding:NSUTF8StringEncoding
                                                    error:nil];
  if (contents == nil) {
    [NSException raise:NSGenericException
                format:@"Failed to read file from: %@", path];
  }

  for (ReporterTask *task in self.reporters) {
    NSString *openError = nil;
    [task openWithStandardOutput:[NSFileHandle fileHandleWithNullDevice]
                   standardError:[NSFileHandle fileHandleWithNullDevice]
                           error:&openError];
    NSAssert(openError == nil, @"Got error while opening reporter task for reporter '%@': %@", task.reporterPath, openError);
  }

  __block XcodeSubjectInfo *subjectInfo = nil;
  __block NSString *error = nil;
  __block BOOL valid = NO;

  [[FakeTaskManager sharedManager] runBlockWithFakeTasks:^{
    [[FakeTaskManager sharedManager] addLaunchHandlerBlocks:@[
     [^(FakeTask *task){
      if ([[task launchPath] hasSuffix:@"xcodebuild"] &&
          [[task arguments] containsObject:@"-showBuildSettings"]) {
        [task pretendTaskReturnsStandardOutput:contents];
      }
    } copy],
     ]];

    valid = [self validateAndReturnXcodeSubjectInfo:&subjectInfo
                                       errorMessage:&error];
  }];

  for (ReporterTask *task in self.reporters) {
    [task close];
  }

  *validOut = valid;
  *errorOut = error;
}

- (void)assertOptionsFailToValidateWithError:(NSString *)message
                   withBuildSettingsFromFile:(NSString *)path
{
  NSString *errorMessage = nil;
  BOOL valid = NO;

  [self evaluateOptionsWithBuildSettingsFromFile:path
                                           valid:&valid
                                           error:&errorMessage];

  if (valid) {
    [NSException raise:NSGenericException
                format:@"Expected validation to failed, but passed."];
  } else if (!valid && ![message isEqualToString:errorMessage]) {
    [NSException raise:NSGenericException
                format:
     @"Expected validation to fail with message '%@' but instead "
     @"failed with '%@'", message, errorMessage];
  }
}

- (Options *)assertOptionsValidateWithBuildSettingsFromFile:(NSString *)path
{
  [self assertReporterOptionsValidate];

  NSString *errorMessage = nil;
  BOOL valid = NO;

  [self evaluateOptionsWithBuildSettingsFromFile:path
                                           valid:&valid
                                           error:&errorMessage];

  if (!valid) {
    [NSException raise:NSGenericException
                format:
     @"Expected validation to pass but failed with message '%@'", errorMessage];
  }

  return self;
}

- (Options *)assertOptionsValidate
{
  NSString *errorMessage = nil;
  XcodeSubjectInfo *xcodeSubjectInfo = [[XcodeSubjectInfo alloc] init];
  BOOL valid = [self validateAndReturnXcodeSubjectInfo:&xcodeSubjectInfo
                                          errorMessage:&errorMessage];

  if (!valid) {
    [NSException raise:NSGenericException
                format:
     @"Expected validation to pass but failed with message '%@'", errorMessage];
  }

  return self;
}

@end
