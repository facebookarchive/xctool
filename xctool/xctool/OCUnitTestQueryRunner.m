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

#import "OCUnitTestQueryRunner.h"

#import "SimulatorInfo.h"
#import "TaskUtil.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"

@interface OCUnitTestQueryRunner ()
@property (nonatomic, copy) SimulatorInfo *simulatorInfo;
@end

@implementation OCUnitTestQueryRunner

// Designated initializer.
- (instancetype)initWithSimulatorInfo:(SimulatorInfo *)simulatorInfo
{
  if (self = [super init]) {
    _simulatorInfo = [simulatorInfo copy];
  }
  return self;
}

- (NSTask *)createTaskForQuery NS_RETURNS_RETAINED
{
  return nil;
}

- (void)prepareToRunQuery
{
}

- (NSArray *)runQueryWithError:(NSString **)error
{
  BOOL bundleIsDir = NO;
  BOOL bundleExists = [[NSFileManager defaultManager] fileExistsAtPath:[_simulatorInfo productBundlePath] isDirectory:&bundleIsDir];
  if (!IsRunningUnderTest() && !(bundleExists && bundleIsDir)) {
    *error = [NSString stringWithFormat:@"Test bundle not found at: %@", [_simulatorInfo productBundlePath]];
    return nil;
  }

  if ([_simulatorInfo testHostPath]) {
    if (![[NSFileManager defaultManager] isExecutableFileAtPath:[_simulatorInfo testHostPath]]) {
      *error = [NSString stringWithFormat:@"The test host executable is missing: '%@'", [_simulatorInfo testHostPath]];
      return nil;
    }
  }

  [self prepareToRunQuery];

  NSTask *task = [self createTaskForQuery];
  NSDictionary *output = LaunchTaskAndCaptureOutput(task, @"running otest-query");

  int terminationStatus = [task terminationStatus];
  task = nil;

  if (terminationStatus != 0) {
    *error = output[@"stderr"];
    return nil;
  } else {
    NSString *jsonOutput = output[@"stdout"];

    NSError *parseError = nil;
    NSArray *list = [NSJSONSerialization JSONObjectWithData:[jsonOutput dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:0
                                                      error:&parseError];
    if (list) {
      return list;
    } else {
      *error = [NSString stringWithFormat:@"Error while parsing JSON: %@: %@",
                [parseError localizedFailureReason],
                output];
      return nil;
    }
  }
}

@end
