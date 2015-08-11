//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2014 hamcrest.org. See LICENSE.txt

#import <Foundation/Foundation.h>
#import <OCHamcrest/HCDescription.h>


/**
 Base class for all HCDescription implementations.

 @ingroup core
 */
@interface HCBaseDescription : NSObject <HCDescription>
@end


/**
 Methods that must be provided by subclasses of HCBaseDescription.
 */
@interface HCBaseDescription (SubclassResponsibility)

/**
 Append the string @a str to the description.
 */
- (void)append:(NSString *)str;

@end
