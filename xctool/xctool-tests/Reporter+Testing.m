
#import "Reporter+Testing.h"

#import "FakeFileHandle.h"
#import "XCToolUtil.h"

@implementation Reporter (Testing)

+ (NSData *)outputDataWithEventsFromFile:(NSString *)path
                                 options:(Options *)options
{
  Reporter *reporter = [[self alloc] init];
  [reporter setOutputPath:@"-"];

  FakeFileHandle *fakeFileHandle = [[FakeFileHandle alloc] init];

  [reporter openWithStandardOutput:(NSFileHandle *)fakeFileHandle error:nil];

  NSString *pathContents = [NSString stringWithContentsOfFile:path
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
  NSArray *lines = [pathContents componentsSeparatedByCharactersInSet:
                    [NSCharacterSet newlineCharacterSet]];
  for (NSString *line in lines) {
    if ([line length] == 0) {
      break;
    }

    PublishEventToReporters(@[reporter],
                            [NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding]
                                                            options:0
                                                              error:nil]);
  }

  [reporter close];
  NSData *outputData = [[fakeFileHandle dataWritten] retain];

  [reporter release];
  [fakeFileHandle release];

  return [outputData autorelease];
}

@end

