//
//  NSObject+KiwiAdditions.h
//  Kiwi
//
//  Created by Luke Redpath on 24/01/2011.
//  Copyright 2011 Allen Ding. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (KiwiGenericMatchingAdditions)

- (BOOL)isEqualOrMatches:(id)object;

@end

@interface NSArray (KiwiGenericMatchingAdditions)

- (BOOL)containsObjectEqualToOrMatching:(id)object;
- (BOOL)containsObjectMatching:(id)matcher;

@end

@interface NSSet (KiwiGenericMatchingAdditions)

- (BOOL)containsObjectEqualToOrMatching:(id)object;

@end

@interface NSOrderedSet (KiwiGenericMatchingAdditions)

- (BOOL)containsObjectEqualToOrMatching:(id)object;

@end
