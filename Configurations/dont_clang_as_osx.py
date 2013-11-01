#!/usr/bin/env python
#
# In 'iOS-Simulator-Dylib.xcconfig', we used to be able to fudge OTHER_CFLAGS
# and OTHER_LDFLAGS enough to trick Xcode/clang into building a OSX dylib
# target as an iOS dylib target.  Something changed in the linker for Xcode5,
# and we really need to strip out the OSX-specific flags to make this work.

import os
import subprocess
import sys

developer_dir = None

if 'DEVELOPER_DIR' in os.environ:
    developer_dir = os.environ['DEVELOPER_DIR']
else:
    # Before building, Xcode runs clang in a special mode that dumps a bunch
    # of the internal macros that are set. e.g. --
    #
    # /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang \
    #   -v -E -dM -arch i386 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.9.sdk \
    #   -x objective-c -c /dev/null 2>&1
    #
    # At this point, it's not yet setting DEVELOPER_DIR in the environment, but
    # it is prepending '/Applications/Xcode.app/Contents/Developer/usr/bin' to
    # the path.  We can deduce DEVELOPER_DIR from that.

    # This should give us a path that's inside the developer dir, given how
    # Xcode has set our path. e.g. --
    # /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild
    xcodebuild_path = subprocess.check_output(['which', 'xcodebuild']).strip()
    usr_bin_path = os.path.dirname(xcodebuild_path)
    developer_dir = os.path.normpath(os.path.join(usr_bin_path, '..', '..'))

clang_path = '%s/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang' % (
    developer_dir)

new_argv = []
i = 1
while i < len(sys.argv):
    arg = sys.argv[i]
    next_arg = sys.argv[i + 1] if (i + 1 < len(sys.argv)) else None

    if arg == '-isysroot' and 'SDKs/MacOSX' in next_arg:
        # skip, it's referencing the OSX SDK.
        i = i + 2
    elif '-mmacosx-version-min' in arg:
        # clang won't be OK with '-mmacosx-version-min' and
        # '-miphoneos-version-min' being passed at the same time.
        i = i + 1
    elif (arg == '-F/Applications/Xcode.app/Contents/'
                 'Developer/Library/Frameworks'):
        # skip - for some reason Xcode5 always includes this framework path
        # and it's causing ld to select the wrong version of SenTestingKit:
        #
        # ld: building for iOS Simulator, but linking against dylib built for
        # MacOSX file '/Applications/Xcode.app/Contents/Developer/Library/
        # Frameworks/SenTestingKit.framework/SenTestingKit' for
        # architecture i386
        #
        # It's also always using /Application/Xcode.app even when the active
        # Xcode is something else.
        i = i + 1
    else:
        i = i + 1
        new_argv.append(arg)

env_pruned = {}
for k, v in os.environ.iteritems():
    if k == 'MACOSX_DEPLOYMENT_TARGET':
        continue
    elif k == 'PATH':
        path_parts = v.split(':')
        new_path = ':'.join([part.replace('MacOSX.platform', 'iPhoneSimulator.platform') for part in path_parts])
        env_pruned[k] = new_path
    else:
        env_pruned[k] = v

os.execve(clang_path, [clang_path] + new_argv, env_pruned)
