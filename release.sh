#!/usr/bin/env sh

set -e

./format_and_lint.sh

printf "Merging Scripts and minifying...\n"

common_script="${PWD}/common/utils.sh"

_merge() (
    shell="${1:?Error: give folder name.}"
    { [ "${shell}" = "sh" ] && flag="-p"; } || flag=""

    cd "${shell}" 2>| /dev/null 1>&2 || exit 1
    {
        sed -n 1p gdl."${shell}"
        printf "%s\n" "SELF_SOURCE=\"true\""
        # shellcheck disable=SC2086
        {
            sed 1d "${common_script}"
            sed 1d auth-utils."${shell}"
            sed 1d common-utils."${shell}"
            sed 1d download-utils."${shell}"
            sed 1d drive-utils."${shell}"
            sed 1d gdl."${shell}"
        } | shfmt -mn ${flag}
    } >| "release/gdl"
    chmod +x "release/gdl"

    printf "%s\n" "${shell}/release/gdl done."
)

_merge sh
_merge bash
