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

#import <Foundation/Foundation.h>

@interface FakeTask : NSTask
{
  int _fakeExitStatus;
  NSString *_fakeStandardOutputPath;
  NSString *_fakeStandardErrorPath;
}

@property (nonatomic, retain) NSString *launchPath;
@property (nonatomic, retain) NSArray *arguments;
@property (nonatomic, retain) NSDictionary *environment;
@property (nonatomic, retain) id standardOutput;
@property (nonatomic, retain) id standardError;
@property (nonatomic, assign) int terminationStatus;
@property (nonatomic, assign) BOOL isRunning;

+ (NSTask *)fakeTaskWithExitStatus:(int)exitStatus
                standardOutputPath:(NSString *)standardOutputPath
                 standardErrorPath:(NSString *)standardErrorPath;

+ (NSTask *)fakeTaskWithExitStatus:(int)exitStatus;

@end
