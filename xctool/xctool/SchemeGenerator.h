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

/*!
 Generate temporary workspace and scheme for feeding to xcodebuild.
 */
@interface SchemeGenerator : NSObject

@property (nonatomic, assign) BOOL parallelizeBuildables;
@property (nonatomic, assign) BOOL buildImplicitDependencies;

+ (SchemeGenerator *)schemeGenerator;

- (void)addBuildableWithID:(NSString *)identifier
                 inProject:(NSString *)projectPath;

- (void)addProjectPathToWorkspace:(NSString *)projectPath;

/// Write the workspace into this directory.
- (BOOL)writeWorkspaceNamed:(NSString *)name
                         to:(NSString *)destination;

/// Write the workspace into a temporary directory.
/// Returns the path to the xcworkspace directory.
- (NSString *)writeWorkspaceNamed:(NSString *)name;

@end
