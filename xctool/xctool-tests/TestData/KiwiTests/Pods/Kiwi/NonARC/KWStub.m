//
// Licensed under the terms in License.txt
//
// Copyright 2010 Allen Ding. All rights reserved.
//

#import "KWStub.h"
#import "KWMessagePattern.h"
#import "KWObjCUtilities.h"
#import "KWStringUtilities.h"
#import "KWValue.h"

#import "NSInvocation+OCMAdditions.h"

@interface KWStub(){}
@property (nonatomic, copy) id (^block)(NSArray *params);
@end

@implementation KWStub

#pragma mark - Initializing

- (id)initWithMessagePattern:(KWMessagePattern *)aMessagePattern {
    return [self initWithMessagePattern:aMessagePattern value:nil];
}

- (id)initWithMessagePattern:(KWMessagePattern *)aMessagePattern value:(id)aValue {
    self = [super init];
    if (self) {
        messagePattern = [aMessagePattern retain];
        value = [aValue retain];
    }

    return self;
}

- (id)initWithMessagePattern:(KWMessagePattern *)aMessagePattern block:(id (^)(NSArray *params))aBlock {
    self = [super init];
    if (self) {
        messagePattern = [aMessagePattern retain];
        _block = [aBlock copy];
    }
	
    return self;
}

- (id)initWithMessagePattern:(KWMessagePattern *)aMessagePattern value:(id)aValue times:(id)times afterThatReturn:(id)aSecondValue {
    self = [super init];
    if (self) {
        messagePattern = [aMessagePattern retain];
        value = [aValue retain];
        returnValueTimes = [times retain];
        secondValue = [aSecondValue retain];
    }
    
    return self;
}

+ (id)stubWithMessagePattern:(KWMessagePattern *)aMessagePattern {
    return [self stubWithMessagePattern:aMessagePattern value:nil];
}

+ (id)stubWithMessagePattern:(KWMessagePattern *)aMessagePattern value:(id)aValue {
    return [[[self alloc] initWithMessagePattern:aMessagePattern value:aValue] autorelease];
}

+ (id)stubWithMessagePattern:(KWMessagePattern *)aMessagePattern block:(id (^)(NSArray *params))aBlock {
    return [[[self alloc] initWithMessagePattern:aMessagePattern block:aBlock] autorelease];
}

+ (id)stubWithMessagePattern:(KWMessagePattern *)aMessagePattern value:(id)aValue times:(id)times afterThatReturn:(id)aSecondValue {
    return [[[self alloc] initWithMessagePattern:aMessagePattern value:aValue times:times afterThatReturn:aSecondValue] autorelease];
}

- (void)dealloc {
    [messagePattern release];
    [value release];
    [returnValueTimes release];
    [secondValue release];
	[_block release];
    [super dealloc];
}

#pragma mark - Properties

@synthesize messagePattern;
@synthesize value;
@synthesize secondValue;
@synthesize returnValueTimes;
@synthesize returnedValueTimes;

#pragma mark - Processing Invocations

- (void)writeZerosToInvocationReturnValue:(NSInvocation *)anInvocation {
    NSUInteger returnLength = [[anInvocation methodSignature] methodReturnLength];

    if (returnLength == 0)
        return;

    void *bytes = malloc(returnLength);
    memset(bytes, 0, returnLength);
    [anInvocation setReturnValue:bytes];
    free(bytes);
}

- (NSData *)valueDataWithObjCType:(const char *)objCType {
    assert(self.value && "self.value must not be nil");
    NSData *data = [self.value dataForObjCType:objCType];

    if (data == nil) {
        [NSException raise:@"KWStubException" format:@"wrapped stub value type (%s) could not be converted to the target type (%s)",
                                                     [self.value objCType],
                                                     objCType];
    }

    return data;
}

- (void)writeWrappedValueToInvocationReturnValue:(NSInvocation *)anInvocation {
    assert(self.value && "self.value must not be nil");
    const char *returnType = [[anInvocation methodSignature] methodReturnType];
    NSData *data = nil;

    NSData *choosedForData = [self.value dataValue];

    if (returnValueTimes != nil) {
        NSString *returnValueTimesString = returnValueTimes;
        int returnValueTimesInt = [returnValueTimesString intValue];
        
        if (returnedValueTimes >= returnValueTimesInt) {
            choosedForData = [self.secondValue dataValue];
        }
        returnedValueTimes++;
    }

    
    // When the return type is not the same as the type of the wrapped value,
    // attempt to convert the wrapped value to the desired type.

    if (KWObjCTypeEqualToObjCType([self.value objCType], returnType))
        data = choosedForData;
    else
        data = [self valueDataWithObjCType:returnType];

    [anInvocation setReturnValue:(void *)[data bytes]];
}

- (void)writeObjectValueToInvocationReturnValue:(NSInvocation *)anInvocation {
    assert(self.value && "self.value must not be nil");
    
    void *choosedForData = &value;
    
    if (returnValueTimes != nil) {
        NSString *returnValueTimesString = returnValueTimes;
        int returnValueTimesInt = [returnValueTimesString intValue];
        
        if (returnedValueTimes >= returnValueTimesInt) {
            choosedForData = &secondValue;
        }
        returnedValueTimes++;
    }

    [anInvocation setReturnValue:choosedForData];

#ifndef __clang_analyzer__
    NSString *selectorString = NSStringFromSelector([anInvocation selector]);

    // To conform to memory management conventions, retain if writing a result
    // that begins with alloc, new or contains copy. This shows up as a false
    // positive in clang due to the runtime conditional, so ignore it.
    if (KWStringHasWordPrefix(selectorString, @"alloc") ||
        KWStringHasWordPrefix(selectorString, @"new") ||
        KWStringHasWord(selectorString, @"copy") ||
        KWStringHasWord(selectorString, @"Copy")) {
        [self.value retain];
    }
#endif
}

- (BOOL)processInvocation:(NSInvocation *)anInvocation {
    if (![self.messagePattern matchesInvocation:anInvocation])
        return NO;
	
	if (self.block) {
		NSUInteger numberOfArguments = [[anInvocation methodSignature] numberOfArguments];
		NSMutableArray *args = [NSMutableArray arrayWithCapacity:(numberOfArguments-2)];
		for (NSUInteger i = 2; i < numberOfArguments; ++i) {
			id arg = [anInvocation getArgumentAtIndexAsObject:(int)i];
			
			const char *argType = [[anInvocation methodSignature] getArgumentTypeAtIndex:i];
			if (strcmp(argType, "@?") == 0) arg = [[arg copy] autorelease];
            
            if (arg == nil)
                arg = [NSNull null];
            
			[args addObject:arg];
		}
		
		id newValue = self.block(args);
		if (newValue != value) {
			[value release];
			value = [newValue retain];
		}
		
		[args removeAllObjects]; // We don't want these objects to be in autorelease pool
	}

    if (self.value == nil)
        [self writeZerosToInvocationReturnValue:anInvocation];
    else if ([self.value isKindOfClass:[KWValue class]])
        [self writeWrappedValueToInvocationReturnValue:anInvocation];
    else
        [self writeObjectValueToInvocationReturnValue:anInvocation];

    return YES;
}

#pragma mark - Debugging

- (NSString *)description {
    return [NSString stringWithFormat:@"messagePattern: %@\nvalue: %@", self.messagePattern, self.value];
}

@end
