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

#ifdef __cplusplus
extern "C" {
#endif

NSDictionary *BuildSettingsFromOutput(NSString *output);
NSString *XCToolLibPath(void);
NSString *XCToolLibExecPath(void);
NSString *XCToolReportersPath(void);

/**
 Returns the path to XCODE_APP/Contents/Developer, as returned by
 xcode-select --print-path.
 */
NSString *XcodeDeveloperDirPath(void);

/**
 Like XcodeDeveloperDirPath(), but can optionally force a concrete task to
 be used.  This is useful if FakeTaskManager is active and swizzling
 all NSTasks.
 */
NSString *XcodeDeveloperDirPathViaForcedConcreteTask(BOOL forceConcreteTask);

NSString *MakeTempFileInDirectoryWithPrefix(NSString *directory, NSString *prefix);
NSString *MakeTempFileWithPrefix(NSString *prefix);

/**
 Returns a NSDictionary with a NSString to NSDictionary mapping of information
 to values for all available SDK types. Here is an example of what the output
 might look like:

 @{@"macosx10.8" : @{
                     @"SDK": "macosx10.8"
                     @"SDKVersion" : @"10.8",
                     @"ProductBuildVersion" : @"12F37",
                    },
   @"macosx"     : @{
                     @SDK": "macosx10.9"
                     @"SDKVersion" : @"10.9",
                     @"ProductBuildVersion" : @"12347",
                   }
  };

 @return NSDictionary mapping a NSString of the particular SDK to an
 NSDictionary containing label/value mappings that xcodebuild -sdk -version
 returned for that environment (e.g. "SDKVersion", "Path",
 "ProductBuildVersion"); also adds a mapping of "SDK" to the sdk version
 (e.g. "macosx10.9") for lookup purposes.
 */
NSDictionary *GetAvailableSDKsInfo();

/**
 Returns a NSDictionary with a NSString to NSString mapping of what SDKs are
 available for a particular environment as reported by xcodebuild -sdk -version.
 In addition to mapping the version for a specific SDK (e.g. "macosx10.8" =>
 "macosx10.8"), it also maps the latest version of an SDK family that's
 available (e.g. if macosx10.8 and macosx10.9 are both available, "macosx" will
 map to "macos10.9" since it is the most recent version).

 @return NSDictionary mapping a NSString of either a specific SDK or an
 SDK family to an NSString representing the appropriate SDK. Note that this
 mapping is the same as if we we grabbed the appropriate dictionary from the
 GetAvailableSDKsInfo return value and looked at the "SDK" mapping
 (i.e. GetAvailableSDKsInfo()[whichSDK][@"SDK"] ==
       GetAvailableSDKsAndAliases()[whichSDK])
 */
NSDictionary *GetAvailableSDKsAndAliases();
NSDictionary *GetAvailableSDKsAndAliasesWithSDKInfo(NSDictionary *sdkInfo);

/**
 Returns YES if runing on Travis or TeamCity
 */
BOOL IsRunningOnCISystem();

BOOL IsRunningUnderTest();

/**
 Returns the Xcode version, as read from DTXCode in:
 /Applications/Xcode.app/Contents/Info.plist

 Version will be @"0600" for Xcode 6.0, @"0500" for Xcode 5.0, @"0501" for Xcode 5.0.1, or @"0460" for Xcode 4.6.

 @return NSString Xcode version
 */
NSString *XcodebuildVersion();

/**
 Returns YES if we're running with Xcode 7 or better.
 */
BOOL ToolchainIsXcode7OrBetter(void);

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
 This method returns the command line arguments contained in an
 argument string. It splits the string into arguments at spaces which are not contained
 in unescaped quotes
 It treats quotes and escaped quotes like Xcode does when it runs
 a test executable. (The escape character is the backslash.)
 */
NSArray *ParseArgumentsFromArgumentString(NSString *string);

/**
 This method returns the dictonary with key/values specified in destination string.

 If it fails, errorMessage will be populated.
 */
NSDictionary *ParseDestinationString(NSString *destinationString, NSString **errorMessage);

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
 Returns the absolute path to the current executable, with sym links resolved.
 */
NSString *AbsoluteExecutablePath();

/**
 * Returns the contents of `/etc/paths` in the form of `path1:path2:path3`.
 */
NSString *SystemPaths();

/**
 * Returns absolute paths to directories with iOS test frameworks in the form of `path1:path2:path3`.
 */
NSString *IOSTestFrameworkDirectories();

/**
 * Returns absolute paths to directories with OS X test frameworks in the form of `path1:path2:path3`.
 */
NSString *OSXTestFrameworkDirectories();

/**
 * Returns common environment required to query and run iOS tests.
 */
NSMutableDictionary *IOSTestEnvironment(NSDictionary *buildSettings);

/**
 * Returns common environment required to query and run OS X tests.
 */
NSMutableDictionary *OSXTestEnvironment(NSDictionary *buildSettings);

/**
 * Returns common environment required to query and run TV OS tests.
 */
NSMutableDictionary *TVOSTestEnvironment(NSDictionary *buildSettings);

/**
 * Creates a temporary directory under NSTemporaryDirectory() using mkdtemp,
 * and returns the path.
 */
NSString *MakeTemporaryDirectory(NSString *nameTemplate);

/**
 * Returns YES if the build settings indicate this is an application test.
 * i.e. we have a TEST_HOST, and that TEST_HOST refers to an executable.
 */
BOOL TestableSettingsIndicatesApplicationTest(NSDictionary *settings);

/**
 * Returns path to the latest xcodebuild crash report or nil.
 */
NSString *LatestXcodebuildCrashReportPath();

/**
 * Returns SHA1 for provided string.
 */
NSString *HashForString(NSString *string);

/**
 * Looks into bundle's executable architectures and returns:
 *  - `CPU_TYPE_X86_64` if only x86_64 is supported,
 *  - `CPU_TYPE_I386` if only i386 is supported,
 *  - `CPU_TYPE_ANY` if both x86_64 and i386 are supported;
 * or crashes if none of the above applies to bundle's executable.
 */
cpu_type_t CpuTypeForTestBundleAtPath(NSString *testBundlePath);

/**
 * Returns test host path specified in build settings or nil.
 */
NSString *TestHostPathForBuildSettings(NSDictionary *buildSettings);

/**
 * Returns product bundle path specified in build settings.
 */
NSString *ProductBundlePathForBuildSettings(NSDictionary *buildSettings);


#ifdef __cplusplus
}
#endif

