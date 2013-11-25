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

#import "SwizzleGuard.h"

#import <objc/runtime.h>

@interface XTIMPRestoreRecord : NSObject
{
  Method _method;
  IMP _originalIMP;
}

@property (nonatomic, assign) Method method;
@property (nonatomic, assign) IMP originalIMP;

@end

@interface XTMethodAddedRecord : NSObject
{
  Class _cls;
  SEL _name;
  IMP _imp;
}

@property (nonatomic, assign) Class cls;
@property (nonatomic, assign) SEL name;
@property (nonatomic, assign) IMP imp;

@end

/**
 Returns an array of any IMPs to be restored when guard is disabled.
 */
NSArray *XTSwizzleGuardIMPRestoreRecords();

/**
 Returns an array of any methods added.
 */
NSArray *XTSwizzleGuardMethodAddedRecords();