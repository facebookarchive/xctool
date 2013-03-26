
#import <Foundation/Foundation.h>

@interface TestRunner : NSObject {
  NSDictionary *_buildSettings;
  NSString *_senTestList;
  BOOL _senTestInvertScope;
  NSFileHandle *_standardOutput;
  NSFileHandle *_standardError;
  NSArray *_reporters;
}

- (id)initWithBuildSettings:(NSDictionary *)buildSettings
                senTestList:(NSString *)senTestList
         senTestInvertScope:(BOOL)senTestInvertScope
             standardOutput:(NSFileHandle *)standardOutput
              standardError:(NSFileHandle *)standardError
                  reporters:(NSArray *)reporters;

- (BOOL)runTestsWithError:(NSString **)error;

@end
