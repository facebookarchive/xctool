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

#import "Options.h"

#import "AnalyzeAction.h"
#import "ArchiveAction.h"
#import "BuildAction.h"
#import "BuildTestsAction.h"
#import "CleanAction.h"
#import "InstallAction.h"
#import "ReportStatus.h"
#import "ReporterTask.h"
#import "RunTestsAction.h"
#import "SimulatorInfo.h"
#import "TestAction.h"
#import "TestRunning.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"
#import "XcodeSubjectInfo.h"
#import "XcodeTargetMatch.h"

@interface Options ()
@property (nonatomic, strong) NSMutableArray *reporterOptions;
@end

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
           [InstallAction class],
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
    [Action actionOptionWithName:@"resultBundlePath"
                         aliases:nil
                     description:@"path to bundle to write results from performing a build action"
                       paramName:@"PATH"
                           mapTo:@selector(setResultBundlePath:)],
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
                     description:@"alias or path to sdk to use for building (e.g. iphonesimulator, iphonesimulator8.4)"
                       paramName:@"ALIAS"
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
    [Action actionOptionWithName:@"destination-timeout"
                         aliases:nil
                     description:@"wait for TIMEOUT seconds while searching for the destination device"
                       paramName:@"DESTINATION-TIMEOUT"
                           mapTo:@selector(setDestinationTimeout:)],
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
    [Action actionOptionWithName:@"showTasks"
                         aliases:nil
                     description:@"show all tasks being spawned by xctool"
                         setFlag:@selector(setShowTasks:)],
    [Action actionOptionWithName:@"actionScripts"
                         aliases:nil
                     description:@"run pre and post action scripts defined in the scheme"
                         setFlag:@selector(setActionScripts:)],
    [Action actionOptionWithName:@"version"
                         aliases:@[@"v"]
                     description:@"print version and exit"
                         setFlag:@selector(setShowVersion:)],
    [Action actionOptionWithName:@"derivedDataPath"
                         aliases:nil
                     description:@"override the default derived data path"
                       paramName:@"PATH"
                           mapTo:@selector(setDerivedDataPath:)],
    [Action actionOptionWithName:@"launch-timeout"
                         aliases:nil
                     description:@"simulator launch timeout in seconds (default is 30 seconds)"
                       paramName:@"TIMEOUT"
                           mapTo:@selector(setLaunchTimeout:)],
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

- (instancetype)init
{
  if (self = [super init])
  {
    _reporters = [[NSMutableArray alloc] init];
    _reporterOptions = [[NSMutableArray alloc] init];
    _buildSettings = [[NSMutableDictionary alloc] init];
    _userDefaults = [[NSMutableDictionary alloc] init];
    _actions = [[NSMutableArray alloc] init];
  }
  return self;
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
      Action *action = [[verbToClass[argument] alloc] init];
      consumed += [action consumeArguments:argumentList errorMessage:errorMessage];
      [_actions addObject:action];
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
    [[ReporterTask alloc] initWithReporterPath:reporterPath
                                     outputPath:outputFile];
    [_reporters addObject:reporterTask];
  }

  if (_reporters.count == 0) {
    ReporterTask *reporterTask =
    [[ReporterTask alloc] initWithReporterPath:[XCToolReportersPath() stringByAppendingPathComponent:@"pretty"]
                                     outputPath:@"-"];
    [_reporters addObject:reporterTask];

    if (!IsRunningOnCISystem() && !IsRunningUnderTest()) {
      ReporterTask *userNotificationsReporterTask =
      [[ReporterTask alloc] initWithReporterPath:[XCToolReportersPath() stringByAppendingPathComponent:@"user-notifications"]
                                       outputPath:@"-"];
      [_reporters addObject:userNotificationsReporterTask];
    }
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

  if (![self _validateSdkWithErrorMessage:errorMessage]) {
    return NO;
  }

  if (![self _validateDestinationWithErrorMessage:errorMessage]) {
    return NO;
  }

  __block BOOL testsPresentInOptions = NO;
  [_actions enumerateObjectsUsingBlock:^(Action *action, NSUInteger idx, BOOL *stop) {
    if ([action conformsToProtocol:@protocol(TestRunning)]) {
      testsPresentInOptions = [(id<TestRunning>)action testsPresentInOptions];
      *stop = YES;
    }
  }];

  if (testsPresentInOptions && (_workspace || _project || _scheme)) {
    *errorMessage = @"If -logicTest or -appTest are specified, -workspace, -project, and -scheme must not be specified.";
    return NO;
  } else if (testsPresentInOptions) {
    *xcodeSubjectInfoOut = [[XcodeSubjectInfo alloc] init];
    return [self _validateActionsWithSubjectInfo:*xcodeSubjectInfoOut
                                    errorMessage:errorMessage];
  } else if (!_workspace && !_project && !_findTarget) {
    NSString *defaultProject = [self findDefaultProjectErrorMessage:errorMessage];
    if (!defaultProject) {
      return NO;
    } else {
      _project = defaultProject;
    }
  } else if (_workspace && _project) {
    *errorMessage = @"Either -workspace or -project can be specified, but not both.";
    return NO;
  } else if (_findTarget && (_workspace || _project || _scheme)) {
    *errorMessage = @"If -find-target is specified, -workspace, -project, and -scheme must not be specified.";
    return NO;
  }

  if (_findTargetPath && !_findTarget) {
    *errorMessage = @"If -find-target-path is specified, -find-target must be specified.";
    return NO;
  }

  if (_findTarget) {
    ReportStatusMessageBegin(_reporters,
                             REPORTER_MESSAGE_INFO,
                             @"Searching for target '%@' ...",
                             _findTarget);

    XcodeTargetMatch *targetMatch;
    if (![XcodeSubjectInfo findTarget:_findTarget
                          inDirectory:_findTargetPath ?: @"."
                         excludePaths:_findTargetExcludePaths ?: @[]
                      bestTargetMatch:&targetMatch]) {
      *errorMessage = [NSString stringWithFormat:@"Couldn't find workspace/project and scheme for target: %@", _findTarget];
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
        _findTarget,
        pathRelativeToCurrentDir(targetMatch.workspacePath),
        targetMatch.schemeName);
    } else {
      ReportStatusMessageEnd(
        _reporters,
        REPORTER_MESSAGE_INFO,
        @"Found target %@. Using project path %@, scheme %@.",
        _findTarget,
        pathRelativeToCurrentDir(targetMatch.projectPath),
        targetMatch.schemeName);
    }

    _workspace = targetMatch.workspacePath;
    _project = targetMatch.projectPath;
    _scheme = targetMatch.schemeName;
  };

  if (!_scheme) {
    *errorMessage = @"Missing the required -scheme argument.";
    return NO;
  }

  if (_workspace && !isDirectory(_workspace)) {
    *errorMessage = [NSString stringWithFormat:@"Specified workspace doesn't exist: %@", _workspace];
    return NO;
  }

  if (_workspace && ![[_workspace pathExtension] isEqualToString:@"xcworkspace"]) {
    *errorMessage = [NSString stringWithFormat:@"Workspace must end in .xcworkspace: %@", _workspace];
    return NO;
  }

  if (_project && !isDirectory(_project)) {
    *errorMessage = [NSString stringWithFormat:@"Specified project doesn't exist: %@", _project];
    return NO;
  }

  if (_project && ![[_project pathExtension] isEqualToString:@"xcodeproj"]) {
    *errorMessage = [NSString stringWithFormat:@"Project must end in .xcodeproj: %@", _project];
    return NO;
  }

  if (_resultBundlePath) {
    BOOL isDirectory = NO;
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:_resultBundlePath isDirectory:&isDirectory];
    if (!isDirectory) {
      NSString *errorReason = fileExists ? @"must be a directory" : @"doesn't exist";
      *errorMessage = [NSString stringWithFormat:@"Specified result bundle path %@: %@", errorReason, _resultBundlePath];
      return NO;
    }
  }

  NSArray *schemePaths = nil;
  if (_workspace) {
    schemePaths = [XcodeSubjectInfo schemePathsInWorkspace:_workspace];
  } else {
    schemePaths = [XcodeSubjectInfo schemePathsInContainer:_project];
  }

  NSMutableArray *schemeNames = [NSMutableArray array];
  for (NSString *schemePath in schemePaths) {
    [schemeNames addObject:[[schemePath lastPathComponent] stringByDeletingPathExtension]];
  }

  BOOL automaticSchemeCreationDisabled = NO;

  {
    NSString *basePath = _project ? [_project stringByAppendingPathComponent:@"project.xcworkspace"] : _workspace;
    NSString *settingsPath = [basePath stringByAppendingPathComponent:@"xcshareddata/WorkspaceSettings.xcsettings"];
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:settingsPath];
    NSNumber *automaticSchemeCreationSetting = settings[@"IDEWorkspaceSharedSettings_AutocreateContextsIfNeeded"];

    if (automaticSchemeCreationSetting && [automaticSchemeCreationSetting isKindOfClass:[NSNumber class]]) {
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

  if (![schemeNames containsObject:_scheme]) {
    *errorMessage = [NSString stringWithFormat:
                     @"Can't find scheme '%@'.\n\nPossible schemes include:\n  %@",
                     _scheme,
                     [schemeNames componentsJoinedByString:@"\n  "]];

    if (!automaticSchemeCreationDisabled) {
      *errorMessage = [*errorMessage stringByAppendingString:schemeCreationTip];
    }

    return NO;
  }

  XcodeSubjectInfo *xcodeSubjectInfo = [[XcodeSubjectInfo alloc] init];
  xcodeSubjectInfo.subjectWorkspace = _workspace;
  xcodeSubjectInfo.subjectProject = _project;
  xcodeSubjectInfo.subjectScheme = _scheme;

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

  return [self _validateActionsWithSubjectInfo:xcodeSubjectInfo
                                  errorMessage:errorMessage];
}

- (BOOL)_validateSdkWithErrorMessage:(NSString **)errorMessage {
  NSDictionary *sdksAndAliases = nil;
  if (_sdk) {
    NSDictionary *sdkInfo = GetAvailableSDKsInfo();
    sdksAndAliases = GetAvailableSDKsAndAliasesWithSDKInfo(sdkInfo);

    // Is this an available SDK?
    if (!sdksAndAliases[_sdk]) {
      *errorMessage = [NSString stringWithFormat:
                       @"SDK '%@' doesn't exist.  Possible SDKs include: %@",
                       _sdk,
                       [[sdksAndAliases allKeys] componentsJoinedByString:@", "]];
      return NO;
    }

    // Map SDK param to actual SDK name.  This allows for aliases like 'iphoneos' to map
    // to 'iphoneos6.1'.
    _sdk = sdksAndAliases[_sdk];
    _sdkPath = sdkInfo[_sdk][@"Path"];
    _platformPath = sdkInfo[_sdk][@"PlatformPath"];

    // Xcode 5's xcodebuild has a bug where it won't build targets for the
    // iphonesimulator SDK.  It fails with...
    //
    // warning: no rule to process file '... somefile.m' of type
    // sourcecode.c.objc for architecture i386
    //
    // Explicitly setting PLATFORM_NAME=iphonesimulator seems to fix it.
    //
    // This also works around a bug in Xcode 7.2, where it seems to not
    // set the platform correctly when -sdk is provided. Setting the
    // platform name manually works to correct the platform it picks.
    if (!_buildSettings[Xcode_PLATFORM_NAME]) {
      NSString *platformName = [[[_platformPath lastPathComponent] stringByDeletingPathExtension] lowercaseString];
      _buildSettings[Xcode_PLATFORM_NAME] = platformName;
    }
  }
  return YES;
}

- (BOOL)_validateDestinationWithErrorMessage:(NSString **)errorMessage {
  if (_destination) {
    NSDictionary *destInfo = ParseDestinationString(_destination, errorMessage);

    NSString *deviceID = destInfo[@"id"];
    NSString *deviceName = destInfo[@"name"];
    NSString *deviceOS = destInfo[@"OS"];

    if (deviceID) {
      NSUUID *udid = [[NSUUID alloc] initWithUUIDString:deviceID];
      if ([SimulatorInfo deviceWithUDID:udid]) {
        if (deviceName || deviceOS) {
          *errorMessage = @"If device id is specified, name or OS must not be specified.";
          return NO;
        } else {
          return YES;
        }
      } else {
        *errorMessage = [NSString stringWithFormat:@"'%@' isn't a valid device id.", deviceID];
        return NO;
      }
    }

    if (deviceName) {
      NSString *deviceSystemName = [SimulatorInfo deviceNameForAlias:deviceName];
      if (![deviceName isEqual:deviceSystemName] &&
          deviceSystemName) {
        ReportStatusMessage(_reporters, REPORTER_MESSAGE_WARNING,
                            @"Device name '%@' is not directly supported by xcodebuild. Replacing it with '%@'.", deviceName, deviceSystemName);
        _destination = [_destination stringByReplacingOccurrencesOfString:deviceName withString:deviceSystemName];
        deviceName = deviceSystemName;
      }
      if (![SimulatorInfo isDeviceAvailableWithAlias:deviceName]) {
        *errorMessage = [NSString stringWithFormat:
                         @"'%@' isn't a valid device name. The valid device names are: %@.",
                         deviceName, [SimulatorInfo availableDevices]];
        return NO;
      }
    }

    if (deviceOS && deviceName) {
      if (![SimulatorInfo isSdkVersion:deviceOS supportedByDevice:deviceName]) {
        *errorMessage = [NSString stringWithFormat:
                         @"Device with name '%@' doesn't support iOS version '%@'. The supported iOS versions are: %@.",
                         deviceName, deviceOS, [SimulatorInfo sdksSupportedByDevice:deviceName]];
        return NO;
      }
    }
  }

  return YES;
}

- (BOOL)_validateActionsWithSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
                           errorMessage:(NSString **)errorMessage {
  for (Action *action in _actions) {
    BOOL valid = [action validateWithOptions:self
                            xcodeSubjectInfo:xcodeSubjectInfo
                                errorMessage:errorMessage];
    if (!valid) {
      return NO;
    }
  }

  // Assume build if no action is given.
  if (_actions.count == 0) {
    [_actions addObject:[[BuildAction alloc] init]];
  }

  return YES;
}

- (NSArray *)commonXcodeBuildArgumentsForSchemeAction:(NSString *)schemeAction
                                     xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo;
{
  NSMutableArray *arguments = [NSMutableArray array];

  NSString *effectiveConfigurationName =
  [self effectiveConfigurationForSchemeAction:schemeAction xcodeSubjectInfo:xcodeSubjectInfo];
  if (effectiveConfigurationName) {
    [arguments addObjectsFromArray:@[@"-configuration", effectiveConfigurationName]];
  }

  if (_sdk) {
    [arguments addObjectsFromArray:@[@"-sdk", _sdk]];
  }

  if (_arch) {
    [arguments addObjectsFromArray:@[@"-arch", _arch]];
  }

  if (_destination) {
    [arguments addObjectsFromArray:@[@"-destination", _destination]];
    if (!_destinationTimeout) {
      _destinationTimeout = @"10";
    }
  }

  if (_destinationTimeout) {
    [arguments addObjectsFromArray:@[@"-destination-timeout", _destinationTimeout]];
  }

  if (_toolchain) {
    [arguments addObjectsFromArray:@[@"-toolchain", _toolchain]];
  }

  if (_xcconfig) {
    [arguments addObjectsFromArray:@[@"-xcconfig", _xcconfig]];
  }

  if (_jobs) {
    [arguments addObjectsFromArray:@[@"-jobs", _jobs]];
  }

  if (_resultBundlePath) {
    [arguments addObjectsFromArray:@[@"-resultBundlePath", _resultBundlePath]];
  }

  [_buildSettings enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
    [arguments addObject:[NSString stringWithFormat:@"%@=%@", key, obj]];
  }];

  [_userDefaults enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
    [arguments addObject:[NSString stringWithFormat:@"-%@=%@", key, obj]];
  }];

  if (_launchTimeout) {
    _buildSettings[Xcode_LAUNCH_TIMEOUT] = _launchTimeout;
  }

  return arguments;
}

- (NSString *)effectiveConfigurationForSchemeAction:(NSString *)schemeAction
                                   xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
{
  if (_configuration) {
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
  NSArray *buildArgs;

  if (_workspace && _scheme) {
    buildArgs = @[@"-workspace", _workspace, @"-scheme", _scheme];
  } else if (_project && _scheme) {
    buildArgs = @[@"-project", _project, @"-scheme", _scheme];
  } else {
    NSLog(@"Should have either a workspace or a project.");
    abort();
  }

  if (_derivedDataPath) {
    return [buildArgs arrayByAddingObjectsFromArray:@[ @"-derivedDataPath", _derivedDataPath ]];
  }
  return buildArgs;
}

- (void)setFindTargetExcludePathsFromString:(NSString *)string
{
  _findTargetExcludePaths = [string componentsSeparatedByString:@":"];
}

- (NSString*)findDefaultProjectErrorMessage:(NSString**) errorMessage
{
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *searchPath = _findProjectPath ? : [fileManager currentDirectoryPath];
  NSArray *directoryContents = [fileManager contentsOfDirectoryAtPath:searchPath error:nil];
  NSArray *projectFiles = [directoryContents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension == 'xcodeproj'"]];
  if (projectFiles.count == 1) {
    return [searchPath stringByAppendingPathComponent:projectFiles[0]];
  } else if (projectFiles.count > 1) {
    *errorMessage = [NSString stringWithFormat:@"The directory %@ contains %lu projects, including multiple projects with the current extension (.xcodeproj). Please specify with -workspace, -project, or -find-target.", searchPath, projectFiles.count];
  } else {
    *errorMessage = [NSString stringWithFormat:@"Unable to find projects (.xcodeproj) in directory %@. Please specify with -workspace, -project, or -find-target.", searchPath];
  }
  return nil;
}

- (NSString*)description
{
  return [NSString stringWithFormat:@"%@\n"
          "workspace: %@\n"
          "project: %@\n"
          "scheme: %@\n"
          "configuration: %@\n"
          "sdk: %@\n"
          "arch: %@\n"
          "destination: %@\n"
          "toolchain: %@\n"
          "xcconfig: %@\n"
          "jobs: %@\n"
          "findTarget: %@\n"
          "findTargetPath: %@\n"
          "findProjectPath: %@",
          [super description],
          _workspace,
          _project,
          _scheme,
          _configuration,
          _sdk,
          _arch,
          _destination,
          _toolchain,
          _xcconfig,
          _jobs,
          _findTarget,
          _findTargetPath,
          _findProjectPath];
}

@end
