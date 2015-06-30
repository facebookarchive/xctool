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

#import "ActionScripts.h"
#import "EventGenerator.h"
#import "ReportStatus.h"
#import "TaskUtil.h"
#import "XCToolUtil.h"

@interface ActionScriptInfo ()

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *shell;
@property (nonatomic, copy) NSString *body;

@end

@implementation ActionScriptInfo

+ (instancetype)scriptInfoFromElement:(NSXMLElement *)node
{
  NSString *type = [[node attributeForName:@"ActionType"] stringValue];
  // we only support shell script actions
  if (![type isEqualToString:@"Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction"]) {
    return nil;
  }

  NSXMLElement *content = [[node elementsForName:@"ActionContent"] firstObject];
  if (!content) {
    return nil;
  }

  NSString *title = [[content attributeForName:@"title"] stringValue];
  NSString *script = [[content attributeForName:@"scriptText"] stringValue];
  if (!script) {
    return nil;
  }

  NSString *shell = [[content attributeForName:@"shellToInvoke"] stringValue];
  if (!shell) {
    // This is the default shell
    shell = @"/bin/sh";
  }

  ActionScriptInfo *info = [ActionScriptInfo new];
  [info setTitle:title];
  [info setBody:script];
  [info setShell:shell];

  return info;
}

@end

@interface ActionScript ()
@property (nonatomic, copy) NSArray *preScripts;
@property (nonatomic, copy) NSArray *postScripts;
@end

@implementation ActionScript

+ (NSArray *)bracketingScriptFromElement:(NSXMLElement *)node byType:(NSString *)type
{
  NSMutableArray *scripts = [NSMutableArray new];
  NSArray *actions = [node elementsForName:type];

  if ([actions count] == 0) {
    return nil;
  }

  NSAssert([actions count] == 1, @"expected only one action");
  NSXMLElement *action = [actions firstObject];

  NSArray *executionList = [action elementsForName:@"ExecutionAction"];

  for (NSXMLElement *execution in executionList) {
    ActionScriptInfo *script = [ActionScriptInfo scriptInfoFromElement:execution];
    if (script) {
      [scripts addObject:script];
    }
  }

  if (scripts.count) {
    return scripts;
  }

  return nil;
}

+ (instancetype)actionFromDoc:(NSXMLDocument *)doc byName:(NSString *)name error:(NSError **)error
{
  NSArray *actions = [doc nodesForXPath:name error:error];
  if (!actions) {
    return nil;
  }

  if ([actions count] == 0) {
    return nil;
  }

  NSAssert([actions count] == 1, @"expecting only one action: %@", name);

  NSXMLElement *action = [actions firstObject];

  NSArray *pre = [ActionScript bracketingScriptFromElement:action byType:@"PreActions"];
  NSArray *post = [ActionScript bracketingScriptFromElement:action byType:@"PostActions"];

  if (!(pre || post)) {
    return nil;
  }

  ActionScript *as = [ActionScript new];
  if (!as) {
    return nil;
  }

  [as setPreScripts:pre];
  [as setPostScripts:post];

  return as;
}

+ (void)runScripts:(NSArray *)scripts options:(Options *)options environment:(NSDictionary *)env
{
  for (ActionScriptInfo *script in scripts) {
    NSTask *task = CreateTaskInSameProcessGroup();
    NSString *desc = [NSString stringWithFormat:@"Running: %@", script.title];

    [task setLaunchPath:script.shell];
    [task setArguments:@[ @"-c", script.body]];
    [task setEnvironment:env];

    NSString *out = LaunchTaskAndCaptureOutputInCombinedStream(task, desc);
    PublishEventToReporters(options.reporters,
      EventDictionaryWithNameAndContent(@"ActionScript", @{
        kReporter_TestOutput_OutputKey: out
        }));
  }
}

@end

@interface ActionScripts ()
@property (nonatomic, copy) NSDictionary *environment;
@property (nonatomic, strong) ActionScript *build;
@property (nonatomic, strong) ActionScript *run;
@property (nonatomic, strong) ActionScript *test;
@property (nonatomic, strong) ActionScript *profile;
@property (nonatomic, strong) ActionScript *analyze;
@property (nonatomic, strong) ActionScript *archive;
@end

@implementation ActionScripts

/**
 *  The environment passed in is not sufficient to run most scripts.
 *  This function allows additional environment variables to be specified or
 *  modified.
 *
 *  @param oldEnv current environment of the tool
 *
 *  @return expanded environment after tweeking
 */
+ (NSDictionary *)fixupScriptEnvironment:(NSDictionary *)oldEnv
{
  NSDictionary *procEnv = [[NSProcessInfo processInfo] environment];
  NSMutableDictionary *env = [oldEnv mutableCopy];

  env[@"PATH"] = [NSString stringWithFormat:@"%@:%@", oldEnv[@"PATH"], procEnv[@"PATH"]];

  return env;
}

- (instancetype)initWithSchemePath:(NSString *)schemePath environment:(NSDictionary *)env error:(NSError **)error
{
  self = [super init];
  if (!self) {
    return nil;
  }

  NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:schemePath]
                                                            options:0
                                                              error:error];
  if (!doc) {
    return nil;
  }

  if (!(_build = [ActionScript actionFromDoc:doc byName:@"//BuildAction" error:error]) && *error) {
    return nil;
  }
  if (!(_run = [ActionScript actionFromDoc:doc byName:@"//RunAction" error:error]) && *error) {
    return nil;
  }
  if (!(_test = [ActionScript actionFromDoc:doc byName:@"//TestAction" error:error]) && *error) {
    return nil;
  }

  // This is not accessible from xctool at the moment
  if (!(_profile = [ActionScript actionFromDoc:doc byName:@"//ProfileAction" error:error]) && *error) {
    return nil;
  }

  // Analyze actually uses the build action scripts
  if (!(_analyze = [ActionScript actionFromDoc:doc byName:@"//BuildAction" error:error]) && *error) {
    return nil;
  }
  if (!(_archive = [ActionScript actionFromDoc:doc byName:@"//ArchiveAction" error:error]) && *error) {
    return nil;
  }

  // fill out environment
  _environment = [[[self class] fixupScriptEnvironment:env] copy];

  return self;
}

- (void)runPreScripts:(ActionScript *)scripts type:(NSString*)type options:(Options *)options
{
  if (!scripts) {
    return;
  }

  if (!options.actionScripts) {
    return;
  }

  ReportStatusMessageBegin(options.reporters, REPORTER_MESSAGE_INFO,
                           @"Running PreAction %@ Scripts...", type);

  [ActionScript runScripts:scripts.preScripts options:options environment:_environment];

  ReportStatusMessageEnd(options.reporters, REPORTER_MESSAGE_INFO,
                         @"Running PreAction %@ Scripts...", type);

}

- (void)runPostScripts:(ActionScript *)scripts type:(NSString*)type options:(Options *)options
{
  if (!scripts) {
    return;
  }

  if (!options.actionScripts) {
    return;
  }

  ReportStatusMessageBegin(options.reporters, REPORTER_MESSAGE_INFO,
                           @"Running PostAction %@ Scripts...", type);

  [ActionScript runScripts:scripts.postScripts options:options environment:_environment];

  ReportStatusMessageEnd(options.reporters, REPORTER_MESSAGE_INFO,
                         @"Running PostAction %@ Scripts...", type);

}

- (void)preBuildWithOptions:(Options *)options
{
  return [self runPreScripts:self.build type:@"build" options:options];
}

- (void)postBuildWithOptions:(Options *)options
{
  return [self runPostScripts:self.build type:@"build" options:options];
}

- (void)preRunWithOptions:(Options *)options
{
  return [self runPreScripts:self.run type:@"run" options:options];
}

- (void)postRunWithOptions:(Options *)options
{
  return [self runPostScripts:self.run type:@"run" options:options];
}

- (void)preTestWithOptions:(Options *)options
{
  return [self runPreScripts:self.test type:@"test" options:options];
}

- (void)postTestWithOptions:(Options *)options
{
  return [self runPostScripts:self.test type:@"test" options:options];
}

- (void)preProfileWithOptions:(Options *)options
{
  return [self runPreScripts:self.profile type:@"profile" options:options];
}

- (void)postProfileWithOptions:(Options *)options
{
  return [self runPostScripts:self.profile type:@"profile" options:options];
}

- (void)preAnalyzeWithOptions:(Options *)options
{
  return [self runPreScripts:self.analyze type:@"analyze" options:options];
}

- (void)postAnalyzeWithOptions:(Options *)options
{
  return [self runPostScripts:self.analyze type:@"analyze" options:options];
}

- (void)preArchiveWithOptions:(Options *)options
{
  return [self runPreScripts:self.archive type:@"archive" options:options];
}

- (void)postArchiveWithOptions:(Options *)options
{
  return [self runPostScripts:self.archive type:@"archive" options:options];
}

@end
