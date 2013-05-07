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

#import "ArchiveAction.h"
#import "BuildAction.h"
#import "BuildTestsAction.h"
#import "CleanAction.h"
#import "Reporter.h"
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
                         aliases:nil
                     description:@"print version and exit"
                         setFlag:@selector(setShowVersion:)],
    [Action actionOptionWithMatcher:^(NSString *argument){
      // Anything that looks like KEY=VALUE - xcodebuild will accept options like this.
      return (BOOL)([argument rangeOfString:@"="].length > 0 ? YES : NO);
    }
                        description:@"Set the build 'setting' to 'value'"
                          paramName:@"SETTING=VALUE"
                              mapTo:@selector(addBuildSetting:)],
    ];
}

- (id)init
{
  if (self = [super init])
  {
    self.reporters = [NSMutableArray array];
    _reporterOptions = [[NSMutableArray alloc] init];
    self.buildSettings = [NSMutableArray array];
    self.actions = [NSMutableArray array];
  }
  return self;
}

- (void)dealloc
{
  [_reporterOptions release];
  self.reporters = nil;
  self.buildSettings = nil;
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
  [self.buildSettings addObject:argument];
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
    NSString *name = optionParts[0];
    NSString *outputFile = (optionParts.count > 1) ? optionParts[1] : @"-";

    Reporter *reporter = [Reporter reporterWithName:name outputPath:outputFile options:self];

    if (reporter == nil) {
      *errorMessage = [NSString stringWithFormat:@"No reporter with name '%@' found.", name];
      return NO;
    }

    [self.reporters addObject:reporter];
  }

  if (self.reporters.count == 0) {
    [self.reporters addObject:[Reporter reporterWithName:@"pretty" outputPath:@"-" options:self]];
  }

  return YES;
}

- (BOOL)validateOptions:(NSString **)errorMessage
          xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
         options:(Options *)options
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
    XcodeTargetMatch *targetMatch;
    if (![XcodeSubjectInfo findTarget:self.findTarget
                          inDirectory:self.findTargetPath ?: @"."
                         excludePaths:self.findTargetExcludePaths ?: @[]
                      bestTargetMatch:&targetMatch]) {
      *errorMessage = [NSString stringWithFormat:@"Couldn't find workspace/project and scheme for target: %@", self.findTarget];
      return NO;
    }

    if (targetMatch.workspacePath) {
      ReportMessage(REPORTER_MESSAGE_INFO,
        @"Found target %@. Using workspace path %@, scheme %@.",
        self.findTarget, targetMatch.workspacePath, targetMatch.schemeName);
    } else {
      ReportMessage(REPORTER_MESSAGE_INFO,
        @"Found target %@. Using project path %@, scheme %@.",
        self.findTarget, targetMatch.projectPath, targetMatch.schemeName);
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

  if (self.project != nil && !isDirectory(self.project)) {
    *errorMessage = [NSString stringWithFormat:@"Specified project doesn't exist: %@", self.project];
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

  if (![schemeNames containsObject:self.scheme]) {
    *errorMessage = [NSString stringWithFormat:
                     @"Can't find scheme '%@'. Possible schemes include: %@",
                     self.scheme,
                     [schemeNames componentsJoinedByString:@", "]];
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
  }

  xcodeSubjectInfo.subjectWorkspace = self.workspace;
  xcodeSubjectInfo.subjectProject = self.project;
  xcodeSubjectInfo.subjectScheme = self.scheme;
  xcodeSubjectInfo.subjectXcodeBuildArguments = [self xcodeBuildArgumentsForSubject];

  if (self.sdk == nil) {
    BOOL valid = YES;
    for (Action *action in self.actions) {
      if (![action validateSDK:xcodeSubjectInfo.sdkName]) {
        valid = NO;
        break;
      }
    }

    if (valid) {
      self.sdk = xcodeSubjectInfo.sdkName;
    } else {
      if ([xcodeSubjectInfo.sdkName hasPrefix:@"iphone"]) {
        // Tests can't (currently) be run on iphoneos, so fall back
        // from device to i386 simulator.
        //
        // TODO: If a device is connected, it'd be nice to allow
        // running tests on it.
        self.sdk = @"iphonesimulator";
        self.arch = @"i386";
      } else {
        *errorMessage =
          [NSString stringWithFormat:@"Cannot perform action[s] with SDK %@ specified by target.",
                    xcodeSubjectInfo.sdkName];
        return NO;
      }
    }
  }

  if (self.configuration == nil) {
    self.configuration = xcodeSubjectInfo.configuration;
  }

  for (Action *action in self.actions) {
    BOOL valid = [action validateOptions:errorMessage xcodeSubjectInfo:xcodeSubjectInfo options:self];
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

- (NSArray *)commonXcodeBuildArgumentsIncludingSDK:(BOOL)includingSDK
{
  NSMutableArray *arguments = [NSMutableArray array];

  if (self.configuration != nil) {
    [arguments addObjectsFromArray:@[@"-configuration", self.configuration]];
  }

  if (self.sdk != nil && includingSDK) {
    [arguments addObjectsFromArray:@[@"-sdk", self.sdk]];
  }

  if (self.arch != nil) {
    [arguments addObjectsFromArray:@[@"-arch", self.arch]];
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

  [arguments addObjectsFromArray:self.buildSettings];

  return arguments;
}

- (NSArray *)commonXcodeBuildArguments
{
  return [self commonXcodeBuildArgumentsIncludingSDK:YES];
}

- (NSArray *)xcodeBuildArgumentsForSubject
{
  // The subject being the thing we're building or testing, which is a workspace/scheme combo
  // or a project/scheme combo.
  NSMutableArray *arguments = [NSMutableArray array];

  if (self.workspace != nil && self.scheme != nil) {
    [arguments addObjectsFromArray:@[@"-workspace", self.workspace, @"-scheme", self.scheme]];
  } else if (self.project != nil && self.scheme != nil) {
    [arguments addObjectsFromArray:@[@"-project", self.project, @"-scheme", self.scheme]];
  }

  [arguments addObjectsFromArray:[self commonXcodeBuildArguments]];

  return arguments;
}

- (void)setFindTargetExcludePathsFromString:(NSString *)string
{
  self.findTargetExcludePaths = [string componentsSeparatedByString:@":"];
}

@end
