/*$Id: SenTestCase_Macros.h,v 1.27 2005/04/02 03:17:52 phink Exp $"*/

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

#import <SenTestingKit/SenTestingUtilities.h>

#if !defined(SENTEST_IGNORE_DEPRECATION_WARNING)
#warning OCUnit (SenTestingKit) is deprecated, please convert to XCTest.
#endif

#undef STFail

#undef STAssertNil

#undef STAssertNotNil

#undef STAssertTrue

#undef STAssertFalse

#undef STAssertEquals
#undef STAssertEqualObjects
#undef STAssertEqualsWithAccuracy

#undef STAssertThrows
#undef STAssertThrowsSpecific
#undef STAssertThrowsSpecificNamed

#undef STAssertNoThrow
#undef STAssertNoThrowSpecific
#undef STAssertNoThrowSpecificNamed

#undef STAssertTrueNoThrow

#undef STAssertFalseNoThrow

/* 
    The following macros are deprecated.  If you have code that uses them and you
    don't wish to migrate to the modern macros immediately, add the following line
    before importing this header or any header that imports it:
    
    #define STEnableDeprecatedAssertionMacros 1
 */
#ifdef STEnableDeprecatedAssertionMacros
#undef fail
#undef fail1
#undef should
#undef should1
#undef shouldnt
#undef shouldnt1
#undef shouldBeEqual
#undef shouldBeEqual1
#undef shouldRaise
#undef shouldRaise1
#undef shouldntRaise
#undef shouldntRaise1
#undef shouldnoraise
#undef should1noraise
#undef shouldntnoraise
#undef shouldnt1noraise
#endif /* STEnableDeprecatedAssertionMacros */

/*" Generates a failure when !{ [a1 isEqualTo:a2] } is false 
    (or one is nil and the other is not). 
    _{a1    The object on the left.}
    _{a2    The object on the right.}
    _{description A format string as in the printf() function. Can be nil or
        an empty string but must be present.}
    _{... A variable number of arguments to the format string. Can be absent.}
"*/
#define STAssertEqualObjects(a1, a2, description, ...) \
do { \
    @try {\
        id a1value = (a1); \
            id a2value = (a2); \
                if (a1value != a2value) { \
                    if ( (strcmp(@encode(__typeof__(a1value)), @encode(id)) == 0) && \
                         (strcmp(@encode(__typeof__(a2value)), @encode(id)) == 0) && \
                         [(id)a1value isEqual:(id)a2value] ) continue; \
                             [self failWithException:([NSException failureInEqualityBetweenObject:a1value \
                                                                                       andObject:a2value \
                                                                                    inFile:[NSString stringWithUTF8String:__FILE__] \
                                                                                    atLine:__LINE__ \
                                                                           withDescription:@"%@", STComposeString(description, ##__VA_ARGS__)])]; \
                } \
    }\
    @catch (id anException) {\
        [self failWithException:([NSException failureInRaise:[NSString stringWithFormat:@"(%s) == (%s)", #a1, #a2] \
                                                  exception:anException \
                                                     inFile:[NSString stringWithUTF8String:__FILE__] \
                                                     atLine:__LINE__ \
                                            withDescription:@"%@", STComposeString(description, ##__VA_ARGS__)])]; \
    }\
} while(0)


/*" Generates a failure when a1 is not equal to a2. This test is for
    C scalars, structs and unions.
    _{a1    The argument on the left.}
    _{a2    The argument on the right.}
    _{description A format string as in the printf() function. Can be nil or
        an empty string but must be present.}
    _{... A variable number of arguments to the format string. Can be absent.}
"*/
#define STAssertEquals(a1, a2, description, ...) \
do { \
    @try {\
        if (strcmp(@encode(__typeof__(a1)), @encode(__typeof__(a2))) != 0) { \
            [self failWithException:([NSException failureInFile:[NSString stringWithUTF8String:__FILE__] \
                                                         atLine:__LINE__ \
                                                withDescription:@"%@", [@"Type mismatch -- " stringByAppendingString:STComposeString(description, ##__VA_ARGS__)]])]; \
        } \
        else { \
            __typeof__(a1) a1value = (a1); \
            __typeof__(a2) a2value = (a2); \
            NSValue *a1encoded = [NSValue value:&a1value withObjCType:@encode(__typeof__(a1))]; \
            NSValue *a2encoded = [NSValue value:&a2value withObjCType:@encode(__typeof__(a2))]; \
            if (![a1encoded isEqualToValue:a2encoded]) { \
                [self failWithException:([NSException failureInEqualityBetweenValue:a1encoded \
                                                                           andValue:a2encoded \
                                                                       withAccuracy:nil \
                                                                             inFile:[NSString stringWithUTF8String:__FILE__] \
                                                                             atLine:__LINE__ \
                                                                    withDescription:@"%@", STComposeString(description, ##__VA_ARGS__)])]; \
            } \
        } \
    } \
    @catch (id anException) {\
        [self failWithException:([NSException \
                 failureInRaise:[NSString stringWithFormat:@"(%s) == (%s)", #a1, #a2] \
                      exception:anException \
                         inFile:[NSString stringWithUTF8String:__FILE__] \
                         atLine:__LINE__ \
                withDescription:@"%@", STComposeString(description, ##__VA_ARGS__)])]; \
    }\
} while(0)

#define STAbsoluteDifference(left,right) (MAX(left,right)-MIN(left,right))


/*" Generates a failure when a1 is not equal to a2 within + or - accuracy is false. 
    This test is for scalars such as floats and doubles where small differences 
    could make these items not exactly equal, but also works for all scalars.
    _{a1    The scalar on the left.}
    _{a2    The scalar on the right.}
    _{accuracy  The maximum difference between a1 and a2 for these values to be
    considered equal.}
    _{description A format string as in the printf() function. Can be nil or
        an empty string but must be present.}
    _{... A variable number of arguments to the format string. Can be absent.}
"*/

#define STAssertEqualsWithAccuracy(a1, a2, accuracy, description, ...) \
do { \
    @try {\
        if (strcmp(@encode(__typeof__(a1)), @encode(__typeof__(a2))) != 0) { \
            [self failWithException:([NSException failureInFile:[NSString stringWithUTF8String:__FILE__] \
                                                         atLine:__LINE__ \
                                                withDescription:@"%@", [@"Type mismatch -- " stringByAppendingString:STComposeString(description, ##__VA_ARGS__)]])]; \
        } \
        else { \
            __typeof__(a1) a1value = (a1); \
            __typeof__(a2) a2value = (a2); \
            __typeof__(accuracy) accuracyvalue = (accuracy); \
            if (STAbsoluteDifference(a1value, a2value) > accuracyvalue) { \
                NSValue *a1encoded = [NSValue value:&a1value withObjCType:@encode(__typeof__(a1))]; \
                NSValue *a2encoded = [NSValue value:&a2value withObjCType:@encode(__typeof__(a2))]; \
                NSValue *accuracyencoded = [NSValue value:&accuracyvalue withObjCType:@encode(__typeof__(accuracy))]; \
                [self failWithException:([NSException failureInEqualityBetweenValue:a1encoded \
                                                                           andValue:a2encoded \
                                                                       withAccuracy:accuracyencoded \
                                                                             inFile:[NSString stringWithUTF8String:__FILE__] \
                                                                             atLine:__LINE__ \
                                                                    withDescription:@"%@", STComposeString(description, ##__VA_ARGS__)])]; \
            } \
        } \
    } \
    @catch (id anException) {\
        [self failWithException:([NSException failureInRaise:[NSString stringWithFormat:@"(%s) == (%s)", #a1, #a2] \
                                                   exception:anException \
                                                      inFile:[NSString stringWithUTF8String:__FILE__] \
                                                      atLine:__LINE__ \
                                             withDescription:@"%@", STComposeString(description, ##__VA_ARGS__)])]; \
    }\
} while(0)



/*" Generates a failure unconditionally. 
    _{description A format string as in the printf() function. Can be nil or
        an empty string but must be present.}
    _{... A variable number of arguments to the format string. Can be absent.}
"*/
#define STFail(description, ...) \
[self failWithException:([NSException failureInFile:[NSString stringWithUTF8String:__FILE__] \
                                             atLine:__LINE__ \
                                    withDescription:@"%@", STComposeString(description, ##__VA_ARGS__)])]



/*" Generates a failure when a1 is not nil.
    _{a1    An object.}
    _{description A format string as in the printf() function. Can be nil or
        an empty string but must be present.}
    _{... A variable number of arguments to the format string. Can be absent.}
"*/
#define STAssertNil(a1, description, ...) \
do { \
    @try {\
        id a1value = (a1); \
                if (a1value != nil) { \
                    NSString *_a1 = [NSString stringWithUTF8String:#a1]; \
                    NSString *_expression = [NSString stringWithFormat:@"((%@) == nil)", _a1]; \
                    [self failWithException:([NSException failureInCondition:_expression \
                                                                      isTrue:NO \
                                                                      inFile:[NSString stringWithUTF8String:__FILE__] \
                                                                      atLine:__LINE__ \
                                                             withDescription:@"%@", STComposeString(description, ##__VA_ARGS__)])]; \
                } \
    }\
    @catch (id anException) {\
        [self failWithException:([NSException failureInRaise:[NSString stringWithFormat:@"(%s) == nil fails", #a1] \
                                                   exception:anException \
                                                      inFile:[NSString stringWithUTF8String:__FILE__] \
                                                      atLine:__LINE__ \
                                             withDescription:@"%@", STComposeString(description, ##__VA_ARGS__)])]; \
    }\
} while(0)


/*" Generates a failure when a1 is nil.
    _{a1    An object.}
    _{description A format string as in the printf() function. Can be nil or
        an empty string but must be present.}
    _{... A variable number of arguments to the format string. Can be absent.}
"*/
#define STAssertNotNil(a1, description, ...) \
do { \
    @try {\
        id a1value = (a1); \
                if (a1value == nil) { \
                    NSString *_a1 = [NSString stringWithUTF8String:#a1]; \
                    NSString *_expression = [NSString stringWithFormat:@"((%@) != nil)", _a1]; \
                    [self failWithException:([NSException failureInCondition:_expression \
                                                                      isTrue:NO \
                                                                      inFile:[NSString stringWithUTF8String:__FILE__] \
                                                                      atLine:__LINE__ \
                                                             withDescription:@"%@", STComposeString(description, ##__VA_ARGS__)])]; \
                } \
    }\
    @catch (id anException) {\
        [self failWithException:([NSException failureInRaise:[NSString stringWithFormat:@"(%s) != nil fails", #a1] \
                                                   exception:anException \
                                                      inFile:[NSString stringWithUTF8String:__FILE__] \
                                                      atLine:__LINE__ \
                                             withDescription:@"%@", STComposeString(description, ##__VA_ARGS__)])]; \
    }\
} while(0)


/*" Generates a failure when expression evaluates to false. 
    _{expr    The expression that is tested.}
    _{description A format string as in the printf() function. Can be nil or
        an empty string but must be present.}
    _{... A variable number of arguments to the format string. Can be absent.}
"*/
#define STAssertTrue(expr, description, ...) \
do { \
        BOOL _evaluatedExpression = !!(expr);\
            if (!_evaluatedExpression) {\
                NSString *_expression = [NSString stringWithUTF8String:#expr];\
                    [self failWithException:([NSException failureInCondition:_expression \
                                                                      isTrue:NO \
                                                                      inFile:[NSString stringWithUTF8String:__FILE__] \
                                                                      atLine:__LINE__ \
                                                             withDescription:@"%@", STComposeString(description, ##__VA_ARGS__)])]; \
            } \
} while (0)


/*" Generates a failure when expression evaluates to false and in addition will 
    generate error messages if an exception is encountered. 
    _{expr    The expression that is tested.}
    _{description A format string as in the printf() function. Can be nil or
        an empty string but must be present.}
    _{... A variable number of arguments to the format string. Can be absent.}
"*/
#define STAssertTrueNoThrow(expr, description, ...) \
do { \
    @try {\
        BOOL _evaluatedExpression = !!(expr);\
            if (!_evaluatedExpression) {\
                NSString *_expression = [NSString stringWithUTF8String:#expr];\
                    [self failWithException:([NSException failureInCondition:_expression \
                                                                      isTrue:NO \
                                                                      inFile:[NSString stringWithUTF8String:__FILE__] \
                                                                      atLine:__LINE__ \
                                                             withDescription:@"%@", STComposeString(description, ##__VA_ARGS__)])]; \
            } \
    } \
    @catch (id anException) {\
        [self failWithException:([NSException failureInRaise:[NSString stringWithFormat:@"(%s) ", #expr] \
                                                   exception:anException \
                                                      inFile:[NSString stringWithUTF8String:__FILE__] \
                                                      atLine:__LINE__ \
                                             withDescription:@"%@", STComposeString(description, ##__VA_ARGS__)])]; \
    }\
} while (0)


/*" Generates a failure when the expression evaluates to true. 
    _{expr    The expression that is tested.}
    _{description A format string as in the printf() function. Can be nil or
        an empty string but must be present.}
    _{... A variable number of arguments to the format string. Can be absent.}
"*/
#define STAssertFalse(expr, description, ...) \
do { \
        BOOL _evaluatedExpression = !!(expr);\
            if (_evaluatedExpression) {\
                NSString *_expression = [NSString stringWithUTF8String:#expr];\
                    [self failWithException:([NSException failureInCondition:_expression \
                                                                      isTrue:YES \
                                                                      inFile:[NSString stringWithUTF8String:__FILE__] \
                                                                      atLine:__LINE__ \
                                                             withDescription:@"%@", STComposeString(description, ##__VA_ARGS__)])]; \
            } \
} while (0)


/*" Generates a failure when the expression evaluates to true and in addition 
    will generate error messages if an exception is encountered.
    _{expr    The expression that is tested.}
    _{description A format string as in the printf() function. Can be nil or
        an empty string but must be present.}
    _{... A variable number of arguments to the format string. Can be absent.}
"*/
#define STAssertFalseNoThrow(expr, description, ...) \
do { \
    @try {\
        BOOL _evaluatedExpression = !!(expr);\
            if (_evaluatedExpression) {\
                NSString *_expression = [NSString stringWithUTF8String:#expr];\
                    [self failWithException:([NSException failureInCondition:_expression \
                                                                      isTrue:YES \
                                                                      inFile:[NSString stringWithUTF8String:__FILE__] \
                                                                      atLine:__LINE__ \
                                                             withDescription:@"%@", STComposeString(description, ##__VA_ARGS__)])]; \
            } \
    } \
    @catch (id anException) {\
        [self failWithException:([NSException failureInRaise:[NSString stringWithFormat:@"!(%s) ", #expr] \
                                                   exception:anException \
                                                      inFile:[NSString stringWithUTF8String:__FILE__] \
                                                      atLine:__LINE__ \
                                             withDescription:@"%@", STComposeString(description, ##__VA_ARGS__)])]; \
    }\
} while (0)


/*" Generates a failure when expression does not throw an exception. 
    _{expression    The expression that is evaluated.}
    _{description A format string as in the printf() function. Can be nil or
        an empty string but must be present.}
    _{... A variable number of arguments to the format string. Can be absent.}

"*/
#define STAssertThrows(expr, description, ...) \
do { \
    BOOL __caughtException = NO; \
    @try { \
        (expr);\
    } \
    @catch (id anException) { \
        __caughtException = YES; \
    }\
    if (!__caughtException) { \
        [self failWithException:([NSException failureInRaise:[NSString stringWithUTF8String:#expr] \
                                                   exception:nil \
                                                      inFile:[NSString stringWithUTF8String:__FILE__] \
                                                      atLine:__LINE__ \
                                             withDescription:@"%@", STComposeString(description, ##__VA_ARGS__)])]; \
    } \
} while (0)


/*" Generates a failure when expression does not throw an exception of a 
    specific class. 
    _{expression    The expression that is evaluated.}
    _{specificException    The specified class of the exception.}
    _{description A format string as in the printf() function. Can be nil or
        an empty string but must be present.}
    _{... A variable number of arguments to the format string. Can be absent.}

"*/
#define STAssertThrowsSpecific(expr, specificException, description, ...) \
do { \
    BOOL __caughtException = NO; \
    @try { \
        (expr);\
    } \
    @catch (specificException *anException) { \
        __caughtException = YES; \
    }\
    @catch (id anException) {\
        __caughtException = YES; \
        NSString *_descrip = STComposeString(@"(Expected exception: %@) %@", NSStringFromClass([specificException class]), description);\
            [self failWithException:([NSException failureInRaise:[NSString stringWithUTF8String:#expr] \
                                                       exception:anException \
                                                          inFile:[NSString stringWithUTF8String:__FILE__] \
                                                          atLine:__LINE__ \
                                                 withDescription:@"%@", STComposeString(_descrip, ##__VA_ARGS__)])]; \
    }\
    if (!__caughtException) { \
        NSString *_descrip = STComposeString(@"(Expected exception: %@) %@", NSStringFromClass([specificException class]), description);\
            [self failWithException:([NSException failureInRaise:[NSString stringWithUTF8String:#expr] \
                                                       exception:nil \
                                                          inFile:[NSString stringWithUTF8String:__FILE__] \
                                                          atLine:__LINE__ \
                                                 withDescription:@"%@", STComposeString(_descrip, ##__VA_ARGS__)])]; \
    } \
} while (0)


/*" Generates a failure when expression does not throw an exception of a 
    specific class with a specific name.  Useful for those frameworks like
    AppKit or Foundation that throw generic NSException w/specific names 
    (NSInvalidArgumentException, etc).
    _{expression    The expression that is evaluated.}
    _{specificException    The specified class of the exception.}
    _{aName    The name of the specified exception.}
    _{description A format string as in the printf() function. Can be nil or
        an empty string but must be present.}
    _{... A variable number of arguments to the format string. Can be absent.}

"*/
#define STAssertThrowsSpecificNamed(expr, specificException, aName, description, ...) \
do { \
    BOOL __caughtException = NO; \
    @try { \
        (expr);\
    } \
    @catch (specificException *anException) { \
        __caughtException = YES; \
        if (![aName isEqualToString:[anException name]]) { \
            NSString *_descrip = STComposeString(@"(Expected exception: %@ (name: %@)) %@", NSStringFromClass([specificException class]), aName, description);\
            [self failWithException: \
                ([NSException failureInRaise:[NSString stringWithUTF8String:#expr] \
                                   exception:anException \
                                      inFile:[NSString stringWithUTF8String:__FILE__] \
                                      atLine:__LINE__ \
                             withDescription:@"%@", STComposeString(_descrip, ##__VA_ARGS__)])]; \
        } \
    }\
    @catch (id anException) {\
        __caughtException = YES; \
        NSString *_descrip = STComposeString(@"(Expected exception: %@) %@", NSStringFromClass([specificException class]), description);\
        [self failWithException: \
            ([NSException failureInRaise:[NSString stringWithUTF8String:#expr] \
                               exception:anException \
                                  inFile:[NSString stringWithUTF8String:__FILE__] \
                                  atLine:__LINE__ \
                         withDescription:@"%@", STComposeString(_descrip, ##__VA_ARGS__)])]; \
    }\
    if (!__caughtException) { \
        NSString *_descrip = STComposeString(@"(Expected exception: %@) %@", NSStringFromClass([specificException class]), description);\
        [self failWithException: \
            ([NSException failureInRaise:[NSString stringWithUTF8String:#expr] \
                               exception:nil \
                                  inFile:[NSString stringWithUTF8String:__FILE__] \
                                  atLine:__LINE__ \
                         withDescription:@"%@", STComposeString(_descrip, ##__VA_ARGS__)])]; \
    } \
} while (0)


/*" Generates a failure when expression does throw an exception. 
    _{expression    The expression that is evaluated.}
    _{description A format string as in the printf() function. Can be nil or
        an empty string but must be present.}
    _{... A variable number of arguments to the format string. Can be absent.}
"*/
#define STAssertNoThrow(expr, description, ...) \
do { \
    @try { \
        (expr);\
    } \
    @catch (id anException) { \
        [self failWithException:([NSException failureInRaise:[NSString stringWithUTF8String:#expr] \
                                                   exception:anException \
                                                      inFile:[NSString stringWithUTF8String:__FILE__] \
                                                      atLine:__LINE__ \
                                             withDescription:@"%@", STComposeString(description, ##__VA_ARGS__)])]; \
    }\
} while (0)


/*" Generates a failure when expression does throw an exception of the specitied
    class. Any other exception is okay (i.e. does not generate a failure).
    _{expression    The expression that is evaluated.}
    _{specificException    The specified class of the exception.}
    _{description A format string as in the printf() function. Can be nil or
        an empty string but must be present.}
    _{... A variable number of arguments to the format string. Can be absent.}
"*/
#define STAssertNoThrowSpecific(expr, specificException, description, ...) \
do { \
    @try { \
        (expr);\
    } \
    @catch (specificException *anException) { \
        [self failWithException:([NSException failureInRaise:[NSString stringWithUTF8String:#expr] \
                                                   exception:anException \
                                                      inFile:[NSString stringWithUTF8String:__FILE__] \
                                                      atLine:__LINE__ \
                                             withDescription:@"%@", STComposeString(description, ##__VA_ARGS__)])]; \
    }\
    @catch (id anythingElse) {\
        ; \
    }\
} while (0)


/*" Generates a failure when expression does throw an exception of a 
    specific class with a specific name.  Useful for those frameworks like
    AppKit or Foundation that throw generic NSException w/specific names 
    (NSInvalidArgumentException, etc).
    _{expression    The expression that is evaluated.}
    _{specificException    The specified class of the exception.}
    _{aName    The name of the specified exception.}
    _{description A format string as in the printf() function. Can be nil or
        an empty string but must be present.}
    _{... A variable number of arguments to the format string. Can be absent.}

"*/
#define STAssertNoThrowSpecificNamed(expr, specificException, aName, description, ...) \
do { \
    @try { \
        (expr);\
    } \
    @catch (specificException *anException) { \
        if ([aName isEqualToString:[anException name]]) { \
            NSString *_descrip = STComposeString(@"(Expected exception: %@ (name: %@)) %@", NSStringFromClass([specificException class]), aName, description);\
            [self failWithException: \
                ([NSException failureInRaise:[NSString stringWithUTF8String:#expr] \
                                   exception:anException \
                                      inFile:[NSString stringWithUTF8String:__FILE__] \
                                      atLine:__LINE__ \
                             withDescription:@"%@", STComposeString(_descrip, ##__VA_ARGS__)])]; \
        } \
    }\
    @catch (id anythingElse) {\
        ; \
    }\
} while (0)


#ifdef STEnableDeprecatedAssertionMacros

/*" This macro has been deprecated as of Feb 2004.
    Generates a failure unconditionally.
"*/
#define fail() STFail(@"")

/*" This macro has been deprecated as of Feb 2004.
    Generates a failure unconditionally.
"*/
#define fail1(description) STFail(description)

/*" This macro has been deprecated as of Feb 2004.
    Generates a failure when expression evaluates to false.
"*/
#define should(expression)  STAssertTrue(expression, @"")

/*" This macro has been deprecated as of Feb 2004.
    Generates a failure when expression evaluates to false.
"*/
#define should1(expression, description)  STAssertTrue(expression, description)

/*" This macro has been deprecated as of Feb 2004.
    Generates a failure when a expression evaluates to true.
"*/
#define shouldnt(expression)  STAssertFalse(expression, @"")

/*" This macro has been deprecated as of Feb 2004.
    Generates a failure when a expression evaluates to true.
"*/
#define shouldnt1(expression, description)  STAssertFalse(expression, description)

/*" This macro has been deprecated as of Feb 2004.
    Generates a failure when !{ [left isEqualTo:right] } is false 
    (or left is nil and right is not).
"*/
#define shouldBeEqual(left, right)  STAssertEqualObjects(left, right, @"")

/*" This macro has been deprecated as of Feb 2004.
    Generates a failure when !{ [left isEqualTo:right] } is false 
    (or left is nil and right is not).
"*/
#define shouldBeEqual1(left, right, description)  STAssertEqualObjects(left, right, description)

/*" This macro has been deprecated as of Feb 2004.
    Generates a failure when expression does not raise an exception.
"*/
#define shouldRaise(expression)  STAssertThrows(expression, @"")

/*" This macro has been deprecated as of Feb 2004.
    Generates a failure when expression does not raise an exception.
"*/
#define shouldRaise1(expression, description)  STAssertThrows(expression, description)

/*" This macro has been deprecated as of Feb 2004.
    Generates a failure when expression does raise an exception.
"*/
#define shouldntRaise(expression)  STAssertNoThrow(expression, @"")

/*" This macro has been deprecated as of Feb 2004.
    Generates a failure when expression does raise an exception.
"*/
#define shouldntRaise1(expression, description)  STAssertNoThrow(expression, description)

/*" This macro has been deprecated as of Feb 2004.
    Wrapper for should() that will generate error messages if an exception is
    raised. Uses new-style exception.
"*/
#define shouldnoraise(expression)  STAssertTrueNoThrow(expression, @"")

/*" This macro has been deprecated as of Feb 2004.
    Wrapper for should() that will generate error messages if an exception is
    raised. Uses new-style exception.
"*/
#define should1noraise(expression, description)  STAssertTrueNoThrow(expression, description)

/*" This macro has been deprecated as of Feb 2004.
    Wrapper for shouldnt() that will generate error messages if an exception is
    raised. Uses new-style exceptions
"*/
#define shouldntnoraise(expression)  STAssertFalseNoThrow(expression, @"")

/*" This macro has been deprecated as of Feb 2004.
    Wrapper for shouldnt() that will generate error messages if an exception is
    raised. Uses new-style exceptions
"*/
#define shouldnt1noraise(expression, description)  STAssertFalseNoThrow(expression, description)

#endif /* STEnableDeprecatedAssertionMacros */
