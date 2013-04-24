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

@class XcodeTargetMatch;

/**
 * XcodeSubjectInfo offers up info about the subject (either a workspace/scheme pair, or
 * project/scheme pair) being built or tested.
 */
@interface XcodeSubjectInfo : NSObject
{
  BOOL _didPopulate;
}

@property (nonatomic, retain) NSString *subjectWorkspace;
@property (nonatomic, retain) NSString *subjectProject;
@property (nonatomic, retain) NSString *subjectScheme;
@property (nonatomic, retain) NSArray *subjectXcodeBuildArguments;

@property (nonatomic, retain) NSString *sdkName;
@property (nonatomic, retain) NSString *objRoot;
@property (nonatomic, retain) NSString *symRoot;
@property (nonatomic, retain) NSString *sharedPrecompsDir;
@property (nonatomic, retain) NSString *configuration;
@property (nonatomic, retain) NSArray *testables;
// Everything in the scheme marked as Build for Test
@property (nonatomic, retain) NSArray *buildablesForTest;

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
 * Searches for the target in all the workspaces under the specified directory.
 * If found, returns YES and sets *bestTargetMatchOut appropriately.
 * Otherwise, returns NO.
 */
+ (BOOL)findTarget:(NSString *)target
       inDirectory:(NSString *)directory
      excludePaths:(NSArray *)excludePaths
   bestTargetMatch:(XcodeTargetMatch **)bestTargetMatchOut;

- (NSDictionary *)testableWithTarget:(NSString *)target;

@end
