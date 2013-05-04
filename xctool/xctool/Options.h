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

#import "Action.h"

/**
 * Options is a special case of Action.  It's an action that accepts its own params
 * (defined via +[Action options]), but also is the parent of other Actions's.  The
 * params it accepts are all the common params that xcodebuild would accept.
 */
@interface Options : Action
{
  NSMutableArray *_reporterOptions;
}

+ (NSArray *)actionClasses;

@property (nonatomic, retain) NSString *workspace;
@property (nonatomic, retain) NSString *project;
@property (nonatomic, retain) NSString *scheme;
@property (nonatomic, retain) NSString *configuration;
@property (nonatomic, retain) NSString *sdk;
@property (nonatomic, retain) NSString *arch;
@property (nonatomic, retain) NSString *toolchain;
@property (nonatomic, retain) NSString *xcconfig;
@property (nonatomic, retain) NSString *jobs;
@property (nonatomic, retain) NSString *findTarget;
@property (nonatomic, retain) NSString *findTargetPath;
@property (nonatomic, retain) NSArray *findTargetExcludePaths;

@property (nonatomic, assign) BOOL showBuildSettings;

@property (nonatomic, retain) NSMutableArray *buildSettings;
@property (nonatomic, retain) NSMutableArray *reporters;

@property (nonatomic, assign) BOOL showHelp;
@property (nonatomic, assign) BOOL showVersion;

@property (nonatomic, retain) NSMutableArray *actions;

- (NSArray *)commonXcodeBuildArgumentsIncludingSDK:(BOOL)includingSDK;
- (NSArray *)commonXcodeBuildArguments;
- (NSArray *)xcodeBuildArgumentsForSubject;
- (BOOL)validateReporterOptions:(NSString **)errorMessage;

@end
