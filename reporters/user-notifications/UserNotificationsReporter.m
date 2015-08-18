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

#import "UserNotificationsReporter.h"

#import "ReporterEvents.h"

@interface UserNotificationsReporter ()
@property (nonatomic, copy) NSString *mainProjectName;
@property (nonatomic, copy) NSString *mainProjectPath;
@property (nonatomic, copy) NSString *mainWorkspaceName;
@property (nonatomic, copy) NSString *mainWorkspacePath;
@end

@implementation UserNotificationsReporter


- (void)beginAction:(NSDictionary *)event
{
  if (_mainProjectPath || _mainWorkspacePath) {
    return;
  }

  _mainProjectPath = event[kReporter_BeginAction_ProjectKey];
  if ([_mainProjectPath isKindOfClass:[NSString class]]) {
    _mainProjectName = [[_mainProjectPath lastPathComponent] stringByDeletingPathExtension];
  } else {
    _mainProjectPath = nil;
    _mainProjectName = nil;
  }

  _mainWorkspacePath = event[kReporter_BeginAction_WorkspaceKey];
  if ([_mainWorkspacePath isKindOfClass:[NSString class]]) {
    _mainWorkspaceName = [[_mainWorkspacePath lastPathComponent] stringByDeletingPathExtension];
  } else {
    _mainWorkspacePath = nil;
    _mainWorkspaceName = nil;
  }
}

- (void)endAction:(NSDictionary *)event
{
  if (_mainWorkspacePath) {
    if (![event[kReporter_EndAction_WorkspaceKey] isEqual:_mainWorkspacePath]) {
      return;
    }
  }

  if (_mainProjectPath) {
    if (![event[kReporter_EndAction_ProjectKey] isEqual:_mainProjectPath]) {
      return;
    }
  }

  NSString *name = event[kReporter_EndAction_NameKey];
  NSString *schemeName = event[kReporter_EndAction_SchemeKey] ?: @"";
  BOOL succeeded = [event[kReporter_EndAction_SucceededKey] boolValue];
  NSString *status = succeeded ? @"Succeeded" : @"Failed";

  [self deliverNotificationWithTitle:[NSString stringWithFormat:@"%@ %@", [name capitalizedString], status]
                            subtitle:[NSString stringWithFormat:@"%@ | %@ Scheme", _mainProjectName ?: _mainWorkspaceName, schemeName]
                             message:nil
                             options:@{}
                               sound:NSUserNotificationDefaultSoundName];
}

#pragma mark -
#pragma mark Private methods

- (void)deliverNotificationWithTitle:(NSString *)title
                            subtitle:(NSString *)subtitle
                             message:(NSString *)message
                             options:(NSDictionary *)options
                               sound:(NSString *)sound;
{
  NSUserNotification *userNotification = [[NSUserNotification alloc] init];
  userNotification.title = title;
  userNotification.subtitle = subtitle;
  userNotification.informativeText = message;
  userNotification.userInfo = options;
  userNotification.soundName = sound;

  NSUserNotificationCenter *center = [NSUserNotificationCenter defaultUserNotificationCenter];
  [center scheduleNotification:userNotification];
}

@end
