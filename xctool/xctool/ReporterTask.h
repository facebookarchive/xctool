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

#import "EventSink.h"

@interface ReporterTask : NSObject <EventSink>

@property (nonatomic, copy, readonly) NSString *reporterPath;

/**
 @param string Path to reporter executable.
 @param string Path to save output of reporter.  Can be "-" for stdout.
 */
- (instancetype)initWithReporterPath:(NSString *)reporterPath
                          outputPath:(NSString *)outputPath;

/**
 To be called before any action is run.
 */
- (BOOL)openWithStandardOutput:(NSFileHandle *)standardOutput
                 standardError:(NSFileHandle *)standardError
                         error:(NSString **)error;

/**
 To be called just before xctool exits.
 */
- (void)close;

@end
