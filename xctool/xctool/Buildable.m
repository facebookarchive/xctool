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

#import "Buildable.h"

@implementation Buildable

- (id)copyWithZone:(NSZone *)zone
{
  Buildable *copy = [[[self class] allocWithZone:zone] init];

  if (copy) {
    copy.projectPath = _projectPath;
    copy.target = _target;
    copy.targetID = _targetID;
    copy.executable = _executable;
    copy.buildForRunning = _buildForRunning;
    copy.buildForTesting = _buildForTesting;
    copy.buildForAnalyzing = _buildForAnalyzing;
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
          bothNilOrEqual(_projectPath, other.projectPath) &&
          bothNilOrEqual(_target, other.target) &&
          bothNilOrEqual(_targetID, other.targetID) &&
          bothNilOrEqual(_executable, other.executable) &&
          _buildForRunning == other.buildForRunning &&
          _buildForTesting == other.buildForTesting &&
          _buildForAnalyzing == other.buildForAnalyzing);
}

- (NSUInteger)hash
{
  return ([_projectPath hash] ^
          [_target hash] ^
          [_targetID hash] ^
          [_executable hash] ^
          _buildForRunning ^
          _buildForTesting ^
          _buildForAnalyzing);
}


@end
