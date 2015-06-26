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

#import "TestResultCounter.h"

@implementation TestResultCounter

- (void)suiteBegin {
  _suitePassed = 0;
  _suiteFailed = 0;
  _suiteErrored = 0;
  _suiteTotal = 0;
}

- (void)suiteEnd {
  _actionPassed += _suitePassed;
  _actionFailed += _suiteFailed;
  _actionErrored += _suiteErrored;
  _actionTotal += _suiteTotal;
}

- (void)testPassed {
  _suitePassed++;
  _suiteTotal++;
}

- (void)testFailed {
  _suiteFailed++;
  _suiteTotal++;
}

- (void)testErrored {
  _suiteErrored++;
  _suiteTotal++;
}

@end
