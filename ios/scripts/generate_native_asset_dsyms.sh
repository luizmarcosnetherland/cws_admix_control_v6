#!/bin/sh

set -eu

APP_FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${WRAPPER_NAME}/Frameworks"
DSYM_OUTPUT_DIR="${DWARF_DSYM_FOLDER_PATH:-}"

if [ ! -d "${APP_FRAMEWORKS_DIR}" ] || [ -z "${DSYM_OUTPUT_DIR}" ]; then
  exit 0
fi

generate_framework_dsym() {
  FRAMEWORK_NAME="$1"
  FRAMEWORK_BINARY="${APP_FRAMEWORKS_DIR}/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}"
  FRAMEWORK_DSYM="${DSYM_OUTPUT_DIR}/${FRAMEWORK_NAME}.framework.dSYM"

  if [ ! -f "${FRAMEWORK_BINARY}" ]; then
    return 0
  fi

  rm -rf "${FRAMEWORK_DSYM}"

  if ! /usr/bin/dsymutil "${FRAMEWORK_BINARY}" -o "${FRAMEWORK_DSYM}" >/dev/null 2>&1; then
    echo "warning: Could not generate dSYM for ${FRAMEWORK_NAME}.framework"
    rm -rf "${FRAMEWORK_DSYM}"
  fi
}

generate_framework_dsym "objective_c"
generate_framework_dsym "sqlite3"
