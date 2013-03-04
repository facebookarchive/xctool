
#import "Functions.h"
#import "NSFileHandle+Print.h"
#import "LineReader.h"
#import <mach-o/dyld.h>

static NSMutableArray *__fakeTasks = nil;
static NSTask *(^__TaskInstanceBlock)(void) = nil;

NSTask *TaskInstance(void)
{
  if (__TaskInstanceBlock == nil) {
    return [[[NSTask alloc] init] autorelease];
  } else {
    return __TaskInstanceBlock();
  }
}

void SetTaskInstanceBlock(NSTask *(^taskInstanceBlock)())
{
  if (__TaskInstanceBlock != taskInstanceBlock) {
    [__TaskInstanceBlock release];
    __TaskInstanceBlock = [taskInstanceBlock copy];
  }
}

void ReturnFakeTasks(NSArray *tasks)
{
  [__fakeTasks release];
  __fakeTasks = [[NSMutableArray arrayWithArray:tasks] retain];
  
  if (tasks == nil) {
    SetTaskInstanceBlock(nil);
  } else {
    SetTaskInstanceBlock(^{
      assert(__fakeTasks.count > 0);
      NSTask *task = __fakeTasks[0];
      [__fakeTasks removeObjectAtIndex:0];
      return task;
    });
  }
}

NSArray *ProjectsInWorkspace(NSString *workspacePath)
{
  NSString *workspaceBasePath = [workspacePath stringByDeletingLastPathComponent];
  NSURL *URL = [NSURL fileURLWithPath:[workspacePath stringByAppendingPathComponent:@"contents.xcworkspacedata"]];
  NSError *error = nil;
  NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:URL
                                                             options:0
                                                               error:&error];
  if (error != nil) {
    NSLog(@"Error in parsing: %@: %@", workspacePath, error);
    abort();
  }
  
  NSArray *fileRefNodes = [doc nodesForXPath:@"//FileRef" error:nil];
  NSMutableArray *projectFiles = [NSMutableArray array];
  for (NSXMLElement *node in fileRefNodes) {
    NSString *location = [[node attributeForName:@"location"] stringValue];
    
    if ([location hasSuffix:@".xcodeproj"]) {
      
      if (![location hasPrefix:@"group:"] && ![location hasPrefix:@"container:"]) {
        [NSException raise:NSGenericException
                    format:@"Unexpected format in FileRef location: %@", location];
      }
      
      NSRange colonRange = [location rangeOfString:@":"];
      location = [location substringFromIndex:colonRange.location + 1];
      
      [projectFiles addObject:[workspaceBasePath stringByAppendingPathComponent:location]];
    }
  }
  
  return projectFiles;
}

NSArray *SchemesInProject(NSString *xcodeprojPath)
{
  NSMutableArray *schemes = [NSMutableArray array];
  NSFileManager *fm = [NSFileManager defaultManager];
  
  // Collect shared schemes (those that have 'Shared' checked in the Schemes Manager).
  NSString *sharedSchemesPath = [xcodeprojPath stringByAppendingPathComponent:@"xcshareddata/xcschemes"];
  NSArray *sharedContents = [fm contentsOfDirectoryAtPath:sharedSchemesPath
                                                    error:nil];
  if (sharedContents != nil) {
    for (NSString *file in sharedContents) {
      if ([file hasSuffix:@".xcscheme"]) {
        [schemes addObject:[sharedSchemesPath stringByAppendingPathComponent:file]];
      }
    }
  }
  
  // Collect user-specific schemes.
  NSString *userdataPath = [xcodeprojPath stringByAppendingPathComponent:@"xcuserdata"];
  NSArray *userContents = [fm contentsOfDirectoryAtPath:userdataPath
                                                  error:nil];
  if (userContents != nil) {
    for (NSString *file in userContents) {
      if ([file hasSuffix:@".xcuserdatad"]) {
        NSString *userSchemesPath = [[userdataPath stringByAppendingPathComponent:file] stringByAppendingPathComponent:@"xcschemes"];
        NSArray *userSchemesContents = [fm contentsOfDirectoryAtPath:userSchemesPath error:nil];
        
        for (NSString *file in userSchemesContents) {
          if ([file hasSuffix:@".xcscheme"]) {
            [schemes addObject:[userSchemesPath stringByAppendingPathComponent:file]];
          }
        }
      }
    }
  }
  
  return schemes;
}

NSArray *BuildablesForTestInScheme(NSString *schemePath, NSString *parentProjectPath)
{
  NSString *parentProjectBasePath = [parentProjectPath stringByDeletingLastPathComponent];
  
  NSError *error = nil;
  NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:schemePath]
                                                            options:0
                                                              error:&error];
  if (error != nil) {
    NSLog(@"Error in parsing: %@: %@", schemePath, error);
    abort();
  }
  
  NSArray *buildActionEntryNodes = [doc nodesForXPath:@"//BuildActionEntry[@buildForTesting='YES']" error:nil];
  
  NSMutableArray *buildables = [NSMutableArray array];
  for (NSXMLElement *node in buildActionEntryNodes) {
    NSArray *buildableReferences = [node nodesForXPath:@"BuildableReference" error:nil];
    
    assert(buildableReferences.count == 1);
    NSXMLElement *buildableReference = buildableReferences[0];
    
    NSString *referencedContainer = [[buildableReference attributeForName:@"ReferencedContainer"] stringValue];
    assert([referencedContainer hasPrefix:@"container:"]);
    
    NSString *projectPath = [parentProjectBasePath stringByAppendingPathComponent:[referencedContainer substringFromIndex:@"container:".length]];
    assert([[NSFileManager defaultManager] fileExistsAtPath:projectPath]);
    
    NSString *target = [[buildableReference attributeForName:@"BlueprintName"] stringValue];
    
    [buildables addObject:@{
     @"projectPath" : projectPath,
     @"target": target,
     }];
  }
  
  return buildables;
}

NSArray *TestablesInScheme(NSString *schemePath, NSString *parentProjectPath)
{
  NSString *parentProjectBasePath = [parentProjectPath stringByDeletingLastPathComponent];
  
  NSError *error = nil;
  NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:schemePath]
                                                             options:0
                                                               error:&error];
  if (error != nil) {
    NSLog(@"Error in parsing: %@: %@", schemePath, error);
    abort();
  }
  
  NSArray *testableReferenceNodes = [doc nodesForXPath:@"//TestableReference[@skipped='NO']" error:nil];
  
  NSMutableArray *testables = [NSMutableArray array];
  for (NSXMLElement *node in testableReferenceNodes) {
    NSArray *buildableReferences = [node nodesForXPath:@"BuildableReference" error:nil];

    assert(buildableReferences.count == 1);
    NSXMLElement *buildableReference = buildableReferences[0];
    
    NSString *referencedContainer = [[buildableReference attributeForName:@"ReferencedContainer"] stringValue];
    assert([referencedContainer hasPrefix:@"container:"]);
    
    NSString *projectPath = [parentProjectBasePath stringByAppendingPathComponent:[referencedContainer substringFromIndex:@"container:".length]];
    assert([[NSFileManager defaultManager] fileExistsAtPath:projectPath]);
    
    NSString *executable = [[buildableReference attributeForName:@"BuildableName"] stringValue];
    NSString *target = [[buildableReference attributeForName:@"BlueprintName"] stringValue];
    
    NSArray *skippedTestsNodes = [node nodesForXPath:@"SkippedTests/Test" error:nil];
    NSMutableArray *testsToSkip = [NSMutableArray array];
    for (NSXMLElement *node in skippedTestsNodes) {
      NSString *test = [[node attributeForName:@"Identifier"] stringValue];
      [testsToSkip addObject:test];
    }
    
    NSString *senTestList = nil;
    BOOL senTestInvertScope = NO;
    if (testsToSkip.count > 0) {
      senTestList = [testsToSkip componentsJoinedByString:@","];
      senTestInvertScope = YES;
    } else {
      senTestList = @"All";
      senTestInvertScope = NO;
    }
    
    [testables addObject:@{@"projectPath" : projectPath, @"target": target, @"executable": executable, @"senTestInvertScope": @(senTestInvertScope), @"senTestList": senTestList}];
  }
  
  return testables;
}

void ProjectPathAndSchemePathForWorkspacePathAndScheme(NSString *workspacePath,
                                                       NSString *scheme,
                                                       NSString **outProjectPath,
                                                       NSString **outSchemePath)
{
  // Find the schemePath for our specified scheme
  NSString *foundProjectPath = nil;
  NSString *foundSchemePath = nil;
  
  for (NSString *projectPath in ProjectsInWorkspace(workspacePath)) {
    for (NSString *schemePath in SchemesInProject(projectPath)) {
      if ([schemePath hasSuffix:[NSString stringWithFormat:@"%@.xcscheme", scheme]]) {
        foundSchemePath = schemePath;
        foundProjectPath = projectPath;
        goto outer;
      }
    }
  }
outer:
  ;
  
  assert(foundProjectPath != nil);
  assert(foundSchemePath != nil);
  
  *outSchemePath = foundSchemePath;
  *outProjectPath = foundProjectPath;
}

void SchemePathForProjectPathAndScheme(NSString *projectPath,
                                       NSString *scheme,
                                       NSString **outSchemePath)
{
  // Find the schemePath for our specified scheme
  NSString *foundSchemePath = nil;
  
  for (NSString *schemePath in SchemesInProject(projectPath)) {
    if ([schemePath hasSuffix:[NSString stringWithFormat:@"%@.xcscheme", scheme]]) {
      foundSchemePath = schemePath;
      break;
    }
  }
  
  assert(foundSchemePath != nil);

  *outSchemePath = foundSchemePath;
}

NSArray *TestablesInWorkspaceAndScheme(NSString *workspacePath, NSString *scheme)
{
  // Find the schemePath for our specified scheme
  NSString *foundProjectPath = nil;
  NSString *foundSchemePath = nil;

  ProjectPathAndSchemePathForWorkspacePathAndScheme(workspacePath, scheme, &foundProjectPath, &foundSchemePath);
  
  return TestablesInScheme(foundSchemePath, foundProjectPath);
}

NSArray *TestablesInProjectAndScheme(NSString *projectPath, NSString *scheme)
{
  // Find the schemePath for our specified scheme
  NSString *foundSchemePath = nil;
  
  SchemePathForProjectPathAndScheme(projectPath, scheme, &foundSchemePath);
  
  return TestablesInScheme(foundSchemePath, projectPath);
}

NSArray *BuildablesForTestInWorkspaceAndScheme(NSString *workspacePath, NSString *scheme)
{
  // Find the schemePath for our specified scheme
  NSString *foundProjectPath = nil;
  NSString *foundSchemePath = nil;
  
  ProjectPathAndSchemePathForWorkspacePathAndScheme(workspacePath, scheme, &foundProjectPath, &foundSchemePath);
  
  return BuildablesForTestInScheme(foundSchemePath, foundProjectPath);
}

NSArray *BuildablesForTestInProjectAndScheme(NSString *projectPath, NSString *scheme)
{
  // Find the schemePath for our specified scheme
  NSString *foundSchemePath = nil;
  
  SchemePathForProjectPathAndScheme(projectPath, scheme, &foundSchemePath);
  
  return BuildablesForTestInScheme(foundSchemePath, projectPath);
}

NSDictionary *LaunchTaskAndCaptureOutput(NSTask *task)
{
  NSPipe *stdoutPipe = [NSPipe pipe];
  NSFileHandle *stdoutHandle = [stdoutPipe fileHandleForReading];

  NSPipe *stderrPipe = [NSPipe pipe];
  NSFileHandle *stderrHandle = [stderrPipe fileHandleForReading];
  
  __block NSString *standardOutput = nil;
  __block NSString *standardError = nil;
  
  void (^completionBlock)(NSNotification *) = ^(NSNotification *notification){
    NSData *data = notification.userInfo[NSFileHandleNotificationDataItem];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    if (notification.object == stdoutHandle) {
      standardOutput = str;
    } else if (notification.object == stderrHandle) {
      standardError = str;
    }
    
    CFRunLoopStop(CFRunLoopGetCurrent());
  };
  
  id stdoutObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleReadToEndOfFileCompletionNotification
                                                    object:stdoutHandle
                                                     queue:nil
                                                usingBlock:completionBlock];
  id stderrObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleReadToEndOfFileCompletionNotification
                                                    object:stderrHandle
                                                     queue:nil
                                                usingBlock:completionBlock];
  [stdoutHandle readToEndOfFileInBackgroundAndNotify];
  [stderrHandle readToEndOfFileInBackgroundAndNotify];
  [task setStandardOutput:stdoutPipe];
  [task setStandardError:stderrPipe];
  
  [task launch];
  [task waitUntilExit];
  
  while (standardOutput == nil || standardError == nil) {
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, YES);
  }
  
  [[NSNotificationCenter defaultCenter] removeObserver:stdoutObserver];
  [[NSNotificationCenter defaultCenter] removeObserver:stderrObserver];

  return @{@"stdout" : standardOutput, @"stderr" : standardError};
}

void LaunchTaskAndFeedOuputLinesToBlock(NSTask *task, void (^block)(NSString *))
{
  NSPipe *stdoutPipe = [NSPipe pipe];
  NSFileHandle *stdoutReadHandle = [stdoutPipe fileHandleForReading];
  NSFileHandle *stdoutWriteHandle = [stdoutPipe fileHandleForWriting];
  
  LineReader *reader = [[[LineReader alloc] initWithFileHandle:stdoutReadHandle] autorelease];
  reader.didReadLineBlock = block;
  
  [task setStandardOutput:stdoutWriteHandle];
  [task launch];
  
  [reader startReading];

  [task waitUntilExit];
  
  [stdoutWriteHandle closeFile];

  [reader stopReading];
  [reader finishReadingToEndOfFile];
}

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

NSString *PathToFBXcodeTestBinaries(void)
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

