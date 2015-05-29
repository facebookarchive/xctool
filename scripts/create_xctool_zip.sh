#!/bin/bash

set -e

# Creates xctool.zip with the binary, libraries, etc. laid out how the process expects it.

PLATFORM="macosx-x86_64"

while getopts "b:l:x:r:m:o:" opt; do
    case "$opt" in
        b)
            binary=$OPTARG
            ;;
        l)
            libs=$OPTARG
            ;;
        m)
            mobile_installation_helper_app=$OPTARG
            ;;
        x)
            libexecs=$OPTARG
            ;;
        r)
            reporters=$OPTARG
            ;;
        o)
            output=$OPTARG
            ;;
    esac
done

mkdir -p out/bin out/lib out/libexec out/libexec/mobile-installation-helper.app out/reporters
cp "$binary" out/bin/xctool

for lib in ${libs//:/ }; do
    cp "$lib" out/lib/$(basename $lib \#$PLATFORM)
done

for libexec in ${libexecs//:/ }; do
    cp "$libexec" out/libexec/$(basename $libexec \#$PLATFORM)
done

if [[ "$mobile_installation_helper_app" ]]; then
    pushd out/libexec/mobile-installation-helper.app && unzip "$mobile_installation_helper_app" && popd
fi

for reporter in ${reporters//:/ }; do
    cp "$reporter" out/reporters/$(basename $reporter \#$PLATFORM)
done

cd out && zip -r -0 "$output" bin lib libexec reporters
