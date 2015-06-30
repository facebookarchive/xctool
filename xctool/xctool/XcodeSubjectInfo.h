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

#import "ActionScripts.h"

@class Testable;
@class XcodeTargetMatch;

/**
 * XcodeSubjectInfo offers up info about the subject (either a workspace/scheme pair, or
 * project/scheme pair) being built or tested.
 */
@interface XcodeSubjectInfo : NSObject

@property (nonatomic, copy) NSString *subjectWorkspace;
@property (nonatomic, copy) NSString *subjectProject;
@property (nonatomic, copy) NSString *subjectScheme;
@property (nonatomic, copy) NSArray *subjectXcodeBuildArguments;

@property (nonatomic, copy) NSString *objRoot;
@property (nonatomic, copy) NSString *symRoot;
@property (nonatomic, copy) NSString *sharedPrecompsDir;
@property (nonatomic, copy) NSString *effectivePlatformName;
@property (nonatomic, copy) NSString *targetedDeviceFamily;
@property (nonatomic, copy) NSArray *testables;
@property (nonatomic, strong) ActionScripts *actionScripts;
@property (nonatomic, copy) NSDictionary *environmentForScripts;
// Everything in the scheme marked as Build for Test
@property (nonatomic, copy) NSArray *buildablesForTest;
@property (nonatomic, assign) BOOL parallelizeBuildables;
@property (nonatomic, assign) BOOL buildImplicitDependencies;

// buildables for Running or Testing
@property (nonatomic, copy) NSArray *buildables;

/**
 Load subject info for workspace/scheme or project/scheme.
 */
- (void)loadSubjectInfo;

/**
 * Returns the contents of 'testables' and 'buildablesForTest' with any
 * duplicates removed.
 */
- (NSArray *)testablesAndBuildablesForTest;

/**
 * Returns a list of paths to .xcodeproj directories in the workspace.
 */
+ (NSArray *)projectPathsInWorkspace:(NSString *)workspace;

/**
 * Returns a list of paths to .xcscheme files contained within the workspace itself and for
 * all projects in the workspace.
 */
+ (NSArray *)schemePathsInWorkspace:(NSString *)workspace;

/**
 * Returns a list of paths to .xcscheme files.  Container may be an xcodeproj or xcworkspace
 * directory since either may contain xcscheme files.
 */
+ (NSArray *)schemePathsInContainer:(NSString *)project;

/**
 * Returns a dictionary of info for each test target added to the Test
 * action of the scheme.
 */
+ (NSArray *)testablesInSchemePath:(NSString *)schemePath
                          basePath:(NSString *)basePath;

/**
 * Searches for the target in all the workspaces under the specified directory.
 * If found, returns YES and sets *bestTargetMatchOut appropriately.
 * Otherwise, returns NO.
 */
+ (BOOL)findTarget:(NSString *)target
       inDirectory:(NSString *)directory
      excludePaths:(NSArray *)excludePaths
   bestTargetMatch:(XcodeTargetMatch **)bestTargetMatchOut;

- (Testable *)testableWithTarget:(NSString *)target;

- (NSString *)configurationNameForAction:(NSString *)action;

@end
