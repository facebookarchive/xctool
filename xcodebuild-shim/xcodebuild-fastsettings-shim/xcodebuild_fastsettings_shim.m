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

#import <objc/message.h>
#import <objc/runtime.h>

#import <Foundation/Foundation.h>

#import "Swizzle.h"

// class-dump'ed from:
// /Applications/Xcode.app/Contents/PlugIns/Xcode3Core.ideplugin/Contents/Frameworks/DevToolsCore.framework/DevToolsCore
@interface Xcode3Target : NSObject
- (NSString *)name;
@end

@interface Xcode3TargetBuildable : NSObject
@property (readonly) Xcode3Target *xcode3Target;
@end

@interface Xcode3TargetProduct : Xcode3TargetBuildable
@end

static NSArray *FilterBuildables(NSArray *buildables)
{
  NSString *showOnlyBuildsettingsForTarget = [[NSProcessInfo processInfo] environment][@"SHOW_ONLY_BUILD_SETTINGS_FOR_TARGET"];
  NSString *showOnlyBuildsettingsForFirstBuildable = [[NSProcessInfo processInfo] environment][@"SHOW_ONLY_BUILD_SETTINGS_FOR_FIRST_BUILDABLE"];

  if (showOnlyBuildsettingsForTarget != nil) {
    for (Xcode3TargetProduct *buildable in buildables) {
      if ([[[buildable xcode3Target] name] isEqualToString:showOnlyBuildsettingsForTarget]) {
        return @[buildable];
      }
    }
    return @[];
  } else if ([showOnlyBuildsettingsForFirstBuildable isEqualToString:@"YES"]) {
    return buildables.count > 0 ? @[buildables[0]] : @[];
  } else {
    return buildables;
  }
}

static id IDEBuildSchemeAction__uniquedBuildablesForBuildables_includingDependencies(id self, SEL sel, id buildables, BOOL includingDependencies)
{
  id result = objc_msgSend(self,
                      @selector(__IDEBuildSchemeAction__uniquedBuildablesForBuildables:includingDependencies:),
                      buildables,
                      includingDependencies);
  return FilterBuildables(result);
}

__attribute__((constructor)) static void EntryPoint()
{
  NSCAssert(NSClassFromString(@"IDEBuildSchemeAction") != NULL, @"Should have IDEBuildSchemeAction");

  // Xcode 5 and later will call this method several times as its
  // collecting all the buildables.  We can filter the list each time.
  XTSwizzleClassSelectorForFunction(NSClassFromString(@"IDEBuildSchemeAction"),
                               @selector(_uniquedBuildablesForBuildables:includingDependencies:),
                               (IMP)IDEBuildSchemeAction__uniquedBuildablesForBuildables_includingDependencies);

  // Unset so we don't cascade into other process that get spawned from xcodebuild.
  unsetenv("DYLD_INSERT_LIBRARIES");
}
