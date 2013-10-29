//
//  KWProbePoller.m
//  iOSFalconCore
//
//  Created by Luke Redpath on 13/01/2011.
//  Copyright 2011 LJR Software Limited. All rights reserved.
//

#import "KWProbePoller.h"

@interface KWTimeout : NSObject

@property (nonatomic, strong) NSDate *timeoutDate;

@end

@implementation KWTimeout

- (id)initWithTimeout:(NSTimeInterval)timeout
{
    self = [super init];
    if (self) {
        _timeoutDate = [[NSDate alloc] initWithTimeIntervalSinceNow:timeout];
    }
    return self;
}


- (BOOL)hasTimedOut {
    return [self.timeoutDate timeIntervalSinceDate:[NSDate date]] < 0;
}

@end


@interface KWProbePoller()

@property (nonatomic, assign) NSTimeInterval timeoutInterval;
@property (nonatomic, assign) NSTimeInterval delayInterval;
@property (nonatomic, assign) BOOL shouldWait;

@end

@implementation KWProbePoller

- (id)initWithTimeout:(NSTimeInterval)theTimeout
                delay:(NSTimeInterval)theDelay
           shouldWait:(BOOL)wait {
    self = [super init];
    if (self) {
        _timeoutInterval = theTimeout;
        _delayInterval = theDelay;
        _shouldWait = wait;
    }
    return self;
}

- (BOOL)check:(id<KWProbe>)probe; {
    KWTimeout *timeout = [[KWTimeout alloc] initWithTimeout:self.timeoutInterval];
    
    while (self.shouldWait || ![probe isSatisfied]) {
        if ([timeout hasTimedOut]) {
            return [probe isSatisfied];
        }
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:self.delayInterval]];
        [probe sample];
    }
    
    return YES;
}

@end
