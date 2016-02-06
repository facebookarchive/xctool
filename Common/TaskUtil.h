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

typedef void (^FdOutputLineFeedBlock)(int fd, NSString *);
typedef void (^BlockToRunWhileReading)(void);

NSString *StripAnsi(NSString *inputString);
NSString *StringFromDispatchDataWithBrokenUTF8Encoding(const char *dataPtr, size_t dataSz);

/**
 *  Returns array of NSString's with contents read from fildes.
 *
 *  @param fildes                  Array of file descriptors from where to read.
 *  @param sz                      Size of the `fildes` array.
 *  @param block                   Callback block which will be called when new
 *                                 line is read from any of the fd. Optional.
 *  @param blockDispatchQueue      Queue on which `block` will be dispatched.
 *                                 Optional.
 *  @param blockToRunWhileReading  Block which will be executed on the current
 *                                 thread after fd are prepared to be read from.
 *                                 Once block execution is completed reading
 *                                 from fds will be interrupted and function will
 *                                 return unless `waitUntilFdsAreClosed` is `YES`.
 *  @param waitUntilFdsAreClosed   If `NO` then function will block current thread
 *                                 until all fds are closed. Otherwise, read above.
 *
 *  @discussion
 *  If `block` is provided then function dynamically and asynchronously feeds lines
 *  to a block on the provided queue. Ensure that provided queue is serial otherwise
 *  order of lines could be wrong. If not queue is provided then block is invoked on
 *  the background queue.
 */
void ReadOutputsAndFeedOuputLinesToBlockOnQueue(
  int * const fildes,
  const int sz,
  FdOutputLineFeedBlock block,
  dispatch_queue_t blockDispatchQueue,
  BlockToRunWhileReading blockToRunWhileReading,
  BOOL waitUntilFdsAreClosed
);

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
void LaunchTaskAndFeedOuputLinesToBlock(NSTask *task, NSString *description, FdOutputLineFeedBlock block);

/**
 * Launchs a task, waits for exit, and feeds lines from stdout and stderr to a block as simulator output events
 * and forwards all otest-shim events directly to a feed block.
 */
void LaunchTaskAndFeedSimulatorOutputAndOtestShimEventsToBlock(NSTask *task, NSString *description, NSString *otestShimOutputFilePath, FdOutputLineFeedBlock block);

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
 * Returns a command-line expression which includes the environment, launch
 * path, and args to reproduce a given task.
 */
NSString *CommandLineEquivalentForTask(NSConcreteTask *task);

/**
 * Strips ANSI escape codes from a string passed to it.
 */
NSString *StripAnsi(NSString *inputString);
