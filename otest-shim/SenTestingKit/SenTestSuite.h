/*$Id: SenTestSuite.h,v 1.8 2005/04/02 03:18:22 phink Exp $*/

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

#import <SenTestingKit/SenTest.h>
#import <SenTestingKit/SenTestCase.h>
#import <Foundation/Foundation.h>

/*"A TestSuite is a Composite of Tests. It runs a collection of test cases. Here is an example using the dynamic test definition.

!{
 SenTestSuite *suite= [SenTestSuite testSuiteWithName:@"My tests"];
 [suite addTest: [MathTest testCaseWithSelector:@selector(testAdd)]];
 [suite addTest: [MathTest testCaseWithSelector:@selector(testDivideByZero)]];
}

Alternatively, a TestSuite can extract the tests to be run automatically. To do so you pass the class of your TestCase class to the TestSuite constructor. 

!{
 SenTestSuite *suite= [SenTestSuite testSuiteForTestCaseClass:[MathTest class]];
}

This  creates a suite with all the methods starting with "test" that take no arguments. 


And finally, a TestSuite of all the test cases found in the runtime can be created automatically:

!{
 SenTestSuite *suite = [SenTestSuite defaultTestSuite];
}

This  creates a suite of suites with all the SenTestCase subclasses methods starting with "test" that take no arguments. 

"*/

@interface SenTestSuite : SenTest <NSCoding>
{
    @private
    NSString *name;
    NSMutableArray *tests;
}

+ (id) defaultTestSuite;
+ (id) testSuiteForBundlePath:(NSString *) bundlePath;
+ (id) testSuiteForTestCaseWithName:(NSString *) aName;
+ (id) testSuiteForTestCaseClass:(Class) aClass;

+ (id) testSuiteWithName:(NSString *) aName;
- (id) initWithName:(NSString *) aName;

- (void) addTest:(SenTest *) aTest;
- (void) addTestsEnumeratedBy:(NSEnumerator *) anEnumerator;
@end

@interface SenTestCase (SenTestSuiteExtensions)
+ (void) setUp;
+ (void) tearDown;
@end

