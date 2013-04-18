
#import <Foundation/Foundation.h>

NSDictionary *BuildSettingsFromOutput(NSString *output);
NSString *AbsoluteExecutablePath(void);
NSString *PathToXCToolBinaries(void);
NSString *XcodeDeveloperDirPath(void);
NSString *MakeTempFileWithPrefix(NSString *prefix);
NSDictionary *GetAvailableSDKsAndAliases();
