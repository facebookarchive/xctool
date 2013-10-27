//
//  KWStringContainsMatcher.h
//  Kiwi
//
//  Created by Stewart Gleadow on 7/06/12.
//  Copyright (c) 2012 Allen Ding. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KWGenericMatcher.h"

@interface KWStringContainsMatcher : NSObject <KWGenericMatching>

+ (id)matcherWithSubstring:(NSString *)aSubstring;
- (id)initWithSubstring:(NSString *)aSubstring;
- (BOOL)matches:(id)object;

@end

#define hasSubstring(substring) [KWStringContainsMatcher matcherWithSubstring:substring]
