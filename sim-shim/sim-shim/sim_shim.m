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

#import "Swizzle.h"

@interface BootlegTask : NSObject
{
  BOOL _waitForDebugger;
  BOOL _setExec;
  int _cpuType;
  NSString *_launchPath;
  NSArray *_arguments;
  NSDictionary *_environment;
  NSDictionary *_sessionCookie;
}

@property int cpuType; // @synthesize cpuType=_cpuType;
@property BOOL setExec; // @synthesize setExec=_setExec;
@property BOOL waitForDebugger; // @synthesize waitForDebugger=_waitForDebugger;
@property(copy) NSDictionary *sessionCookie; // @synthesize sessionCookie=_sessionCookie;
@property(copy) NSDictionary *environment; // @synthesize environment=_environment;
@property(copy) NSArray *arguments; // @synthesize arguments=_arguments;
@property(copy) NSString *launchPath; // @synthesize launchPath=_launchPath;
- (int)runUntilExit;

@end

static int BootlegTask_runUntilExit(BootlegTask *self, SEL sel)
{
  NSMutableDictionary *newEnv = [NSMutableDictionary dictionary];
  [newEnv addEntriesFromDictionary:[self environment]];

  [[[NSProcessInfo processInfo] environment] enumerateKeysAndObjectsUsingBlock:
   ^(id key, id value, BOOL *stop){
     if ([key hasPrefix:@"SIMSHIM_"]) {
       NSString *newKey = [key stringByReplacingOccurrencesOfString:@"SIMSHIM_" withString:@""];
       [newEnv setObject:value forKey:newKey];
     }
   }];

  [self setValue:newEnv forKey:@"_environment"];

  return (int)objc_msgSend(self, @selector(__BootlegTask_runUntilExit));
}

__attribute__((constructor)) static void Initializer()
{
  NSCAssert(NSClassFromString(@"BootlegTask") != nil, @"Class should exist.");

  XTSwizzleSelectorForFunction(NSClassFromString(@"BootlegTask"),
                               @selector(runUntilExit),
                               (IMP)BootlegTask_runUntilExit);

  // Don't cascade into other spawned processes.
  unsetenv("DYLD_INSERT_LIBRARIES");
}
