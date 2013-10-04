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

#import "Options.h"

#import "AnalyzeAction.h"
#import "ArchiveAction.h"
#import "BuildAction.h"
#import "BuildTestsAction.h"
#import "CleanAction.h"
#import "ReporterTask.h"
#import "ReportStatus.h"
#import "RunTestsAction.h"
#import "TestAction.h"
#import "XCToolUtil.h"
#import "XcodeSubjectInfo.h"
#import "XcodeTargetMatch.h"

@implementation Options

+ (NSArray *)actionClasses
{
  return @[[CleanAction class],
           [BuildAction class],
           [BuildTestsAction class],
           [RunTestsAction class],
           [TestAction class],
           [ArchiveAction class],
           [AnalyzeAction class],
           ];
}

+ (NSArray *)options
{
  return
  @[[Action actionOptionWithName:@"help"
                         aliases:@[@"h", @"usage"]
                     description:@"show help"
                         setFlag:@selector(setShowHelp:)],
    [Action actionOptionWithName:@"workspace"
                         aliases:nil
                     description:@"path to workspace"
                       paramName:@"PATH"
                           mapTo:@selector(setWorkspace:)],
    [Action actionOptionWithName:@"project"
                         aliases:nil
                     description:@"path to project"
                       paramName:@"PATH"
                           mapTo:@selector(setProject:)],
    [Action actionOptionWithName:@"scheme"
                         aliases:nil
                     description:@"scheme to use for building or testing"
                       paramName:@"NAME"
                           mapTo:@selector(setScheme:)],
    [Action actionOptionWithName:@"find-target"
                         aliases:nil
                     description:@"Search for the workspace/project/scheme to build the target"
                       paramName:@"TARGET"
                           mapTo:@selector(setFindTarget:)],
    [Action actionOptionWithName:@"find-target-path"
                         aliases:nil
                     description:@"Path to search for -find-target."
                       paramName:@"PATH"
                           mapTo:@selector(setFindTargetPath:)],
    [Action actionOptionWithName:@"find-target-exclude-paths"
                         aliases:nil
                     description:@"Colon-separated list of paths to exclude for -find-target."
                       paramName:@"PATHS"
                           mapTo:@selector(setFindTargetExcludePathsFromString:)],
    [Action actionOptionWithName:@"sdk"
                         aliases:nil
                     description:@"sdk to use for building (e.g. 6.0, 6.1)"
                       paramName:@"VERSION"
                           mapTo:@selector(setSdk:)],
    [Action actionOptionWithName:@"configuration"
                         aliases:nil
                     description:@"configuration to use (e.g. Debug, Release)"
                       paramName:@"NAME"
                           mapTo:@selector(setConfiguration:)],
    [Action actionOptionWithName:@"destination"
                         aliases:nil
                     description:@"use the destination described by DESTINATION (a comma-separated set of key=value "
                                  "pairs describing the destination to use)"
                       paramName:@"DESTINATION"
                           mapTo:@selector(setDestination:)],
    [Action actionOptionWithName:@"jobs"
                         aliases:nil
                     description:@"number of concurrent build operations to run"
                       paramName:@"NUMBER"
                           mapTo:@selector(setJobs:)],
    [Action actionOptionWithName:@"arch"
                         aliases:nil
                     description:@"arch to build for (e.g. i386, armv7)"
                       paramName:@"ARCH"
                           mapTo:@selector(setArch:)],
    [Action actionOptionWithName:@"toolchain"
                         aliases:nil
                     description:@"path to toolchain"
                       paramName:@"PATH"
                           mapTo:@selector(setToolchain:)],
    [Action actionOptionWithName:@"xcconfig"
                         aliases:nil
                     description:@"path to an xcconfig"
                       paramName:@"PATH"
                           mapTo:@selector(setXcconfig:)],
    [Action actionOptionWithName:@"reporter"
                         aliases:nil
                     description:@"add reporter"
                       paramName:@"TYPE[:FILE]"
                           mapTo:@selector(addReporter:)],
    [Action actionOptionWithName:@"showBuildSettings"
                         aliases:nil
                     description:@"display a list of build settings and values"
                         setFlag:@selector(setShowBuildSettings:)],
    [Action actionOptionWithName:@"version"
                         aliases:@[@"v"]
                     description:@"print version and exit"
                         setFlag:@selector(setShowVersion:)],
    [Action actionOptionWithMatcher:^(NSString *argument){
      // Anything that looks like KEY=VALUE should get passed to xcodebuild
      // as a command-line build setting.
      return
        (BOOL)(([argument rangeOfString:@"="].length > 0) &&
               ![argument hasPrefix:@"-"]);
    }
                        description:@"Set the build 'setting' to 'value'"
                          paramName:@"SETTING=VALUE"
                              mapTo:@selector(addBuildSetting:)],
    [Action actionOptionWithMatcher:^(NSString *argument){
      // Anything that looks like -DEFAULT=VALUE should get passed to xcodebuild
      // as a command-line user default setting.  These let you override values
      // in NSUserDefaults.
      return
        (BOOL)(([argument rangeOfString:@"="].length > 0) &&
               [argument hasPrefix:@"-"]);
    }
                        description:@"Set the user default 'default' to 'value'"
                          paramName:@"-DEFAULT=VALUE"
                              mapTo:@selector(addUserDefault:)],
    ];
}

- (id)init
{
  if (self = [super init])
  {
    self.reporters = [NSMutableArray array];
    _reporterOptions = [[NSMutableArray alloc] init];
    self.buildSettings = [NSMutableDictionary dictionary];
    self.userDefaults = [NSMutableDictionary dictionary];
    self.actions = [NSMutableArray array];
  }
  return self;
}

- (void)dealloc
{
  [_reporterOptions release];
  self.reporters = nil;
  self.buildSettings = nil;
  self.userDefaults = nil;
  self.actions = nil;
  self.findTargetExcludePaths = nil;
  [super dealloc];
}

- (void)addReporter:(NSString *)argument
{
  [_reporterOptions addObject:argument];
}

- (void)addBuildSetting:(NSString *)argument
{
  NSRange eqRange = [argument rangeOfString:@"="];

  if (eqRange.location != NSNotFound && eqRange.location > 0) {
    NSString *key = [argument substringToIndex:eqRange.location];
    NSString *val = [argument substringFromIndex:eqRange.location + 1];
    _buildSettings[key] = val;
  }
}

- (void)addUserDefault:(NSString *)argument
{
  // Skip the hyphen in the front.
  argument = [argument substringFromIndex:1];

  NSRange eqRange = [argument rangeOfString:@"="];

  if (eqRange.location != NSNotFound && eqRange.location > 0) {
    NSString *key = [argument substringToIndex:eqRange.location];
    NSString *val = [argument substringFromIndex:eqRange.location + 1];
    _userDefaults[key] = val;
  }
}

- (NSUInteger)consumeArguments:(NSMutableArray *)arguments errorMessage:(NSString **)errorMessage
{
  NSMutableDictionary *verbToClass = [NSMutableDictionary dictionary];
  for (Class actionClass in [Options actionClasses]) {
    NSString *actionName = [actionClass name];
    verbToClass[actionName] = actionClass;
  }

  NSUInteger consumed = 0;

  NSMutableArray *argumentList = [NSMutableArray arrayWithArray:arguments];
  while (argumentList.count > 0) {
    consumed += [super consumeArguments:argumentList errorMessage:errorMessage];

    if (argumentList.count == 0) {
      break;
    }

    NSString *argument = argumentList[0];
    [argumentList removeObjectAtIndex:0];
    consumed++;

    if (verbToClass[argument]) {
      Action *action = [[[verbToClass[argument] alloc] init] autorelease];
      consumed += [action consumeArguments:argumentList errorMessage:errorMessage];
      [self.actions addObject:action];
    } else {
      *errorMessage = [NSString stringWithFormat:@"Unexpected action: %@", argument];
      break;
    }
  }

  return consumed;
}

- (BOOL)validateReporterOptions:(NSString **)errorMessage
{
  for (NSString *reporterOption in _reporterOptions) {
    NSArray *optionParts = [reporterOption componentsSeparatedByString:@":"];
    NSString *nameOrPath = optionParts[0];
    NSString *outputFile = (optionParts.count > 1) ? optionParts[1] : @"-";

    NSString *reporterPath = nil;

    if ([[NSFileManager defaultManager] isExecutableFileAtPath:nameOrPath]) {
      // The argument might be the path to a reporter.
      reporterPath = nameOrPath;
    } else if ([[NSFileManager defaultManager] isExecutableFileAtPath:
                [XCToolReportersPath() stringByAppendingPathComponent:nameOrPath]]) {
      // Or, it could be the name of one of the built-in reporters.
      reporterPath = [XCToolReportersPath() stringByAppendingPathComponent:nameOrPath];
    } else {
      *errorMessage = [NSString stringWithFormat:
                       @"Reporter with name or path '%@' could not be found.",
                       nameOrPath];
      return NO;
    }

    ReporterTask *reporterTask =
    [[[ReporterTask alloc] initWithReporterPath:reporterPath
                                     outputPath:outputFile] autorelease];
    [self.reporters addObject:reporterTask];
  }

  if (self.reporters.count == 0) {
    ReporterTask *reporterTask =
    [[[ReporterTask alloc] initWithReporterPath:[XCToolReportersPath() stringByAppendingPathComponent:@"pretty"]
                                     outputPath:@"-"] autorelease];
    [self.reporters addObject:reporterTask];
  }

  return YES;
}

- (BOOL)validateAndReturnXcodeSubjectInfo:(XcodeSubjectInfo **)xcodeSubjectInfoOut
                             errorMessage:(NSString **)errorMessage
{
  BOOL (^isDirectory)(NSString *) = ^(NSString *path){
    BOOL isDirectory = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
    return (BOOL)(exists && isDirectory);
  };

  if (self.workspace == nil && self.project == nil && self.findTarget == nil) {
    *errorMessage = @"Either -workspace, -project, or -find-target must be specified.";
    return NO;
  } else if (self.workspace != nil && self.project != nil) {
    *errorMessage = @"Either -workspace or -project must be specified, but not both.";
    return NO;
  } else if (self.findTarget != nil && (self.workspace != nil || self.project != nil || self.scheme != nil)) {
    *errorMessage = @"If -find-target is specified, -workspace, -project, and -scheme must not be specified.";
    return NO;
  }

  if (self.findTargetPath != nil && self.findTarget == nil) {
    *errorMessage = @"If -find-target-path is specified, -find-target must be specified.";
    return NO;
  }

  if (self.findTarget != nil) {
    ReportStatusMessageBegin(_reporters,
                             REPORTER_MESSAGE_INFO,
                             @"Searching for target '%@' ...",
                             self.findTarget);

    XcodeTargetMatch *targetMatch;
    if (![XcodeSubjectInfo findTarget:self.findTarget
                          inDirectory:self.findTargetPath ?: @"."
                         excludePaths:self.findTargetExcludePaths ?: @[]
                      bestTargetMatch:&targetMatch]) {
      *errorMessage = [NSString stringWithFormat:@"Couldn't find workspace/project and scheme for target: %@", self.findTarget];
      return NO;
    }

    // If the current dir is '/a/b' and path is '/a/b/foo.txt', then return
    // 'foo.txt'.
    NSString *(^pathRelativeToCurrentDir)(NSString *) = ^(NSString *path){
      NSString *cwd = [[[NSFileManager defaultManager] currentDirectoryPath]
                       stringByAppendingString:@"/"];

      NSRange range = [path rangeOfString:cwd];

      if (range.location == 0 && range.length > 0) {
        path = [path stringByReplacingCharactersInRange:range withString:@""];
      }

      return path;
    };

    if (targetMatch.workspacePath) {
      ReportStatusMessageEnd(
        _reporters,
        REPORTER_MESSAGE_INFO,
        @"Found target %@. Using workspace path %@, scheme %@.",
        self.findTarget,
        pathRelativeToCurrentDir(targetMatch.workspacePath),
        targetMatch.schemeName);
    } else {
      ReportStatusMessageEnd(
        _reporters,
        REPORTER_MESSAGE_INFO,
        @"Found target %@. Using project path %@, scheme %@.",
        self.findTarget,
        pathRelativeToCurrentDir(targetMatch.projectPath),
        targetMatch.schemeName);
    }

    self.workspace = targetMatch.workspacePath;
    self.project = targetMatch.projectPath;
    self.scheme = targetMatch.schemeName;
  };

  if (self.scheme == nil) {
    *errorMessage = @"Missing the required -scheme argument.";
    return NO;
  }

  if (self.workspace != nil && !isDirectory(self.workspace)) {
    *errorMessage = [NSString stringWithFormat:@"Specified workspace doesn't exist: %@", self.workspace];
    return NO;
  }

  if (self.workspace != nil && ![[self.workspace pathExtension] isEqualToString:@"xcworkspace"]) {
    *errorMessage = [NSString stringWithFormat:@"Workspace must end in .xcworkspace: %@", self.workspace];
    return NO;
  }

  if (self.project != nil && !isDirectory(self.project)) {
    *errorMessage = [NSString stringWithFormat:@"Specified project doesn't exist: %@", self.project];
    return NO;
  }

  if (self.project != nil && ![[self.project pathExtension] isEqualToString:@"xcodeproj"]) {
    *errorMessage = [NSString stringWithFormat:@"Project must end in .xcodeproj: %@", self.project];
    return NO;
  }

  NSArray *schemePaths = nil;
  if (self.workspace != nil) {
    schemePaths = [XcodeSubjectInfo schemePathsInWorkspace:self.workspace];
  } else {
    schemePaths = [XcodeSubjectInfo schemePathsInContainer:self.project];
  }

  NSMutableArray *schemeNames = [NSMutableArray array];
  for (NSString *schemePath in schemePaths) {
    [schemeNames addObject:[[schemePath lastPathComponent] stringByDeletingPathExtension]];
  }

  BOOL automaticSchemeCreationDisabled = NO;

  {
    NSString *basePath = self.project != nil ? [self.project stringByAppendingPathComponent:@"project.xcworkspace"] : self.workspace;
    NSString *settingsPath = [basePath stringByAppendingPathComponent:@"xcshareddata/WorkspaceSettings.xcsettings"];
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:settingsPath];
    NSNumber *automaticSchemeCreationSetting = [settings objectForKey:@"IDEWorkspaceSharedSettings_AutocreateContextsIfNeeded"];

    if (automaticSchemeCreationSetting != nil && [automaticSchemeCreationSetting isKindOfClass:[NSNumber class]]) {
      automaticSchemeCreationDisabled = ![automaticSchemeCreationSetting boolValue];
    }
  }

  NSString *schemeCreationTip = @""
  @"\n\nTIP: This might happen if you're relying on Xcode to autocreate your schemes\n"
  @"and your scheme files don't yet exist.  xctool, like xcodebuild, isn't able to\n"
  @"automatically create schemes.  We recommend disabling \"Autocreate schemes\"\n"
  @"in your workspace/project, making sure your existing schemes are marked as\n"
  @"\"Shared\", and making sure they're checked into source control.";

  if ([schemeNames count] == 0) {
    *errorMessage = [NSString stringWithFormat:
                     @"Cannot find schemes. Please consider creating shared schemes in Xcode."];

    if (!automaticSchemeCreationDisabled) {
      *errorMessage = [*errorMessage stringByAppendingString:schemeCreationTip];
    }

    return NO;
  }

  if (![schemeNames containsObject:self.scheme]) {
    *errorMessage = [NSString stringWithFormat:
                     @"Can't find scheme '%@'.\n\nPossible schemes include:\n  %@",
                     self.scheme,
                     [schemeNames componentsJoinedByString:@"\n  "]];

    if (!automaticSchemeCreationDisabled) {
      *errorMessage = [*errorMessage stringByAppendingString:schemeCreationTip];
    }

    return NO;
  }

  if (self.sdk != nil) {
    NSDictionary *sdksAndAliases = GetAvailableSDKsAndAliases();

    // Is this an available SDK?
    if (sdksAndAliases[self.sdk] == nil) {
      *errorMessage = [NSString stringWithFormat:
                       @"SDK '%@' doesn't exist.  Possible SDKs include: %@",
                       self.sdk,
                       [[sdksAndAliases allKeys] componentsJoinedByString:@", "]];
      return NO;
    }

    // Map SDK param to actual SDK name.  This allows for aliases like 'iphoneos' to map
    // to 'iphoneos6.1'.
    self.sdk = sdksAndAliases[self.sdk];

    // Xcode 5's xcodebuild has a bug where it won't build targets for the
    // iphonesimulator SDK.  It fails with...
    //
    // warning: no rule to process file '... somefile.m' of type
    // sourcecode.c.objc for architecture i386
    //
    // Explicitly setting PLATFORM_NAME=iphonesimulator seems to fix it.
    if (_buildSettings[@"PLATFORM_NAME"] == nil &&
        [_sdk hasPrefix:@"iphonesimulator"]) {
      _buildSettings[@"PLATFORM_NAME"] = @"iphonesimulator";
    }
  }

  XcodeSubjectInfo *xcodeSubjectInfo = [[[XcodeSubjectInfo alloc] init] autorelease];
  xcodeSubjectInfo.subjectWorkspace = self.workspace;
  xcodeSubjectInfo.subjectProject = self.project;
  xcodeSubjectInfo.subjectScheme = self.scheme;

  if (xcodeSubjectInfoOut) {
    *xcodeSubjectInfoOut = xcodeSubjectInfo;
  }

  // We can pass nil for the scheme action since we don't care to use the
  // scheme's specific configuration.
  NSArray *commonXcodeBuildArguments = [self commonXcodeBuildArgumentsForSchemeAction:nil
                                                                     xcodeSubjectInfo:nil];
  xcodeSubjectInfo.subjectXcodeBuildArguments =
    [[self xcodeBuildArgumentsForSubject] arrayByAddingObjectsFromArray:commonXcodeBuildArguments];

  ReportStatusMessageBegin(_reporters, REPORTER_MESSAGE_INFO, @"Loading settings for scheme '%@' ...", _scheme);
  [xcodeSubjectInfo loadSubjectInfo];
  ReportStatusMessageEnd(_reporters, REPORTER_MESSAGE_INFO, @"Loading settings for scheme '%@' ...", _scheme);

  for (Action *action in self.actions) {
    BOOL valid = [action validateWithOptions:self
                            xcodeSubjectInfo:xcodeSubjectInfo
                                errorMessage:errorMessage];
    if (!valid) {
      return NO;
    }
  }

  // Assume build if no action is given.
  if (self.actions.count == 0) {
    [self.actions addObject:[[[BuildAction alloc] init] autorelease]];
  }

  return YES;
}

- (NSArray *)commonXcodeBuildArgumentsForSchemeAction:(NSString *)schemeAction
                                     xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo;
{
  NSMutableArray *arguments = [NSMutableArray array];

  NSString *effectiveConfigurationName =
  [self effectiveConfigurationForSchemeAction:schemeAction xcodeSubjectInfo:xcodeSubjectInfo];
  if (effectiveConfigurationName != nil) {
    [arguments addObjectsFromArray:@[@"-configuration", effectiveConfigurationName]];
  }

  if (self.sdk != nil) {
    [arguments addObjectsFromArray:@[@"-sdk", self.sdk]];
  }

  if (self.arch != nil) {
    [arguments addObjectsFromArray:@[@"-arch", self.arch]];
  }

  if (self.destination != nil) {
    [arguments addObjectsFromArray:@[@"-destination", self.destination]];
  }

  if (self.toolchain != nil) {
    [arguments addObjectsFromArray:@[@"-toolchain", self.toolchain]];
  }

  if (self.xcconfig != nil) {
    [arguments addObjectsFromArray:@[@"-xcconfig", self.xcconfig]];
  }

  if (self.jobs != nil) {
    [arguments addObjectsFromArray:@[@"-jobs", self.jobs]];
  }

  [_buildSettings enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
    [arguments addObject:[NSString stringWithFormat:@"%@=%@", key, obj]];
  }];

  [_userDefaults enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
    [arguments addObject:[NSString stringWithFormat:@"-%@=%@", key, obj]];
  }];

  return arguments;
}

- (NSString *)effectiveConfigurationForSchemeAction:(NSString *)schemeAction
                                   xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  if (_configuration != nil) {
    // The -configuration option from the command-line takes precedence.
    return _configuration;
  } else if (schemeAction && xcodeSubjectInfo) {
    return [xcodeSubjectInfo configurationNameForAction:schemeAction];
  } else {
    return nil;
  }
}

- (NSArray *)xcodeBuildArgumentsForSubject
{
  if (self.workspace != nil && self.scheme != nil) {
    return @[@"-workspace", self.workspace, @"-scheme", self.scheme];
  } else if (self.project != nil && self.scheme != nil) {
    return @[@"-project", self.project, @"-scheme", self.scheme];
  } else {
    NSLog(@"Should have either a workspace or a project.");
    abort();
  }
}

- (void)setFindTargetExcludePathsFromString:(NSString *)string
{
  self.findTargetExcludePaths = [string componentsSeparatedByString:@":"];
}

@end
