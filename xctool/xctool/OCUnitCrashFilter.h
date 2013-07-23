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
 * In the event that an OCUnit test crashes, we never get the usual stream of events
 * from the test runner - it just dies!  OCUnitCrashFilter helps in this case by generating
 * the final stream of events to signal that the crashing test failed (shielding the Reporters
 * from having to deal with this complexity).
 */
@interface OCUnitCrashFilter : NSObject <EventSink>
{
}

@property (nonatomic, retain) NSDictionary *currentTestEvent;
@property (nonatomic, assign) CFTimeInterval currentTestEventTimestamp;
// Test suites are nested, so we have to keep a stack of them.
@property (nonatomic, retain) NSMutableArray *currentTestSuiteEventStack;
@property (nonatomic, retain) NSMutableArray *currentTestSuiteEventTimestampStack;
@property (nonatomic, retain) NSMutableArray *currentTestSuiteEventTestCountStack;
@property (nonatomic, retain) NSMutableString *currentTestOutput;
@property (nonatomic, retain) NSDictionary *lastTestEvent;

- (void)fireEventsToSimulateTestRunFinishing:(NSArray *)reporters
                             fullProductName:(NSString *)fullProductName
                    concatenatedCrashReports:(NSString *)concatenatedCrashReports;
- (BOOL)testRunWasUnfinished;

@end
