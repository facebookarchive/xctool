
#import <Foundation/Foundation.h>

@interface OCUnitTestRunner : NSObject {
  NSDictionary *_buildSettings;
  NSString *_senTestList;
  BOOL _senTestInvertScope;
  BOOL _garbageCollection;
  NSFileHandle *_standardOutput;
  NSFileHandle *_standardError;
  NSArray *_reporters;
}

- (id)initWithBuildSettings:(NSDictionary *)buildSettings
                senTestList:(NSString *)senTestList
         senTestInvertScope:(BOOL)senTestInvertScope
          garbageCollection:(BOOL)garbageCollection
             standardOutput:(NSFileHandle *)standardOutput
              standardError:(NSFileHandle *)standardError
                  reporters:(NSArray *)reporters;

- (BOOL)runTestsWithError:(NSString **)error;

- (NSArray *)otestArguments;

- (NSString *)testBundlePath;

@end
