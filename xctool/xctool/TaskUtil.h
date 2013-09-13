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

/**
 * Launchs a task, waits for exit, and returns a dictionary like
 * { @"stdout": "...", @"stderr": "..." }
 */
NSDictionary *LaunchTaskAndCaptureOutput(NSTask *task);

/**
 * Launchs a task, waits for exit, and feeds lines from standard out to a block.
 */
void LaunchTaskAndFeedOuputLinesToBlock(NSTask *task, void (^block)(NSString *));

/**
 * Returns an NSTask that is configured NOT to start a new process group.  This
 * way, the child will be killed if the parent is killed (or interrupted).  This
 * is what we want all the time.
 *
 * @return Task with a retain count of 1.
 */
NSTask *CreateTaskInSameProcessGroup();