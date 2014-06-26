//
//  SimulatorWrapperInternal.h
//  xctool
//
//  Created by Aleksey Kononov on 6/25/14.
//  Copyright (c) 2014 Facebook, Inc. All rights reserved.
//

#import "SimulatorWrapper.h"

@class DTiPhoneSimulatorSessionConfig;
@class SimulatorInfo;

@interface SimulatorWrapper (Internal)
+ (DTiPhoneSimulatorSessionConfig *)sessionConfigForRunningTestsOnSimulator:(SimulatorInfo *)simInfo
                                                      applicationLaunchArgs:(NSArray *)launchArgs
                                               applicationLaunchEnvironment:(NSDictionary *)launchEnvironment
                                                                 outputPath:(NSString *)outputPath;
@end
