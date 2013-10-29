//
// Licensed under the terms in License.txt
//
// Copyright 2010 Allen Ding. All rights reserved.
//

#import "KiwiConfiguration.h"

@interface NSObject(KiwiMockAdditions)

#pragma mark - Creating Mocks

+ (id)mock;
+ (id)mockWithName:(NSString *)aName;

+ (id)nullMock;
+ (id)nullMockWithName:(NSString *)aName;

@end
