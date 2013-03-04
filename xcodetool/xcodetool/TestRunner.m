
#import "TestRunner.h"

@implementation TestRunner

- (id)initWithBuildSettings:(NSDictionary *)buildSettings
                senTestList:(NSString *)senTestList
         senTestInvertScope:(BOOL)senTestInvertScope
             standardOutput:(NSFileHandle *)standardOutput
              standardError:(NSFileHandle *)standardError
                  reporters:(NSArray *)reporters
{
  if (self = [super init]) {
    _buildSettings = [buildSettings retain];
    _senTestList = [senTestList retain];
    _senTestInvertScope = senTestInvertScope;
    _standardOutput = [standardOutput retain];
    _standardError = [standardError retain];
    _reporters = [reporters retain];
  }
  return self;
}

- (void)dealloc
{
  [_buildSettings release];
  [_senTestList release];
  [_standardOutput release];
  [_standardError release];
  [_reporters release];
  [super dealloc];
}

- (BOOL)runTests {
  return NO;
}

@end
