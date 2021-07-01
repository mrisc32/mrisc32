#!/bin/bash

TARGET_FILE=$1
TMP_FILE=$(mktemp)

# Generate a \specrev TeX command based on git describe.
echo '\newcommand{\specrev}{\mbox{'"$(git describe --tags --match 'v*.*' --dirty=-MODIFIED)"'}}' > "${TMP_FILE}"

# Only replace the target file if it's different from the temporary file.
diff "${TMP_FILE}" "${TARGET_FILE}" &>/dev/null || cp "${TMP_FILE}" "${TARGET_FILE}"

rm -f "${TMP_FILE}"

