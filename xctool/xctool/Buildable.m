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

#import "Buildable.h"

@implementation Buildable

- (id)copyWithZone:(NSZone *)zone
{
  Buildable *copy = [[[self class] allocWithZone:zone] init];

  if (copy) {
    copy.projectPath = self.projectPath;
    copy.target = self.target;
    copy.targetID = self.targetID;
    copy.executable = self.executable;
    copy.buildForRunning = self.buildForRunning;
    copy.buildForTesting = self.buildForTesting;
    copy.buildForAnalyzing = self.buildForAnalyzing;
  }

  return copy;
}

- (BOOL)isEqual:(Buildable *)other
{
  BOOL (^bothNilOrEqual)(id, id) = ^(id a, id b) {
    if (a == nil && b == nil) {
      return YES;
    } else {
      return [a isEqual:b];
    }
  };

  return ([other isKindOfClass:[Buildable class]] &&
          bothNilOrEqual(self.projectPath, other.projectPath) &&
          bothNilOrEqual(self.target, other.target) &&
          bothNilOrEqual(self.targetID, other.targetID) &&
          bothNilOrEqual(self.executable, other.executable) &&
          self.buildForRunning == other.buildForRunning &&
          self.buildForTesting == other.buildForTesting &&
          self.buildForAnalyzing == other.buildForAnalyzing);
}

- (NSUInteger)hash
{
  return ([self.projectPath hash] ^
          [self.target hash] ^
          [self.targetID hash] ^
          [self.executable hash] ^
          self.buildForRunning ^
          self.buildForTesting ^
          self.buildForAnalyzing);
}

@end
