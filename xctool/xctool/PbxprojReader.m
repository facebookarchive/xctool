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

#import "PbxprojReader.h"

// Xcode defined
static NSString * const PBXSourceTreeKey = @"sourceTree";
static NSString * const PBXPathKey = @"path";
static NSString * const PBXObjects = @"objects";
static NSString * const PBXChildren = @"children";
static NSString * const PBXIsa = @"isa";
static NSString * const PBXProjectDirPath = @"projectDirPath";

// xctool defined
static NSString * const PBXFullPathKey = @"fullPath";
static NSString * const PBXUniqueIdKey = @"uniqueId";

static NSString * GetObjectFullRelativePath(NSMutableDictionary *object, NSDictionary *groupsById, NSDictionary *childGroups)
{
  if (!object[PBXFullPathKey]) {
    if ([object[PBXSourceTreeKey] isEqualToString:@"SOURCE_ROOT"]) {
      object[PBXFullPathKey] = object[PBXPathKey];
    } else {
      NSString *parentId = childGroups[object[PBXUniqueIdKey]];
      if (parentId == nil) {
        object[PBXFullPathKey] = object[PBXPathKey];
      } else {
        NSString *parentFullRelativePath = GetObjectFullRelativePath(groupsById[parentId], groupsById, childGroups);
        object[PBXFullPathKey] = [parentFullRelativePath ?: @"" stringByAppendingPathComponent:object[PBXPathKey] ?: @""];
      }
    }
  }
  return object[PBXFullPathKey];
}

NSSet * ProjectFilesReferencedInProjectAtPath(NSString *filePath)
{
  NSDictionary *contents = [[NSDictionary alloc] initWithContentsOfFile:[filePath stringByAppendingPathComponent:@"project.pbxproj"]];
  NSDictionary *objects = contents[PBXObjects];
  __block NSDictionary *mainProject = nil;
  NSMutableDictionary *groupsById = [@{} mutableCopy];
  NSMutableArray *projects = [@[] mutableCopy];
  NSMutableDictionary *childGroups = [@{} mutableCopy];
  [objects enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *objWithoutId, BOOL *stop) {
    NSMutableDictionary *obj = [objWithoutId mutableCopy];
    obj[PBXUniqueIdKey] = key;
    if ([obj[PBXIsa] isEqualToString:@"PBXGroup"] && obj[PBXPathKey] != nil) {
      for (NSString *childId in obj[PBXChildren]) {
        childGroups[childId] = obj[PBXUniqueIdKey];
      }
      groupsById[key] = obj;
    } else if ([obj[PBXIsa] isEqualToString:@"PBXFileReference"] && [[obj[PBXPathKey] pathExtension] isEqualToString:@"xcodeproj"]) {
      [projects addObject:obj];
    } else if ([obj[PBXIsa] isEqualToString:@"PBXProject"]) {
      mainProject = obj;
    }
  }];
  NSString *mainProjectPath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:mainProject[PBXProjectDirPath] ?: @""];
  for (NSMutableDictionary *project in projects) {
    project[PBXFullPathKey] = [[mainProjectPath stringByAppendingPathComponent:GetObjectFullRelativePath(project, groupsById, childGroups)] stringByStandardizingPath];
  }
  return [NSSet setWithArray:[projects valueForKeyPath:PBXFullPathKey]];
}

NSString * ProjectBaseDirectoryPath(NSString *filePath)
{
  NSDictionary *contents = [[NSDictionary alloc] initWithContentsOfFile:[filePath stringByAppendingPathComponent:@"project.pbxproj"]];
  NSDictionary *objects = contents[PBXObjects];
  __block NSDictionary *mainProject = nil;
  [objects enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *obj, BOOL *stop) {
    if ([obj[PBXIsa] isEqualToString:@"PBXProject"]) {
      mainProject = obj;
      *stop = YES;
    }
  }];
  NSString *mainProjectPath = [[filePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:mainProject[PBXProjectDirPath] ?: @""];
  return mainProjectPath;
}
