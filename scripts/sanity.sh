#!/bin/bash

set -eu
here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# bash $here/validate_license_header.sh
bash $here/validate_format.sh
