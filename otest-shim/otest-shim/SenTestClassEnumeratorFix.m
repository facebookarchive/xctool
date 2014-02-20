//
// Copyright 2013 Facebook
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

// A struct with the same layout as SenTestClassEnumerator.
//
// We use this instead of copying the class-dump of SenTestClassEnumerator into
// this file.  If we did that, the linker would need to link directly into
// SenTestingKit, which we specifically do not want to do (because the initializer
// in SenTestingKit will immediately start running tests, prematurely for what
// we're doing).
struct XTSenTestClassEnumerator {
  Class isa;

  NSMutableArray *classes;
  int currentIndex;
  _Bool isAtEnd;
};

@interface XTSenTestClassEnumerator : NSObject
- (_Bool)isValidClass:(Class)arg1;
@end

static id SenTestClassEnumerator_init(id self, SEL cmd)
{
  unsigned int classCount = 0;
  Class *classList = objc_copyClassList(&classCount);

  struct XTSenTestClassEnumerator *selfStruct = (struct XTSenTestClassEnumerator *)self;
  selfStruct->classes = [[NSMutableArray alloc] init];
  selfStruct->isAtEnd = NO;
  selfStruct->currentIndex = 0;

  for (unsigned int i = 0; i < classCount; i++) {
    Class cls = classList[i];

    if ([self isValidClass:cls]) {
      [selfStruct->classes addObject:[NSValue valueWithPointer:cls]];
    }
  }

  return self;
}

void XTApplySenTestClassEnumeratorFix()
{
  XTSwizzleSelectorForFunction(NSClassFromString(@"SenTestClassEnumerator"),
                               @selector(init),
                               (IMP)SenTestClassEnumerator_init);
}
