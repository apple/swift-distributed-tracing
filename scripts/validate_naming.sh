#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift Tracing open source project
##
## Copyright (c) 2020 Moritz Lang and the Swift Tracing project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

##===----------------------------------------------------------------------===##
##
## This source file is part of the SwiftNIO open source project
##
## Copyright (c) 2017-2019 Apple Inc. and the SwiftNIO project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of SwiftNIO project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

printf "=> Checking for unacceptable language... "
# This greps for unacceptable terminology. The square bracket[s] are so that
# "git grep" doesn't find the lines that greps :).
unacceptable_terms=(
  -e blacklis[t]
  -e whitelis[t]
  -e slav[e]
)
if git grep --color=never -i "${unacceptable_terms[@]}" > /dev/null; then
  printf "\033[0;31mUnacceptable language found.\033[0m\n"
  git grep -i "${unacceptable_terms[@]}"
  exit 1
fi
printf "\033[0;32mokay.\033[0m\n"
