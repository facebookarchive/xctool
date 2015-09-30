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
#define kReporter_TimestampKey @"timestamp"

#define kReporter_Event_Key @"event"

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
#define kReporter_Events_BeginStatus @"begin-status"
#define kReporter_Events_EndStatus @"end-status"
#define kReporter_Events_AnalyzerResult @"analyzer-result"
#define kReporter_Events_OutputBeforeTestBundleStarts @"output-before-test-bundle-starts"
#define kReporter_Events_SimulatorOuput @"simulator-output"

#define kReporter_BeginAction_NameKey @"name"
#define kReporter_BeginAction_WorkspaceKey @"workspace"
#define kReporter_BeginAction_ProjectKey @"project"
#define kReporter_BeginAction_SchemeKey @"scheme"

#define kReporter_EndAction_NameKey @"name"
#define kReporter_EndAction_WorkspaceKey @"workspace"
#define kReporter_EndAction_ProjectKey @"project"
#define kReporter_EndAction_SchemeKey @"scheme"
#define kReporter_EndAction_SucceededKey @"succeeded"
#define kReporter_EndAction_DurationKey @"duration"

#define kReporter_BeginOCUnit_BundleNameKey @"bundleName"
#define kReporter_BeginOCUnit_SDKNameKey @"sdkName"
#define kReporter_BeginOCUnit_DeviceNameKey @"deviceName"
#define kReporter_BeginOCUnit_TestTypeKey @"testType"
#define kReporter_BeginOCUnit_TargetNameKey @"targetName"

#define kReporter_EndOCUnit_BundleNameKey @"bundleName"
#define kReporter_EndOCUnit_SDKNameKey @"sdkName"
#define kReporter_EndOCUnit_TestTypeKey @"testType"
#define kReporter_EndOCUnit_SucceededKey @"succeeded"
#define kReporter_EndOCUnit_MessageKey @"message"

#define kReporter_TestSuite_TopLevelSuiteName @"Toplevel Test Suite"

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
#define kReporter_EndTest_ResultKey @"result"
#define kReporter_EndTest_TotalDurationKey @"totalDuration"
#define kReporter_EndTest_OutputKey @"output"
#define kReporter_EndTest_ExceptionsKey @"exceptions"
#define kReporter_EndTest_Exception_FilePathInProjectKey @"filePathInProject"
#define kReporter_EndTest_Exception_LineNumberKey @"lineNumber"
#define kReporter_EndTest_Exception_ReasonKey @"reason"

#define kReporter_TestOutput_OutputKey @"output"

#define kReporter_BeginBuildCommand_TitleKey @"title"
#define kReporter_BeginBuildCommand_CommandKey @"command"

#define kReporter_EndBuildCommand_TitleKey @"title"
#define kReporter_EndBuildCommand_SucceededKey @"succeeded"
#define kReporter_EndBuildCommand_EmittedOutputTextKey @"emittedOutputText"
#define kReporter_EndBuildCommand_DurationKey @"duration"
#define kReporter_EndBuildCommand_ResultCode @"resultCode"
#define kReporter_EndBuildCommand_TotalNumberOfWarnings @"totalNumberOfWarnings"
#define kReporter_EndBuildCommand_TotalNumberOfErrors @"totalNumberOfErrors"

#define kReporter_BeginBuildTarget_ProjectKey @"project"
#define kReporter_BeginBuildTarget_TargetKey @"target"
#define kReporter_BeginBuildTarget_ConfigurationKey @"configuration"

#define kReporter_EndBuildTarget_ProjectKey @"project"
#define kReporter_EndBuildTarget_TargetKey @"target"
#define kReporter_EndBuildTarget_ConfigurationKey @"configuration"

#define kReporter_BeginXcodebuild_CommandKey @"command"
#define kReporter_BeginXcodebuild_TitleKey @"title"

#define kReporter_EndXcodebuild_CommandKey @"command"
#define kReporter_EndXcodebuild_TitleKey @"title"
#define kReporter_EndXcodebuild_SucceededKey @"succeeded"
#define kReporter_EndXcodebuild_ErrorMessageKey @"errorMessage"
#define kReporter_EndXcodebuild_ErrorCodeKey @"errorCode"

#define kReporter_BeginStatus_MessageKey @"message"
#define kReporter_BeginStatus_LevelKey @"level"

#define kReporter_EndStatus_MessageKey @"message"
#define kReporter_EndStatus_LevelKey @"level"

#define kReporter_AnalyzerResult_ProjectKey @"project"
#define kReporter_AnalyzerResult_TargetKey @"target"
#define kReporter_AnalyzerResult_FileKey @"file"
#define kReporter_AnalyzerResult_LineKey @"line"
#define kReporter_AnalyzerResult_ColumnKey @"col"
#define kReporter_AnalyzerResult_DescriptionKey @"description"
#define kReporter_AnalyzerResult_ContextKey @"context"
#define kReporter_AnalyzerResult_CategoryKey @"category"
#define kReporter_AnalyzerResult_TypeKey @"type"

#define kReporter_OutputBeforeTestBundleStarts_OutputKey @"output"

#define kReporter_SimulatorOutput_OutputKey @"output"
