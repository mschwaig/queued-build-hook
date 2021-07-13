#!/bin/sh

set -eu
set -f # disable globbing
export IFS=' '

echo "Test dequeue hook received paths" $OUT_PATHS
