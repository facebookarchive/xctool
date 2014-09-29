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

#import "HeaderCopyDatabaseReporter.h"

#import "ReporterEvents.h"

@interface HeaderCopyDatabaseReporter()

@property (nonatomic, retain) NSDictionary *currentBuildCommand;

@end

@implementation HeaderCopyDatabaseReporter

- (void)collectEvent
{
  NSString *title = _currentBuildCommand[kReporter_BeginBuildCommand_TitleKey];
  if (![title hasPrefix:@"Copy"]) {
    return;
  }

  NSString *command = _currentBuildCommand[kReporter_BeginBuildCommand_CommandKey];
  NSError *error = nil;
  NSRegularExpression *copyRegexp =
    [NSRegularExpression regularExpressionWithPattern:@"builtin-copy .* ([^ ]*) ([^ ]*)\n"
                                              options:0
                                                error:&error];

  NSTextCheckingResult *match = [copyRegexp firstMatchInString:command
                                                       options:0
                                                         range:NSMakeRange(0, [command length])];
  if (!match) {
    return;
  }

  NSString *source = [command substringWithRange:[match rangeAtIndex:1]];
  NSString *dest = [NSString stringWithFormat:@"%@/%@",
                    [command substringWithRange:[match rangeAtIndex:2]],
                    [source lastPathComponent]];

  // Write a one-entry inverse map: dest -> source
  [_outputHandle writeData:[NSJSONSerialization dataWithJSONObject:@{dest : source}
                                                           options:0
                                                             error:&error]];
  [_outputHandle writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];

  // The data written by this reporter are meant to be
  // available before the compilation is finished.
  [_outputHandle synchronizeFile];
}

- (void)beginBuildCommand:(NSDictionary *)event
{
  _currentBuildCommand = [event retain];
}

- (void)endBuildCommand:(NSDictionary *)event
{
  BOOL succeeded = [event[kReporter_EndBuildCommand_SucceededKey] boolValue];
  if (succeeded && _currentBuildCommand) {
    [self collectEvent];
  }

  [_currentBuildCommand release];
}

@end
