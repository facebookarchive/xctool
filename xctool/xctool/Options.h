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

#import "Action.h"

/**
 * Options is a special case of Action.  It's an action that accepts its own params
 * (defined via +[Action options]), but also is the parent of other Actions's.  The
 * params it accepts are all the common params that xcodebuild would accept.
 */
@interface Options : Action

+ (NSArray *)actionClasses;

@property (nonatomic, copy) NSString *workspace;
@property (nonatomic, copy) NSString *project;
@property (nonatomic, copy) NSString *scheme;
@property (nonatomic, copy) NSString *configuration;
@property (nonatomic, copy) NSString *sdk;
@property (nonatomic, copy) NSString *sdkPath;
@property (nonatomic, copy) NSString *platformPath;
@property (nonatomic, copy) NSString *arch;
@property (nonatomic, copy) NSString *destination;
@property (nonatomic, copy) NSString *destinationTimeout;
@property (nonatomic, copy) NSString *toolchain;
@property (nonatomic, copy) NSString *xcconfig;
@property (nonatomic, copy) NSString *jobs;
@property (nonatomic, copy) NSString *findTarget;
@property (nonatomic, copy) NSString *findTargetPath;
@property (nonatomic, copy) NSString *findProjectPath;
@property (nonatomic, copy) NSString *resultBundlePath;
@property (nonatomic, copy) NSString *derivedDataPath;
@property (nonatomic, copy) NSArray *findTargetExcludePaths;
@property (nonatomic, copy) NSString *launchTimeout;

@property (nonatomic, assign) BOOL showBuildSettings;
@property (nonatomic, assign) BOOL showTasks;
@property (nonatomic, assign) BOOL actionScripts;

@property (nonatomic, strong) NSMutableDictionary *buildSettings;
@property (nonatomic, strong) NSMutableDictionary *userDefaults;
@property (nonatomic, strong) NSMutableArray *reporters;

@property (nonatomic, assign) BOOL showHelp;
@property (nonatomic, assign) BOOL showVersion;

@property (nonatomic, strong) NSMutableArray *actions;

/**
 Returns the command-line arguments that were passed to xctool, and which should
 carry through to the xcodebuild commands that xctool spawns.

 'spawnAction' should be one of LaunchAction, TestAction, ArchiveAction,
 AnalyzeAction, or ProfileAction.
 */
- (NSArray *)commonXcodeBuildArgumentsForSchemeAction:(NSString *)schemeAction
                                     xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo;

/**
 Returns the configuration name taking into account of passed in -configuration
 param.

 @return Configuration name like 'Debug' or 'Release'. May return nil if
         '-configuration' is not specified on the command line and
         `schemeAction` or `xcodeSubjectInfo` is nil.
 */
- (NSString *)effectiveConfigurationForSchemeAction:(NSString *)schemeAction
                                   xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo;

- (NSArray *)xcodeBuildArgumentsForSubject;

/**
 Validates and creates the list of internal Reporter objects.
 */
- (BOOL)validateReporterOptions:(NSString **)errorMessage;

/**
 Validates all of the provided top-level options and runs validate for each of
 the specified actions.

 @param XcodeSubjectInfo Out parameter used to return the created XcodeSubjectInfo
   instance.
 @param string Out parameter that will contain an error message if validation fails.
 @return YES if validation succeeded.
 */
- (BOOL)validateAndReturnXcodeSubjectInfo:(XcodeSubjectInfo **)xcodeSubjectInfo
                             errorMessage:(NSString **)errorMessage;

@end
