
#import <Foundation/Foundation.h>

void ParseClassAndMethodFromTestName(NSString **className, NSString **methodName, NSString *testName)
{
  NSCAssert(className, @"className should be non-nil");
  NSCAssert(methodName, @"methodName should be non-nil");
  NSCAssert(testName, @"testName should be non-nil");

  NSRegularExpression *testNameRegex =
  [NSRegularExpression regularExpressionWithPattern:@"^-\\[([\\w.]+) (\\w+)\\]$"
                                            options:0
                                              error:nil];
  NSTextCheckingResult *match =
  [testNameRegex firstMatchInString:testName
                            options:0
                              range:NSMakeRange(0, [testName length])];
  NSCAssert(match && [match numberOfRanges] == 3,
            @"Test name seems to be malformed: %@", testName);

  *className = [testName substringWithRange:[match rangeAtIndex:1]];
  *methodName = [testName substringWithRange:[match rangeAtIndex:2]];
}
