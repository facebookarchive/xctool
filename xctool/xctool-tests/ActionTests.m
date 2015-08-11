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

#import <XCTest/XCTest.h>

#import "Action.h"

@interface FakeAction : Action
@property (nonatomic, assign) BOOL showHelp;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSMutableArray *numbers;
@end

@implementation FakeAction
+ (NSArray *)options {
  // Some bogus actions to help exercise the plumbing.
  return @[
           [Action actionOptionWithName:@"help" aliases:@[@"h"] description:@"show help" setFlag:@selector(setShowHelp:)],
           [Action actionOptionWithName:@"name" aliases:nil description:@"set name" paramName:@"NAME" mapTo:@selector(setName:)],
           [Action actionOptionWithMatcher:^(NSString *str){
             return (BOOL)(([str intValue] > 0) ? YES : NO);
           }
                               description:@"a number"
                                 paramName:@"NUMBER"
                                     mapTo:@selector(addNumber:)],
           ];
}

- (instancetype)init
{
  if (self = [super init]) {
    _numbers = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)addNumber:(NSString *)number
{
  [_numbers addObject:@([number intValue])];
}

@end

@interface ActionTests : XCTestCase
@end

@implementation ActionTests

- (void)testActionUsage
{
  assertThat([FakeAction actionUsage],
             equalTo(@"    -help                      show help\n"
                     @"    -name NAME                 set name\n"
                     @"    NUMBER                     a number\n"));
}

- (void)testFlagOptionSetsFlag
{
  NSMutableArray *arguments = [NSMutableArray arrayWithArray:@[
                               @"-help",
                               ]];
  FakeAction *action = [[FakeAction alloc] init];
  assertThatBool(action.showHelp, isFalse());

  NSString *errorMessage = nil;
  NSUInteger consumed = [action consumeArguments:arguments errorMessage:&errorMessage];
  assertThat(errorMessage, equalTo(nil));

  assertThatInteger(consumed, equalToInteger(1));
  assertThatInteger(arguments.count, equalToInteger(0));
  assertThatBool(action.showHelp, isTrue());
}

- (void)testAliasesAreRespected
{
  NSMutableArray *arguments = [NSMutableArray arrayWithArray:@[
                               @"-h",
                               ]];
  FakeAction *action = [[FakeAction alloc] init];
  assertThatBool(action.showHelp, isFalse());

  NSString *errorMessage = nil;
  NSUInteger consumed = [action consumeArguments:arguments errorMessage:&errorMessage];
  assertThat(errorMessage, equalTo(nil));

  assertThatInteger(consumed, equalToInteger(1));
  assertThatInteger(arguments.count, equalToInteger(0));
  assertThatBool(action.showHelp, isTrue());
}

- (void)testMapOptionSetsValue
{
  NSMutableArray *arguments = [NSMutableArray arrayWithArray:@[
                               @"-name", @"SomeName",
                               ]];
  FakeAction *action = [[FakeAction alloc] init];

  NSString *errorMessage = nil;
  NSUInteger consumed = [action consumeArguments:arguments errorMessage:&errorMessage];
  assertThat(errorMessage, equalTo(nil));

  assertThatInteger(consumed, equalToInteger(2));
  assertThatInteger(arguments.count, equalToInteger(0));
  assertThat(action.name, equalTo(@"SomeName"));
}

- (void)testMatcherOptionSetsValue
{
  NSMutableArray *arguments = [NSMutableArray arrayWithArray:@[
                               @"1", @"2",
                               ]];
  FakeAction *action = [[FakeAction alloc] init];

  NSString *errorMessage = nil;
  NSUInteger consumed = [action consumeArguments:arguments errorMessage:&errorMessage];
  assertThat(errorMessage, equalTo(nil));

  assertThatInteger(consumed, equalToInteger(2));
  assertThatInteger(arguments.count, equalToInteger(0));
  assertThat(action.numbers, equalTo(@[@1, @2]));
}

@end
