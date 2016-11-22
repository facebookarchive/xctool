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

  // specify a path where to write otest-query output
  NSString *outputPath = MakeTempFileWithPrefix(@"otest-query-output");
  NSMutableDictionary *taskEnvironment = [task.environment mutableCopy];
  if ([[task.launchPath lastPathComponent] isEqual:@"simctl"]) {
    taskEnvironment[@"SIMCTL_CHILD_OTEST_QUERY_OUTPUT_FILE"] = outputPath;
  } else {
    taskEnvironment[@"OTEST_QUERY_OUTPUT_FILE"] = outputPath;
  }
  task.environment = taskEnvironment;

  NSDictionary *output = LaunchTaskAndCaptureOutput(task, @"running otest-query");

  int terminationStatus = [task terminationStatus];
  task = nil;

  if (terminationStatus != 0) {
    *error = [NSString stringWithFormat:@"\nstdout:\n%@\nstderr:\n%@", output[@"stdout"], output[@"stderr"]];
    return nil;
  } else {
    NSData *data = [NSData dataWithContentsOfFile:outputPath];
    NSString *jsonOutput = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    NSError *parseError = nil;
    NSArray *list = [NSJSONSerialization JSONObjectWithData:[jsonOutput dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:0
                                                      error:&parseError];
    if (parseError) {

      // If the test bundle (or any frameworks loaded by the test bundle) write to stdout, the expected JSON will
      // be prepended with that output, causing an error. As a workaround, if we failed above, scan the output
      // for something that looks like a JSON array, and try again.

      // Note that we are assuming the test query binary returns a JSON array, not a JSON object.

      NSRange leftBracket = [jsonOutput rangeOfString:@"[\""];
      
      if (leftBracket.location != NSNotFound) {
        jsonOutput = [jsonOutput substringFromIndex:leftBracket.location];

        parseError = nil;
        list = [NSJSONSerialization JSONObjectWithData:[jsonOutput dataUsingEncoding:NSUTF8StringEncoding]
                                               options:0
                                                 error:&parseError];
      }
    }
    if (list) {
      return list;
    } else {
      *error = [NSString stringWithFormat:@"Error while parsing JSON: %@: %@.\nstdout:\n%@\nstderr:\n%@",
                [parseError localizedFailureReason],
                jsonOutput, output[@"stdout"], output[@"stderr"]];
      return nil;
    }
  }
}

@end
