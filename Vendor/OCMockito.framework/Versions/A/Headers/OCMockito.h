//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2015 Jonathan M. Reid. See LICENSE.txt

#import <Foundation/Foundation.h>

#import "MKTArgumentCaptor.h"
#import "MKTClassObjectMock.h"
#import "MKTObjectMock.h"
#import "MKTObjectAndProtocolMock.h"
#import "MKTOngoingStubbing.h"
#import "MKTProtocolMock.h"


#define MKTMock(aClass) (id)[MKTObjectMock mockForClass:aClass]

/**
 Returns a mock object of a given class.

 (In the event of a name clash, don't \#define @c MOCKITO_SHORTHAND and use the synonym
 @c MKTMock instead.)
 */
#ifdef MOCKITO_SHORTHAND
    #define mock(aClass) MKTMock(aClass)
#endif


#define MKTMockClass(aClass) (id)[MKTClassObjectMock mockForClass:aClass]

/**
 Returns a mock class object of a given class.

 (In the event of a name clash, don't \#define @c MOCKITO_SHORTHAND and use the synonym
 @c MKTMockClass instead.)
 */
#ifdef MOCKITO_SHORTHAND
    #define mockClass(aClass) MKTMockClass(aClass)
#endif


#define MKTMockProtocol(aProtocol) (id)[MKTProtocolMock mockForProtocol:aProtocol]

/**
 Returns a mock object implementing a given protocol.

 (In the event of a name clash, don't \#define @c MOCKITO_SHORTHAND and use the synonym
 @c MKTMockProtocol instead.)
 */
#ifdef MOCKITO_SHORTHAND
    #define mockProtocol(aProtocol) MKTMockProtocol(aProtocol)
#endif


#define MKTMockProtocolWithoutOptionals(aProtocol) (id)[MKTProtocolMock mockForProtocol:aProtocol includeOptionalMethods:NO]

/**
 Returns a mock object implementing a given protocol, but with no optional methods.

 (In the event of a name clash, don't \#define @c MOCKITO_SHORTHAND and use the synonym
 @c MKTMockProtocolWithoutOptionals instead.)
*/
#ifdef MOCKITO_SHORTHAND
    #define mockProtocolWithoutOptionals(aProtocol) MKTMockProtocolWithoutOptionals(aProtocol)
#endif


#define MKTMockObjectAndProtocol(aClass, aProtocol) (id)[MKTObjectAndProtocolMock mockForClass:aClass protocol:aProtocol]

/**
 Returns a mock object of a given class that also implements a given protocol.

 (In the event of a name clash, don't \#define @c MOCKITO_SHORTHAND and use the synonym
 @c MKTMockObjectAndProtocol instead.)
 */
#ifdef MOCKITO_SHORTHAND
    #define mockObjectAndProtocol(aClass, aProtocol) (id)MKTMockObjectAndProtocol(aClass, aProtocol)
#endif


FOUNDATION_EXPORT MKTOngoingStubbing *MKTGivenWithLocation(id testCase, const char *fileName, int lineNumber, ...);
#define MKTGiven(methodCall) MKTGivenWithLocation(self, __FILE__, __LINE__, methodCall)

/**
 Enables method stubbing.

 Use @c given when you want the mock to return particular value when particular method is called.

 Example:
 @li @ref [given([mockObject methodReturningString]) willReturn:@"foo"];

 See @ref MKTOngoingStubbing for other methods to stub different types of return values.

 (In the event of a name clash, don't \#define @c MOCKITO_SHORTHAND and use the synonym
 @c MKTGiven instead.)
 */
#ifdef MOCKITO_SHORTHAND
    #define given(methodCall) MKTGiven(methodCall)
#endif


#define MKTStubProperty(instance, property, value)                          \
    do {                                                                    \
        [MKTGiven([instance property]) willReturn:value];                   \
        [MKTGiven([instance valueForKey:@#property]) willReturn:value];     \
        [MKTGiven([instance valueForKeyPath:@#property]) willReturn:value]; \
    } while(0)

/**
 Stubs given property and its related KVO methods.

 (In the event of a name clash, don't \#define @c MOCKITO_SHORTHAND and use the synonym
 @c MKTStubProperty instead.)
 */
#ifdef MOCKITO_SHORTHAND
    #define stubProperty(instance, property, value) MKTStubProperty(instance, property, value)
#endif


FOUNDATION_EXPORT id MKTVerifyWithLocation(id mock, id testCase, const char *fileName, int lineNumber);
#define MKTVerify(mock) MKTVerifyWithLocation(mock, self, __FILE__, __LINE__)

/**
 Verifies certain behavior happened once.

 @c verify checks that a method was invoked once, with arguments that match given OCHamcrest
 matchers. If an argument is not a matcher, it is implicitly wrapped in an @c equalTo matcher to
 check for equality.

 Examples:
 @code
 [verify(mockObject) someMethod:startsWith(@"foo")];
 [verify(mockObject) someMethod:@"bar"];
 @endcode

 @c verify(mockObject) is equivalent to
 @code
 verifyCount(mockObject, times(1))
 @endcode

 (In the event of a name clash, don't \#define @c MOCKITO_SHORTHAND and use the synonym
 @c MKTVerify instead.)
 */
#ifdef MOCKITO_SHORTHAND
    #undef verify
    #define verify(mock) MKTVerify(mock)
#endif


FOUNDATION_EXPORT id MKTVerifyCountWithLocation(id mock, id mode, id testCase, const char *fileName, int lineNumber);
#define MKTVerifyCount(mock, mode) MKTVerifyCountWithLocation(mock, mode, self, __FILE__, __LINE__)

/**
 Verifies certain behavior happened a given number of times.

 Examples:
 @code
 [verifyCount(mockObject, times(5)) someMethod:@"was called five times"];
 [verifyCount(mockObject, never()) someMethod:@"was never called"];
 @endcode

 @c verifyCount checks that a method was invoked a given number of times, with arguments that
 match given OCHamcrest matchers. If an argument is not a matcher, it is implicitly wrapped in an
 @c equalTo matcher to check for equality.

 (In the event of a name clash, don't \#define @c MOCKITO_SHORTHAND and use the synonym
 @c MKTVerifyCount instead.)
 */
#ifdef MOCKITO_SHORTHAND
    #define verifyCount(mock, mode) MKTVerifyCount(mock, mode)
#endif


FOUNDATION_EXPORT id MKTTimes(NSUInteger wantedNumberOfInvocations);

/**
 Verifies exact number of invocations.

 Example:
 @code
 [verifyCount(mockObject, times(2)) someMethod:@"some arg"];
 @endcode

 (In the event of a name clash, don't \#define @c MOCKITO_SHORTHAND and use the synonym
 @c MKTTimes instead.)
 */
#ifdef MOCKITO_SHORTHAND
    #define times(wantedNumberOfInvocations) MKTTimes(wantedNumberOfInvocations)
#endif


FOUNDATION_EXPORT id MKTNever(void);

/**
 Verifies that interaction did not happen.

 Example:
 @code
 [verifyCount(mockObject, never()) someMethod:@"some arg"];
 @endcode

 (In the event of a name clash, don't \#define @c MOCKITO_SHORTHAND and use the synonym
 @c MKTNever instead.)
 */
#ifdef MOCKITO_SHORTHAND
    #define never() MKTNever()
#endif


FOUNDATION_EXPORT id MKTAtLeast(NSUInteger minNumberOfInvocations);

/**
 Verifies minimum number of invocations.

 The verification will succeed if the specified invocation happened the number of times
 specified or more.

 Example:
 @code
 [verifyCount(mockObject, atLeast(2)) someMethod:@"some arg"];
 @endcode

 (In the event of a name clash, don't \#define @c MOCKITO_SHORTHAND and use the synonym
 @c MKTAtLeast instead.)
 */
#ifdef MOCKITO_SHORTHAND
    #define atLeast(minNumberOfInvocations) MKTAtLeast(minNumberOfInvocations)
#endif


FOUNDATION_EXPORT id MKTAtLeastOnce(void);

/**
 Verifies that interaction happened once or more.

 Example:
 @code
 [verifyCount(mockObject, atLeastOnce()) someMethod:@"some arg"];
 @endcode

 (In the event of a name clash, don't \#define @c MOCKITO_SHORTHAND and use the synonym
 @c MKTAtLeastOnce instead.)
 */
#ifdef MOCKITO_SHORTHAND
    #define atLeastOnce() MKTAtLeastOnce()
#endif
