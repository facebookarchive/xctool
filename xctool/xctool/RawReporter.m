
#import "RawReporter.h"

@implementation RawReporter

- (void)passThrough:(NSDictionary *)event
{
  [self.outputHandle writeData:[NSJSONSerialization dataWithJSONObject:event options:0 error:nil]];
  [self.outputHandle writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)beginBuildTarget:(NSDictionary *)event { [self passThrough:event]; }
- (void)endBuildTarget:(NSDictionary *)event { [self passThrough:event]; }
- (void)beginBuildCommand:(NSDictionary *)event { [self passThrough:event]; }
- (void)endBuildCommand:(NSDictionary *)event { [self passThrough:event]; }
- (void)beginXcodebuild:(NSDictionary *)event { [self passThrough:event]; }
- (void)endXcodebuild:(NSDictionary *)event { [self passThrough:event]; }
- (void)beginOctest:(NSDictionary *)event { [self passThrough:event]; }
- (void)endOctest:(NSDictionary *)event { [self passThrough:event]; }
- (void)beginTestSuite:(NSDictionary *)event { [self passThrough:event]; }
- (void)endTestSuite:(NSDictionary *)event { [self passThrough:event]; }
- (void)beginTest:(NSDictionary *)event { [self passThrough:event]; }
- (void)endTest:(NSDictionary *)event { [self passThrough:event]; }
- (void)testOutput:(NSDictionary *)event { [self passThrough:event]; }
- (void)message:(NSDictionary *)event { [self passThrough:event]; }

@end
