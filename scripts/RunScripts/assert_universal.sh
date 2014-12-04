#!/bin/bash
#
# We use this to help us catch build-system issues where we aren't building
# things as Universal when we should be.
#

EXECUTABLE_PATH="$BUILT_PRODUCTS_DIR"/"$FULL_PRODUCT_NAME"

ARCHS=$(echo "$ARCHS" | tr " " "\n" | sort -g | tr "\n" " ")
VALID_ARCHS=$(echo "$VALID_ARCHS" | tr " " "\n" | sort -g | tr "\n" " ")

if [[ "$ARCHS" != "$VALID_ARCHS" ]]; then
  echo -n "error: '$EXECUTABLE_PATH' should have been built as a universal "
  echo    "binary ($VALID_ARCHS), but only had archs '$ARCHS'."
  exit 1
fi
