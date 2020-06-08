#!/bin/bash

set -u

# verify that swiftformat is on the PATH
command -v swiftformat >/dev/null 2>&1 || { echo >&2 "'swiftformat' could not be found. Please ensure it is installed and on the PATH."; exit 1; }

printf "=> Checking format\n"
FIRST_OUT="$(git status --porcelain)"
# swiftformat does not scale so we loop ourselves
shopt -u dotglob
find Sources/* Tests/* -type d | while IFS= read -r d; do
  printf "   * checking $d... "
  out=$(swiftformat $d 2>&1)
  SECOND_OUT="$(git status --porcelain)"
  if [[ "$out" == *"error"*] && ["$out" != "*No eligible files" ]]; then
    printf "\033[0;31merror!\033[0m\n"
    echo $out
    exit 1
  fi
  if [[ "$FIRST_OUT" != "$SECOND_OUT" ]]; then
    printf "\033[0;31mformatting issues!\033[0m\n"
    git --no-pager diff
    exit 1
  fi
  printf "\033[0;32mokay.\033[0m\n"
done
