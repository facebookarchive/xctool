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


#import "OCUnitIOSDeviceTestRunner.h"

#import "TaskUtil.h"

@implementation OCUnitIOSDeviceTestRunner

- (void)runTestsAndFeedOutputTo:(FdOutputLineFeedBlock)outputLineBlock
                   startupError:(NSString **)startupError
                    otherErrors:(NSString **)otherErrors
{
  // Just a place holder.  The plumbing for 'run-tests' expects each SDK to have
  // an associated test runner.
  *startupError = @"Testing with the 'iphoneos' SDK is not yet supported.  Instead, "
                  @"test with the simulator SDK by setting '-sdk iphonesimulator'.";
}

@end
