
#import <Foundation/Foundation.h>

#import "XcodeTool.h"

int main(int argc, const char * argv[])
{
  @autoreleasepool {
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];
    
    XcodeTool *tool = [[[XcodeTool alloc] init] autorelease];
    tool.arguments = [arguments subarrayWithRange:NSMakeRange(1, arguments.count - 1)];
    tool.standardOutput = [NSFileHandle fileHandleWithStandardOutput];
    tool.standardError = [NSFileHandle fileHandleWithStandardError];
    
    [tool run];
    
    return tool.exitStatus;
  }
  return 0;
}

