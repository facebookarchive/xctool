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

#import "PhabricatorReporter.h"
#import "Reporter+Testing.h"

@interface PhabricatorReporterTests : XCTestCase
@end

@implementation PhabricatorReporterTests

- (void)testGoodBuild
{
  NSData *outputData =
    [PhabricatorReporter outputDataWithEventsFromFile:TEST_DATA @"JSONStreamReporter-build-good.txt"];
  NSArray *results = [NSJSONSerialization JSONObjectWithData:outputData
                                                     options:0
                                                       error:nil];
  assertThat(results, notNilValue());
  assertThat(results,
             equalTo(@[
                     @{
                     @"name" : @"TestProject-Library: Build TestProject-Library:TestProject-Library",
                     @"result" : @"pass",
                     @"userdata" : @"",
                     @"link" : [NSNull null],
                     @"extra" : [NSNull null],
                     @"coverage" : [NSNull null],
                     },
                     @{
                     @"name" : @"TestProject-Library: Build TestProject-Library:TestProject-LibraryTests",
                     @"result" : @"pass",
                     @"userdata" : @"",
                     @"link" : [NSNull null],
                     @"extra" : [NSNull null],
                     @"coverage" : [NSNull null],
                     },
                     ]));
}

- (void)testBadBuild
{
  NSData *outputData =
    [PhabricatorReporter outputDataWithEventsFromFile:TEST_DATA @"JSONStreamReporter-build-bad.txt"];
  NSArray *results = [NSJSONSerialization JSONObjectWithData:outputData
                                                     options:0
                                                       error:nil];
  assertThat(results, notNilValue());
  assertThat(results,
             equalTo(@[
                     @{
                     @"name" : @"TestProject-Library: Build TestProject-Library:TestProject-Library",
                     @"result" : @"pass",
                     @"userdata" : @"",
                     @"link" : [NSNull null],
                     @"extra" : [NSNull null],
                     @"coverage" : [NSNull null],
                     },
                     @{
                     @"name" : @"TestProject-Library: Build TestProject-Library:TestProject-LibraryTests",
                     @"result" : @"broken",
                     @"userdata" : @"CompileC /Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-gpcgrfaidrhstlbqbvqcqcehbnqc/Build/Intermediates/TestProject-Library.build/Debug-iphonesimulator/TestProject-LibraryTests.build/Objects-normal/i386/SomeTests.o TestProject-LibraryTests/SomeTests.m normal i386 objective-c com.apple.compilers.llvm.clang.1_0.compiler\n    cd /Users/fpotter/fb/git/fbobjc/Tools/xctool/xctool/xctool-tests/TestData/TestProject-Library\n    setenv LANG en_US.US-ASCII\n    setenv PATH \"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/usr/bin:/Applications/Xcode.app/Contents/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin\"\n    /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang -x objective-c -arch i386 -fmessage-length=0 -std=gnu99 -Wno-trigraphs -fpascal-strings -O0 -Wno-missing-field-initializers -Wno-missing-prototypes -Wreturn-type -Wno-implicit-atomic-properties -Wno-receiver-is-weak -Wduplicate-method-match -Wformat -Wno-missing-braces -Wparentheses -Wswitch -Wno-unused-function -Wno-unused-label -Wno-unused-parameter -Wunused-variable -Wunused-value -Wempty-body -Wuninitialized -Wno-unknown-pragmas -Wno-shadow -Wno-four-char-constants -Wno-conversion -Wno-constant-conversion -Wno-int-conversion -Wno-enum-conversion -Wno-shorten-64-to-32 -Wpointer-sign -Wno-newline-eof -Wno-selector -Wno-strict-selector-match -Wno-undeclared-selector -Wno-deprecated-implementations -DDEBUG=1 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator6.1.sdk -fexceptions -fasm-blocks -fstrict-aliasing -Wprotocol -Wdeprecated-declarations -g -Wno-sign-conversion -fobjc-abi-version=2 -fobjc-legacy-dispatch -mios-simulator-version-min=6.0 -iquote /Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-gpcgrfaidrhstlbqbvqcqcehbnqc/Build/Intermediates/TestProject-Library.build/Debug-iphonesimulator/TestProject-LibraryTests.build/TestProject-LibraryTests-generated-files.hmap -I/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-gpcgrfaidrhstlbqbvqcqcehbnqc/Build/Intermediates/TestProject-Library.build/Debug-iphonesimulator/TestProject-LibraryTests.build/TestProject-LibraryTests-own-target-headers.hmap -I/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-gpcgrfaidrhstlbqbvqcqcehbnqc/Build/Intermediates/TestProject-Library.build/Debug-iphonesimulator/TestProject-LibraryTests.build/TestProject-LibraryTests-all-target-headers.hmap -iquote /Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-gpcgrfaidrhstlbqbvqcqcehbnqc/Build/Intermediates/TestProject-Library.build/Debug-iphonesimulator/TestProject-LibraryTests.build/TestProject-LibraryTests-project-headers.hmap -I/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-gpcgrfaidrhstlbqbvqcqcehbnqc/Build/Products/Debug-iphonesimulator/include -I/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include -I/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include -I/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include -I/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-gpcgrfaidrhstlbqbvqcqcehbnqc/Build/Intermediates/TestProject-Library.build/Debug-iphonesimulator/TestProject-LibraryTests.build/DerivedSources/i386 -I/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-gpcgrfaidrhstlbqbvqcqcehbnqc/Build/Intermediates/TestProject-Library.build/Debug-iphonesimulator/TestProject-LibraryTests.build/DerivedSources -F/Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-gpcgrfaidrhstlbqbvqcqcehbnqc/Build/Products/Debug-iphonesimulator -F/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator6.1.sdk/Developer/Library/Frameworks -F/Applications/Xcode.app/Contents/Developer/Library/Frameworks -include /Users/fpotter/fb/git/fbobjc/Tools/xctool/xctool/xctool-tests/TestData/TestProject-Library/TestProject-Library/TestProject-Library-Prefix.pch -MMD -MT dependencies -MF /Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-gpcgrfaidrhstlbqbvqcqcehbnqc/Build/Intermediates/TestProject-Library.build/Debug-iphonesimulator/TestProject-LibraryTests.build/Objects-normal/i386/SomeTests.d --serialize-diagnostics /Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-gpcgrfaidrhstlbqbvqcqcehbnqc/Build/Intermediates/TestProject-Library.build/Debug-iphonesimulator/TestProject-LibraryTests.build/Objects-normal/i386/SomeTests.dia -c /Users/fpotter/fb/git/fbobjc/Tools/xctool/xctool/xctool-tests/TestData/TestProject-Library/TestProject-LibraryTests/SomeTests.m -o /Users/fpotter/Library/Developer/Xcode/DerivedData/TestProject-Library-gpcgrfaidrhstlbqbvqcqcehbnqc/Build/Intermediates/TestProject-Library.build/Debug-iphonesimulator/TestProject-LibraryTests.build/Objects-normal/i386/SomeTests.o\n/Users/fpotter/fb/git/fbobjc/Tools/xctool/xctool/xctool-tests/TestData/TestProject-Library/TestProject-LibraryTests/SomeTests.m:17:1: error: use of undeclared identifier 'WTF'\nWTF\n^\n/Users/fpotter/fb/git/fbobjc/Tools/xctool/xctool/xctool-tests/TestData/TestProject-Library/TestProject-LibraryTests/SomeTests.m:63:20: warning: implicit declaration of function 'backtrace' is invalid in C99 [-Wimplicit-function-declaration]\n  int numSymbols = backtrace(exceptionSymbols, 256);\n                   ^\n/Users/fpotter/fb/git/fbobjc/Tools/xctool/xctool/xctool-tests/TestData/TestProject-Library/TestProject-LibraryTests/SomeTests.m:64:3: warning: implicit declaration of function 'backtrace_symbols_fd' is invalid in C99 [-Wimplicit-function-declaration]\n  backtrace_symbols_fd(exceptionSymbols, numSymbols, STDERR_FILENO);\n  ^\n2 warnings and 1 error generated.\n",
                     @"link" : [NSNull null],
                     @"extra" : [NSNull null],
                     @"coverage" : [NSNull null],
                     },
                     ]));
}

- (void)testTestResults
{
  NSData *outputData =
    [PhabricatorReporter outputDataWithEventsFromFile:TEST_DATA @"JSONStreamReporter-runtests.txt"];
  NSArray *results = [NSJSONSerialization JSONObjectWithData:outputData
                                                     options:0
                                                       error:nil];

  assertThat(results, notNilValue());
  assertThat(results,
             equalTo(@[
                     @{
                     @"name" : @"TestProject-Library: -[OtherTests testSomething]",
                     @"result" : @"pass",
                     @"userdata" : @"",
                     @"coverage" : [NSNull null],
                     @"extra" :  [NSNull null],
                     @"link" : [NSNull null],
                     },
                     @{
                     @"name" : @"TestProject-Library: -[SomeTests testBacktraceOutputIsCaptured]",
                     @"result" : @"pass",
                     @"userdata" : @"0   TestProject-LibraryTests            0x016cd817 -[SomeTests testBacktraceOutputIsCaptured] + 103\n"
                                   @"1   CoreFoundation                      0x00a051bd __invoking___ + 29\n"
                                   @"2   CoreFoundation                      0x00a050d6 -[NSInvocation invoke] + 342\n"
                                   @"3   SenTestingKit                       0x20103ed1 -[SenTestCase invokeTest] + 219\n"
                                   @"4   SenTestingKit                       0x2010405b -[SenTestCase performTest:] + 183\n"
                                   @"5   SenTestingKit                       0x201037bf -[SenTest run] + 82\n"
                                   @"6   SenTestingKit                       0x2010792b -[SenTestSuite performTest:] + 139\n"
                                   @"7   SenTestingKit                       0x201037bf -[SenTest run] + 82\n"
                                   @"8   SenTestingKit                       0x2010792b -[SenTestSuite performTest:] + 139\n"
                                   @"9   SenTestingKit                       0x201037bf -[SenTest run] + 82\n"
                                   @"10  SenTestingKit                       0x201063ec +[SenTestProbe runTests:] + 174\n"
                                   @"11  libobjc.A.dylib                     0x0073c5c8 +[NSObject performSelector:withObject:] + 70\n"
                                   @"12  otest                               0x00002342 otest + 4930\n"
                                   @"13  otest                               0x000025ef otest + 5615\n"
                                   @"14  otest                               0x0000268c otest + 5772\n"
                                   @"15  otest                               0x00002001 otest + 4097\n"
                                   @"16  otest                               0x00001f71 otest + 3953\n",
                     @"coverage" : [NSNull null],
                     @"extra" :  [NSNull null],
                     @"link" : [NSNull null],
                     },
                     @{
                     @"name" : @"TestProject-Library: -[SomeTests testOutputMerging]",
                     @"result" : @"pass",
                     @"userdata" : @"stdout-line1\nstderr-line1\nstdout-line2\nstdout-line3\nstderr-line2\nstderr-line3\n",
                     @"coverage" : [NSNull null],
                     @"extra" :  [NSNull null],
                     @"link" : [NSNull null],
                     },
                     @{
                     @"name" : @"TestProject-Library: -[SomeTests testPrintSDK]",
                     @"result" : @"pass",
                     @"userdata" : @"2013-09-10 15:06:05.784 otest[25153:707] SDK: 6.1\n",
                     @"coverage" : [NSNull null],
                     @"extra" :  [NSNull null],
                     @"link" : [NSNull null],
                     },
                     @{
                     @"name" : @"TestProject-Library: -[SomeTests testStream]",
                     @"result" : @"pass",
                     @"userdata" : @"2013-09-10 15:06:05.784 otest[25153:707] >>>> i = 0\n2013-09-10 15:06:06.035 otest[25153:707] >>>> i = 1\n2013-09-10 15:06:06.286 otest[25153:707] >>>> i = 2\n",
                     @"coverage" : [NSNull null],
                     @"extra" :  [NSNull null],
                     @"link" : [NSNull null],
                     },
                     @{
                     @"name" : @"TestProject-Library: -[SomeTests testWillFail]",
                     @"result" : @"fail",
                     @"userdata" : @"/Users/fpotter/xctool/xctool/xctool-tests/TestData/TestProject-Library/TestProject-LibraryTests/SomeTests.m:40: 'a' should be equal to 'b' Strings aren't equal",
                     @"coverage" : [NSNull null],
                     @"extra" :  [NSNull null],
                     @"link" : [NSNull null],
                     },
                     @{
                     @"name" : @"TestProject-Library: -[SomeTests testWillPass]",
                     @"result" : @"pass",
                     @"userdata" : @"",
                     @"coverage" : [NSNull null],
                     @"extra" :  [NSNull null],
                     @"link" : [NSNull null],
                     },
                     ]));
}

@end
