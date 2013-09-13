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

#import "XCTool.h"

#import <QuartzCore/QuartzCore.h>

#import "Action.h"
#import "NSFileHandle+Print.h"
#import "Options.h"
#import "ReporterEvents.h"
#import "ReporterTask.h"
#import "TaskUtil.h"
#import "Version.h"
#import "XcodeSubjectInfo.h"
#import "XCToolUtil.h"

@implementation XCTool

- (id)init
{
  if (self = [super init]) {
    _exitStatus = 0;
  }
  return self;
}

- (void)printUsage
{
  [_standardError printString:@"usage: xctool [BASE OPTIONS] [ACTION [ACTION ARGUMENTS]] ...\n\n"];

  [_standardError printString:@"Examples:\n"];
  for (Class actionClass in [Options actionClasses]) {
    NSString *actionName = [actionClass name];
    NSArray *options = [actionClass options];

    NSMutableString *buffer = [NSMutableString string];

    for (NSDictionary *option in options) {
      if (option[kActionOptionParamName]) {
        [buffer appendFormat:@" [-%@ %@]", option[kActionOptionName], option[kActionOptionParamName]];
      } else {
        [buffer appendFormat:@" [-%@]", option[kActionOptionName]];
      }
    }

    [_standardError printString:@"    xctool [BASE OPTIONS] %@%@", actionName, buffer];
    [_standardError printString:@"\n"];
  }

  [_standardError printString:@"\n"];

  [_standardError printString:@"Base Options:\n"];
  [_standardError printString:@"%@", [Options actionUsage]];

  [_standardError printString:@"\n"];
  [_standardError printString:@"Available Reporters:\n"];

  for (NSString *name in AvailableReporters()) {
    [_standardError printString:@"    %@\n", name];
  }

  for (Class actionClass in [Options actionClasses]) {
    NSString *actionName = [actionClass name];
    NSString *actionUsage = [actionClass actionUsage];

    if (actionUsage.length > 0) {
      [_standardError printString:@"\n"];
      [_standardError printString:@"Options for '%@' action:\n", actionName];
      [_standardError printString:@"%@", actionUsage];
    }
  }

  [_standardError printString:@"\n"];
}

- (void)run
{
  Options *options = [[[Options alloc] init] autorelease];
  NSString *errorMessage = nil;

  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm isReadableFileAtPath:@".xctool-args"]) {
    NSError *readError = nil;
    NSString *argumentsString = [NSString stringWithContentsOfFile:@".xctool-args"
                                                          encoding:NSUTF8StringEncoding
                                                             error:&readError];
    if (readError) {
      [_standardError printString:@"ERROR: Cannot read '.xctool-args' file: %@\n", [readError localizedFailureReason]];
      _exitStatus = 1;
      return;
    }

    NSError *JSONError = nil;
    NSArray *argumentsList = [NSJSONSerialization JSONObjectWithData:[argumentsString dataUsingEncoding:NSUTF8StringEncoding]
                                                             options:0
                                                               error:&JSONError];
    if (JSONError) {
      [_standardError printString:@"ERROR: couldn't parse json: %@: %@\n", argumentsString, [JSONError localizedDescription]];
      _exitStatus = 1;
      return;
    }

    [options consumeArguments:[NSMutableArray arrayWithArray:argumentsList] errorMessage:&errorMessage];
    if (errorMessage != nil) {
      [_standardError printString:@"ERROR: %@\n", errorMessage];
      _exitStatus = 1;
      return;
    }
  }

  [options consumeArguments:[NSMutableArray arrayWithArray:self.arguments] errorMessage:&errorMessage];
  if (errorMessage != nil) {
    [_standardError printString:@"ERROR: %@\n", errorMessage];
    _exitStatus = 1;
    return;
  }

  if (options.showHelp) {
    [self printUsage];
    _exitStatus = 1;
    return;
  }

  if (options.showVersion) {
    [_standardOutput printString:@"%@\n", XCToolVersionString];
    _exitStatus = 0;
    return;
  }

  if (options.showBuildSettings) {
    NSTask *task = CreateTaskInSameProcessGroup();
    [task setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"usr/bin/xcodebuild"]];
    [task setArguments:[[[options xcodeBuildArgumentsForSubject]
                         arrayByAddingObjectsFromArray:[options commonXcodeBuildArgumentsForSchemeAction:nil xcodeSubjectInfo:nil]]
                        arrayByAddingObject:@"-showBuildSettings"]];
    [task setStandardOutput:_standardOutput];
    [task setStandardError:_standardError];
    [task launch];
    [task waitUntilExit];
    _exitStatus = [task terminationStatus];
    [task release];
    return;
  }

  if (![options validateReporterOptions:&errorMessage]) {
    [_standardError printString:@"ERROR: %@\n\n", errorMessage];
    _exitStatus = 1;
    return;
  }

  for (ReporterTask *reporter in options.reporters) {
    NSString *error = nil;
    if (![reporter openWithStandardOutput:_standardOutput
                            standardError:_standardError
                                    error:&error]) {
      [_standardError printString:@"ERROR: %@\n\n", error];
      _exitStatus = 1;
      return;
    }
  }

  // We want to make sure we always close the reporters, even if validation fails,
  // so we use a try-finally block.
  @try {
    XcodeSubjectInfo *xcodeSubjectInfo = nil;

    if (![options validateAndReturnXcodeSubjectInfo:&xcodeSubjectInfo
                                       errorMessage:&errorMessage]) {
      [_standardError printString:@"ERROR: %@\n\n", errorMessage];
      _exitStatus = 1;
      return;
    }

    for (Action *action in options.actions) {
      CFTimeInterval startTime = CACurrentMediaTime();
      PublishEventToReporters(options.reporters, @{
       @"event": kReporter_Events_BeginAction,
       kReporter_BeginAction_NameKey: [[action class] name],
       kReporter_BeginAction_WorkspaceKey: options.workspace ?: [NSNull null],
       kReporter_BeginAction_ProjectKey: options.project ?: [NSNull null],
       kReporter_BeginAction_SchemeKey: options.scheme,
       });

      BOOL succeeded = [action performActionWithOptions:options xcodeSubjectInfo:xcodeSubjectInfo];

      CFTimeInterval stopTime = CACurrentMediaTime();

      PublishEventToReporters(options.reporters, @{
       @"event": kReporter_Events_EndAction,
       kReporter_EndAction_NameKey: [[action class] name],
       kReporter_EndAction_WorkspaceKey: options.workspace ?: [NSNull null],
       kReporter_EndAction_ProjectKey: options.project ?: [NSNull null],
       kReporter_EndAction_SchemeKey: options.scheme,
       kReporter_EndAction_SucceededKey: @(succeeded),
       kReporter_EndAction_DurationKey: @(stopTime - startTime),
       });

      CleanupTemporaryDirectoryForAction();

      if (!succeeded) {
        _exitStatus = 1;
        break;
      }
    }
  } @finally {
    [options.reporters makeObjectsPerformSelector:@selector(close)];
  }
}


@end
