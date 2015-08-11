//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <Foundation/Foundation.h>


/**
 Test failure location and reason.

 @ingroup integration
 */
@interface HCTestFailure : NSObject

@property (readonly, nonatomic, strong) id testCase;
@property (readonly, nonatomic, copy) NSString *fileName;
@property (readonly, nonatomic, assign) NSUInteger lineNumber;
@property (readonly, nonatomic, strong) NSString *reason;

- (instancetype)initWithTestCase:(id)testCase
                        fileName:(NSString *)fileName
                      lineNumber:(NSUInteger)lineNumber
                          reason:(NSString *)reason;

@end
