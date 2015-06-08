/*$Id: SenTestRun.h,v 1.7 2005/04/02 03:18:22 phink Exp $*/

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

#import <Foundation/NSObject.h>
#import <SenTestingKit/SenTest.h>

/*"A TestResult collects the results of executing a test. The test framework distinguishes between %failures which are anticipated and checked for problems like a test that failed; and %{unexpected failures} which are unforeseen (catastrophic) problems, like an exception.
"*/

@interface SenTestRun : NSObject <NSCoding>
{
    @private
    NSTimeInterval startDate;
    NSTimeInterval stopDate;
    SenTest * test;
}

+ (id) testRunWithTest:(SenTest *) aTest;
- (id) initWithTest:(SenTest *) aTest;

- (SenTest *) test;

- (void) start;
- (void) stop;

- (NSDate *) startDate;
- (NSDate *) stopDate;
- (NSTimeInterval) totalDuration; 
- (NSTimeInterval) testDuration;

- (unsigned int) testCaseCount;

- (unsigned int) failureCount;
- (unsigned int) unexpectedExceptionCount;
- (unsigned int) totalFailureCount;
- (BOOL) hasSucceeded;

- (void) postNotificationName:(NSString *) aNotification userInfo:(NSDictionary *) aUserInfo; 
- (void) postNotificationName:(NSString *) aNotification;

@end
