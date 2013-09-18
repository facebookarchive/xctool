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

#import "TestingFramework.h"

NSString *const kTestingFrameworkClassName = @"class";
NSString *const kTestingFrameworkAllTestsSelectorName = @"selector";

NSDictionary *FrameworkInfoForExtension(NSString *extension)
{
  static NSDictionary *frameworks = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    frameworks = @{
      @"octest": @{
        kTestingFrameworkClassName: @"SenTestCase",
        kTestingFrameworkAllTestsSelectorName: @"senAllSubclasses",
      },
      @"xctest": @{
        kTestingFrameworkClassName: @"XCTestCase",
        kTestingFrameworkAllTestsSelectorName: @"xct_allSubclasses",
      }
    };
    [frameworks retain];
  });
  if (![[frameworks allKeys] containsObject:extension]) {
    NSLog(@"The bundle extension %@ is not supported. The supported extensions are: %@.",
          extension, [frameworks allKeys]);
    return nil;
  }
  return [frameworks objectForKey:extension];
}

NSDictionary *FrameworkInfoForTestBundleAtPath (NSString *path)
{
  NSString *extension = [path pathExtension];
  return FrameworkInfoForExtension(extension);
}