#!/bin/sh

set -eu
set -f # disable globbing
export IFS=' '

echo "Copying received paths" $OUT_PATHS
ssh-add $CREDENTIALS_DIRECTORY/build_host_ssh_key
nix copy --to recv@cache $OUT_PATHS
ssh-add -D
echo "Done copying"
