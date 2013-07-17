#import "Reporter.h"

@interface JSONCompilationDatabaseReporter : Reporter
{
  NSMutableArray *_compiles;
  NSMutableArray *_precompiles;
  NSDictionary *_currentBuildCommand;
}

@end
