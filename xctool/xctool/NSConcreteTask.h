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

/**
 * NSConcreteTask is the true implementation behind NSTask.
 */
@interface NSConcreteTask : NSTask

/**
 * Internal dictionary of settings.  Passed to `launchWithDictionary:`.
 */
- (NSMutableDictionary *)taskDictionary;

/**
 * Set to `@[@(CPU_TYPE_X86_64)]` to prefer x86_64, or to `@[@(CPU_TYPE_I386)]`
 * to prefer i386.
 */
- (void)setPreferredArchitectures:(NSArray *)architectures;

/**
 * Returns preferred architectures.
 */
- (id)preferredArchitectures;

/**
 * When YES (default), a new progress group is created for the child (via
 * POSIX_SPAWN_SETPGROUP to posix_spawnattr_setflags).  If YES, then the child
 * will continue running even if the parent is killed or interrupted.
 */
- (void)setStartsNewProcessGroup:(BOOL)startsNewProcessGroup;

@end
