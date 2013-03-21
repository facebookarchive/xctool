
#import <Foundation/Foundation.h>

NSDictionary *BuildSettingsFromOutput(NSString *output);
NSString *AbsoluteExecutablePath(void);
NSString *PathToFBXcodetoolBinaries(void);
NSString *XcodeDeveloperDirPath(void);
NSString *StringForJSON(id object);
NSString *MakeTempFileWithPrefix(NSString *prefix);
NSDictionary *GetAvailableSDKsAndAliases();
