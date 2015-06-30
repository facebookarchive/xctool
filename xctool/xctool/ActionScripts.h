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
#import "Options.h"

@interface ActionScriptInfo : NSObject
+ (instancetype)scriptInfoFromElement:(NSXMLElement *)node;
@end

@interface ActionScript : NSObject
+ (instancetype)actionFromDoc:(NSXMLDocument *)doc byName:(NSString *)name error:(NSError **)error;
+ (void)runScripts:(NSArray *)scripts options:(Options *)options environment:(NSDictionary *)env;
@end

/**
 * ActionScripts finds all pre and post actions scripts described in the active scheme.
 * The resulting object can then be used to execute the scripts.
 */
@interface ActionScripts : NSObject
/**
 * Init ActionScripts
 *
 *  @param schemePath path to the XML Scheme
 *  @param env        The shell environement that have been defined so far
 *
 *  @return nil on failure
 */
- (instancetype)initWithSchemePath:(NSString *)schemePath
                       environment:(NSDictionary *)env
                             error:(NSError **)error;
- (void)preBuildWithOptions:(Options *)options;
- (void)postBuildWithOptions:(Options *)options;
- (void)preRunWithOptions:(Options *)options;
- (void)postRunWithOptions:(Options *)options;
- (void)preTestWithOptions:(Options *)options;
- (void)postTestWithOptions:(Options *)options;
- (void)preProfileWithOptions:(Options *)options;
- (void)postProfileWithOptions:(Options *)options;
- (void)preAnalyzeWithOptions:(Options *)options;
- (void)postAnalyzeWithOptions:(Options *)options;
- (void)preArchiveWithOptions:(Options *)options;
- (void)postArchiveWithOptions:(Options *)options;
@end
