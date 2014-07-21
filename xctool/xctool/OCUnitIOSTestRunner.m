//
// Copyright 2014 Facebook
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

#import "OCUnitIOSTestRunner.h"

#import "SimulatorInfo.h"
#import "SimulatorWrapper.h"

@implementation OCUnitIOSTestRunner

- (void)updateSimulatorInfo
{
  if (!_simulatorInfo) {
    self.simulatorInfo = [SimulatorInfo infoForCurrentVersionOfXcode];
  }
  _simulatorInfo.cpuType = _cpuType;
  _simulatorInfo.deviceName = _deviceName;
  _simulatorInfo.OSVersion = _OSVersion;
  _simulatorInfo.buildSettings = _buildSettings;
}

- (SimulatorInfo *)simulatorInfo
{
  [self updateSimulatorInfo];
  return _simulatorInfo;
}


@end
