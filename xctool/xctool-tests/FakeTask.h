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

#import <Foundation/Foundation.h>

@interface FakeTask : NSTask
{
  NSString *_pretendStandardOutput;
  NSString *_pretendStandardError;
  int _pretendExitStatus;
  NSTaskTerminationReason _pretendTerminationReason;
}

@property (nonatomic, retain) NSString *currentDirectoryPath;
@property (nonatomic, retain) NSString *launchPath;
@property (nonatomic, retain) NSArray *arguments;
@property (nonatomic, retain) NSDictionary *environment;
@property (nonatomic, retain) id standardOutput;
@property (nonatomic, retain) id standardError;
@property (nonatomic, assign) int terminationStatus;
@property (nonatomic, assign) NSTaskTerminationReason terminationReason;
@property (nonatomic, assign) BOOL isRunning;

/**
 * If YES (default), this task will be included in the list of launched
 * tasks that's accessible from runWithFakeTasks:onTaskLaunch:.  We use this
 * to exclude tasks we don't care about interacting with during tests.
 */
@property (nonatomic, assign) BOOL includeInLaunchedTasks;

/**
 * When launched, pretend the task writes this str to stdout.
 */
- (void)pretendTaskReturnsStandardOutput:(NSString *)str;

/**
 * When launched, pretend the task writes this str to stderr.
 */
- (void)pretendTaskReturnsStandardError:(NSString *)str;

/**
 * When launched, pretend the task exits with this status.
 */
- (void)pretendExitStatusOf:(int)exitStatus;

- (void)pretendTerminationReason:(NSTaskTerminationReason)reason;

+ (NSTask *)fakeTaskWithExitStatus:(int)exitStatus
                 terminationReason:(NSTaskTerminationReason)reason
                standardOutputPath:(NSString *)standardOutputPath
                 standardErrorPath:(NSString *)standardErrorPath;

+ (NSTask *)fakeTaskWithExitStatus:(int)exitStatus;

@end
