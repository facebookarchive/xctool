#!/bin/bash
#
# We use this to help us catch build-system issues where we aren't building
# things as Universal when we should be.
#

EXECUTABLE_PATH="$BUILT_PRODUCTS_DIR"/"$FULL_PRODUCT_NAME"

ARCHS=$(lipo -info "$EXECUTABLE_PATH" | \
          perl -n -e '/\: .*?: (.*?)$/ && print "$1\n";' | \
          xargs -n 1 echo | sort | xargs)

if [[ $ARCHS != "i386 x86_64" ]]; then
  echo -n "error: '$EXECUTABLE_PATH' should have been built as a universal "
  echo    "binary, but only had archs '$ARCHS'."
  exit 1
fi
