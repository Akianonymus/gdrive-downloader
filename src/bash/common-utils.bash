#!/usr/bin/env bash

###################################################
# Check if something contains some
# Arguments:
#    ${1} = pattern to match, can be regex
#    ${2} = string where it should match the pattern
# Result: return 0 or 1
###################################################
_assert_regex() {
    declare pattern="${1:?Error: Missing pattern}" string="${2:?Missing string}"
    if [[ ${string} =~ ${pattern} ]]; then
        return 0
    else
        return 1
    fi
}

###################################################
# Alternative to wc -l command
# Arguments: 1  or pipe
#   ${1} = file, _count < file
#          variable, _count <<< variable
#   pipe = echo something | _count
# Result: Read description
# Reference:
#   https://github.com/dylanaraps/pure-bash-bible#get-the-number-of-lines-in-a-file
###################################################
_count() {
    mapfile -tn 0 lines
    printf '%s\n' "${#lines[@]}"
}

###################################################
# Print epoch seconds
###################################################
_epoch() {
    printf "%(%s)T\\n" "-1"
}

###################################################
# set or get flag varianle which contains the individual help contents
# if ${1} = set then
#    ${2} = flags seperated by space
#    ${3} = flag help content
# if ${1} = get
#    ${2} = var name which will be set to help contents of the flag
#    ${3} = flag name
###################################################
_flag_help() {
    case "${1}" in
        set)
            for f in ${2}; do
                _set_value d "help_${f//-/}" "${3}"
            done
            ;;
        get)
            _set_value i "${2}" "help_${3//-/}"
            ;;
        *) return 1 ;;
    esac
}

###################################################
# fetch column size and check if greater than the num ( see in function)
# set trap on sigwinch to update COLUMNS variable
# return 1 or 0
###################################################
_required_column_size() {
    shopt -s checkwinsize && (: && :)
    if [[ ${COLUMNS} -gt 45 ]]; then
        trap 'shopt -s checkwinsize; (:;:)' SIGWINCH
        return 0
    else
        return 1
    fi
}

###################################################
# Evaluates value1=value2
# Arguments: 3
#   ${1} = direct ( d ) or indirect ( i ) - ( evaluation mode )  #   ${2} = var name
#   ${3} = var value
# Result: export value1=value2
###################################################
_set_value() {
    case "${1:?}" in
        d | direct) export "${2:?}=${3}" ;;
        i | indirect) export "${2:?}=${!3}" ;;
        *) return 1 ;;
    esac
}

export -f _count \
    _set_value
