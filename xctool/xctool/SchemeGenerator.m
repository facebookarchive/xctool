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

#import "SchemeGenerator.h"

#import "XCToolUtil.h"

@interface SchemeGenerator ()
@property (nonatomic, copy) NSMutableArray *buildables;
@property (nonatomic, copy) NSMutableSet *projectPaths;

@end

@implementation SchemeGenerator {
}

+ (SchemeGenerator *)schemeGenerator
{
  return [[SchemeGenerator alloc] init];
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _buildables = [[NSMutableArray alloc] init];
    _projectPaths = [[NSMutableSet alloc] init];
  }
  return self;
}


- (void)addBuildableWithID:(NSString *)identifier
                 inProject:(NSString *)projectPath
{
  NSString *absPath = [[[NSURL fileURLWithPath:projectPath] URLByStandardizingPath] path];
  [_buildables addObject:@{@"id":identifier, @"project":absPath}];
}

- (void)addProjectPathToWorkspace:(NSString *)projectPath
{
  NSString *absPath = [[[NSURL fileURLWithPath:projectPath] URLByStandardizingPath] path];
  [_projectPaths addObject:absPath];
}

- (NSString *)writeWorkspaceNamed:(NSString *)name
{
  NSString *tempDir = TemporaryDirectoryForAction();
  if ([self writeWorkspaceNamed:name to:tempDir]) {
    return [tempDir stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"xcworkspace"]];
  }

  return nil;
}

- (BOOL)writeWorkspaceNamed:(NSString *)name
                         to:(NSString *)destination
{
  void (^errorBlock)(NSError *) = ^(NSError *error){
    NSLog(@"Error creating temporary workspace: %@", error.localizedFailureReason);
  };
  NSError *err = nil;

  NSString *workspacePath = [destination stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"xcworkspace"]];

  NSFileManager *fileManager = [NSFileManager defaultManager];
  [fileManager createDirectoryAtPath:workspacePath
         withIntermediateDirectories:NO
                          attributes:@{}
                               error:&err];
  if (err) {
    errorBlock(err);
    return NO;
  }

  [[[self _workspaceDocument] XMLStringWithOptions:NSXMLNodePrettyPrint]
   writeToFile:[workspacePath stringByAppendingPathComponent:@"contents.xcworkspacedata"]
   atomically:NO
   encoding:NSUTF8StringEncoding
   error:&err];
  if (err) {
    errorBlock(err);
    return NO;
  }

  NSString * schemeDirPath = [workspacePath stringByAppendingPathComponent:@"xcshareddata/xcschemes"];
  [fileManager createDirectoryAtPath:schemeDirPath
         withIntermediateDirectories:YES
                          attributes:@{}
                               error:&err];
  if (err) {
    errorBlock(err);
    return NO;
  }

  NSString *schemePath = [schemeDirPath stringByAppendingPathComponent:
                          [name stringByAppendingPathExtension:@"xcscheme"]];
  [[[self _schemeDocument] XMLStringWithOptions:NSXMLNodePrettyPrint]
   writeToFile:schemePath
   atomically:NO
   encoding:NSUTF8StringEncoding
   error:nil];
  if (err) {
    errorBlock(err);
    return NO;
  }

  return YES;
}

- (NSXMLDocument *)_workspaceDocument
{
  NSXMLElement *root =
  [NSXMLNode
   elementWithName:@"Workspace"
   children:@[]
   attributes:@[[NSXMLNode attributeWithName:@"version" stringValue:@"1.0"]]];

  for (NSString *path in _projectPaths) {
    NSXMLElement *fileRef =
    [NSXMLNode
     elementWithName:@"FileRef" children:@[]
     attributes:@[[NSXMLNode attributeWithName:@"location"
                                   stringValue:[@"absolute:" stringByAppendingString:path]]]];
    [root addChild:fileRef];
  }

  return [NSXMLDocument documentWithRootElement:root];
}

NSArray *attributeListFromDict(NSDictionary *dict) {
  NSMutableArray *array = [NSMutableArray array];
  [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    [array addObject:[NSXMLNode attributeWithName:key stringValue:obj]];
  }];
  return array;
}

- (NSXMLDocument *)_schemeDocument
{
  NSXMLElement *buildActionEntries = [NSXMLNode elementWithName:@"BuildActionEntries"];

  for (NSDictionary *buildable in _buildables) {
    NSString *container = [@"absolute:" stringByAppendingString:buildable[@"project"]];
    NSXMLElement *buildableReference =
    [NSXMLNode
     elementWithName:@"BuildableReference" children:@[]
     attributes:attributeListFromDict(@{
                                      @"BuildableIdentifier": @"primary",
                                      @"BlueprintIdentifier": buildable[@"id"],
                                      @"ReferencedContainer": container,
                                      })];

    NSXMLElement *buildActionEntry =
    [NSXMLNode
     elementWithName:@"BuildActionEntry"
     children:@[buildableReference]
     attributes:attributeListFromDict(@{
                                      @"buildForRunning": @"YES",
                                      @"buildForTesting": @"YES",
                                      @"buildForProfiling": @"YES",
                                      @"buildForArchiving": @"YES",
                                      @"buildForAnalyzing": @"YES",
                                      })];

    [buildActionEntries addChild:buildActionEntry];
  }

  NSXMLElement *buildAction =
  [NSXMLNode
   elementWithName:@"BuildAction"
   children:@[[NSXMLNode elementWithName:@"PreActions"],
              [NSXMLNode elementWithName:@"PostActions"],
              buildActionEntries]
   attributes:@[[NSXMLNode attributeWithName:@"parallelizeBuildables"
                                 stringValue:_parallelizeBuildables ? @"YES" : @"NO"],
                [NSXMLNode attributeWithName:@"buildImplicitDependencies"
                                 stringValue:_buildImplicitDependencies ? @"YES" : @"NO"]]];

  NSXMLElement *root =
  [NSXMLNode
   elementWithName:@"Scheme"
   children:@[buildAction]
   attributes:@[[NSXMLNode attributeWithName:@"version" stringValue:@"1.7"]]];

  return [NSXMLDocument documentWithRootElement:root];
}

@end
