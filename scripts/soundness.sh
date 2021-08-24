#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift Distributed Tracing open source project
##
## Copyright (c) 2020-2021 Apple Inc. and the Swift Distributed Tracing project
## authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

set -eu
here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

printf "=> Checking linux tests... "
FIRST_OUT="$(git status --porcelain)"
ruby "$here/../scripts/generate_linux_tests.rb" > /dev/null
SECOND_OUT="$(git status --porcelain)"
if [[ "$FIRST_OUT" != "$SECOND_OUT" ]]; then
  printf "\033[0;31mmissing changes!\033[0m\n"
  git --no-pager diff
  exit 1
else
  printf "\033[0;32mokay.\033[0m\n"
fi

bash $here/validate_license_headers.sh
bash $here/validate_language.sh
bash $here/validate_format.sh
