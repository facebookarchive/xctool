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
//

#import "SenTestClassEnumeratorFix.h"

#import "Swizzle.h"
#import "dyld-interposing.h"

@interface XTSenTestClassEnumerator : NSObject
- (_Bool)isValidClass:(Class)cls;
@end

static id SenTestClassEnumerator_init(id self, SEL cmd)
{
  unsigned int classCount = 0;
  Class *classList = objc_copyClassList(&classCount);

  NSMutableArray *classes = [NSMutableArray array];

  for (unsigned int i = 0; i < classCount; i++) {
    Class cls = classList[i];

    if ([self isValidClass:cls]) {
      [classes addObject:[NSValue valueWithPointer:cls]];
    }
  }

  [self setValue:classes forKey:@"classes"];
  [self setValue:@(classes.count == 0) forKey:@"isAtEnd"];

  return self;
}

void XTApplySenTestClassEnumeratorFix()
{
  XTSwizzleSelectorForFunction(NSClassFromString(@"SenTestClassEnumerator"),
                               @selector(init),
                               (IMP)SenTestClassEnumerator_init);
}
