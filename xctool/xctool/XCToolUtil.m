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

#import "XCToolUtil.h"

#import <mach-o/dyld.h>

#import "EventSink.h"
#import "NSFileHandle+Print.h"
#import "Options.h"
#import "ReporterEvents.h"
#import "ReporterTask.h"
#import "TaskUtil.h"
#import "XcodeSubjectInfo.h"

static NSString *__tempDirectoryForAction = nil;

NSDictionary *BuildSettingsFromOutput(NSString *output)
{
  NSScanner *scanner = [NSScanner scannerWithString:output];
  [scanner setCharactersToBeSkipped:nil];

  NSMutableDictionary *settings = [NSMutableDictionary dictionary];

  void (^scanUntilEmptyLine)() = ^{
    // Advance until we hit an empty line.
    while (![scanner scanString:@"\n" intoString:NULL]) {
      [scanner scanUpToString:@"\n" intoString:NULL];
      [scanner scanString:@"\n" intoString:NULL];
    }
  };

  if ([scanner scanString:@"User defaults from command line:\n" intoString:NULL]) {
    scanUntilEmptyLine();
  }

  if ([scanner scanString:@"Build settings from command line:\n" intoString:NULL]) {
    scanUntilEmptyLine();
  }

  for (;;) {
    NSString *target = nil;
    NSMutableDictionary *targetSettings = [NSMutableDictionary dictionary];

    // Line with look like...
    // 'Build settings for action build and target SomeTarget:'
    //
    // or, if there are spaces in the target name...
    // 'Build settings for action build and target "Some Target Name":'
    if (![scanner scanString:@"Build settings for action build and target " intoString:NULL]) {
      break;
    }

    [scanner scanUpToString:@":\n" intoString:&target];
    [scanner scanString:@":\n" intoString:NULL];

    // Target names with spaces will be quoted.
    target = [target stringByTrimmingCharactersInSet:
              [NSCharacterSet characterSetWithCharactersInString:@"\""]];

    for (;;) {

      if ([scanner scanString:@"\n" intoString:NULL]) {
        // We know we've reached the end when we see one empty line.
        break;
      }

      // Each line / setting looks like: "    SOME_KEY = some value\n"
      NSString *key = nil;
      NSString *value = nil;

      [scanner scanString:@"    " intoString:NULL];
      [scanner scanUpToString:@" = " intoString:&key];
      [scanner scanString:@" = " intoString:NULL];

      [scanner scanUpToString:@"\n" intoString:&value];
      [scanner scanString:@"\n" intoString:NULL];

      targetSettings[key] = (value == nil) ? @"" : value;
    }

    settings[target] = targetSettings;
  }

  return settings;
}

NSString *AbsoluteExecutablePath() {
  char execRelativePath[PATH_MAX] = {0};
  uint32_t execRelativePathSize = sizeof(execRelativePath);
  _NSGetExecutablePath(execRelativePath, &execRelativePathSize);

  return AbsolutePathFromRelative([NSString stringWithUTF8String:execRelativePath]);
}

NSString *XCToolBasePath(void)
{
  if (IsRunningUnderTest()) {
    // The Xcode scheme is configured to set XT_INSTALL_ROOT when running
    // tests.
    return [[NSProcessInfo processInfo] environment][@"XT_INSTALL_ROOT"];
  } else {
    return [[AbsoluteExecutablePath() stringByDeletingLastPathComponent]
            stringByDeletingLastPathComponent];
  }
}

NSString *XCToolLibPath(void)
{
  return [XCToolBasePath() stringByAppendingPathComponent:@"lib"];
}

NSString *XCToolLibExecPath(void)
{
  return [XCToolBasePath() stringByAppendingPathComponent:@"libexec"];
}

NSString *XCToolReportersPath(void)
{
  return [XCToolBasePath() stringByAppendingPathComponent:@"reporters"];
}

NSString *XcodeDeveloperDirPath(void)
{
  NSString *(^getPath)() = ^{
    NSTask *task = CreateTaskInSameProcessGroup();
    [task setLaunchPath:@"/usr/bin/xcode-select"];
    [task setArguments:@[@"--print-path"]];

    NSString *path = LaunchTaskAndCaptureOutput(task)[@"stdout"];
    path = [path stringByTrimmingCharactersInSet:
            [NSCharacterSet newlineCharacterSet]];

    [task release];
    return path;
  };

  static NSString *savedPath = nil;

  if (IsRunningUnderTest()) {
    // Under test, we'd like to always invoke the task so it can be tested.
    return getPath();
  } else {
    if (savedPath == nil) {
      savedPath = [getPath() retain];
    }
    return savedPath;
  }
}

NSString *MakeTempFileWithPrefix(NSString *prefix)
{
  const char *template = [[TemporaryDirectoryForAction() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.XXXXXXX", prefix]] UTF8String];

  char tempPath[PATH_MAX] = {0};
  strcpy(tempPath, template);

  int handle = mkstemp(tempPath);
  assert(handle != -1);
  close(handle);

  return [NSString stringWithFormat:@"%s", tempPath];
}

NSDictionary *GetAvailableSDKsAndAliases()
{
  NSMutableDictionary *(^getSdksAndAliases)(void) = ^{
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    // Get a list of available SDKs in the form of:
    //   "macosx 10.7"
    //   "macosx 10.8"
    //   "iphoneos 6.1"
    //   "iphonesimulator 5.0"
    //
    // xcodebuild is nice enough to return them to us in ascending order.
    NSTask *task = CreateTaskInSameProcessGroup();
    [task setLaunchPath:@"/bin/bash"];
    [task setArguments:@[
     @"-c",
     [[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"usr/bin/xcodebuild"] stringByAppendingString:
      @" -showsdks | perl -ne '/-sdk (.*?)([\\d\\.]+)$/ && print \"$1 $2\n\"'; "
      // Exit with xcodebuild's return value.  This is getting ugly.
      @"exit ${PIPESTATUS[0]};"
      ],
     ]];
    [task setEnvironment:@{@"PATH": SystemPaths()}];

    NSDictionary *output = LaunchTaskAndCaptureOutput(task);
    NSCAssert([task terminationStatus] == 0,
              @"xcodebuild failed to run with error: %@", output[@"stderr"]);

    NSArray *lines = [output[@"stdout"] componentsSeparatedByString:@"\n"];
    lines = [lines subarrayWithRange:NSMakeRange(0, lines.count - 1)];

    for (NSString *line in lines) {
      NSArray *parts = [line componentsSeparatedByString:@" "];
      NSString *sdkName = parts[0];
      NSString *sdkVersion = parts[1];

      NSString *sdk = [NSString stringWithFormat:@"%@%@", sdkName, sdkVersion];
      result[sdk] = sdk;

      // Map [name] -> [name][version]. i.e. 'iphoneos' -> 'iphoneos6.1'.  Since SDKs are listed
      // in ascending order by version number, this will always leave us with 'iphoneos' mapped
      // to the newest 'iphoneos' SDK.
      result[sdkName] = sdk;
    }

    [task release];
    return result;
  };

  static NSMutableDictionary *savedResult = nil;

  if (IsRunningUnderTest()) {
    // Under test, we'd like to always invoke the task so it can be tested.
    return getSdksAndAliases();
  } else {
    if (savedResult == nil) {
      savedResult = [getSdksAndAliases() retain];
    }
    return savedResult;
  }
}

BOOL IsRunningUnderTest()
{
  NSString *processName = [[NSProcessInfo processInfo] processName];
  return ([processName isEqualToString:@"otest"] ||
          [processName isEqualToString:@"otest-x86_64"]);
}

BOOL LaunchXcodebuildTaskAndFeedEventsToReporters(NSTask *task,
                                                  NSArray *reporters,
                                                  NSString **errorMessageOut,
                                                  long long *errorCodeOut)
{
  __block NSString *errorMessage = nil;
  __block long long errorCode = LONG_LONG_MIN;
  __block BOOL hadFailingBuildCommand = NO;

  LaunchTaskAndFeedOuputLinesToBlock(task, ^(NSString *line){
    NSError *error = nil;
    NSDictionary *event = [NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding]
                                                          options:0
                                                            error:&error];
    NSCAssert(error == nil,
              @"Got error while trying to deserialize event '%@': %@",
              line,
              [error localizedFailureReason]);

    NSString *eventName = event[@"event"];

    if ([eventName isEqualToString:@"__xcodebuild-error__"]) {
      // xcodebuild-shim will generate this special event if it sees that
      // xcodebuild failed with an error message.  We don't want this to bubble
      // up to reporters itself - instead the caller will capture the error
      // message and include it in the 'end-xcodebuild' event.
      errorMessage = [event[@"message"] retain];
      errorCode = [event[@"code"] longLongValue];
    } else {
      PublishEventToReporters(reporters, event);
    }

    if ([eventName isEqualToString:kReporter_Events_EndBuildCommand]) {
      BOOL succeeded = [event[kReporter_EndBuildCommand_SucceededKey] boolValue];

      if (!succeeded) {
        hadFailingBuildCommand = YES;
      }
    }
  });

  if (errorMessage) {
    *errorMessageOut = errorMessage;
    *errorCodeOut = errorCode;
  }

  // xcodebuild's 'archive' action has a bug where the build can fail, but
  // xcodebuild will still print 'ARCHIVE SUCCEEDED' and give you an exit status
  // of 0.  To compensate, we'll only say xcodebuild succeeded if the exit status
  // was 0 AND we saw no failing build commands.
  return ([task terminationStatus] == 0) && !hadFailingBuildCommand;
}

BOOL RunXcodebuildAndFeedEventsToReporters(NSArray *arguments,
                                           NSString *command,
                                           NSString *title,
                                           NSArray *reporters)
{
  NSTask *task = CreateTaskInSameProcessGroup();
  [task setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"usr/bin/xcodebuild"]];
  [task setArguments:arguments];
  NSMutableDictionary *environment =
    [NSMutableDictionary dictionaryWithDictionary:
     [[NSProcessInfo processInfo] environment]];
  [environment addEntriesFromDictionary:@{
   @"DYLD_INSERT_LIBRARIES" : [XCToolLibPath()
                               stringByAppendingPathComponent:@"xcodebuild-shim.dylib"],
   @"PATH": @"/usr/bin:/bin:/usr/sbin:/sbin",
   }];
  [task setEnvironment:environment];

  NSDictionary *beginEvent = @{@"event": kReporter_Events_BeginXcodebuild,
                               kReporter_BeginXcodebuild_CommandKey: command,
                               kReporter_BeginXcodebuild_TitleKey: title,
                               };
  PublishEventToReporters(reporters, beginEvent);

  NSString *xcodebuildErrorMessage = nil;
  long long xcodebuildErrorCode = 0;
  BOOL succeeded = LaunchXcodebuildTaskAndFeedEventsToReporters(task,
                                                                reporters,
                                                                &xcodebuildErrorMessage,
                                                                &xcodebuildErrorCode);

  NSMutableDictionary *endEvent = [NSMutableDictionary dictionary];
  [endEvent addEntriesFromDictionary:@{
   @"event": kReporter_Events_EndXcodebuild,
   kReporter_EndXcodebuild_CommandKey: command,
   kReporter_EndXcodebuild_TitleKey: title,
   kReporter_EndXcodebuild_SucceededKey : @(succeeded),
   }];

  id errorMessage = [NSNull null];
  id errorCode = [NSNull null];

  if (!succeeded && xcodebuildErrorMessage != nil) {
    // xcodebuild failed, not because of a compile error, but because something
    // was wrong with the workspace/project or scheme.
    errorMessage = xcodebuildErrorMessage;
    errorCode = @(xcodebuildErrorCode);
  }

  [endEvent addEntriesFromDictionary:@{
   kReporter_EndXcodebuild_ErrorMessageKey: errorMessage,
   kReporter_EndXcodebuild_ErrorCodeKey: errorCode,
   }];

  PublishEventToReporters(reporters, endEvent);

  [task release];
  return succeeded;
}

NSArray *ArgumentListByOverriding(NSArray *arguments,
                                  NSString *option,
                                  NSString *optionValue)
{
  NSMutableArray *result = [NSMutableArray array];

  BOOL foundAndReplaced = NO;

  for (int i = 0; i < [arguments count]; i++) {
    if ([arguments[i] isEqualToString:option]) {
      [result addObjectsFromArray:@[option, optionValue]];
      i++;
      foundAndReplaced = YES;
    } else {
      [result addObject:arguments[i]];
    }
  }

  if (!foundAndReplaced) {
    [result addObjectsFromArray:@[option, optionValue]];
  }

  return result;
}

NSString *TemporaryDirectoryForAction()
{
  if (__tempDirectoryForAction == nil) {
    NSString *nameTemplate = nil;

    // Let our names be consistent while under test - we don't want our tests
    // to have to match against random values.
    if (IsRunningUnderTest()) {
      nameTemplate = @"xctool_temp_UNDERTEST";
    } else {
      nameTemplate = @"xctool_temp_XXXXXX";
    }

    NSMutableData *template =
    [[[[NSTemporaryDirectory() stringByAppendingPathComponent:nameTemplate]
       dataUsingEncoding:NSUTF8StringEncoding] mutableCopy] autorelease];
    [template appendBytes:"\0" length:1];

    if (!mkdtemp(template.mutableBytes) && !IsRunningUnderTest()) {
      NSLog(@"Failed to create temporary directory: %s", strerror(errno));
      abort();
    }

    __tempDirectoryForAction = [[NSString alloc] initWithUTF8String:template.bytes];
  }

  return __tempDirectoryForAction;
}

void CleanupTemporaryDirectoryForAction()
{
  if (__tempDirectoryForAction != nil) {
    NSError *error = nil;
    if (![[NSFileManager defaultManager] removeItemAtPath:__tempDirectoryForAction
                                                    error:&error]) {
      NSLog(@"Failed to remove temporary directory '%@': %@",
            __tempDirectoryForAction,
            [error localizedFailureReason]);
      abort();
    }

    [__tempDirectoryForAction release];
    __tempDirectoryForAction = nil;
  }
}

void PublishEventToReporters(NSArray *reporters, NSDictionary *event)
{
  NSError *error = nil;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:event options:0 error:&error];
  NSCAssert(jsonData != nil, @"Error while encoding event into JSON: %@", [error localizedFailureReason]);

  for (id<EventSink> reporter in reporters) {
    [reporter publishDataForEvent:jsonData];
  }
}

NSArray *AvailableReporters()
{
  NSString *reportersPath = XCToolReportersPath();
  
  NSError *error = nil;
  NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:reportersPath
                                                                          error:&error];
  NSCAssert(contents != nil,
            @"Failed to read from reporters directory '%@': %@", reportersPath, [error localizedFailureReason]);
  return contents;
}

NSString *AbsolutePathFromRelative(NSString *path)
{
  char absolutePath[PATH_MAX] = {0};
  assert(realpath((const char *)[path UTF8String], absolutePath) != NULL);

  return [NSString stringWithUTF8String:absolutePath];
}

NSString *SystemPaths()
{
  NSError *error = nil;
  NSString *pathLines = [NSString stringWithContentsOfFile:@"/etc/paths"
                                                  encoding:NSUTF8StringEncoding
                                                     error:&error];
  NSCAssert(error == nil, @"Failed to read from /etc/paths: %@", [error localizedFailureReason]);

  return [[pathLines componentsSeparatedByString:@"\n"] componentsJoinedByString:@":"];
}
