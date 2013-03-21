
#import "XcodeToolUtil.h"
#import "TaskUtil.h"
#import "NSFileHandle+Print.h"
#import <mach-o/dyld.h>

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
    
    if (![scanner scanString:@"Build settings for action build and target " intoString:NULL]) {
      break;
    }
    
    [scanner scanUpToString:@":\n" intoString:&target];
    [scanner scanString:@":\n" intoString:NULL];
    
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

NSString *PathToFBXcodetoolBinaries(void)
{
  if ([[NSString stringWithUTF8String:getprogname()] isEqualToString:@"otest"]) {
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

NSString *StringForJSON(id object)
{
  NSError *error = nil;
  NSData *data = [NSJSONSerialization dataWithJSONObject:object
                                                 options:0
                                                   error:&error];
  
  if (error != nil) {
    fprintf(stderr, "ERROR: Error encoding JSON for object: %s: %s\n",
            [[object description] UTF8String],
            [[error localizedFailureReason] UTF8String]);
    exit(1);
  }
  
  return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
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

NSArray *GetAvailableSDKs()
{
  static NSArray *SDKs = nil;
  
  if (SDKs == nil) {
    NSTask *task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath:@"/bin/bash"];
    [task setArguments:@[
     @"-c",
     @"/usr/bin/xcodebuild -showsdks | perl -ne '/-sdk (.*)$/ && print \"$1\n\"'",
     ]];
    [task setEnvironment:@{}];
    
    SDKs = [LaunchTaskAndCaptureOutput(task)[@"stdout"] componentsSeparatedByString:@"\n"];
    SDKs = [SDKs subarrayWithRange:NSMakeRange(0, SDKs.count - 1)];
    [SDKs retain];
  }
  
  return SDKs;
}
