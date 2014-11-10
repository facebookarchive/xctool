#!/usr/bin/python
#
# To make our hack work, we change CC and LD to point at this script, and this
# script will swap out all the OSX-specific flags for iOS-specific flags.
#

import glob
import os
import re
import subprocess
import sys


def get_developer_dir():
    if 'DEVELOPER_DIR' in os.environ:
        return os.environ['DEVELOPER_DIR']
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
        xcodebuild_path = subprocess.check_output(['/usr/bin/which', 'xcodebuild']).strip()
        usr_bin_path = os.path.dirname(xcodebuild_path)
        return os.path.normpath(os.path.join(usr_bin_path, '..', '..'))


def get_clang_path():
    return os.path.join(get_developer_dir(),
        'Toolchains/XcodeDefault.xctoolchain/usr/bin/clang')


def get_path_for_iphonesimulator_platform(developer_dir):
    return ':'.join([
        os.path.join(developer_dir, 'Toolchains/XcodeDefault.xctoolchain/usr/bin'),
        os.path.join(developer_dir, 'Toolchains/XcodeDefault.xctoolchain/usr/libexec'),
        os.path.join(developer_dir, 'Platforms/iPhoneSimulator.platform/Developer/usr/bin'),
        os.path.join(developer_dir, 'Platforms/iPhoneSimulator.platform/Developer/usr/local/bin'),
        os.path.join(developer_dir, 'Platforms/iPhoneSimulator.platform/usr/bin'),
        os.path.join(developer_dir, 'Platforms/iPhoneSimulator.platform/usr/local/bin'),
        '/usr/bin',
        '/usr/local/bin',
        '/Tools',
        '/usr/bin',
        '/bin',
        '/usr/sbin',
        '/sbin'])


def get_env_for_iphonesimulator_platform(developer_dir):
    env = os.environ.copy()

    if 'MACOSX_DEPLOYMENT_TARGET' in env:
        del env['MACOSX_DEPLOYMENT_TARGET']

    env['PATH'] = get_path_for_iphonesimulator_platform(developer_dir)
    return env


def get_args_without_osxims():
    new_argv = []
    i = 1
    while i < len(sys.argv):
        arg = sys.argv[i]
        next_arg = sys.argv[i + 1] if (i + 1 < len(sys.argv)) else None

        if arg == '-isysroot' and 'SDKs/MacOSX' in next_arg:
            # skip, it's referencing the OSX SDK.
            i = i + 2
        elif ('-mmacosx-version-min' in arg):
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
    return new_argv


def get_iphonesimulator_sdk_versions_for_arch(developer_dir, arch):
    sdk_paths = glob.glob(os.path.join(
        developer_dir,
        'Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator*.*.sdk'))
    sdk_paths.sort()
    sdk_names = [os.path.basename(sdk_path) for sdk_path in sdk_paths]
    sdk_versions = [
        re.match(r'iPhoneSimulator(.+?)\.sdk', sdk_name).group(1) for sdk_name
        in sdk_names]

    # Only 7.0+ supports x86_64 builds.
    if arch == 'x86_64':
        sdk_versions = [
            version for version in sdk_versions
            if float(version) >= 7.0]

    if len(sdk_versions) == 0:
        raise Exception('No matching SDK for arch %s' % arch)

    return sdk_versions


def get_latest_iphonesimulator_sdk_version_arch(developer_dir, arch):
    sdk_versions = get_iphonesimulator_sdk_versions_for_arch(
        developer_dir, arch)
    return sdk_versions[len(sdk_versions) - 1]


def get_earliest_iphonesimulator_sdk_version_arch(developer_dir, arch):
    sdk_versions = get_iphonesimulator_sdk_versions_for_arch(
        developer_dir, arch)
    return sdk_versions[0]


def get_iphonesimulator_sdk_path(developer_dir, version):
    return '%s/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator%s.sdk' % (
        developer_dir, version)


def get_args_for_iphonesimulator_platform(developer_dir, sdk_version, deployment_target):
    isysroot = get_iphonesimulator_sdk_path(developer_dir, sdk_version)

    new_args = get_args_without_osxims()
    new_args.extend([
        '-isysroot', isysroot,
        '-F%s/Developer/Library/Frameworks' % isysroot,
        '-F%s/../../Library/Frameworks' % isysroot,
        '-mios-simulator-version-min=%s' % deployment_target,
        ])
    return new_args


def parse_sdk_version_and_deployment_target_from_script_name(
        developer_dir, script_name):
    clang_name = None
    tool = None
    sdk_version_label = None
    deployment_target_label = None

    pattern = re.compile(r'^(?:(?P<clang_name>clang(?:\+\+)?)-)?(?P<tool>cc|ld)-iphonesimulator-(?P<sdk>.*?)-targeting-(?P<target>.*?)$')
    match = pattern.match(script_name)

    if match:
        clang_name = match.group('clang_name') or 'clang'
        tool = match.group('tool')
        sdk_version_label = match.group('sdk')
        deployment_target_label = match.group('target')
    else:
        raise Exception(
            'script_name was not formatted as '
            'TOOL-iphonesimulator-VERSION-targeting-VERSION or '
            'CLANG_NAME-TOOL-iphonesimulator-VERSION-targeting-VERSION')

    latest_sdk_version = get_latest_iphonesimulator_sdk_version_arch(
        developer_dir, get_arch_from_args())
    earliest_sdk_version = get_earliest_iphonesimulator_sdk_version_arch(
        developer_dir, get_arch_from_args())

    def version_from_label(label):
        if label == 'latest':
            return latest_sdk_version
        elif label == 'earliest':
            return earliest_sdk_version
        else:
            return label

    sdk_version = version_from_label(sdk_version_label)
    deployment_target = version_from_label(deployment_target_label)

    return (clang_name, tool, sdk_version, deployment_target)


def get_arch_from_args():
    for i in range(len(sys.argv)):
        arg = sys.argv[i]
        next_arg = sys.argv[i + 1] if (i + 1) < len(sys.argv) else None

        if arg == '-arch':
            return next_arg
    raise Exception('Did not find the -arch argument')


developer_dir = get_developer_dir()
script_name = os.path.basename(sys.argv[0])

(clang_name, tool, sdk_version, deployment_target) = \
    parse_sdk_version_and_deployment_target_from_script_name(
        developer_dir, script_name)

new_env = get_env_for_iphonesimulator_platform(developer_dir)
new_argv = get_args_for_iphonesimulator_platform(
    developer_dir, sdk_version, deployment_target)

# Always be verbose, otherwise the build logs are entirely confusing because
# they only show OSX-specific args.
new_argv.append('-v')

if tool == 'ld':
    new_env['IPHONEOS_DEPLOYMENT_TARGET'] = deployment_target

clang_path = os.path.join(
    developer_dir,
    'Toolchains/XcodeDefault.xctoolchain/usr/bin/' + clang_name)

os.execve(clang_path, [clang_path] + new_argv, new_env)
