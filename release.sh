#!/usr/bin/env bash

set -e

./format_and_lint.sh

printf "Merging Scripts and minifying...\n"

_PARENT_DIR="${PWD}"

cd src || exit 1

_merge() (
    mkdir -p "${_PARENT_DIR}/release"
    release_path="${_PARENT_DIR}/release/gdl"

    {
        sed -n 1p gdl.sh
        printf "%s\n" 'SELF_SOURCE="true"'
        # shellcheck disable=SC2086
        {
            # this is to export the functions so that can used in parallel functions
            echo 'set -a'
            sed 1d common/common-utils.sh
            for script in \
                update.sh \
                parser.sh \
                flags.sh \
                auth-utils.sh \
                common-utils.sh \
                drive-utils.sh \
                download-utils.sh \
                gdl-common.sh; do
                sed 1d "common/${script}"
            done
            echo 'set +a'
            sed 1d gdl.sh
        } | shfmt -mn
    } >| "${release_path}"
    chmod +x "${release_path}"

    printf "%s\n" "${release_path} done."
)

_merge
