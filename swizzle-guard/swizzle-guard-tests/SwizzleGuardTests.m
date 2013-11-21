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

#import <SenTestingKit/SenTestingKit.h>

#import <objc/message.h>
#import <objc/runtime.h>

#import "SwizzleGuard.h"
#import "SwizzleGuardInternal.h"

@interface FooClass : NSObject

- (int)multiplyByTwo:(int)value;
- (int)multiplyByThree:(int)value;
+ (int)clsMultiplyByTwo:(int)value;

@end

@interface FooClass (MethodWithoutIMP)

// We'll dynamically add this method at runtime.
- (int)multiplyByFour:(int)value;
- (int)multiplyByFive:(int)value;

@end

@implementation FooClass

- (int)multiplyByTwo:(int)value
{
  return value * 2;
}

- (int)multiplyByThree:(int)value
{
  return value * 3;
}

+ (int)clsMultiplyByTwo:(int)value
{
  return value * 2;
}

@end

static int MultiplyByThree(id self, SEL cmd, int value)
{
  return value * 3;
}

static int MultiplyByFour(id self, SEL cmd, int value)
{
  return value * 4;
}

static int MultiplyByFive(id self, SEL cmd, int value)
{
  return value * 5;
}

@interface SwizzleGuardTests : SenTestCase
@end

@implementation SwizzleGuardTests

- (void)testReplaceMethodCallsAreUndoneForInstanceMethods
{
  FooClass *foo = [[[FooClass alloc] init] autorelease];

  STAssertEquals([foo multiplyByTwo:5], 10,
                 @"Should get the original implementation to start.");

  IMP originalIMP = class_getMethodImplementation([FooClass class],
                                                  @selector(multiplyByTwo:));

  XTSwizzleGuardEnable();

  IMP replaceMethodOriginalIMP = class_replaceMethod([FooClass class],
                                                     @selector(multiplyByTwo:),
                                                     (IMP)MultiplyByThree,
                                                     "i@:i");
  STAssertEquals(originalIMP, replaceMethodOriginalIMP, @"replaceMethod should return original IMP.");

  // Now swizzled, we should get the swizzled implementation.
  STAssertEquals([foo multiplyByTwo:5], 15,  nil);

  XTSwizzleGuardDisable();

  // After SwizzleGuardDisable(), we should get the original IMP again.
  STAssertEquals([foo multiplyByTwo:5], 10, nil);
}

- (void)testReplaceMethodCallsAreUndoneForClassMethods
{
  STAssertEquals([FooClass clsMultiplyByTwo:5], 10,
                 @"Should get the original implementation to start.");

  IMP originalIMP = class_getMethodImplementation(object_getClass([FooClass class]),
                                                  @selector(clsMultiplyByTwo:));

  XTSwizzleGuardEnable();

  IMP replaceMethodOriginalIMP = class_replaceMethod(object_getClass([FooClass class]),
                                                     @selector(clsMultiplyByTwo:),
                                                     (IMP)MultiplyByThree,
                                                     "i@:i");
  STAssertEquals(originalIMP, replaceMethodOriginalIMP, @"replaceMethod should return original IMP.");

  // Now swizzled, we should get the swizzled implementation.
  STAssertEquals([FooClass clsMultiplyByTwo:5], 15, nil);

  XTSwizzleGuardDisable();

  // After SwizzleGuardDisable(), we should get the original IMP again.
  STAssertEquals([FooClass clsMultiplyByTwo:5], 10, nil);
}

- (void)testExchaneImplmentationIsUndone
{
  FooClass *foo = [[[FooClass alloc] init] autorelease];

  XTSwizzleGuardEnable();

  STAssertEqualObjects(XTSwizzleGuardIMPRestoreRecords(), @[],
                       @"Should have no records to start.");

  Method mMultipleByTwo = class_getInstanceMethod([FooClass class], @selector(multiplyByTwo:));
  Method mMultipleByThree = class_getInstanceMethod([FooClass class], @selector(multiplyByThree:));

  STAssertEquals([foo multiplyByTwo:5], 10, @"Should have original IMP.");
  STAssertEquals([foo multiplyByThree:5], 15, @"Should have original IMP.");

  method_exchangeImplementations(mMultipleByTwo, mMultipleByThree);

  STAssertEquals([foo multiplyByTwo:5], 15, @"Should have swapped IMP.");
  STAssertEquals([foo multiplyByThree:5], 10, @"Should have swapped IMP.");

  XTSwizzleGuardDisable();

  STAssertEquals([foo multiplyByTwo:5], 10, @"Should be back to original IMP.");
  STAssertEquals([foo multiplyByThree:5], 15, @"Should be back to original IMP.");
}

- (void)testRestoreRecordsAreCreatedWhenMethodsAreSwizzledViaReplaceMethod
{
  XTSwizzleGuardEnable();
  STAssertEqualObjects(XTSwizzleGuardIMPRestoreRecords(), @[],
                       @"Should have no records to start.");

  IMP originalIMP = class_replaceMethod([FooClass class],
                                        @selector(multiplyByTwo:),
                                        (IMP)MultiplyByThree,
                                        "i@:i");

  STAssertEquals([XTSwizzleGuardIMPRestoreRecords() count], (NSUInteger)1,
                 @"Should have 1 record.");
  XTIMPRestoreRecord *record = [XTSwizzleGuardIMPRestoreRecords() objectAtIndex:0];

  STAssertEquals(record.method, class_getInstanceMethod([FooClass class], @selector(multiplyByTwo:)), @"method should be set.");
  STAssertEquals(record.originalIMP, originalIMP, @"originalIMP should be set.");

  XTSwizzleGuardDisable();
}

- (void)testRestoreRecordsAreCreatedWhenMethodsAreSwizzledViaSetImplementation
{
  XTSwizzleGuardEnable();
  STAssertEqualObjects(XTSwizzleGuardIMPRestoreRecords(), @[],
                       @"Should have no records to start.");

  Method m = class_getInstanceMethod([FooClass class], @selector(multiplyByTwo:));
  IMP originalIMP = method_setImplementation(m, (IMP)MultiplyByThree);

  STAssertEquals([XTSwizzleGuardIMPRestoreRecords() count], (NSUInteger)1,
                 @"Should have 1 record.");
  XTIMPRestoreRecord *record = [XTSwizzleGuardIMPRestoreRecords() objectAtIndex:0];

  STAssertEquals(record.method, class_getInstanceMethod([FooClass class], @selector(multiplyByTwo:)), @"method should be set.");
  STAssertEquals(record.originalIMP, originalIMP, @"originalIMP should be set.");

  XTSwizzleGuardDisable();
}

- (void)testRestoreRecordsAreCreatedWhenMethodsAreSwizzledViaExchangeImplementation
{
  XTSwizzleGuardEnable();
  STAssertEqualObjects(XTSwizzleGuardIMPRestoreRecords(), @[],
                       @"Should have no records to start.");

  Method mMultipleByTwo = class_getInstanceMethod([FooClass class], @selector(multiplyByTwo:));
  Method mMultipleByThree = class_getInstanceMethod([FooClass class], @selector(multiplyByThree:));

  IMP impMultipleByTwo = method_getImplementation(mMultipleByTwo);
  IMP impMultipleByThree = method_getImplementation(mMultipleByThree);

  method_exchangeImplementations(mMultipleByTwo, mMultipleByThree);

  STAssertEquals([XTSwizzleGuardIMPRestoreRecords() count], (NSUInteger)2,
                 @"Should have 2 records.");

  XTIMPRestoreRecord *record1 = [XTSwizzleGuardIMPRestoreRecords() objectAtIndex:0];
  XTIMPRestoreRecord *record2 = [XTSwizzleGuardIMPRestoreRecords() objectAtIndex:1];

  STAssertEquals(record1.method, class_getInstanceMethod([FooClass class], @selector(multiplyByThree:)), @"method should be set.");
  STAssertEquals(record1.originalIMP, impMultipleByThree, @"originalIMP should be set.");

  STAssertEquals(record2.method, class_getInstanceMethod([FooClass class], @selector(multiplyByTwo:)), @"method should be set.");
  STAssertEquals(record2.originalIMP, impMultipleByTwo, @"originalIMP should be set.");

  XTSwizzleGuardDisable();
}

- (void)testRecordsAreRemovedWhenCodeReplacesOriginalIMP
{
  XTSwizzleGuardEnable();
  STAssertEqualObjects(XTSwizzleGuardIMPRestoreRecords(), @[],
                       @"Should have no records to start.");

  // Swizzle ...
  IMP originalIMP = class_replaceMethod([FooClass class],
                                        @selector(multiplyByTwo:),
                                        (IMP)MultiplyByThree,
                                        "i@:i");

  STAssertEquals([XTSwizzleGuardIMPRestoreRecords() count], (NSUInteger)1,
                 @"Should have 1 record.");

  // Then, restore the original IMP.
  class_replaceMethod([FooClass class],
                      @selector(multiplyByTwo:),
                      originalIMP,
                      "i@:i");

  STAssertEquals([XTSwizzleGuardIMPRestoreRecords() count], (NSUInteger)0,
                 @"Should have 0 records to restore since the code cleaned up after itself.");

  XTSwizzleGuardDisable();
}

- (void)testSwizzleViaReplaceMethodAndRestoreViaSetImplementation
{
  XTSwizzleGuardEnable();

  FooClass *foo = [[[FooClass alloc] init] autorelease];
  STAssertEquals([foo multiplyByTwo:5], 10, @"Should be original IMP.");

  // Swizzle ...
  IMP originalIMP = class_replaceMethod([FooClass class],
                                        @selector(multiplyByTwo:),
                                        (IMP)MultiplyByThree,
                                        "i@:i");

  STAssertEquals([foo multiplyByTwo:5], 15, @"Should be MultiplyByThree now.");

  // Then, restore the original IMP.  Even though we're using different objc
  // runtime functions to restore the IMP, the swizzle guard should recognize
  // that we're restoring the original IMP.
  Method m = class_getInstanceMethod([FooClass class], @selector(multiplyByTwo:));
  method_setImplementation(m, originalIMP);

  STAssertEquals([foo multiplyByTwo:5], 10, @"Should be back to original IMP.");

  STAssertEquals([XTSwizzleGuardIMPRestoreRecords() count], (NSUInteger)0,
                 @"Should have no records since we restored the IMP.");

  XTSwizzleGuardDisable();
}



- (void)testStateDescriptionReturnsSwizzledMethods
{
  XTSwizzleGuardEnable();
  STAssertEqualObjects(XTSwizzleGuardIMPRestoreRecords(), @[],
                       @"Should have no records to start.");

  Method mMultipleByTwo = class_getInstanceMethod([FooClass class], @selector(multiplyByTwo:));
  Method mMultipleByThree = class_getInstanceMethod([FooClass class], @selector(multiplyByThree:));

  method_exchangeImplementations(mMultipleByTwo, mMultipleByThree);

  STAssertEqualObjects(XTSwizzleGuardStateDescription(),
                       @"'-[FooClass multiplyByThree:]' was swizzled with '-[FooClass multiplyByTwo:]', but never restored. (will be undone)\n"
                       @"'-[FooClass multiplyByTwo:]' was swizzled with '-[FooClass multiplyByThree:]', but never restored. (will be undone)\n",
                       @"Should have correct description.");

  XTSwizzleGuardDisable();

  STAssertEqualObjects(XTSwizzleGuardStateDescription(), nil, @"Will be nil after guard is disabled.");
}

- (void)testAddMethodViaReplaceMethodCreatesRecord
{
  XTSwizzleGuardEnable();
  FooClass *foo = [[[FooClass alloc] init] autorelease];

  STAssertEquals([XTSwizzleGuardMethodAddedRecords() count], (NSUInteger)0,
                 @"Should have no records yet.");

  IMP originalIMP = class_replaceMethod([FooClass class], @selector(multiplyByFour:), (IMP)MultiplyByFour, "i@:i");
  STAssertTrue(originalIMP == NULL, @"There was no original IMP.");

  STAssertEquals([XTSwizzleGuardMethodAddedRecords() count], (NSUInteger)1,
                 @"Should have 1 record.");

  STAssertEquals([foo multiplyByFour:5], 20, @"This should be the expected IMP.");

  STAssertEqualObjects(XTSwizzleGuardStateDescription(),
                       @"'-[FooClass multiplyByFour:]' was added with IMP 'MultiplyByFour'. (cannot be undone)\n",
                       @"Should have correct description.");

  XTSwizzleGuardDisable();
}

- (void)testAddMethodViaAddMethodCreatesRecord
{
  XTSwizzleGuardEnable();
  FooClass *foo = [[[FooClass alloc] init] autorelease];

  STAssertEquals([XTSwizzleGuardMethodAddedRecords() count], (NSUInteger)0,
                 @"Should have no records yet.");

  BOOL added = class_addMethod([FooClass class], @selector(multiplyByFive:), (IMP)MultiplyByFive, "i@:i");
  STAssertTrue(added, @"Should have worked - it didn't exist before.");

  STAssertEquals([XTSwizzleGuardMethodAddedRecords() count], (NSUInteger)1,
                 @"Should have 1 record.");

  STAssertEquals([foo multiplyByFive:5], 25, @"Should be original IMP.");

  STAssertEqualObjects(XTSwizzleGuardStateDescription(),
                       @"'-[FooClass multiplyByFive:]' was added with IMP 'MultiplyByFive'. (cannot be undone)\n",
                       @"Should have correct description.");

  XTSwizzleGuardDisable();
}

- (void)testBlockIMPsAreDescribedCorrectly
{
  XTSwizzleGuardEnable();

  IMP newIMP = imp_implementationWithBlock(^(Class cls, int value){
    return (int)(value * 10);
  });

  class_replaceMethod(object_getClass([FooClass class]),
                      @selector(clsMultiplyByTwo:),
                      newIMP,
                      "i@:i");

  // Now swizzled, we should get the swizzled implementation.
  STAssertEquals([FooClass clsMultiplyByTwo:5], 50, nil);

  STAssertEqualObjects(XTSwizzleGuardStateDescription(),
                       @"'+[FooClass clsMultiplyByTwo:]' was swizzled with '(block)', but never restored. (will be undone)\n",
                       @"Description should mention the block.");

  XTSwizzleGuardDisable();

  // After SwizzleGuardDisable(), we should get the original IMP again.
  STAssertEquals([FooClass clsMultiplyByTwo:5], 10, nil);
}

@end
