#!/bin/bash

GFX_START=32768
GFX_W=256
GFX_H=256
GFX_SIZE=$((${GFX_W} * ${GFX_H}))

if [ $# -eq 0 ] ; then
    echo "Usage: $0 ram-dump-file"
    exit 1
fi

RAM_FILE="$1"
PNG_FILE="${RAM_FILE}.png"

cat "${RAM_FILE}" | tail -c +$((${GFX_START} + 1)) | head -c ${GFX_SIZE} | convert -size ${GFX_W}x${GFX_H} -depth 8 gray:- "${PNG_FILE}"

