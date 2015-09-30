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

#import <Foundation/Foundation.h>

@interface Reporter : NSObject
{
@protected
  NSFileHandle *_outputHandle;
}

+ (void)readFromInput:(NSFileHandle *)inputHandle
          andOutputTo:(NSFileHandle *)outputHandle;

/**
 Called before any events are processed, right after the process starts.
 */
- (void)willBeginReporting;

/**
 Called after all events have been processed, once we've received an EOF
 from xctool and just before we exit.
 */
- (void)didFinishReporting;

- (void)parseAndHandleEvent:(NSString *)event;
- (void)handleEvent:(NSDictionary *)event;

- (void)beginAction:(NSDictionary *)event;
- (void)endAction:(NSDictionary *)event;
- (void)beginBuildTarget:(NSDictionary *)event;
- (void)endBuildTarget:(NSDictionary *)event;
- (void)beginBuildCommand:(NSDictionary *)event;
- (void)endBuildCommand:(NSDictionary *)event;
- (void)beginXcodebuild:(NSDictionary *)event;
- (void)endXcodebuild:(NSDictionary *)event;
- (void)beginOcunit:(NSDictionary *)event;
- (void)endOcunit:(NSDictionary *)event;
- (void)beginTestSuite:(NSDictionary *)event;
- (void)endTestSuite:(NSDictionary *)event;
- (void)beginTest:(NSDictionary *)event;
- (void)endTest:(NSDictionary *)event;
- (void)testOutput:(NSDictionary *)event;
- (void)simulatorOutput:(NSDictionary *)event;
- (void)beginStatus:(NSDictionary *)event;
- (void)endStatus:(NSDictionary *)event;
- (void)analyzerResult:(NSDictionary *)event;

@end
