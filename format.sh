#!/usr/bin/env bash

if ! which shfmt > /dev/null; then
    printf 'Install shfmt to format script\n\n'
    printf 'You can install it by bash install_shfmt.sh, or\n'
    printf 'Check https://github.com/mvdan/sh/releases\n'
    exit 1
fi

for i in *.sh; do
    if ! shfmt -ci -kp -p -sr -i 4 -w "$i"; then
        echo "$i: Failed" >> failedlog
    else
        echo "$i: Passed" >> log
    fi
done

if [ -f failedlog ]; then
    printf '\nChecks have failed\n\n'
    cat failedlog
    printf '\n'
    cat log
    rm failedlog log
else
    printf 'Checks have passed\n\n'
    cat log
    rm log
fi
