#!/usr/bin/python
#
# Generates symlinks to the clang-as-ios-dylib.py script for all the possible
# combinations of iOS SDK and IPHONEOS_DEPLOYMENT_TARGET.
#
# As more SDKs are released, we'll need to update the `versions` array, re-run
# the script, and commit the new links.

import os

versions = [
    '5.0',
    '5.1',
    '6.0',
    '6.1',
    '7.0',
    '7.1',
    '8.0',
    # Symbolic names for the earliest and latest SDK versions that support the
    # current arch.
    'earliest',
    'latest',
]

for sdk_version in versions:
    for deployment_target in versions:
        for tool in ['cc', 'ld']:
            name = 'links/%s-iphonesimulator-%s-targeting-%s' % (
                tool, sdk_version, deployment_target)

            if os.path.exists(name):
                print '%s (exists)' % name
            else:
                print '%s (creating)' % name
                os.symlink('../clang-as-ios-dylib.py', name)

