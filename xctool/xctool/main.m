
#import <Foundation/Foundation.h>

#import "XCTool.h"

int main(int argc, const char * argv[])
{
  @autoreleasepool {
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];

    XCTool *tool = [[[XCTool alloc] init] autorelease];
    tool.arguments = [arguments subarrayWithRange:NSMakeRange(1, arguments.count - 1)];
    tool.standardOutput = [NSFileHandle fileHandleWithStandardOutput];
    tool.standardError = [NSFileHandle fileHandleWithStandardError];

    [tool run];

    return tool.exitStatus;
  }
  return 0;
}

