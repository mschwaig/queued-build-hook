#!/bin/sh

set -eu
set -f # disable globbing
export IFS=' '

echo "Dummy dequeue hook received paths" $OUT_PATHS
