#!/bin/bash
#
# Compile xctool on-demand so we don't have to check-in binaries.
#

set -e

REALPATH="$([[ -L $0 ]] && echo $(dirname "$0")/$(readlink "$0") || echo "$0")"
XCTOOL_DIR="$(cd $(dirname "$REALPATH")/..; pwd)"

TEMP_PATH=$(/usr/bin/mktemp -t xctool-build)
trap "rm -f "$TEMP_PATH"" EXIT

BUILD_NEEDED_TOOL_PATH="$XCTOOL_DIR"/scripts/build_needed.sh
BUILD_NEEDED=$("$BUILD_NEEDED_TOOL_PATH" "$*")

COLOR_BRIGHT_WHITE="\033[1;97m"
COLOR_BOLD_RED="\033[1;31m"
COLOR_GREEN="\033[0;32m"
COLOR_NORMAL="\033[0m"
CHECK_MARK="\xe2\x9c\x93"

if [ "$BUILD_NEEDED" -eq 1 ]; then
  echo -e "${COLOR_BRIGHT_WHITE}=== BUILDING XCTOOL ===${COLOR_NORMAL}"
  echo
  echo -e "  $XCTOOL_DIR/scripts/build.sh"

  # Alas, date on Mac OS X has no %N, so we can't get milliseconds here.
  BUILD_TIME_START=$SECONDS
  if ! "$XCTOOL_DIR"/scripts/build.sh > $TEMP_PATH 2>&1; then
    echo
    echo -e "${COLOR_BOLD_RED}ERROR${COLOR_NORMAL}: Failed to build xctool:"
    cat $TEMP_PATH
    exit 1
  fi

  BUILD_TIME_END=$SECONDS

  BUILD_DURATION_MS=$(((${BUILD_TIME_END}-${BUILD_TIME_START}) * 1000))

  echo -ne "      ${COLOR_GREEN}${CHECK_MARK}${COLOR_NORMAL} Built xctool "
  echo -e "${COLOR_GREEN}(${BUILD_DURATION_MS} ms)${COLOR_NORMAL}"
  echo
fi

# Will be a short git hash or just '.' if we're not in a git repo.
REVISION=$((\
  git --git-dir="${XCTOOL_DIR}/.git" log -n 1 --format=%h 2> /dev/null) || \
  echo ".")

XCODEBUILD_VERSION=$(xcodebuild -version)
XCODEBUILD_VERSION=`expr "$XCODEBUILD_VERSION" : '^.*Build version \(.*\)'`

"$XCTOOL_DIR"/build/$REVISION/$XCODEBUILD_VERSION/Products/Release/bin/xctool "$@"
