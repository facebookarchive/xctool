
#import "ImplicitAction.h"
#import "Reporter.h"
#import "Functions.h"
#import "XcodeSubjectInfo.h"
#import "BuildAction.h"
#import "CleanAction.h"
#import "BuildTestsAction.h"
#import "RunTestsAction.h"

@implementation ImplicitAction

+ (NSArray *)actionClasses
{
  return @[@[@"clean", [CleanAction class]],
           @[@"build", [BuildAction class]],
           @[@"build-tests", [BuildTestsAction class]],
           @[@"run-tests", [RunTestsAction class]],
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
                     description:@"sheme to use for building or testing"
                       paramName:@"NAME"
                           mapTo:@selector(setScheme:)],
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
    self.buildSettings = [NSMutableArray array];
    self.actions = [NSMutableArray array];
  }
  return self;
}

- (void)addReporter:(NSString *)argument
{
  NSArray *argumentParts = [argument componentsSeparatedByString:@":"];
  NSString *name = argumentParts[0];
  NSString *outputFile = (argumentParts.count > 1) ? argumentParts[1] : @"-";
  
  [self.reporters addObject:[Reporter reporterWithName:name outputPath:outputFile]];
}

- (void)addBuildSetting:(NSString *)argument
{
  [self.buildSettings addObject:argument];
}

- (NSUInteger)consumeArguments:(NSMutableArray *)arguments errorMessage:(NSString **)errorMessage
{
  NSMutableDictionary *verbToClass = [NSMutableDictionary dictionary];
  for (NSArray *verbAndClass in [ImplicitAction actionClasses]) {
    verbToClass[verbAndClass[0]] = verbAndClass[1];
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

//  if (![self.implicitAction validateOptions:errorMessage xcodeSubjectInfo:xcodeSubjectInfo implicitAction:nil]) {
//    return NO;
//  }
//
//  for (Action *action in self.actions) {
//    BOOL valid = [action validateOptions:errorMessage xcodeSubjectInfo:xcodeSubjectInfo implicitAction:self.implicitAction];
//    if (!valid) {
//      return NO;
//    }
//  }
//
//  // Assume build if no action is given.
//  if (self.actions.count == 0) {
//    [self.actions addObject:[[[BuildAction alloc] init] autorelease]];
//  }
//
//  return YES;


- (BOOL)validateOptions:(NSString **)errorMessage
          xcodeSubjectInfo:(XcodeSubjectInfo *)xcodeSubjectInfo
         implicitAction:(ImplicitAction *)implicitAction
{
  BOOL (^isDirectory)(NSString *) = ^(NSString *path){
    BOOL isDirectory = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
    return (BOOL)(exists && isDirectory);
  };

  if (self.workspace == nil && self.project == nil) {
    *errorMessage = @"Either -workspace or -project must be specified.";
    return NO;
  } else if (self.workspace != nil && self.project != nil) {
    *errorMessage = @"Either -workspace or -project must be specified, but not both.";
    return NO;
  }
  
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
    NSArray *SDKs = GetAvailableSDKs();
    if (![SDKs containsObject:self.sdk]) {
      *errorMessage = [NSString stringWithFormat:
                       @"SDK '%@' doesn't exist.  Possible SDKs include: %@",
                       self.sdk,
                       [SDKs componentsJoinedByString:@", "]];
      return NO;
    }
  }
  
  xcodeSubjectInfo.subjectWorkspace = self.workspace;
  xcodeSubjectInfo.subjectProject = self.project;
  xcodeSubjectInfo.subjectScheme = self.scheme;
  xcodeSubjectInfo.subjectXcodeBuildArguments = [self xcodeBuildArgumentsForSubject];
  
  if (self.sdk == nil) {
    self.sdk = xcodeSubjectInfo.sdkName;
  }
  
  if (self.configuration == nil) {
    self.configuration = xcodeSubjectInfo.configuration;
  }
  
  if (self.reporters.count == 0) {
    [self.reporters addObject:[Reporter reporterWithName:@"pretty" outputPath:@"-"]];
  }
  
  for (Action *action in self.actions) {
    BOOL valid = [action validateOptions:errorMessage xcodeSubjectInfo:xcodeSubjectInfo implicitAction:self];
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

@end
