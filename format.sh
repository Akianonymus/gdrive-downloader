#!/usr/bin/env bash

if ! type -p shfmt &> /dev/null; then
    printf 'Install shfmt to format script\n\n'
    printf 'You can install it by bash <(curl -L -s https://gist.github.com/Akianonymus/56e80cc1aa469c5b74d41273e202cadd/raw/24bdfd9fd0ceca53b923fe4b694c03be0b208d2a/install-shfmt.sh), or\n'
    printf 'Check https://github.com/mvdan/sh/releases\n'
    exit 1
fi

STRING="$((RANDOM * RANDOM))"

trap 'rm -f "${STRING}".failedlog "${STRING}".passedlog' INT TERM EXIT

for i in *sh; do
    if ! shfmt -ci -sr -i 4 -w "${i}"; then
        printf "%s\n\n" "${i}: ERROR" >> "${STRING}".failedlog
    else
        printf "%s\n" "${i}: SUCCESS" >> "${STRING}".passedlog
    fi
done

if [[ -f "${STRING}".failedlog ]]; then
    printf '\nError: Cannot format some files.\n\n'
    printf "%s\n\n" "$(< "${STRING}".failedlog)"
    printf "%s\n" "$(< "${STRING}".passedlog)"
    exit 1
else
    printf 'All files formatted successfully.\n\n'
    printf "%s\n" "$(< "${STRING}".passedlog)"
    exit 0
fi
