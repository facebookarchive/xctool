#!/bin/bash
#
# We use this to codesign libraries that we use in Xcode 8.
#

codesign --force --sign - --timestamp=none "${CODESIGNING_FOLDER_PATH}"
