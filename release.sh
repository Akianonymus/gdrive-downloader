#!/usr/bin/env sh

set -e

./format_and_lint.sh

printf "Merging Scripts and minifying...\n"

_PARENT_DIR="${PWD}"

cd src || exit 1

_merge() (
    shell="${1:?Error: give folder name.}"
    { [ "${shell}" = "sh" ] && flag="-p"; } || flag=""

    mkdir -p "${_PARENT_DIR}/release/${shell}"
    release_path="${_PARENT_DIR}/release/${shell}/gdl"

    {
        sed -n 1p "${shell}/gdl.${shell}"
        printf "%s\n" 'SELF_SOURCE="true"'
        # shellcheck disable=SC2086
        {
            sed 1d "${shell}/common-utils.${shell}"
            for script in \
                update.sh \
                auth-utils.sh \
                common-utils.sh \
                drive-utils.sh \
                download-utils.sh \
                parser.sh \
                flags.sh \
                gdl-common.sh; do
                sed 1d "common/${script}"
            done
            sed 1d "${shell}/gdl.${shell}"
        } | shfmt -mn ${flag}
    } >| "${release_path}"
    chmod +x "${release_path}"

    printf "%s\n" "${release_path} done."
)

_merge sh
_merge bash
