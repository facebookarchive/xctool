#!/bin/bash

# BuildSettingsWithConfigurationFile.txt
OUTFILE='BuildSettingsWithConfigurationFile.txt'
echo "Build settings from configuration file 'xctool/xctool-tests/TestData/dummy.xcconfig':\n    VAR1 = hello\n" > $OUTFILE
xcodebuild build -showBuildSettings -project TestProject-App-OSX/TestProject-App-OSX.xcodeproj >> $OUTFILE

# BuildSettingsWithUserDefaults.txt
OUTFILE='BuildSettingsWithUserDefaults.txt'
xcodebuild build -showBuildSettings -project TestProject-Library/TestProject-Library.xcodeproj ARCHS=i386 ONLY_ACTIVE_ARCH=NO SDKROOT=iphonesimulator -IDEBuildLocationStyle=DeterminedByTarget > $OUTFILE

# iOS-Application-Test-showBuildSettings.txt
OUTFILE='iOS-Application-Test-showBuildSettings.txt'
xcodebuild build -showBuildSettings -sdk iphonesimulator -project TestProject/TestProject.xcodeproj -target TestProjectApplicationTests >$OUTFILE

# iOS-Logic-Test-showBuildSettings.txt
OUTFILE='iOS-Logic-Test-showBuildSettings.txt'
xcodebuild build -showBuildSettings -sdk iphonesimulator -project TestProject-Library/TestProject-Library.xcodeproj -target TestProject-LibraryTests >$OUTFILE

# iOS-TestsThatCrash-showBuildSettings.txt
OUTFILE='iOS-TestsThatCrash-showBuildSettings.txt'
xcodebuild build -showBuildSettings -sdk iphonesimulator -project TestsThatCrash/TestsThatCrash.xcodeproj -target TestsThatCrashTests >$OUTFILE

# OSX-Application-Test-showBuildSettings.txt
OUTFILE='OSX-Application-Test-showBuildSettings.txt'
xcodebuild build -showBuildSettings -sdk macosx -project TestProject-App-OSX/TestProject-App-OSX.xcodeproj -target TestProject-App-OSXTests >$OUTFILE

# OSX-Logic-Test-showBuildSettings.txt
OUTFILE='OSX-Logic-Test-showBuildSettings.txt'
xcodebuild build -showBuildSettings -sdk macosx -project TestProject-Library-OSX/TestProject-Library-OSX.xcodeproj -target TestProject-Library-OSXTests >$OUTFILE

# ProjectsWithDifferentSDKs-ProjectsWithDifferentSDKs-showBuildSettings.txt
OUTFILE='ProjectsWithDifferentSDKs-ProjectsWithDifferentSDKs-showBuildSettings.txt'
xcodebuild build -showBuildSettings -project ProjectsWithDifferentSDKs/OSXLibrary/OSXLibrary.xcodeproj -target OSXLibrary >$OUTFILE

# ProjectWithOnlyATestTarget-showBuildSettings-test.txt
OUTFILE='ProjectWithOnlyATestTarget-showBuildSettings-test.txt'
xcodebuild test -showBuildSettings -sdk iphonesimulator  -showBuildSettings -project ProjectWithOnlyATestTarget/ProjectWithOnlyATestTarget.xcodeproj -target ProjectWithOnlyATestTarget >$OUTFILE

# TargetNamesWithSpaces-showBuildSettings.txt
OUTFILE='TargetNamesWithSpaces-showBuildSettings.txt'
xcodebuild build -showBuildSettings -project TestProject-Library/TestProject-Library.xcodeproj -sdk iphonesimulator -target "Target Name With Spaces" >$OUTFILE

# TestGetAvailableSDKsAndAliasesOutput.txt
OUTFILE='TestGetAvailableSDKsAndAliasesOutput.txt'
xcodebuild -sdk -version >$OUTFILE

# TestProject-App-OSX-showBuildSettings.txt
OUTFILE='TestProject-App-OSX-showBuildSettings.txt'
xcodebuild build -showBuildSettings -project TestProject-App-OSX/TestProject-App-OSX.xcodeproj >$OUTFILE

# TestProject-Assertion-SenTestingKit_Assertion-showBuildSettings.txt
OUTFILE='TestProject-Assertion-SenTestingKit_Assertion-showBuildSettings.txt'
xcodebuild build -showBuildSettings -sdk iphonesimulator -project TestProject-Assertion/TestProject-Assertion.xcodeproj/ -target SenTestingKit_Assertion >$OUTFILE

# TestProject-Assertion-XCTest_Assertion-showBuildSettings.txt
OUTFILE='TestProject-Assertion-XCTest_Assertion-showBuildSettings.txt'
xcodebuild build -showBuildSettings -sdk iphonesimulator -project TestProject-Assertion/TestProject-Assertion.xcodeproj/ -target XCTest_Assertion >$OUTFILE

# TestProject-Library-showBuildSettings.txt
OUTFILE='TestProject-Library-showBuildSettings.txt'
xcodebuild build -showBuildSettings -sdk iphonesimulator -project TestProject-Library/TestProject-Library.xcodeproj > $OUTFILE

# TestProject-Library-TestProject-Library-showBuildSettings.txt
OUTFILE='TestProject-Library-TestProject-Library-showBuildSettings.txt'
xcodebuild build -showBuildSettings -project TestProject-Library/TestProject-Library.xcodeproj > $OUTFILE

# TestProject-Library-TestProject-LibraryTests-showBuildSettings-iphoneos.txt
OUTFILE='TestProject-Library-TestProject-LibraryTests-showBuildSettings-iphoneos.txt'
xcodebuild build -showBuildSettings -sdk iphoneos -configuration Debug -project TestProject-Library/TestProject-Library.xcodeproj -target TestProject-LibraryTests > $OUTFILE

# TestProject-Library-TestProject-LibraryTests-showBuildSettings.txt
OUTFILE='TestProject-Library-TestProject-LibraryTests-showBuildSettings.txt'
xcodebuild build -showBuildSettings -sdk iphonesimulator -configuration Debug -project TestProject-Library/TestProject-Library.xcodeproj -target TestProject-LibraryTests > $OUTFILE

# TestProject-Library-XCTest-iOS-showBuildSettings.txt
OUTFILE='TestProject-Library-XCTest-iOS-showBuildSettings.txt'
xcodebuild build -showBuildSettings -project TestProject-Library-XCTest-iOS/TestProject-Library-XCTest-iOS.xcodeproj > $OUTFILE

# TestProject-Library-XCTest-iOS-TestProject-Library-XCTest-iOSTests-showBuildSettings-iphonesimulator.txt
OUTFILE='TestProject-Library-XCTest-iOS-TestProject-Library-XCTest-iOSTests-showBuildSettings-iphonesimulator.txt'
xcodebuild build -showBuildSettings -sdk iphonesimulator -project TestProject-Library-XCTest-iOS/TestProject-Library-XCTest-iOS.xcodeproj -target TestProject-Library-XCTest-iOSTests > $OUTFILE

# TestProject-Library-XCTest-OSX-showBuildSettings.txt
OUTFILE='TestProject-Library-XCTest-OSX-showBuildSettings.txt'
xcodebuild build -showBuildSettings -sdk macosx -project TestProject-Library-XCTest-OSX/TestProject-Library-XCTest-OSX.xcodeproj -target TestProject-Library-XCTest-OSXTests > $OUTFILE

# TestProject-WithNonExistingTargetInScheme-showBuildSettings.txt
OUTFILE='TestProject-WithNonExistingTargetInScheme-showBuildSettings.txt'
xcodebuild build -showBuildSettings -sdk iphonesimulator -project TestProject-WithNonExistingTargetInScheme/TestProject-WithNonExistingTargetInScheme.xcodeproj -scheme TestProject-WithNonExistingTargetInScheme > $OUTFILE

# TestProject-WithNonExistingTargetInScheme-TestProject-WithNonExistingTargetInSchemeTests-showBuildSettings.txt
OUTFILE='TestProject-WithNonExistingTargetInScheme-TestProject-WithNonExistingTargetInSchemeTests-showBuildSettings.txt'
xcodebuild build -showBuildSettings -sdk iphonesimulator -project TestProject-WithNonExistingTargetInScheme/TestProject-WithNonExistingTargetInScheme.xcodeproj -target TestProject-WithNonExistingTargetInSchemeTests > $OUTFILE

# TestProjectWithSchemeThatReferencesNonExistentTestTarget-showBuildSettings.txt
OUTFILE='TestProjectWithSchemeThatReferencesNonExistentTestTarget-showBuildSettings.txt'
xcodebuild build -showBuildSettings -project TestProjectWithSchemeThatReferencesNonExistentTestTarget/TestProject-Library.xcodeproj -scheme TestProject-Library > $OUTFILE

# TestsWithArgAndEnvSettingsInRunAction-TestsWithArgAndEnvSettings-showBuildSettings.txt
OUTFILE='TestsWithArgAndEnvSettingsInRunAction-TestsWithArgAndEnvSettings-showBuildSettings.txt'
xcodebuild build -showBuildSettings -project TestsWithArgAndEnvSettingsInRunAction/TestsWithArgAndEnvSettings.xcodeproj -target TestsWithArgAndEnvSettings > $OUTFILE

# TestsWithArgAndEnvSettingsInRunAction-TestsWithArgAndEnvSettings-TestsWithArgAndEnvSettingsTests-showBuildSettings.txt
OUTFILE='TestsWithArgAndEnvSettingsInRunAction-TestsWithArgAndEnvSettings-TestsWithArgAndEnvSettingsTests-showBuildSettings.txt'
xcodebuild build -showBuildSettings -project TestsWithArgAndEnvSettingsInRunAction/TestsWithArgAndEnvSettings.xcodeproj -target TestsWithArgAndEnvSettingsTests > $OUTFILE

# TestWorkspace-Library-TestProject-Library-showBuildSettings.txt
OUTFILE='TestWorkspace-Library-TestProject-Library-showBuildSettings.txt'
xcodebuild build -showBuildSettings -workspace TestWorkspace-Library/TestWorkspace-Library.xcworkspace/ -scheme TestProject-Library > $OUTFILE

# TestProject-TVApp-TestProject-TVApp-showBuildSettings.txt
OUTFILE='TestProject-TVApp-TestProject-TVApp-showBuildSettings.txt'
xcodebuild build -showBuildSettings -project TestProject-TVApp/TestProject-TVApp.xcodeproj/ -scheme TestProject-TVApp -sdk appletvsimulator > $OUTFILE

# TestProject-TVApp-TestProject-TVAppTests-showBuildSettings.txt
OUTFILE='TestProject-TVApp-TestProject-TVAppTests-showBuildSettings.txt'
xcodebuild build -showBuildSettings -project TestProject-TVApp/TestProject-TVApp.xcodeproj/ -target TestProject-TVAppTests -sdk appletvsimulator > $OUTFILE

# TestProject-TVFramework-TestProject-TVFramework-showBuildSettings.txt
OUTFILE='TestProject-TVFramework-TestProject-TVFramework-showBuildSettings.txt'
xcodebuild build -showBuildSettings -project TestProject-TVFramework/TestProject-TVFramework.xcodeproj/ -scheme TestProject-TVFramework -sdk appletvsimulator > $OUTFILE

# TestProject-TVApp-TestProject-TVAppTests-showBuildSettings.txt
OUTFILE='TestProject-TVFramework-TestProject-TVFrameworkTests-showBuildSettings.txt'
xcodebuild build -showBuildSettings -project TestProject-TVFramework/TestProject-TVFramework.xcodeproj/ -target TestProject-TVFrameworkTests -sdk appletvsimulator > $OUTFILE

# manually
# remove unexpected events from
# ./xctool.sh -project xctool/xctool-tests/TestData/TestProject-TVFramework/TestProject-TVFramework.xcodeproj/ -scheme TestProject-TVFramework -sdk appletvsimulator run-tests -only TestProject-TVFrameworkTests:TestProject_TVFrameworkTests/testWillPass,TestProject_TVFrameworkTests/testWillFail,TestProject_TVFrameworkTests/testPrintSDK,TestProject_TVFrameworkTests/testStream -reporter json-stream:xctool/xctool-tests/TestData/TestProject-TVFramework-TestProject-TVFrameworkTests-test-results.txt

