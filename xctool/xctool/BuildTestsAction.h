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

#import "Action.h"

@interface BuildTestsAction : Action

@property (nonatomic, strong) NSMutableArray *onlyList;
@property (nonatomic, strong) NSMutableArray *omitList;
@property (nonatomic, assign) BOOL skipDependencies;

+ (BOOL)buildWorkspace:(NSString *)path
                scheme:(NSString *)scheme
             reporters:(NSArray *)reporters
               objRoot:(NSString *)objRoot
               symRoot:(NSString *)symRoot
     sharedPrecompsDir:(NSString *)sharedPrecompsDir
       derivedDataPath:(NSString *)derivedDataPath
        xcodeArguments:(NSArray *)xcodeArguments
          xcodeCommand:(NSString *)xcodeCommand;

+ (BOOL)buildTestables:(NSArray *)testables
               command:(NSString *)command
               options:(Options *)options
      xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo;

@end
