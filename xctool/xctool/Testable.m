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

#import "Testable.h"

@implementation Testable

- (id)copyWithZone:(NSZone *)zone
{
  Testable *copy = [super copyWithZone:zone];

  if (copy) {
    copy.senTestList = self.senTestList;
    copy.senTestInvertScope = self.senTestInvertScope;
    copy.skipped = self.skipped;
    copy.arguments = self.arguments;
    copy.environment = self.environment;
    copy.macroExpansionProjectPath = self.macroExpansionProjectPath;
    copy.macroExpansionTarget = self.macroExpansionTarget;
  }

  return copy;
}

- (BOOL)isEqual:(Testable *)other
{
  BOOL (^bothNilOrEqual)(id, id) = ^(id a, id b) {
    if (a == nil && b == nil) {
      return YES;
    } else {
      return [a isEqual:b];
    }
  };

  return ([super isEqual:other] &&
          [other isKindOfClass:[Testable class]] &&
          bothNilOrEqual(self.senTestList, other.senTestList) &&
          self.senTestInvertScope == other.senTestInvertScope &&
          self.skipped == other.skipped &&
          bothNilOrEqual(self.arguments, other.arguments) &&
          bothNilOrEqual(self.environment, other.environment) &&
          bothNilOrEqual(self.macroExpansionProjectPath, other.macroExpansionProjectPath) &&
          bothNilOrEqual(self.macroExpansionTarget, other.macroExpansionTarget));
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
