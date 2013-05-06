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

#import "NSFileHandle+Print.h"
#import "TaskUtil.h"

NSDictionary *BuildSettingsFromOutput(NSString *output)
{
  NSScanner *scanner = [NSScanner scannerWithString:output];
  [scanner setCharactersToBeSkipped:nil];

  NSMutableDictionary *settings = [NSMutableDictionary dictionary];

  if ([scanner scanString:@"Build settings from command line:\n" intoString:NULL]) {
    // Advance until we hit an empty line.
    while (![scanner scanString:@"\n" intoString:NULL]) {
      [scanner scanUpToString:@"\n" intoString:NULL];
      [scanner scanString:@"\n" intoString:NULL];
    }
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

NSString *AbsoluteExecutablePath(void)
{
  char execRelativePath[1024] = {0};
  uint32_t execRelativePathSize = sizeof(execRelativePath);

  _NSGetExecutablePath(execRelativePath, &execRelativePathSize);

  char execAbsolutePath[1024] = {0};
  assert(realpath((const char *)execRelativePath, execAbsolutePath) != NULL);

  return [NSString stringWithUTF8String:execAbsolutePath];
}

NSString *PathToXCToolBinaries(void)
{
  if (IsRunningUnderTest()) {
    // We're running in the test harness.  Turns out DYLD_LIBRARY_PATH contains the path our
    // build products.
    return [NSProcessInfo processInfo].environment[@"DYLD_LIBRARY_PATH"];
  } else {
    return [AbsoluteExecutablePath() stringByDeletingLastPathComponent];
  }
}

NSString *XcodeDeveloperDirPath(void)
{
  static NSString *path = nil;

  if (path == nil) {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/xcode-select"];
    [task setArguments:@[@"--print-path"]];
    [task setEnvironment:@{}];
    path = LaunchTaskAndCaptureOutput(task)[@"stdout"];
    [task release];

    path = [path stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    [path retain];
  }

  return path;
}

NSString *MakeTempFileWithPrefix(NSString *prefix)
{
  const char *template = [[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.XXXXXXX", prefix]] UTF8String];

  char tempPath[PATH_MAX] = {0};
  strcpy(tempPath, template);

  int handle = mkstemp(tempPath);
  assert(handle != -1);
  close(handle);

  return [NSString stringWithFormat:@"%s", tempPath];
}

NSDictionary *GetAvailableSDKsAndAliases()
{
  static NSMutableDictionary *result = nil;

  if (result == nil) {
    result = [[NSMutableDictionary alloc] initWithCapacity:0];
    // Get a list of available SDKs in the form of:
    //   "macosx 10.7"
    //   "macosx 10.8"
    //   "iphoneos 6.1"
    //   "iphonesimulator 5.0"
    //
    // xcodebuild is nice enough to return them to us in ascending order.
    NSTask *task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath:@"/bin/bash"];
    [task setArguments:@[
     @"-c",
     @"/usr/bin/xcodebuild -showsdks | perl -ne '/-sdk (.*?)([\\d\\.]+)$/ && print \"$1 $2\n\"'",
     ]];
    [task setEnvironment:@{}];

    NSArray *lines = [LaunchTaskAndCaptureOutput(task)[@"stdout"] componentsSeparatedByString:@"\n"];
    lines = [lines subarrayWithRange:NSMakeRange(0, lines.count - 1)];

    if (IsRunningUnderTest()) {
      // Fake it so developers don't have to install all of these SDKs.
      lines = @[
                @"macosx 10.7",
                @"macosx 10.8",
                @"iphoneos 6.1",
                @"iphonesimulator 5.0",
                @"iphonesimulator 5.1",
                @"iphonesimulator 6.0",
                @"iphonesimulator 6.1",
                ];
    }

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
  }

  return result;
}

BOOL IsRunningUnderTest()
{
  NSString *processName = [[NSProcessInfo processInfo] processName];
  return ([processName isEqualToString:@"otest"] ||
          [processName isEqualToString:@"otest-x86_64"]);
}