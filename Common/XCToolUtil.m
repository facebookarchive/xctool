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

#import "XCToolUtil.h"

#import <CommonCrypto/CommonDigest.h>

#import <mach-o/dyld.h>
#import <limits.h>

#import "EventGenerator.h"
#import "EventSink.h"
#import "NSFileHandle+Print.h"
//#import "Options.h"
#import "ReporterEvents.h"
//#import "ReporterTask.h"
#import "TaskUtil.h"
#import "XcodeBuildSettings.h"
//#import "XcodeSubjectInfo.h"

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

  if ([scanner scanString:@"Build settings from configuration file" intoString:NULL]) {
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
    if (!([scanner scanString:@"Build settings for action test and target " intoString:NULL] ||
          [scanner scanString:@"Build settings for action build and target " intoString:NULL] ||
          [scanner scanString:@"Build settings for action analyze and target " intoString:NULL])) {
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

  return AbsolutePathFromRelative(@(execRelativePath));
}

NSString *XCToolBasePath(void)
{
  static NSString *path;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    if (IsRunningUnderTest()) {
      // The Xcode scheme is configured to set XT_INSTALL_ROOT when running
      // tests.
      NSString *installRoot = [[NSProcessInfo processInfo] environment][@"XT_INSTALL_ROOT"];
      NSCAssert(installRoot, @"XT_INSTALL_ROOT is not set.");
      path = installRoot;
    } else {
      path = [[AbsoluteExecutablePath() stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    }
  });
  return path;
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
  return XcodeDeveloperDirPathViaForcedConcreteTask(NO);
}

NSString *XcodeDeveloperDirPathViaForcedConcreteTask(BOOL forceConcreteTask)
{
  NSString *(^getPath)() = ^{
    NSTask *task = (forceConcreteTask ?
                    CreateConcreteTaskInSameProcessGroup() :
                    CreateTaskInSameProcessGroup());
    [task setLaunchPath:@"/usr/bin/xcode-select"];
    [task setArguments:@[@"--print-path"]];

    NSDictionary *output = LaunchTaskAndCaptureOutput(task,
                                                      @"finding Xcode path via xcode-select --print-path");
    NSString *path = output[@"stdout"];
    path = [path stringByTrimmingCharactersInSet:
            [NSCharacterSet newlineCharacterSet]];

    return path;
  };

  static NSString *savedPath = nil;

  if (IsRunningUnderTest()) {
    // Under test, we'd like to always invoke the task so it can be tested.
    return getPath();
  } else {
    if (savedPath == nil) {
      savedPath = getPath();
    }
    return savedPath;
  }
}

NSString *IOSSimulatorPlatformPath(void)
{
  return [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Platforms/iPhoneSimulator.platform"];
}

NSString *AppleTVSimulatorPlatformPath(void)
{
  return [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Platforms/AppleTVSimulator.platform"];
}

NSString *WatchSimulatorPlatformPath(void)
{
  return [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Platforms/WatchSimulator.platform"];
}

NSString *MakeTempFileInDirectoryWithPrefix(NSString *directory, NSString *prefix)
{
  const char *template = [[directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.XXXXXXX", prefix]] UTF8String];

  char tempPath[PATH_MAX] = {0};
  strcpy(tempPath, template);

  int handle = mkstemp(tempPath);
  NSCAssert(handle != -1, @"Failed to make temporary file name for template %s, error: %d", template, handle);
  close(handle);

  return @(tempPath);
}

NSString *MakeTempFileWithPrefix(NSString *prefix)
{
  return MakeTempFileInDirectoryWithPrefix(TemporaryDirectoryForAction(), prefix);
}

/**
 Helper function that takes the SDK dictionary, the file scanner and the SDK
 version and will scan all the SDK values into a newly created NSDictionary,
 then map the SDK version and its family to that new dictionary.
 */
static void AddSDKToDictionary(NSMutableDictionary *dict,
                               NSScanner *scanner,
                               NSString *sdk)
{

  NSMutableDictionary *versionDict = [NSMutableDictionary dictionary];

  // This isn't present in the output, but adding the mapping here in order
  // to assist with looking up the SDK value quickly
  versionDict[@"SDK"] = sdk;

  for (;;) {
    NSString *line = nil;
    NSString *key = nil;
    NSString *value = nil;

    [scanner scanUpToString:@"\n" intoString:&line];
    [scanner scanString:@"\n" intoString:nil];

    if (line.length == 0) {
      // a trailing empty line indicates we're done with this SDK section.
      break;
    }

    NSScanner *lineScanner = [NSScanner scannerWithString:line];

    // Parse the label/value pair from the line and add it to the dictionary
    [lineScanner scanUpToString:@": " intoString:&key];
    [lineScanner scanString:@": " intoString:nil];
    [lineScanner scanUpToCharactersFromSet:[NSCharacterSet newlineCharacterSet]
                                intoString:&value];
    versionDict[key] = value;
  }

  // Map [name] -> [name][version]. i.e. 'iphoneos' -> 'iphoneos6.1'.  Since
  // SDKs are listed in ascending order by version number, this will always
  // leave us with 'iphoneos' mapped to the newest 'iphoneos' SDK.
  NSScanner *versionScanner = [NSScanner scannerWithString:sdk];
  NSString *sdkWithoutVersion = nil;
  NSMutableCharacterSet *sdkCharacterSet = [[NSMutableCharacterSet alloc] init];
  [sdkCharacterSet formUnionWithCharacterSet:[NSCharacterSet letterCharacterSet]];
  [sdkCharacterSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"-+"]];
  [versionScanner scanCharactersFromSet:sdkCharacterSet
                             intoString:&sdkWithoutVersion];
  dict[sdkWithoutVersion] = versionDict;
  dict[sdk] = versionDict;
}

NSDictionary *GetAvailableSDKsInfo()
{
  NSTask *task = CreateTaskInSameProcessGroup();
  [task setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"usr/bin/xcodebuild"]];
  [task setArguments:@[@"-sdk", @"-version"]];

  NSDictionary *output = LaunchTaskAndCaptureOutput(task,
                                                    @"querying available SDKs");
  NSString *sdkContents = output[@"stdout"];

  NSScanner *scanner = [NSScanner scannerWithString:sdkContents];

  // We're choosing not to skip characters since we need to know when we
  // encounter newline characters to determine when we've consumed an SDK
  // "block"
  [scanner setCharactersToBeSkipped:nil];

  // Regex to pull out SDK value; matching lines with ".sdk" and "([\w-.+]+)"
  // (capturing group around what's inside of the parentheses).
  NSRegularExpression *sdkVersionRegex =
    [NSRegularExpression
     regularExpressionWithPattern:@"^[\\w-.+]+.sdk[\\s\\w-.+]+\\(([\\w-.+]+)\\)$"
                          options:0
                            error:nil];

  NSMutableDictionary *versionsAvailable = [NSMutableDictionary dictionary];

  while (![scanner isAtEnd]) {
    NSString *str = nil;

    // Read current line
    [scanner scanUpToString:@"\n" intoString:&str];
    [scanner scanString:@"\n" intoString:nil];

    // Attempt to match the regex
    NSArray *match = [sdkVersionRegex matchesInString:str
                                              options:0
                                                range:NSMakeRange(0, str.length)];

    // If we don't find a match, we are done with the SDK parsing
    if (match.count == 0) {
      break;
    }

    // Pull the SDK value from our capturing group
    NSString *sdkVersion = [str substringWithRange:[match[0] rangeAtIndex:1]];

    AddSDKToDictionary(versionsAvailable, scanner, sdkVersion);
  }

  return versionsAvailable;
}

NSDictionary *GetAvailableSDKsAndAliasesWithSDKInfo(NSDictionary *sdksInfo)
{
  NSMutableDictionary *versionsAvailable = [NSMutableDictionary dictionary];

  for (NSString *sdkAlias in sdksInfo) {
    NSDictionary *sdkInfo = sdksInfo[sdkAlias];
    versionsAvailable[sdkAlias] = sdkInfo[@"SDK"];
    versionsAvailable[sdkInfo[@"Path"]] = sdkInfo[@"SDK"];
  }

  return versionsAvailable;
}

NSDictionary *GetAvailableSDKsAndAliases()
{
  // GetAvailableSDKsInfo already does the hard work for us; we just need to
  //  iterate through its result to pull out the values cooresponding to the
  // "SDK" field for each of the SDK entries.
  NSDictionary *sdkInfo = GetAvailableSDKsInfo();
  return GetAvailableSDKsAndAliasesWithSDKInfo(sdkInfo);
}

BOOL IsRunningOnCISystem()
{
  NSDictionary *environment = [[NSProcessInfo processInfo] environment];
  return ([environment[@"TRAVIS"] isEqualToString:@"true"] ||
          [environment[@"CIRCLECI"] isEqualToString:@"true"] ||
          [environment[@"JENKINS_URL"] length] > 0 ||
          [environment[@"TEAMCITY_VERSION"] length] > 0);
}

BOOL IsRunningUnderTest()
{
  static BOOL isRunningUnderTest;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSString *processName = [[NSProcessInfo processInfo] processName];
    isRunningUnderTest = [processName isEqualToString:@"xctest"] ||
                         [processName isEqualToString:@"xctest-x86_64"];
  });
  return isRunningUnderTest;
}

BOOL LaunchXcodebuildTaskAndFeedEventsToReporters(NSTask *task,
                                                  NSArray *reporters,
                                                  NSString **errorMessageOut,
                                                  long long *errorCodeOut)
{
  __block NSString *errorMessage = nil;
  __block long long errorCode = LLONG_MIN;
  __block BOOL hadFailingBuildCommand = NO;

  LaunchTaskAndFeedOuputLinesToBlock(task,
                                     @"running xcodebuild",
                                     ^(int fd, NSString *line) {
    if (!line.length) {
      return;
    }

    NSError *error = nil;
    NSDictionary *event = [NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding]
                                                          options:0
                                                            error:&error];
    NSCAssert(error == nil,
              @"Got error while trying to deserialize event '%@': %@",
              line,
              [error localizedFailureReason]);

    NSString *eventName = event[kReporter_Event_Key];

    if ([eventName isEqualToString:@"__xcodebuild-error__"]) {
      // xcodebuild-shim will generate this special event if it sees that
      // xcodebuild failed with an error message.  We don't want this to bubble
      // up to reporters itself - instead the caller will capture the error
      // message and include it in the 'end-xcodebuild' event.
      errorMessage = event[@"message"];
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

  if ([task terminationReason] == NSTaskTerminationReasonUncaughtSignal) {
    // xcodebuild crashed
    *errorMessageOut = [NSString stringWithFormat:@"xcodebuild crashed when running the task below:\n%@.", CommandLineEquivalentForTask((NSConcreteTask *)task)];
    *errorCodeOut = -1;

    // waiting for xcodebuild crash report be generated
    sleep(5);

    // retreiving latest crash report
    NSString *crashReportPath = LatestXcodebuildCrashReportPath();
    if (crashReportPath && [[NSFileManager defaultManager] fileExistsAtPath:crashReportPath]) {
      *errorMessageOut = [*errorMessageOut stringByAppendingFormat:@"\n\nLatest available xcodebuild crash report (%@):\n%@", crashReportPath, [NSString stringWithContentsOfFile:crashReportPath encoding:NSUTF8StringEncoding error:nil]];
    }
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
   }];
  [task setEnvironment:environment];

  NSDictionary *beginEvent = EventDictionaryWithNameAndContent(
    kReporter_Events_BeginXcodebuild, @{
      kReporter_BeginXcodebuild_CommandKey: command,
      kReporter_BeginXcodebuild_TitleKey: title
      });
  PublishEventToReporters(reporters, beginEvent);

  NSString *xcodebuildErrorMessage = nil;
  long long xcodebuildErrorCode = 0;
  BOOL succeeded = LaunchXcodebuildTaskAndFeedEventsToReporters(task,
                                                                reporters,
                                                                &xcodebuildErrorMessage,
                                                                &xcodebuildErrorCode);

  NSMutableDictionary *endEvent = [NSMutableDictionary dictionaryWithDictionary:
                                   EventDictionaryWithNameAndContent(kReporter_Events_EndXcodebuild,
  @{
    kReporter_EndXcodebuild_CommandKey: command,
    kReporter_EndXcodebuild_TitleKey: title,
    kReporter_EndXcodebuild_SucceededKey : @(succeeded),
    })];

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

/**
 Every line of arguments defined in an Xcode scheme may provide multiple command line arguments
 which get passed to the testable. This method returns the command line arguments contained in one
 argument line string. It splits the string into arguments at spaces which are not contained
 in unescaped quotes
 It treats quotes and escaped quotes like Xcode does when it runs
 a test executable. (The escape character is the backslash.)
 */
NSArray *ParseArgumentsFromArgumentString(NSString *string)
{
  NSCParameterAssert(string);

  enum ParsingState {
    OutsideOfArgument,
    InsideArgument,
    BetweenQuotes,
  };

  enum ParsingState state = OutsideOfArgument;
  NSUInteger escapeIndex = NSNotFound;  // points to the index following the last single backslash
  unichar openingQuoteCharacter;

  NSMutableArray *arguments = [NSMutableArray array];
  NSMutableString *currentArgument = nil;
  NSUInteger length = string.length;
  for (NSUInteger index = 0; index < length; index++) {
    unichar iChar = [string characterAtIndex:index];

    if(iChar == '\\') {
      if(escapeIndex == index) {
        escapeIndex = NSNotFound;
      } else {
        escapeIndex = index + 1;
        continue;
      }
    }

    if(iChar == ' ') {
      if(state == OutsideOfArgument) {
        continue;
      } else if(state == InsideArgument) {
        state = OutsideOfArgument;
      }
    }
    else if((iChar == '\'' || iChar == '"') && (index != escapeIndex)) {
      if(state == BetweenQuotes) {
        if(iChar == openingQuoteCharacter) {
          state = InsideArgument;
          continue;
        }
      } else {
        openingQuoteCharacter = iChar;
        state = BetweenQuotes;
        continue;
      }
    }
    else if(state == OutsideOfArgument) {
      state = InsideArgument;
    }

    if(state == OutsideOfArgument) {
      if(currentArgument.length > 0) {
        [arguments addObject:currentArgument];
        currentArgument = nil;
      }
    } else {
      if(!currentArgument) {
        currentArgument = [NSMutableString string];
      }
      // As of Mac OS 10.9/iOS 7.0 there still is no Objective-C method for appending single
      // characters to strings therefore we have to fall back to using a CF function.
      CFStringAppendCharacters((CFMutableStringRef)currentArgument, &iChar, 1);
    }
  }

  if(currentArgument.length > 0) {
    [arguments addObject:currentArgument];
  }

  return arguments;
}

NSDictionary *ParseDestinationString(NSString *destinationString, NSString **errorMessage)
{
  NSMutableDictionary *resultBuilder = [[NSMutableDictionary alloc] init];

  // Might need to do this well later on. Right now though, just blindly split on the comma.
  NSArray *components = [destinationString componentsSeparatedByString:@","];
  for (NSString *component in components) {
    NSError *error = nil;
    NSString *pattern = @"^\\s*([^=]*)=([^=]*)\\s*$";
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:0 error:&error];
    if (error) {
      *errorMessage = [NSString stringWithFormat:@"Error while creating regex with pattern '%@'. Reason: '%@'.", pattern, [error localizedFailureReason]];
      return nil;
    }
    NSArray *matches = [re matchesInString:component options:0 range:NSMakeRange(0, [component length])];
    NSCAssert(matches, @"Apple's documentation states that the above call will never return nil.");
    if ([matches count] != 1) {
      *errorMessage = [NSString stringWithFormat:@"The string '%@' is formatted badly. It should be KEY=VALUE. "
                       @"The number of matches with regex '%@' was %llu.",
                       component, pattern, (long long unsigned)[matches count]];
      return nil;
    }
    NSTextCheckingResult *match = matches[0];
    if ([match numberOfRanges] != 3) {
      *errorMessage = [NSString stringWithFormat:@"The string '%@' is formatted badly. It should be KEY=VALUE. "
                       @"The number of ranges with regex '%@' was %llu.",
                       component, pattern, (long long unsigned)[match numberOfRanges]];
      return nil;
    }
    NSString *lhs = [component substringWithRange:[match rangeAtIndex:1]];
    NSString *rhs = [component substringWithRange:[match rangeAtIndex:2]];
    resultBuilder[lhs] = rhs;
  }

  return resultBuilder;
}

NSString *TemporaryDirectoryForAction()
{
  if (__tempDirectoryForAction == nil) {
    NSString *nameTemplate = nil;

    // Let our names be consistent while under test - we don't want our tests
    // to have to match against random values.
    if (IsRunningUnderTest()) {
      nameTemplate = [NSString stringWithFormat:@"xctool_temp_UNDERTEST_%d", [[NSProcessInfo processInfo] processIdentifier]];
    } else {
      nameTemplate = @"xctool_temp_XXXXXX";
    }

    __tempDirectoryForAction = MakeTemporaryDirectory(nameTemplate);
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
  NSCAssert(realpath((const char *)[path UTF8String], absolutePath) != NULL, @"Failed to resolve the path: %s", absolutePath);

  return @(absolutePath);
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

/**
 SenTesting.framework location:
 - Xcode 6: Contents/Developer/Library/Frameworks directory
 XCTest.framework location:
 - Xcode 6: Contents/Developer/Platforms/{iPhoneSimulator.platform/MacOSX}/Developer/Library/Frameworks
 */
NSString *IOSTestFrameworkDirectories()
{
  NSArray *directories = @[
    [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Library/Frameworks"],
    [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks"],
  ];
  return [directories componentsJoinedByString:@":"];
}

NSString *OSXTestFrameworkDirectories()
{
  NSArray *directories = @[
    [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Library/Frameworks"],
    [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Platforms/MacOSX.platform/Developer/Library/Frameworks"],
  ];
  return [directories componentsJoinedByString:@":"];
}

NSString *TVOSTestFrameworkDirectories()
{
  NSArray *directories = @[
    [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Library/Frameworks"],
    [XcodeDeveloperDirPath() stringByAppendingPathComponent:@"Platforms/AppleTVSimulator.platform/Developer/SDKs/AppleTVSimulator.sdk/System/Library/Frameworks"],
  ];
  return [directories componentsJoinedByString:@":"];
}

NSString *AllFrameworkAndLiraryPathsInBuildSettings(NSDictionary *buildSettings)
{
  NSMutableSet *set = [NSMutableSet set];
  for (NSString *pathKey in @[Xcode_BUILT_PRODUCTS_DIR, Xcode_PRODUCT_TYPE_FRAMEWORK_SEARCH_PATHS, Xcode_TEST_FRAMEWORK_SEARCH_PATHS]) {
    NSString *pathExists = buildSettings[pathKey];
    if (pathExists) {
      [set addObject:[pathExists stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    }
  }
  return [[set allObjects] componentsJoinedByString:@":"];
}

NSMutableDictionary *IOSTestEnvironment(NSDictionary *buildSettings)
{
  NSString *paths = AllFrameworkAndLiraryPathsInBuildSettings(buildSettings);
  return [@{
    @"DYLD_FRAMEWORK_PATH" : paths,
    @"DYLD_LIBRARY_PATH" : paths,
    @"DYLD_FALLBACK_FRAMEWORK_PATH" : IOSTestFrameworkDirectories(),
  } mutableCopy];
}

NSMutableDictionary *OSXTestEnvironment(NSDictionary *buildSettings)
{
  NSString *paths = AllFrameworkAndLiraryPathsInBuildSettings(buildSettings);
  return [@{
    @"DYLD_FRAMEWORK_PATH" : paths,
    @"DYLD_LIBRARY_PATH" : paths,
    @"DYLD_FALLBACK_FRAMEWORK_PATH" : OSXTestFrameworkDirectories(),
    @"NSUnbufferedIO" : @"YES",
  } mutableCopy];
}

NSMutableDictionary *TVOSTestEnvironment(NSDictionary *buildSettings)
{
  NSString *paths = AllFrameworkAndLiraryPathsInBuildSettings(buildSettings);
  return [@{
    @"DYLD_FRAMEWORK_PATH" : paths,
    @"DYLD_LIBRARY_PATH" : paths,
    @"DYLD_FALLBACK_FRAMEWORK_PATH" : TVOSTestFrameworkDirectories(),
  } mutableCopy];
}

NSString *XcodebuildVersion()
{
  static NSString *DTXcode;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSString *xcodePlistPath = [XcodeDeveloperDirPathViaForcedConcreteTask(YES)
                                stringByAppendingPathComponent:@"../Info.plist"];
    NSCAssert([[NSFileManager defaultManager] fileExistsAtPath:xcodePlistPath isDirectory:NULL],
              @"Cannot find Xcode's plist at: %@", xcodePlistPath);

    NSDictionary *infoDict = [NSDictionary dictionaryWithContentsOfFile:xcodePlistPath];
    NSCAssert(infoDict[@"DTXcode"], @"Cannot find the 'DTXcode' key in Xcode's Info.plist.");

    DTXcode = infoDict[@"DTXcode"];
  });
  return DTXcode;
}

static BOOL ToolchainIsXcodeVersionSameOrBetter(NSString *versionString)
{
  NSComparisonResult cmpResult = [XcodebuildVersion() compare:versionString];
  return cmpResult != NSOrderedAscending;
}

BOOL ToolchainIsXcode7OrBetter(void)
{
  static BOOL result;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    result = ToolchainIsXcodeVersionSameOrBetter(@"0700");
  });
  return result;
}

BOOL ToolchainIsXcode8OrBetter(void)
{
  static BOOL result;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    result = ToolchainIsXcodeVersionSameOrBetter(@"0800");
  });
  return result;
}

BOOL ToolchainIsXcode81OrBetter(void)
{
  static BOOL result;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    result = ToolchainIsXcodeVersionSameOrBetter(@"0810");
  });
  return result;
}

NSString *MakeTemporaryDirectory(NSString *nameTemplate)
{
  NSMutableData *template = [[[NSTemporaryDirectory() stringByAppendingPathComponent:nameTemplate]
                               dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
  [template appendBytes:"\0" length:1];

  if (!mkdtemp(template.mutableBytes) && !IsRunningUnderTest()) {
    NSLog(@"Failed to create temporary directory: %s", strerror(errno));
    abort();
  }

  return [NSString stringWithUTF8String:template.bytes];
}

// Forward declaration for private CFBundle API.
// https://www.opensource.apple.com/source/CF/CF-855.11/CFBundle.c
CFStringRef _CFBundleCopyFileTypeForFileURL(CFURLRef url) CF_RETURNS_RETAINED;

static BOOL IsMachOExecutable(NSString *path)
{
  NSURL *fileURL = [NSURL fileURLWithPath:path];
  CFStringRef fileType = _CFBundleCopyFileTypeForFileURL((__bridge CFURLRef)fileURL);

  if (fileType != NULL) {
    CFComparisonResult result = CFStringCompare(fileType, CFSTR("tool"), 0);
    CFRelease(fileType);
    return (result == kCFCompareEqualTo);
  } else {
    return NO;
  }
}

BOOL TestableSettingsIndicatesApplicationTest(NSDictionary *settings)
{
  NSString *testHostPath = TestHostPathForBuildSettings(settings);
  return (testHostPath != nil &&
          [[NSFileManager defaultManager] isExecutableFileAtPath:testHostPath] &&
          IsMachOExecutable(testHostPath));
}

NSString *LatestXcodebuildCrashReportPath()
{
  NSMutableArray *crashReports = [NSMutableArray array];
  NSArray *directories = @[[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/DiagnosticReports"],
                           @"/Library/Logs/DiagnosticReports"];
  NSFileManager *manager = [[NSFileManager alloc] init];
  for (NSString *directory in directories) {
    NSDirectoryEnumerator *dirEnum = [manager enumeratorAtPath:directory];
    NSString *file;
    while ((file = [dirEnum nextObject])) {
      if (![file hasPrefix:@"xcodebuild"] ||
          ![file hasSuffix:@"crash"]) {
        continue;
      }

      // process not sent Xcode crash
      [crashReports addObject:[directory stringByAppendingPathComponent:file]];
    }
  }

  return [crashReports lastObject];
}


NSString *HashForString(NSString *string)
{
  NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
  uint8_t digest[CC_SHA1_DIGEST_LENGTH];
  CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
  NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
  for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
    [output appendFormat:@"%02x", digest[i]];
  }
  return output;
}


cpu_type_t CpuTypeForTestBundleAtPath(NSString *testBundlePath)
{
  if (![[NSFileManager defaultManager] fileExistsAtPath:testBundlePath]) {
    // Many unit tests specify a nonexistent bundle.
    return CPU_TYPE_ANY;
  }

  NSBundle *testBundle = [NSBundle bundleWithPath:testBundlePath];
  if (!testBundle) {
    // path could be directly to the executable and not to the bundle
    NSArray *bundleExtensions = @[@"app", @"octest", @"xctest"];
    for (NSString *extension in bundleExtensions) {
      NSRange range = [testBundlePath rangeOfString:[@"." stringByAppendingString:extension] options:NSBackwardsSearch];
      if (range.location == NSNotFound) {
        continue;
      }

      testBundlePath = [testBundlePath substringToIndex:range.location + range.length];
      testBundle = [NSBundle bundleWithPath:testBundlePath];
      break;
    }
  }

  NSCAssert(testBundle, @"Cannot read bundle at path: %@", testBundlePath);

  NSArray *archs = [testBundle executableArchitectures];

  BOOL isI386Only = YES;
  BOOL isX86_64Only = YES;
  for (NSNumber *arch in archs) {
    switch ([arch unsignedIntegerValue]) {
      case NSBundleExecutableArchitectureI386:
        isX86_64Only = NO;
        break;

      case NSBundleExecutableArchitectureX86_64:
        isI386Only = NO;
        break;
    }
  }
  NSCAssert(!(isI386Only && isX86_64Only), @"Bundle's executable code doesn't support nor i386, nor x86_64 CPU types. Bundle path: %@, supported cpu types: %@.", testBundlePath, archs);

  if (isX86_64Only) {
    return CPU_TYPE_X86_64;
  } else if (isI386Only) {
    return CPU_TYPE_I386;
  }
  return CPU_TYPE_ANY;
}

NSString *TestHostPathForBuildSettings(NSDictionary *buildSettings)
{
  // TEST_HOST will sometimes be wrapped in "quotes".
  return [buildSettings[Xcode_TEST_HOST] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
}

NSString *ProductBundlePathForBuildSettings(NSDictionary *buildSettings)
{
  NSString *builtProductsDir = buildSettings[Xcode_TARGET_BUILD_DIR] ?: buildSettings[Xcode_BUILT_PRODUCTS_DIR];
  NSString *fullProductName = buildSettings[Xcode_FULL_PRODUCT_NAME];
  return [builtProductsDir stringByAppendingPathComponent:fullProductName];
}
