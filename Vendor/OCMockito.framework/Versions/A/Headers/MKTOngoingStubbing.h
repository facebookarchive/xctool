//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2015 Jonathan M. Reid. See LICENSE.txt

#import <Foundation/Foundation.h>
#import "MKTPrimitiveArgumentMatching.h"

@class MKTInvocationContainer;


/**
 Methods to invoke on @c given(methodCall) to return stubbed values.

 The methods return the MKTOngoingStubbing object to allow stubbing consecutive calls.
 */
@interface MKTOngoingStubbing : NSObject <MKTPrimitiveArgumentMatching>

- (instancetype)initWithInvocationContainer:(MKTInvocationContainer *)invocationContainer;

/// Sets an object to be returned when the method is called.
- (MKTOngoingStubbing *)willReturn:(id)object;

/**
 Sets a struct to be returned when the method is called.

 The @c type should match the Objective-C type of @c value.
 Type should be created with the Objective-C \@encode() compiler directive.
*/
- (MKTOngoingStubbing *)willReturnStruct:(const void *)value objCType:(const char *)type;

/// Sets a @c BOOL to be returned when the method is called.
- (MKTOngoingStubbing *)willReturnBool:(BOOL)value;

/// Sets a @c char to be returned when the method is called.
- (MKTOngoingStubbing *)willReturnChar:(char)value;

/// Sets an @c int to be returned when the method is called.
- (MKTOngoingStubbing *)willReturnInt:(int)value;

/// Sets a @c short to be returned when the method is called.
- (MKTOngoingStubbing *)willReturnShort:(short)value;

/// Sets a @c long to be returned when the method is called.
- (MKTOngoingStubbing *)willReturnLong:(long)value;

/// Sets a <code>long long</code> to be returned when the method is called.
- (MKTOngoingStubbing *)willReturnLongLong:(long long)value;

/// Sets an @c NSInteger to be returned when the method is called.
- (MKTOngoingStubbing *)willReturnInteger:(NSInteger)value;

/// Sets given <code>unsigned char</code> as return value.
- (MKTOngoingStubbing *)willReturnUnsignedChar:(unsigned char)value;

/// Sets given <code>unsigned int</code> as return value.
- (MKTOngoingStubbing *)willReturnUnsignedInt:(unsigned int)value;

/// Sets an <code>unsigned short</code> to be returned when the method is called.
- (MKTOngoingStubbing *)willReturnUnsignedShort:(unsigned short)value;

/// Sets an <code>unsigned long</code> to be returned when the method is called.
- (MKTOngoingStubbing *)willReturnUnsignedLong:(unsigned long)value;

/// Sets an <code>unsigned long long</code> to be returned when the method is called.
- (MKTOngoingStubbing *)willReturnUnsignedLongLong:(unsigned long long)value;

/// Sets an @c NSUInteger to be returned when the method is called.
- (MKTOngoingStubbing *)willReturnUnsignedInteger:(NSUInteger)value;

/// Sets a @c float to be returned when the method is called.
- (MKTOngoingStubbing *)willReturnFloat:(float)value;

/// Sets a @c double to be returned when the method is called.
- (MKTOngoingStubbing *)willReturnDouble:(double)value;

/// Sets @c NSException to be thrown when the method is called.
- (MKTOngoingStubbing *)willThrow:(NSException *)exception;

/** Sets block to be executed when the method is called.

 The return value of block is returned when the method is called.
 */
- (MKTOngoingStubbing *)willDo:(id (^)(NSInvocation *))block;

@end
