#!/bin/sh -x
set -e

FRAMEWORK_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.framework"

FRAMEWORK_VERSION="${FRAMEWORK_VERSION:-A}"
FRAMEWORK_VERSION_DIR="${FRAMEWORK_DIR}/Versions/${FRAMEWORK_VERSION}"

CURRENT_VERSION="Versions/Current"
FRAMEWORK_CURRENT_DIR="${FRAMEWORK_DIR}/${CURRENT_VERSION}"
HEADERS="Headers"
HEADER_DIR="${BUILT_PRODUCTS_DIR}/include/${PRODUCT_NAME}/" 

mkdir -p "${FRAMEWORK_VERSION_DIR}/${HEADERS}"

# Link "Current" to the framework version, e.g. "A"
/bin/ln -sfh "${FRAMEWORK_VERSION}" "${FRAMEWORK_CURRENT_DIR}"
/bin/ln -sfh "${CURRENT_VERSION}/${PRODUCT_NAME}" "${FRAMEWORK_DIR}/${PRODUCT_NAME}"
/bin/ln -sfh "${CURRENT_VERSION}/${HEADERS}" "${FRAMEWORK_DIR}/${HEADERS}"

# The -a ensures that the headers maintain the source modification date
# so that we don't constantly cause propagating rebuilds of files
# that import these headers.
/bin/cp -a "${HEADER_DIR}" "${FRAMEWORK_VERSION_DIR}/${HEADERS}"
