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

#import <SenTestingKit/SenTestingKit.h>

#import "HeaderCopyDatabaseReporter.h"
#import "Reporter+Testing.h"

@interface HeaderCopyDatabaseReporterTests : SenTestCase
@end

@implementation HeaderCopyDatabaseReporterTests

- (void)testGoodBuild
{
  NSData *outputData = [HeaderCopyDatabaseReporter
                        outputDataWithEventsFromFile:TEST_DATA @"xcodebuild-archive-good.txt"];

  // Note: In general the file would contain several lines "{ key : value }".
  NSUInteger c = 0;
  for (int i = 0; i < [outputData length]; i++) {
    if (((char *)outputData.bytes)[i] == '\n') {
      c++;
    }
  }
  STAssertEquals((NSUInteger)1, c, @"expecting one line");

  NSError *jsonSerializationError;
  id jsonObject = [NSJSONSerialization JSONObjectWithData:outputData options:0 error:&jsonSerializationError];
  STAssertNotNil(jsonObject, @"cannot deserialize events file %@", jsonSerializationError.localizedDescription);

  STAssertTrue([jsonObject isKindOfClass:[NSDictionary class]], @"header copy database json object should be a dictionary");
  NSDictionary *jsonDict = (NSDictionary *)jsonObject;

  STAssertEquals((NSUInteger)1, [jsonDict count], @"expecting one entry in the dictionary.");
  // Note that we include all copied objects. What we have here is not a header.
  STAssertEqualObjects([jsonDict objectForKey:
    @"/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-App-OSX-ejhuwpipipihzubmntcipqbqtwct/Build/\
Intermediates/ArchiveIntermediates/TestProject-App-OSX/InstallationBuildProductsLocation/Applications/\
TestProject-App-OSX.app/Contents/Resources/en.lproj/Credits.rtf"],
    @"/Users/fpotter/xctool/xctool/xctool-tests/TestData/TestProject-App-OSX/TestProject-App-OSX/en.lproj/Credits.rtf",
    @"expecting a different entry");
}

@end
