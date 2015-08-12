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

#import <XCTest/XCTest.h>

#import "PbxprojReader.h"

@interface PbxprojReaderTests : XCTestCase

@end

@implementation PbxprojReaderTests

- (void)testProjectThatHasManyNestedProjectsIncludingOneWithNonEmptyProjectDir
{
  NSString *projectPath = TEST_DATA "TestProject-RecursiveProjectsAndSchemes/TestProject-RecursiveProjectsAndSchemes.xcodeproj";
  NSSet *set = ProjectFilesReferencedInProjectAtPath(projectPath);
  assertThat(set, equalTo([NSSet setWithArray:@[
    TEST_DATA "TestProject-RecursiveProjectsAndSchemes/InternalProjectLibraryA/InternalProjectLibraryA.xcodeproj",
    TEST_DATA "TestProject-RecursiveProjectsAndSchemes/TestProject-RecursiveProjectsAndSchemes/OtherProjects/InternalProjectLibraryB/InternalProjectLibraryB.xcodeproj",
    TEST_DATA "TestProject-RecursiveProjectsAndSchemes/InternalProjectLibraryC/HideProjectFolder/WhyNotMore/InternalProjectLibraryC.xcodeproj",
  ]]));
}

- (void)testSimpleProject
{
  NSString *projectPath = TEST_DATA "TestProject-App-OSX/TestProject-App-OSX.xcodeproj";
  NSSet *set = ProjectFilesReferencedInProjectAtPath(projectPath);
  assertThat(set, equalTo([NSSet setWithArray:@[]]));
}

@end
