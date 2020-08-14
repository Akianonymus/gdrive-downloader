#!/usr/bin/env sh

set -e

command -v shfmt 1>| /dev/null && ./format.sh && printf "\n"

_merge() (
    shell="${1:?Error: give folder name.}"

    cd "${shell}" 2>| /dev/null 1>&2 || exit 1
    {
        sed -n 1p gdl."${shell}"
        printf "%s\n" "SELF_SOURCE=\"true\""
        {
            sed 1d common-utils."${shell}"
            sed 1d download-utils."${shell}"
            sed 1d gdl."${shell}"
        } | shfmt -mn
    } >| "release/gdl"
    chmod +x "release/gdl"

    printf "%s\n" "${shell} done."
)

_merge sh
_merge bash
