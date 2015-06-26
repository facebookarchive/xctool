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

#import <Foundation/Foundation.h>

@class NSConcreteTask, SimulatorInfo;

/**
 * Launchs a task, waits for exit, and returns a dictionary like
 * { @"stdout": "...", @"stderr": "..." }
 */
NSDictionary *LaunchTaskAndCaptureOutput(NSTask *task, NSString *description);

/**
 * Launches a task, waits for exit, and returns a string of the combined
 * STDOUT and STDERR output.
 */
NSString *LaunchTaskAndCaptureOutputInCombinedStream(NSTask *task, NSString *description);

/**
 * Launchs a task, waits for exit, and feeds lines from standard out to a block.
 */
void LaunchTaskAndFeedOuputLinesToBlock(NSTask *task, NSString *description, void (^block)(NSString *));

/**
 * Returns an NSTask that is configured NOT to start a new process group.  This
 * way, the child will be killed if the parent is killed (or interrupted).  This
 * is what we want all the time.
 *
 * @return Task with a retain count of 1.
 */
NSTask *CreateTaskInSameProcessGroup();

NSTask *CreateConcreteTaskInSameProcessGroup();

/**
 * Call CreateTaskInSameProcessGroup() and set the task's preferred architecture.
 *
 * @param arch The preferred architecture for the task returned.
 *
 * @return Task with a retain count of 1 and architecture of CPU_TYPE_I386.
 */
NSTask *CreateTaskInSameProcessGroupWithArch(cpu_type_t arch);

/**
 * Launches task.  Optionally, if the '-showTasks' argument was passed on
 * the command-line, the command-line equivalent for the given task is logged
 * to STDERR.
 *
 * @param task Task to launch.
 * @param description A short description of the task's purpose.
 */
void LaunchTaskAndMaybeLogCommand(NSTask *task, NSString *description);

/**
 * Returns an NSTask that will launch an iOS simulator binary via the
 * iPhoneSimulator.platform/usr/bin/sim launcher.
 */
NSTask *CreateTaskForSimulatorExecutable(NSString *sdkName,
                                         SimulatorInfo *simulatorInfo,
                                         NSString *launchPath,
                                         NSArray *arguments,
                                         NSDictionary *environment);


/**
 * Returns a command-line expression which includes the environment, launch
 * path, and args to reproduce a given task.
 */
NSString *CommandLineEquivalentForTask(NSConcreteTask *task);
