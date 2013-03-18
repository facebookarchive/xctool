
#import "XcodeSubjectInfo.h"
#import "Functions.h"

@implementation XcodeSubjectInfo

+ (NSArray *)projectPathsInWorkspace:(NSString *)workspacePath
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

+ (NSArray *)schemePathsInWorkspace:(NSString *)workspace
{
  NSMutableArray *schemes = [NSMutableArray array];
  
  for (NSString *projectPath in [XcodeSubjectInfo projectPathsInWorkspace:workspace]) {
    [schemes addObjectsFromArray:[XcodeSubjectInfo schemePathsInContainer:projectPath]];
  }
  
  [schemes addObjectsFromArray:[XcodeSubjectInfo schemePathsInContainer:workspace]];

  return schemes;
}

+ (NSArray *)schemePathsInContainer:(NSString *)project
{
  NSMutableArray *schemes = [NSMutableArray array];
  NSFileManager *fm = [NSFileManager defaultManager];
  
  // Collect shared schemes (those that have 'Shared' checked in the Schemes Manager).
  NSString *sharedSchemesPath = [project stringByAppendingPathComponent:@"xcshareddata/xcschemes"];
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
  NSString *userdataPath = [project stringByAppendingPathComponent:@"xcuserdata"];
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

- (void)dealloc
{
  self.sdkName = nil;
  self.objRoot = nil;
  self.symRoot = nil;
  self.configuration = nil;
  self.testables = nil;
  self.buildablesForTest = nil;
  [super dealloc];
}

- (NSArray *)testablesInSchemePath:(NSString *)schemePath basePath:(NSString *)basePath
{
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
    
    NSString *projectPath = [basePath stringByAppendingPathComponent:[referencedContainer substringFromIndex:@"container:".length]];
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

- (NSArray *)buildablesForTestInSchemePath:(NSString *)schemePath basePath:(NSString *)basePath
{
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
    
    NSString *projectPath = [basePath stringByAppendingPathComponent:[referencedContainer substringFromIndex:@"container:".length]];
    assert([[NSFileManager defaultManager] fileExistsAtPath:projectPath]);
    
    NSString *target = [[buildableReference attributeForName:@"BlueprintName"] stringValue];
    
    [buildables addObject:@{
     @"projectPath" : projectPath,
     @"target": target,
     }];
  }
  
  return buildables;
}

- (void)populate
{
  if (_didPopulate) {
    return;
  }
  
  assert(self.subjectXcodeBuildArguments != nil);
  assert(self.subjectScheme != nil);
  assert(self.subjectWorkspace != nil || self.subjectProject != nil);
  
  // First we need to know the OBJROOT and SYMROOT settings for the project we're testing.
  NSTask *task = TaskInstance();
  [task setLaunchPath:[XcodeDeveloperDirPath() stringByAppendingPathComponent:@"usr/bin/xcodebuild"]];
  [task setArguments:[self.subjectXcodeBuildArguments arrayByAddingObject:@"-showBuildSettings"]];
  [task setEnvironment:@{
   @"DYLD_INSERT_LIBRARIES" : [PathToFBXcodeTestBinaries() stringByAppendingPathComponent:@"xcodebuild-fastsettings-lib.dylib"],
   @"SHOW_ONLY_BUILD_SETTINGS_FOR_FIRST_BUILDABLE" : @"YES"
   }];
  
  NSDictionary *result = LaunchTaskAndCaptureOutput(task);
  NSDictionary *settings = BuildSettingsFromOutput(result[@"stdout"]);
  
  assert(settings.count == 1);
  NSDictionary *firstBuildable = [settings allValues][0];
  // The following control where our build output goes - we need to make sure we build the tests
  // in the same places as we built the original products - this is what Xcode does.
  self.objRoot = firstBuildable[@"OBJROOT"];
  self.symRoot = firstBuildable[@"SYMROOT"];
  self.sdkName = firstBuildable[@"SDK_NAME"];
  self.configuration = firstBuildable[@"CONFIGURATION"];
  
  NSString *(^basePathFromSchemePath)(NSString *) = ^(NSString *schemePath){
    for (;;) {
      assert(schemePath.length > 0);
      
      if ([schemePath hasSuffix:@".xcodeproj"] || [schemePath hasSuffix:@".xcworkspace"]) {
        schemePath = [schemePath stringByDeletingLastPathComponent];
        break;
      }
      
      schemePath = [schemePath stringByDeletingLastPathComponent];
    }
    return schemePath;
  };
  
  if (self.subjectWorkspace) {
    NSString *matchingSchemePath = nil;
    NSArray *schemePaths = [XcodeSubjectInfo schemePathsInWorkspace:self.subjectWorkspace];
    for (NSString *schemePath in schemePaths) {
      if ([schemePath hasSuffix:[NSString stringWithFormat:@"/%@.xcscheme", self.subjectScheme]]) {
        matchingSchemePath = schemePath;
      }
    }
    
    NSSet *projectPathsInWorkspace = [NSSet setWithArray:[XcodeSubjectInfo projectPathsInWorkspace:self.subjectWorkspace]];
    
    NSArray *(^itemsMatchingProjectPath)(NSArray *) = ^(NSArray *items) {
      NSMutableArray *newItems = [NSMutableArray array];
      for (NSDictionary *item in items) {
        if ([projectPathsInWorkspace containsObject:item[@"projectPath"]]) {
          [newItems addObject:item];
        }
      }
      return newItems;
    };
    
    NSArray *testables = [self testablesInSchemePath:matchingSchemePath
                                        basePath:basePathFromSchemePath(matchingSchemePath)];
    NSArray *buildablesForTest = [self buildablesForTestInSchemePath:matchingSchemePath
                                                        basePath:basePathFromSchemePath(matchingSchemePath)];
    
    // It's possible that the scheme references projects that aren't part of the workspace.  When
    // Xcode encounters these, it just skips them so we'll do the same.
    self.testables = itemsMatchingProjectPath(testables);
    self.buildablesForTest = itemsMatchingProjectPath(buildablesForTest);
  } else {
    NSString *matchingSchemePath = nil;
    NSArray *schemePaths = [XcodeSubjectInfo schemePathsInContainer:self.subjectProject];
    for (NSString *schemePath in schemePaths) {
      if ([schemePath hasSuffix:[NSString stringWithFormat:@"/%@.xcscheme", self.subjectScheme]]) {
        matchingSchemePath = schemePath;
      }
    }
    
    self.testables = [self testablesInSchemePath:matchingSchemePath
                                        basePath:basePathFromSchemePath(matchingSchemePath)];
    self.buildablesForTest = [self buildablesForTestInSchemePath:matchingSchemePath
                                                        basePath:basePathFromSchemePath(matchingSchemePath)];
  }
  
  _didPopulate = YES;
}

- (NSDictionary *)testableWithTarget:(NSString *)target
{
  for (NSDictionary *testable in self.testables) {
    NSString *testableTarget = testable[@"target"];
    if ([testableTarget isEqualToString:target]) {
      return testable;
    }
  }
  return nil;
}

- (NSString *)sdkName
{
  [self populate];
  return _sdkName;
}

- (NSString *)objRoot
{
  [self populate];
  return _objRoot;
}

- (NSString *)symRoot
{
  [self populate];
  return _symRoot;
}

- (NSString *)configuration
{
  [self populate];
  return _configuration;
}

- (NSArray *)testables
{
  [self populate];
  return _testables;
}

- (NSArray *)buildablesForTest
{
  [self populate];
  return _buildablesForTest;
}

@end
