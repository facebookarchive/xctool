// Copyright 2004-present Facebook. All Rights Reserved.


#import <Foundation/Foundation.h>

/**
 * In the event that an OCUnit test crashes, we never get the usual stream of events
 * from the test runner - it just dies!  OCUnitCrashFilter helps in this case by generating
 * the final stream of events to signal that the crashing test failed (shielding the Reporters
 * from having to deal with this complexity).
 */
@interface OCUnitCrashFilter : NSObject
{
}

@property (nonatomic, retain) NSDictionary *currentTestEvent;
@property (nonatomic, assign) CFTimeInterval currentTestEventTimestamp;
// Test suites are nested, so we have to keep a stack of them.
@property (nonatomic, retain) NSMutableArray *currentTestSuiteEventStack;
@property (nonatomic, retain) NSMutableArray *currentTestSuiteEventTimestampStack;
@property (nonatomic, retain) NSMutableArray *currentTestSuiteEventTestCountStack;
@property (nonatomic, retain) NSMutableString *currentTestOutput;

- (void)handleEvent:(NSDictionary *)event;
- (void)fireEventsToSimulateTestRunFinishing:(NSArray *)reporters;

@end
