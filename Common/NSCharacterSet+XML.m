//
// Copyright 2004-present Facebook. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "NSCharacterSet+XML.h"

@implementation NSCharacterSet (XML)
+ (NSCharacterSet *)fb_xmlCharacterSet
{
    static NSCharacterSet *_xmlCharacterSet;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Valid XML characters reference: http://www.w3.org/TR/REC-xml/#charsets
        NSString *xmlCharacters = [NSString stringWithFormat:@"%C%C%C", 0x9, 0xA, 0xD];
        NSMutableCharacterSet *xmlCharacterSet = [NSMutableCharacterSet characterSetWithCharactersInString:xmlCharacters];
        [xmlCharacterSet addCharactersInRange:NSMakeRange(0x20, 0xD7FF - 0x20)];
        [xmlCharacterSet addCharactersInRange:NSMakeRange(0xE000, 0xFFFD - 0xE000)];
        // XML also allows characters in the range 0x10000 - 0x10FFFF, but since unichar (unsigned short) has a size of 2 bytes
        // no character can be in this range: 2^16 = 65535 (not 65536, since we're starting from 0) < 0x10000 = 65536
        _xmlCharacterSet = [xmlCharacterSet copy];
    });
    
    return _xmlCharacterSet;
}
@end
