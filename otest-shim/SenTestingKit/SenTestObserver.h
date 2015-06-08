/*$Id: SenTestObserver.h,v 1.6 2005/04/02 03:18:21 phink Exp $*/

// Copyright (c) 1997-2005, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the following license:
// 
// Redistribution and use in source and binary forms, with or without modification, 
// are permitted provided that the following conditions are met:
// 
// (1) Redistributions of source code must retain the above copyright notice, 
// this list of conditions and the following disclaimer.
// 
// (2) Redistributions in binary form must reproduce the above copyright notice, 
// this list of conditions and the following disclaimer in the documentation 
// and/or other materials provided with the distribution.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS IS'' 
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
// IN NO EVENT SHALL Sente SA OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT 
// OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, 
// EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// 
// Note: this license is equivalent to the FreeBSD license.
// 
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>
#import <SenTestingKit/SenTestDefines.h>

@class SenTest;
@class SenTestRun;

@interface SenTestObserver : NSObject
{
}

+ (void) resumeObservation;
+ (void) suspendObservation;

+ (void) testSuiteDidStart:(NSNotification *) aNotification;
+ (void) testSuiteDidStop:(NSNotification *) aNotification;

+ (void) testCaseDidStart:(NSNotification *) aNotification;
+ (void) testCaseDidStop:(NSNotification *) aNotification;

+ (void) testCaseDidFail:(NSNotification *) aNotification;
@end

@interface NSNotification (SenTest)
- (SenTestRun *) run;
- (SenTest *) test;
- (NSException *) exception;
@end

// Setting the SenTestObserverClass user default to the name of a subclass of SenTestObserver indicates that OCUnit should use that subclass for reporting test results rather than the default, SenTestLog.  You can specify multiple subclasses of SenTestObserver by specifying a comma between each one, for example @"SenTestLog,SenTestDistributedNotifier".
SENTEST_EXPORT NSString * const SenTestObserverClassKey;
