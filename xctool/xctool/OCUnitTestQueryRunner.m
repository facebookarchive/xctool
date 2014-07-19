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

#import "OCUnitTestQueryRunner.h"

#import "TaskUtil.h"
#import "XCToolUtil.h"
#import "XcodeBuildSettings.h"

@interface OCUnitTestQueryRunner ()
@property (nonatomic, copy) NSDictionary *buildSettings;
@property (nonatomic, assign) cpu_type_t cpuType;
@end

@implementation OCUnitTestQueryRunner

// Designated initializer.
- (instancetype)initWithBuildSettings:(NSDictionary *)buildSettings
                          withCpuType:(cpu_type_t)cpuType
{
  if (self = [super init]) {
    _buildSettings = [buildSettings copy];
    _cpuType = cpuType;
  }
  return self;
}

- (void)dealloc
{
  [_buildSettings release];
  [super dealloc];
}

- (NSString *)bundlePath
{
  NSString *builtProductsDir = _buildSettings[Xcode_BUILT_PRODUCTS_DIR];
  NSString *fullProductName = _buildSettings[Xcode_FULL_PRODUCT_NAME];
  NSString *bundlePath = [builtProductsDir stringByAppendingPathComponent:fullProductName];
  return bundlePath;
}

- (NSString *)testHostPath
{
  // TEST_HOST will sometimes be wrapped in "quotes".
  NSString *testHost = [_buildSettings[Xcode_TEST_HOST]
                        stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
  return testHost;
}

- (NSTask *)createTaskForQuery NS_RETURNS_RETAINED
{
  return nil;
}

- (void)prepareToRunQuery
{
}

- (NSArray *)runQueryWithError:(NSString **)error
{
  BOOL bundleIsDir = NO;
  BOOL bundleExists = [[NSFileManager defaultManager] fileExistsAtPath:[self bundlePath] isDirectory:&bundleIsDir];
  if (!IsRunningUnderTest() && !(bundleExists && bundleIsDir)) {
    *error = [NSString stringWithFormat:@"Test bundle not found at: %@", [self bundlePath]];
    return nil;
  }

  if ([self testHostPath]) {
    if (![[NSFileManager defaultManager] isExecutableFileAtPath:[self testHostPath]]) {
      *error = [NSString stringWithFormat:@"The test host executable is missing: '%@'", [self testHostPath]];
      return nil;
    }
  }

  [self prepareToRunQuery];

  NSTask *task = [self createTaskForQuery];
  NSDictionary *output = LaunchTaskAndCaptureOutput(task, @"running otest-query");

  int terminationStatus = [task terminationStatus];
  [task release];
  task = nil;

  if (terminationStatus != 0) {
    *error = output[@"stderr"];
    return nil;
  } else {
    NSString *jsonOutput = output[@"stdout"];

    NSError *parseError = nil;
    NSArray *list = [NSJSONSerialization JSONObjectWithData:[jsonOutput dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:0
                                                      error:&parseError];
    if (list) {
      return list;
    } else {
      *error = [NSString stringWithFormat:@"Error while parsing JSON: %@: %@",
                [parseError localizedFailureReason],
                output];
      return nil;
    }
  }
}

@end
