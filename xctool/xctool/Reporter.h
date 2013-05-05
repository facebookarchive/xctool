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

#define kReporter_Events_BeginAction @"begin-action"
#define kReporter_Events_EndAction @"end-action"
#define kReporter_Events_BeginOCUnit @"begin-ocunit"
#define kReporter_Events_EndOCUnit @"end-ocunit"
#define kReporter_Events_BeginTestSuite @"begin-test-suite"
#define kReporter_Events_EndTestSuite @"end-test-suite"
#define kReporter_Events_BeginTest @"begin-test"
#define kReporter_Events_EndTest @"end-test"
#define kReporter_Events_TestOuput @"test-output"
#define kReporter_Events_BeginXcodebuild @"begin-xcodebuild"
#define kReporter_Events_EndXcodebuild @"end-xcodebuild"
#define kReporter_Events_BeginBuildCommand @"begin-build-command"
#define kReporter_Events_EndBuildCommand @"end-build-command"
#define kReporter_Events_BeginBuildTarget @"begin-build-target"
#define kReporter_Events_EndBuildTarget @"end-build-target"
#define kReporter_Events_Message @"message"

#define kReporter_BeginAction_NameKey @"name"

#define kReporter_EndAction_NameKey @"name"
#define kReporter_EndAction_SucceededKey @"succeeded"
#define kReporter_EndAction_DurationKey @"duration"

#define kReporter_BeginOCUnit_BundleNameKey @"bundleName"
#define kReporter_BeginOCUnit_SDKNameKey @"sdkName"
#define kReporter_BeginOCUnit_TestTypeKey @"testType"
#define kReporter_BeginOCUnit_GCEnabledKey @"gcEnabled"

#define kReporter_EndOCUnit_BundleNameKey @"bundleName"
#define kReporter_EndOCUnit_SDKNameKey @"sdkName"
#define kReporter_EndOCUnit_TestTypeKey @"testType"
#define kReporter_EndOCUnit_SucceededKey @"succeeded"
#define kReporter_EndOCUnit_FailureReasonKey @"failureReason"

#define kReporter_BeginTestSuite_SuiteKey @"suite"

#define kReporter_EndTestSuite_SuiteKey @"suite"
#define kReporter_EndTestSuite_TestCaseCountKey @"testCaseCount"
#define kReporter_EndTestSuite_TotalFailureCountKey @"totalFailureCount"
#define kReporter_EndTestSuite_UnexpectedExceptionCountKey @"unexpectedExceptionCount"
#define kReporter_EndTestSuite_TestDurationKey @"testDuration"
#define kReporter_EndTestSuite_TotalDurationKey @"totalDuration"

#define kReporter_BeginTest_TestKey @"test"
#define kReporter_BeginTest_ClassNameKey @"className"
#define kReporter_BeginTest_MethodNameKey @"methodName"

#define kReporter_EndTest_TestKey @"test"
#define kReporter_EndTest_ClassNameKey @"className"
#define kReporter_EndTest_MethodNameKey @"methodName"
#define kReporter_EndTest_SucceededKey @"succeeded"
#define kReporter_EndTest_TotalDurationKey @"totalDuration"
#define kReporter_EndTest_OutputKey @"output"
#define kReporter_EndTest_ExceptionKey @"exception"
#define kReporter_EndTest_Exception_FilePathInProjectKey @"filePathInProject"
#define kReporter_EndTest_Exception_LineNumberKey @"lineNumber"
#define kReporter_EndTest_Exception_ReasonKey @"reason"
#define kReporter_EndTest_Exception_NameKey @"name"

#define kReporter_TestOutput_OutputKey @"output"

#define kReporter_BeginBuildCommand_TitleKey @"title"
#define kReporter_BeginBuildCommand_CommandKey @"command"

#define kReporter_EndBuildCommand_TitleKey @"title"
#define kReporter_EndBuildCommand_SucceededKey @"succeeded"
#define kReporter_EndBuildCommand_EmittedOutputTextKey @"emittedOutputText"
#define kReporter_EndBuildCommand_DurationKey @"duration"

#define kReporter_BeginBuildTarget_ProjectKey @"project"
#define kReporter_BeginBuildTarget_TargetKey @"target"
#define kReporter_BeginBuildTarget_ConfigurationKey @"configuration"

#define kReporter_EndBuildTarget_ProjectKey @"project"
#define kReporter_EndBuildTarget_TargetKey @"target"
#define kReporter_EndBuildTarget_ConfigurationKey @"configuration"

#define kReporter_BeginXcodebuild_CommandKey @"command"
#define kReporter_BeginXcodebuild_TitleKey @"command"

#define kReporter_EndXcodebuild_CommandKey @"command"
#define kReporter_EndXcodebuild_TitleKey @"command"

#define kReporter_Message_MessageKey @"message"
#define kReporter_Message_TimestampKey @"timestamp"
#define kReporter_Message_LevelKey @"level"

@class Action;
@class Options;

typedef enum {
  REPORTER_MESSAGE_DEBUG,
  REPORTER_MESSAGE_VERBOSE,
  REPORTER_MESSAGE_INFO,
  REPORTER_MESSAGE_WARNING,
  REPORTER_MESSAGE_ERROR,
} ReporterMessageLevel;

NSString *ReporterMessageLevelToString(ReporterMessageLevel level);

void RegisterReporters(NSArray *reporters);
void UnregisterReporters(NSArray *reporters);

void ReportMessage(ReporterMessageLevel level, NSString *format, ...) NS_FORMAT_FUNCTION(2, 3);

@interface Reporter : NSObject
{
  NSFileHandle *_outputHandle;
}

+ (Reporter *)reporterWithName:(NSString *)name outputPath:(NSString *)outputPath options:(Options *)options;

// The reporter will stream output to here.  Usually this will be "-" to route
// to standard out, but it might point to a file if the -reporter param
// specified an output path.
@property (nonatomic, retain) NSString *outputPath;
@property (nonatomic, readonly) NSFileHandle *outputHandle;
@property (nonatomic, retain) Options *options;

- (void)handleEvent:(NSDictionary *)event;

- (void)beginAction:(NSDictionary *)event;
- (void)endAction:(NSDictionary *)event;
- (void)beginBuildTarget:(NSDictionary *)event;
- (void)endBuildTarget:(NSDictionary *)event;
- (void)beginBuildCommand:(NSDictionary *)event;
- (void)endBuildCommand:(NSDictionary *)event;
- (void)beginXcodebuild:(NSDictionary *)event;
- (void)endXcodebuild:(NSDictionary *)event;
- (void)beginOcunit:(NSDictionary *)event;
- (void)endOcunit:(NSDictionary *)event;
- (void)beginTestSuite:(NSDictionary *)event;
- (void)endTestSuite:(NSDictionary *)event;
- (void)beginTest:(NSDictionary *)event;
- (void)endTest:(NSDictionary *)event;
- (void)testOutput:(NSDictionary *)event;
- (void)message:(NSDictionary *)event;

/**
 To be called before any action is run.
 */
- (BOOL)openWithStandardOutput:(NSFileHandle *)standardOutput error:(NSString **)error;

/**
 To be called just before xctool exits.
 */
- (void)close;

@end
