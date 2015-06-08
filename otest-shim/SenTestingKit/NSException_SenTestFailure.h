/*$Id: NSException_SenTestFailure.h,v 1.10 2005/04/02 03:18:19 phink Exp $*/

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

@interface NSException (SenTestFailure)

- (NSString *) filename;
- (NSString *) filePathInProject;
- (NSNumber *) lineNumber;

+ (NSException *) failureInFile:(NSString *) filename atLine:(int) lineNumber withDescription:(NSString *) formatString, ...;
+ (NSException *) failureInCondition:(NSString *) condition isTrue:(BOOL) isTrue inFile:(NSString *) filename atLine:(int) lineNumber withDescription:(NSString *) formatString, ...;
+ (NSException *) failureInEqualityBetweenObject:(id) left andObject:(id) right  inFile:(NSString *) filename atLine:(int) lineNumber withDescription:(NSString *)formatString, ...;
+ (NSException *) failureInEqualityBetweenValue:(NSValue *) left andValue:(NSValue *) right withAccuracy:(NSValue *) accuracy inFile:(NSString *) filename atLine:(int) lineNumber withDescription:(NSString *)formatString, ...;
+ (NSException *) failureInRaise:(NSString *) expression inFile:(NSString *) filename atLine:(int) lineNumber withDescription:(NSString *)formatString, ...;
+ (NSException *) failureInRaise:(NSString *) expression exception:(NSException *) exception inFile:(NSString *) filename atLine:(int) lineNumber withDescription:(NSString *)formatString, ...;

@end


SENTEST_EXPORT NSString * const SenTestFailureException;

SENTEST_EXPORT NSString * const SenFailureTypeKey;

SENTEST_EXPORT NSString * const SenConditionFailure;
SENTEST_EXPORT NSString * const SenRaiseFailure;
SENTEST_EXPORT NSString * const SenEqualityFailure;
SENTEST_EXPORT NSString * const SenUnconditionalFailure;

SENTEST_EXPORT NSString * const SenTestConditionKey;
SENTEST_EXPORT NSString * const SenTestEqualityLeftKey;
SENTEST_EXPORT NSString * const SenTestEqualityRightKey;
SENTEST_EXPORT NSString * const SenTestEqualityAccuracyKey;
SENTEST_EXPORT NSString * const SenTestFilenameKey;
SENTEST_EXPORT NSString * const SenTestLineNumberKey;
SENTEST_EXPORT NSString * const SenTestDescriptionKey;
