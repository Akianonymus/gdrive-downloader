#!/usr/bin/env sh

###################################################
# Check if something contains some
# Arguments:
#    ${1} = pattern to match, can be regex
#    ${2} = string where it should match the pattern
# Result: return 0 or 1
###################################################
_assert_regex() {
    pattern_assert_regex="${1:?Error: Missing pattern}"
    string_assert_regex="${2:?Missing string}"
    if printf "%s\n" "${string_assert_regex}" | grep -qE "${pattern_assert_regex}"; then
        return 0
    else
        return 1
    fi
}

###################################################
# count number of lines using wc
###################################################
_count() {
    wc -l
}

###################################################
# Alternative to dirname command
# Arguments: 1
#   ${1} = path of file or folder
# Result: read description
# Reference:
#   https://github.com/dylanaraps/pure-sh-bible#file-paths
###################################################
_dirname() {
    dir_dirname="${1:-.}"
    dir_dirname="${dir_dirname%%"${dir_dirname##*[!/]}"}" && [ -n "${dir_dirname##*/*}" ] && dir_dirname=.
    dir_dirname="${dir_dirname%/*}" && dir_dirname="${dir_dirname%%"${dir_dirname##*[!/]}"}"
    printf '%s\n' "${dir_dirname:-/}"
}

###################################################
# Print epoch seconds
###################################################
_epoch() {
    date +'%s'
}

###################################################
# fetch column size and check if greater than the num ( see in function)
# return 1 or 0
###################################################
_required_column_size() {
    COLUMNS="$({ command -v bash 1>| /dev/null && bash -c 'shopt -s checkwinsize && (: && :); printf "%s\n" "${COLUMNS}" 2>&1'; } ||
        { command -v zsh 1>| /dev/null && zsh -c 'printf "%s\n" "${COLUMNS}"'; } ||
        { command -v stty 1>| /dev/null && _tmp="$(stty size)" && printf "%s\n" "${_tmp##* }"; } ||
        { command -v tput 1>| /dev/null && tput cols; })" || :

    [ "$((COLUMNS))" -gt 45 ] && return 0
}

###################################################
# Evaluates value1=value2
# Arguments: 3
#   ${1} = direct ( d ) or indirect ( i ) - ( evaluation mode )
#   ${2} = var name
#   ${3} = var value
# Result: export value1=value2
###################################################
_set_value() {
    case "${1:?}" in
        d | direct) export "${2:?}=${3}" ;;
        i | indirect) eval export "${2}"=\"\$"${3}"\" ;;
        *) return 1 ;;
    esac
}

###################################################
# remove the given character from the given string
# 1st arg - character
# 2nd arg - string
# 3rd arg - var where to save the output
# print trimmed string if 3rd arg empty else set
# Reference: https://stackoverflow.com/a/65350253
###################################################
_trim() {
    char_trim="${1}" str_trim="${2}" var_trim="${3}"
    # Disable globbing.
    # This ensures that the word-splitting is safe.
    set -f
    # store old ifs, restore it later.
    old_ifs="${IFS}"
    IFS="${char_trim}"
    # shellcheck disable=SC2086
    set -- ${str_trim}
    IFS=
    if [ -n "${var_trim}" ]; then
        _set_value d "${var_trim}" "$*"
    else
        printf "%s" "$*"
    fi
    # Restore the value of 'IFS'.
    IFS="${old_ifs}"
    # re enable globbing
    set +f
}
