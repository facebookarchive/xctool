//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2015 Jonathan M. Reid. See LICENSE.txt

#import "MKTBaseMockObject.h"


/**
 Mock object implementing a given protocol.
 */
@interface MKTProtocolMock : MKTBaseMockObject

@property (readonly, nonatomic, strong) Protocol *mockedProtocol;

+ (instancetype)mockForProtocol:(Protocol *)aProtocol;
+ (instancetype)mockForProtocol:(Protocol *)aProtocol includeOptionalMethods:(BOOL)includeOptionalMethods;

- (instancetype)initWithProtocol:(Protocol *)aProtocol;
- (instancetype)initWithProtocol:(Protocol *)aProtocol includeOptionalMethods:(BOOL)includeOptionalMethods;

@end
