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

#import <objc/message.h>
#import <objc/runtime.h>

#import <Foundation/Foundation.h>

// class-dump'ed from:
// /Applications/Xcode.app/Contents/PlugIns/Xcode3Core.ideplugin/Contents/Frameworks/DevToolsCore.framework/DevToolsCore
@interface Xcode3Target : NSObject
- (NSString *)name;
@end

@interface Xcode3TargetBuildable : NSObject
@property(readonly) Xcode3Target *xcode3Target;
@end

@interface Xcode3TargetProduct : Xcode3TargetBuildable
@end

static void SwizzleSelectorForFunction(Class cls, SEL sel, IMP newImp)
{
  Method originalMethod = class_getInstanceMethod(cls, sel);
  const char *typeEncoding = method_getTypeEncoding(originalMethod);

  NSString *newSelectorName = [NSString stringWithFormat:@"__%s_%s", class_getName(cls), sel_getName(sel)];
  SEL newSelector = sel_registerName([newSelectorName UTF8String]);
  class_addMethod(cls, newSelector, newImp, typeEncoding);

  Method newMethod = class_getInstanceMethod(cls, newSelector);
  method_exchangeImplementations(originalMethod, newMethod);
}

static NSArray *IDEBuildSchemeAction_buildablesForAllSchemeCommandsIncludingDependencies(id self, SEL cmd, BOOL arg)
{
  NSArray *buildables = objc_msgSend(self, sel_getUid("__IDEBuildSchemeAction_buildablesForAllSchemeCommandsIncludingDependencies:"), NO);

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

__attribute__((constructor)) static void EntryPoint()
{
  SwizzleSelectorForFunction(NSClassFromString(@"IDEBuildSchemeAction"),
                             @selector(buildablesForAllSchemeCommandsIncludingDependencies:),
                             (IMP)IDEBuildSchemeAction_buildablesForAllSchemeCommandsIncludingDependencies);

  // Unset so we don't cascade into other process that get spawned from xcodebuild.
  unsetenv("DYLD_INSERT_LIBRARIES");
}
