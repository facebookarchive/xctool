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

#import <launch.h>
#import <mach/mach.h>
#import <servers/bootstrap.h>

#import "dyld-interposing.h"

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

// `sim` WANTS to run the process inside the same bootstrap subset as the iOS
// simulator, but we want to prevent this!  We don't know exactly why, but
// sometimes the `sim` process can hang while it's trying to make contact with
// the iOS Simulator.
//
// To do this, `sim` will use the launchd `GetJobs` command to lookup the
// the bootstrap name for the simulator subset (i.e. com.apple.iphonesimulator.launchd.XXXXX).
// Then, it uses that to somehow poke into that bootstrap context.
//
// We can prevent this just by prevening `sim` from ever finding the bootstrap
// service.
static launch_data_t __launch_msg(launch_data_t msg)
{
  if ((launch_data_get_type(msg) == LAUNCH_DATA_STRING) &&
      (strcmp(launch_data_get_string(msg), LAUNCH_KEY_GETJOBS) == 0)) {
    launch_data_t emptyDictionary = launch_data_alloc(LAUNCH_DATA_DICTIONARY);
    return emptyDictionary;
  } else {
    return launch_msg(msg);
  }
}
DYLD_INTERPOSE(__launch_msg, launch_msg);

// In iOS 6, `sim` doesn't have to call GetJobs to look up the bootstrap name
// since it's always constant.  Let's prevent it from over reaching that mach
// service.
kern_return_t	__bootstrap_look_up(mach_port_t bp, const name_t service_name, mach_port_t *sp) {
  if (strcmp(service_name, "com.apple.iphonesimulator.bootstrap_subset") == 0) {
    return BOOTSTRAP_UNKNOWN_SERVICE;
  } else {
    return bootstrap_look_up(bp, service_name, sp);
  }
}
DYLD_INTERPOSE(__bootstrap_look_up, bootstrap_look_up);

__attribute__((constructor)) static void Initializer()
{
  NSCAssert(NSClassFromString(@"BootlegTask") != nil, @"Class should exist.");

  XTSwizzleSelectorForFunction(NSClassFromString(@"BootlegTask"),
                               @selector(runUntilExit),
                               (IMP)BootlegTask_runUntilExit);

  // Don't cascade into other spawned processes.
  unsetenv("DYLD_INSERT_LIBRARIES");
}
