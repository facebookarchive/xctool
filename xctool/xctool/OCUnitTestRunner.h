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

#import <Foundation/Foundation.h>

@interface OCUnitTestRunner : NSObject {
  NSDictionary *_buildSettings;
  NSString *_senTestList;
  BOOL _senTestInvertScope;
  BOOL _garbageCollection;
  BOOL _freshSimulator;
  BOOL _freshInstall;
  NSFileHandle *_standardOutput;
  NSFileHandle *_standardError;
  NSArray *_reporters;
}

- (id)initWithBuildSettings:(NSDictionary *)buildSettings
                senTestList:(NSString *)senTestList
         senTestInvertScope:(BOOL)senTestInvertScope
          garbageCollection:(BOOL)garbageCollection
             freshSimulator:(BOOL)freshSimulator
               freshInstall:(BOOL)freshInstall
             standardOutput:(NSFileHandle *)standardOutput
              standardError:(NSFileHandle *)standardError
                  reporters:(NSArray *)reporters;

- (BOOL)runTestsWithError:(NSString **)error;

- (NSArray *)otestArguments;

- (NSString *)testBundlePath;

@end
