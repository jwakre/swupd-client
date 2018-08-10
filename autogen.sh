#!/bin/sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

autoreconf --force --install --symlink --warnings=all

args="\
--sysconfdir=/etc \
--localstatedir=/var \
--prefix=/usr \
--enable-silent-rules \
--with-fallback-capaths=/tmp/swupd_test_certificates"

./configure CFLAGS="-g -O2 $CFLAGS" $args "$@"
make clean
