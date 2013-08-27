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

NSDictionary *BuildSettingsFromOutput(NSString *output);
NSString *XCToolLibPath(void);
NSString *XCToolLibExecPath(void);
NSString *XCToolReportersPath(void);
NSString *XcodeDeveloperDirPath(void);
NSString *MakeTempFileWithPrefix(NSString *prefix);
NSDictionary *GetAvailableSDKsAndAliases();
BOOL IsRunningUnderTest();

/**
 Launches a task that will invoke xcodebuild.  It will automatically feed
 build events to the provided reporters.

 Returns YES if xcodebuild succeeded.  If it fails, errorMessage and errorCode
 will be populated.
 */
BOOL LaunchXcodebuildTaskAndFeedEventsToReporters(NSTask *task,
                                                  NSArray *reporters,
                                                  NSString **errorMessage,
                                                  long long *errorCode);

/**
 Sends a 'begin-xcodebuild' event, runs xcodebuild, then sends an
 'end-xcodebuild' event.
 */
BOOL RunXcodebuildAndFeedEventsToReporters(NSArray *arguments,
                                           NSString *command,
                                           NSString *title,
                                           NSArray *reporters);

/**
 Finds an occurrence of '-someoption', 'somevalue' in an argument list and
 replaces 'somevalue' with a new value.

 If the option was never present in the argument list, it gets added to the end.
 */
NSArray *ArgumentListByOverriding(NSArray *arguments,
                                  NSString *option,
                                  NSString *optionValue);

/**
 Returns a temporary directory to be used during the current running action
 (i.e. build, or test).  As soon as the action completes, the temporary
 dir is cleaned up.
 */
NSString *TemporaryDirectoryForAction();

/**
 Cleans up any temporary directory that was created earlier with
 `TemporaryDirectoryForRun()`.
 */
void CleanupTemporaryDirectoryForAction();

/**
 Publish event to a list of reporters.

 @param array Array of reporters.
 @param dict Event dictionary.
 */
void PublishEventToReporters(NSArray *reporters, NSDictionary *event);

/**
 @return array A list of available reporter executables in the reporters
  directory.
 */
NSArray *AvailableReporters();

/**
 Uses realpath() to resolve an relative path.
 */
NSString *AbsolutePathFromRelative(NSString *path);

/**
 * Returns the contents of `/etc/paths` in the form of `path1:path2:path3`.
 */
NSString *SystemPaths();
