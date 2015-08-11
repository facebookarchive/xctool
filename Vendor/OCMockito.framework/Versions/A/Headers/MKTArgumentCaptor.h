//  OCMockito by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2015 Jonathan M. Reid. See LICENSE.txt

#import <Foundation/Foundation.h>


@interface MKTArgumentCaptor : NSObject

- (id)capture;
- (id)value;
- (NSArray *)allValues;

@end
