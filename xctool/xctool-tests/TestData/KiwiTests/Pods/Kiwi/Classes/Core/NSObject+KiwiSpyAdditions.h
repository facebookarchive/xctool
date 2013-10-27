//
// Licensed under the terms in License.txt
//
// Copyright 2010 Allen Ding. All rights reserved.
//

#import "KiwiConfiguration.h"

@class KWCaptureSpy;

@interface NSObject (KiwiSpyAdditions)
- (KWCaptureSpy *)captureArgument:(SEL)selector atIndex:(NSUInteger)index;
+ (KWCaptureSpy *)captureArgument:(SEL)selector atIndex:(NSUInteger)index;
@end
