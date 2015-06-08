/*$Id: SenTestingUtilities.h,v 1.7 2005/04/02 03:18:22 phink Exp $*/

// Copyright (c) 1997-2005, Sen:te (Sente SA).  All rights reserved.
//
// Use of this source code is governed by the following license:
// 
// Redistribution and use in source and binary forms, with or without modification, 
// are permitted provided that the following conditions are met:
// 
// (1) Redistributions of source code must retain the above copyright notice, 
// this list of conditions and the following disclaimer.
// 
// (2) Redistributions in binary form must reproduce the above copyright notice, 
// this list of conditions and the following disclaimer in the documentation 
// and/or other materials provided with the distribution.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS IS'' 
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
// IN NO EVENT SHALL Sente SA OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT 
// OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, 
// EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// 
// Note: this license is equivalent to the FreeBSD license.
// 
// This notice may not be removed from this file.

#import <Foundation/Foundation.h>


// Defining ASSIGN and RETAIN.
// ___newVal is to avoid multiple evaluations of val.
// RETAIN is deprecated and should not used.

#if defined (GNUSTEP)
// GNUstep has its own definitions of ASSIGN and RETAIN
#else
#define RETAIN(var,val) \
({ \
	id ___newVal = (val); \
	id ___oldVar = (var); \
	if (___oldVar != ___newVal) { \
		if (___newVal != nil) { \
			[___newVal retain]; \
		} \
		var = ___newVal; \
		if (___oldVar != nil) { \
			[___oldVar release]; \
		} \
	} \
})

#if defined(GARBAGE_COLLECTION)
#define ASSIGN(var,val) \
({ \
	var = val; \
})
#else
#define ASSIGN RETAIN
#endif
#endif


// Defining RELEASE.
//
// The RELEASE macro can be used in any place where a release 
// message would be sent. VAR is released and set to nil
#if defined (GNUSTEP)
// GNUstep has its own macro.
#else
#if defined(GARBAGE_COLLECTION)
#define RELEASE(var)
#else
#define RELEASE(var) \
({ \
	id	___oldVar = (id)(var); \
	if (___oldVar != nil) { \
		var = nil; \
		[___oldVar release]; \
	} \
})
#endif
#endif

@class NSString;

#ifdef __cplusplus
extern "C" NSString *STComposeString(NSString *, ...);
extern "C" NSString *getScalarDescription(NSValue *left);
#else
extern NSString *STComposeString(NSString *, ...);
extern NSString *getScalarDescription(NSValue *left);
#endif

@interface NSFileManager (SenTestingAdditions)
- (BOOL) fileExistsAtPathOrLink:(NSString *)aPath;
@end

@interface NSValue (SenTestingAdditions)
- (NSString *) contentDescription;
@end
