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

#import "Action.h"

/**
 * Break test cases into groups of `bucketSize` test cases.  Test methods in
 * the same test class may be broken into separate buckets.
 *
 * e.g. ['Cls1/test1', 'Cls1/test2', 'Cls2/test1'] with bucketSize=2 woudl be
 * broken into [['Cls1/test1', 'Cls1/test2'], ['Cls2/test1']].
 */
NSArray *BucketizeTestCasesByTestCase(NSArray *testCases, int bucketSize);

/**
 * Break test cases into groups of `bucketSize` test classes.
 *
 * e.g. ['Cls1/test1', 'Cls1/test2', 'Cls1/test3', 'Cls2/test2', 'Cls3/test1']
 * with bucketSize=2 would be broken into [['Cls1/test1', 'Cls1/test2',
 * 'Cls1/test3', 'Cls2/test2'], ['Cls3/test1']].
 */
NSArray *BucketizeTestCasesByTestClass(NSArray *testCases, int bucketSize);

typedef enum {
  // Bucket by individual test case (the most granular option).  Test cases
  // within the same class may be broken into separate buckets.
  //
  // When parallelizing, 2 or more test cases from the same test class may be
  // running at the same time, so it's important they don't use the same
  // resources at the same time.
  BucketByTestCase,

  // Bucket by class name.  All test cases for a given class will
  // be in the same bucket.
  BucketByClass,

} BucketBy;

@interface RunTestsAction : Action {
  int _logicTestBucketSize;
  int _appTestBucketSize;
  BucketBy _bucketBy;
}

@property (nonatomic, assign) BOOL freshSimulator;
@property (nonatomic, assign) BOOL freshInstall;
@property (nonatomic, assign) BOOL parallelize;
@property (nonatomic, retain) NSString *simulatorType;
@property (nonatomic, retain) NSString *testSDK;
@property (nonatomic, retain) NSMutableArray *onlyList;

- (void)setLogicTestBucketSize:(NSString *)str;
- (void)setAppTestBucketSize:(NSString *)str;
- (void)setBucketBy:(NSString *)str;

@end

