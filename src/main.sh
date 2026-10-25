#!/bin/sh
# @file src/main.sh
# @description CLI script entrypoint that delegates execution to the root cdd.sh router.
# shellcheck disable=SC1091
. "$(cd "$(dirname -- "$0")/.." && pwd)/cdd.sh"
