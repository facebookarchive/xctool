COMMON_PREPROCESSOR_FLAGS = ['-fobjc-arc', '-mmacosx-version-min=10.7', '-Wno-deprecated-declarations']

COMMON_COMPILER_FLAGS = ['-Wno-undeclared-selector', '-Wno-implicit-retain-self']

COMMON_OTEST_SRCS = [
    'Common/DuplicateTestNameFix.m',
    'Common/NSInvocationInSetFix.m',
    'Common/ParseTestName.m',
    'Common/SenIsSuperclassOfClassPerformanceFix.m',
    'Common/Swizzle.m',
    'Common/TestingFramework.m',
]

COMMON_OTEST_HEADERS = [
    'Common/DuplicateTestNameFix.h',
    'Common/NSInvocationInSetFix.h',
    'Common/ParseTestName.h',
    'Common/SenIsSuperclassOfClassPerformanceFix.h',
    'Common/Swizzle.h',
    'Common/TestingFramework.h',
]

COMMON_REPORTERS_SRCS = [
    'Common/EventGenerator.m',
    'Common/NSFileHandle+Print.m',
    'Common/Reporter.m',
    'Common/TaskUtil.m',
    'Common/XcodeBuildSettings.m',
    'Common/XCToolUtil.m',
]

COMMON_REPORTERS_HEADERS = [
    'Common/EventGenerator.h',
    'Common/EventSink.h',
    'Common/NSConcreteTask.h',
    'Common/NSFileHandle+Print.h',
    'Common/Reporter.h',
    'Common/ReporterEvents.h',
    'Common/TaskUtil.h',
    'Common/XcodeBuildSettings.h',
    'Common/XCToolUtil.h',
]

TEXT_REPORTERS_SRCS = COMMON_REPORTERS_SRCS + glob(['reporters/text/**/*.m']) + [
    'reporters/TestResultCounter.m',
]

TEXT_REPORTERS_HEADERS = COMMON_REPORTERS_HEADERS + glob(['reporters/text/**/*.h']) + [
    'reporters/TestResultCounter.h',
]

apple_binary(
    name = 'xctool-bin',
    srcs = glob([
        'Common/**/*.m',
        'xctool/xctool/**/*.m',
        'xctool/xctool/**/*.mm',
    ]),
    headers = glob([
        'Common/**/*.h',
        'xctool/Headers/**/*.h',
        'xctool/xctool/**/*.h',
    ]),
    linker_flags = [
        '-F$DEVELOPER_DIR/Platforms/iPhoneSimulator.platform/Developer/Library/PrivateFrameworks',
        '-F$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/Library/Frameworks',
        '-F$DEVELOPER_DIR/../SharedFrameworks',
        '-F$DEVELOPER_DIR/Library/PrivateFrameworks',
        '-F$DEVELOPER_DIR/Library/MigrationFrameworks',
        '-weak_framework',
        'DVTFoundation',
        '-weak_framework',
        'DVTiPhoneSimulatorRemoteClient',
        '-weak_framework',
        'CoreSimulator',
        '-weak_framework',
        'XCTest',
        '-liconv',
    ],
    preprocessor_flags = COMMON_PREPROCESSOR_FLAGS + [
        '-DXCODE_VERSION=0630',
    ],
    lang_preprocessor_flags = {
        'CXX': ['-std=c++11', '-stdlib=libc++'],
        'OBJCXX': ['-std=c++11', '-stdlib=libc++'],
    },
    compiler_flags = COMMON_COMPILER_FLAGS,
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/AppKit.framework',
        '$SDKROOT/System/Library/Frameworks/CoreFoundation.framework',
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
        '$SDKROOT/System/Library/Frameworks/QuartzCore.framework',
    ],
)

apple_binary(
    name = 'pretty',
    srcs = TEXT_REPORTERS_SRCS,
    headers = TEXT_REPORTERS_HEADERS,
    preprocessor_flags = COMMON_PREPROCESSOR_FLAGS,
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
    ],
    linker_flags = [
        '-liconv',
    ],
    compiler_flags = COMMON_COMPILER_FLAGS,
)

apple_binary(
    name = 'plain',
    srcs = TEXT_REPORTERS_SRCS,
    headers = TEXT_REPORTERS_HEADERS,
    preprocessor_flags = COMMON_PREPROCESSOR_FLAGS,
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
    ],
    linker_flags = [
        '-liconv',
    ],
    compiler_flags = COMMON_COMPILER_FLAGS,
)

apple_binary(
    name = 'phabricator',
    srcs = COMMON_REPORTERS_SRCS + glob([
        'reporters/phabricator/**/*.m',
    ]),
    headers = COMMON_REPORTERS_HEADERS + glob([
        'reporters/phabricator/**/*.h'
    ]),
    preprocessor_flags = COMMON_PREPROCESSOR_FLAGS,
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
    ],
    linker_flags = [
        '-liconv',
    ],
    compiler_flags = COMMON_COMPILER_FLAGS,
)

apple_binary(
    name = 'junit',
    srcs = COMMON_REPORTERS_SRCS + glob([
        'reporters/junit/**/*.m',
    ]),
    headers = COMMON_REPORTERS_HEADERS + glob([
        'reporters/junit/**/*.h'
    ]),
    preprocessor_flags = COMMON_PREPROCESSOR_FLAGS,
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
    ],
    linker_flags = [
        '-liconv',
    ],
    compiler_flags = COMMON_COMPILER_FLAGS,
)

apple_binary(
    name = 'json-compilation-database',
    srcs = COMMON_REPORTERS_SRCS + glob([
        'reporters/json-compilation-database/**/*.m',
    ]),
    headers = COMMON_REPORTERS_HEADERS + glob([
        'reporters/json-compilation-database/**/*.h'
    ]),
    preprocessor_flags = COMMON_PREPROCESSOR_FLAGS,
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
    ],
    linker_flags = [
        '-liconv',
    ],
    compiler_flags = COMMON_COMPILER_FLAGS,
)

apple_binary(
    name = 'user-notifications',
    srcs = COMMON_REPORTERS_SRCS + glob([
        'reporters/user-notifications/**/*.m',
    ]),
    headers = COMMON_REPORTERS_HEADERS + glob([
        'reporters/user-notifications/**/*.h'
    ]),
    preprocessor_flags = COMMON_PREPROCESSOR_FLAGS,
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
    ],
    linker_flags = [
        '-liconv',
    ],
    compiler_flags = COMMON_COMPILER_FLAGS,
)

apple_binary(
    name = 'teamcity',
    srcs = COMMON_REPORTERS_SRCS + glob([
        'reporters/teamcity/**/*.m',
    ]),
    headers = COMMON_REPORTERS_HEADERS + glob([
        'reporters/teamcity/**/*.h'
    ]),
    preprocessor_flags = COMMON_PREPROCESSOR_FLAGS,
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
    ],
    linker_flags = [
        '-liconv',
    ],
    compiler_flags = COMMON_COMPILER_FLAGS,
)

apple_binary(
    name = 'json-stream',
    srcs = COMMON_REPORTERS_SRCS + glob([
        'reporters/json-stream/**/*.m',
    ]),
    headers = COMMON_REPORTERS_HEADERS,
    preprocessor_flags = COMMON_PREPROCESSOR_FLAGS,
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
    ],
    linker_flags = [
        '-liconv',
    ],
    compiler_flags = COMMON_COMPILER_FLAGS,
)

apple_binary(
    name = 'otest-query-ios-bin',
    srcs = glob(['otest-query/otest-query-ios/**/*.m']),
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
    ],
    compiler_flags = COMMON_COMPILER_FLAGS,
)

genrule(
    name = 'otest-query-ios',
    srcs = [
        ':otest-query-ios-bin#iphonesimulator-i386',
        ':otest-query-ios-bin#iphonesimulator-x86_64',
    ],
    out = 'otest-query-ios',
    cmd = 'lipo $SRCS -create -output $OUT',
)

apple_binary(
    name = 'otest-query-osx-bin',
    srcs = COMMON_OTEST_SRCS + glob([
        'otest-query/OtestQuery/**/*.m',
        'otest-query/otest-query-osx/**/*.m',
    ]),
    headers = COMMON_OTEST_HEADERS + glob([
        'otest-query/OtestQuery/**/*.h',
    ]),
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
    ],
    compiler_flags = COMMON_COMPILER_FLAGS,
)

genrule(
    name = 'otest-query-osx',
    srcs = [
        ':otest-query-osx-bin#macosx-i386',
        ':otest-query-osx-bin#macosx-x86_64',
    ],
    out = 'otest-query-osx',
    cmd = 'lipo $SRCS -create -output $OUT',
)

apple_library(
    name = 'otest-query-lib',
    srcs = COMMON_OTEST_SRCS + glob([
        'otest-query/otest-query-lib/**/*.m',
        'otest-query/OtestQuery/**/*.m',
    ]),
    headers = COMMON_OTEST_HEADERS + glob([
        'otest-query/OtestQuery/**/*.h',
    ]),
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
    ],
    compiler_flags = COMMON_COMPILER_FLAGS,
)

genrule(
    name = 'otest-query-lib-ios',
    srcs = [
        ':otest-query-lib#iphonesimulator-i386,shared',
        ':otest-query-lib#iphonesimulator-x86_64,shared',
    ],
    out = 'otest-query-lib-ios.dylib',
    cmd = 'lipo $SRCS -create -output $OUT',
)

genrule(
    name = 'otest-query-lib-osx',
    srcs = [
        ':otest-query-lib#macosx-i386,shared',
        ':otest-query-lib#macosx-x86_64,shared',
    ],
    out = 'otest-query-lib-osx.dylib',
    cmd = 'lipo $SRCS -create -output $OUT',
)

apple_library(
    name = 'otest-shim-sentestingkit',
    header_path_prefix = 'SenTestingKit',
    exported_headers = glob(['otest-shim/SenTestingKit/*.h']),
    exported_preprocessor_flags = ['-DSENTEST_IGNORE_DEPRECATION_WARNING'],
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
    ],
)

apple_library(
    name = 'otest-shim',
    srcs = COMMON_OTEST_SRCS + glob([
        'otest-shim/otest-shim/**/*.m',
    ]) + [
        'Common/EventGenerator.m',
    ],
    headers = COMMON_OTEST_HEADERS + glob([
        'otest-shim/otest-shim/**/*.h',
    ]) + [
        'Common/dyld-interposing.h',
        'Common/dyld_priv.h',
        'Common/EventGenerator.h',
        'Common/ReporterEvents.h',
        'Common/XCTest.h',
    ],
    # this shouldn't be needed as soon as Buck is fixed
    # it comes from `otest-shim-sentestingkit`'s `exported_preprocessor_flags`
    preprocessor_flags = ['-DSENTEST_IGNORE_DEPRECATION_WARNING'],
    compiler_flags = COMMON_COMPILER_FLAGS,
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
    ],
    deps = [
        ':otest-shim-sentestingkit',
    ]
)

genrule(
    name = 'otest-shim-ios',
    srcs = [
        ':otest-shim#iphonesimulator-i386,shared',
        ':otest-shim#iphonesimulator-x86_64,shared',
    ],
    out = 'otest-shim-ios.dylib',
    cmd = 'lipo $SRCS -create -output $OUT',
)

genrule(
    name = 'otest-shim-osx',
    srcs = [
        ':otest-shim#macosx-i386,shared',
        ':otest-shim#macosx-x86_64,shared',
    ],
    out = 'otest-shim-osx.dylib',
    cmd = 'lipo $SRCS -create -output $OUT',
)

genrule(
    name = 'xctool-zip',
    srcs = [
        'scripts/create_xctool_zip.sh',
    ],
    cmd = 'scripts/create_xctool_zip.sh ' +
        # Binary
        '-b $(location :xctool-bin#macosx-x86_64) ' +
        # Libs
        '-l $(location :otest-query-lib-ios):' +
           '$(location :otest-query-lib-osx):' +
           '$(location :otest-shim-ios):' +
           '$(location :otest-shim-osx) ' +
        # Libexecs
        '-x $(location :otest-query-ios):' +
           '$(location :otest-query-osx) ' +
        # Reporters
        '-r $(location :pretty#macosx-x86_64):' +
           '$(location :plain#macosx-x86_64):' +
           '$(location :phabricator#macosx-x86_64):' +
           '$(location :junit#macosx-x86_64):' +
           '$(location :json-compilation-database#macosx-x86_64):' +
           '$(location :json-stream#macosx-x86_64):' +
           '$(location :user-notifications#macosx-x86_64):' +
           '$(location :teamcity#macosx-x86_64) ' +
        # Output zip location
        '-o $OUT',
    out = 'xctool.zip',
    visibility = ['PUBLIC'],
)

# Minimal xctool only includes the json-stream reporter
genrule(
    name = 'xctool-minimal-zip',
    srcs = [
        'scripts/create_xctool_zip.sh',
    ],
    cmd = 'scripts/create_xctool_zip.sh ' +
        # Binary
        '-b $(location :xctool-bin#macosx-x86_64) ' +
        # Libs
        '-l $(location :otest-query-lib-ios):' +
           '$(location :otest-query-lib-osx):' +
           '$(location :otest-shim-ios):' +
           '$(location :otest-shim-osx) ' +
        # Libexecs
        '-x $(location :otest-query-ios):' +
           '$(location :otest-query-osx) ' +
        # Reporters
        '-r $(location :json-stream#macosx-x86_64) ' +
        # Output zip location
        '-o $OUT',
    out = 'xctool-minimal.zip',
    visibility = ['PUBLIC'],
)
