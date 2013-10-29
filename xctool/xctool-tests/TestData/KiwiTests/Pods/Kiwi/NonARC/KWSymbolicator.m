//
//  KWSymbolicator.m
//  Kiwi
//
//  Created by Jerry Marino on 4/28/13.
//  Copyright (c) 2013 Allen Ding. All rights reserved.
//

#import "KWSymbolicator.h"
#import <objc/runtime.h>
#import <libunwind.h>

long kwCallerAddress (void){
#if !__arm__
	unw_cursor_t cursor; unw_context_t uc;
	unw_word_t ip;

	unw_getcontext(&uc);
	unw_init_local(&cursor, &uc);

    int pos = 2;
	while (unw_step(&cursor) && pos--){
		unw_get_reg (&cursor, UNW_REG_IP, &ip);
        if(pos == 0) return (NSUInteger)(ip - 4);
	}
#endif
    return 0;
}

@implementation NSString (KWShellCommand)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-method-access"

+ (NSString *)stringWithShellCommand:(NSString *)command arguments:(NSArray *)arguments {
    id task = [[NSClassFromString(@"NSTask") alloc] init];
    [task setEnvironment:[NSDictionary dictionary]];
    [task setLaunchPath:command];
    [task setArguments:arguments];

    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    [task launch];

    [task waitUntilExit];

    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    NSString *string = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    [task release];
    return string;
}

#pragma clang diagnostic pop

@end
