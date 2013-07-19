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

#import "EventSink.h"

/**
 A short name for the reporter, to be used with the -reporter argument.
 */
NSString *const kReporterInfoNameKey;

/**
 A short description for the reporter, to be shown in xctool's usage.
 */
NSString *const kReporterInfoDescriptionKey;

@class Action;
@class Options;

@interface Reporter : NSObject <EventSink>
{
  NSFileHandle *_outputHandle;
}

// The reporter will stream output to here.  Usually this will be "-" to route
// to standard out, but it might point to a file if the -reporter param
// specified an output path.
@property (nonatomic, retain) NSString *outputPath;
@property (nonatomic, readonly) NSFileHandle *outputHandle;

// Handler methods for different event types.
// Messages are routed to these methods via handleEvent, and should not be
// invoked directly.
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
- (void)beginStatus:(NSDictionary *)event;
- (void)endStatus:(NSDictionary *)event;
- (void)analyzerResult:(NSDictionary *)event;

/**
 To be called before any action is run.
 */
- (BOOL)openWithStandardOutput:(NSFileHandle *)standardOutput error:(NSString **)error;

/**
 To be called just before xctool exits.
 */
- (void)close;

@end
