#!/usr/bin/env sh

###################################################
# Print actual size of a file ( apparant size )
# du normally prints the exact size that file is using.
# Required Arguments: 1
#   ${1} = filename
# Result: Print actual size of file in bytes
###################################################
_actual_size_in_bytes() {
    file_actual_size_in_bytes="${1:?Error: give filename}"
    # use block size to 512 because the lowest osx supports is 512
    # multiply with 512 to convert for 1 block size
    { _tmp="$(BLOCK_SIZE=512 BLOCKSIZE=512 du "${file_actual_size_in_bytes}")" &&
        _tmp="${_tmp%%$(printf '\t')*}" && printf "%s\n" "$((_tmp * 512))"; } || return 1
}

###################################################
# Convert bytes to human readable form
# Required Arguments: 1
#   ${1} = Positive integer ( bytes )
# Result: Print human readable form.
# Reference:
#   https://unix.stackexchange.com/a/259254
###################################################
_bytes_to_human() {
    b_bytes_to_human="$(printf "%.0f\n" "${1:-0}")" s_bytes_to_human=0
    d_bytes_to_human='' type_bytes_to_human=''
    while [ "${b_bytes_to_human}" -gt 1024 ]; do
        d_bytes_to_human="$(printf ".%02d" $((b_bytes_to_human % 1024 * 100 / 1024)))"
        b_bytes_to_human=$((b_bytes_to_human / 1024)) && s_bytes_to_human=$((s_bytes_to_human += 1))
    done
    j=0 && for i in B KB MB GB TB PB EB YB ZB; do
        j="$((j += 1))" && [ "$((j - 1))" = "${s_bytes_to_human}" ] && type_bytes_to_human="${i}" && break
        continue
    done
    printf "%s\n" "${b_bytes_to_human}${d_bytes_to_human} ${type_bytes_to_human}"
}

###################################################
# Check if debug is enabled and enable command trace
# Arguments: None
# Result: If DEBUG
#   Present - Enable command trace and change print functions to avoid spamming.
#   Absent  - Disable command trace
#             Check QUIET, then check terminal size and enable print functions accordingly.
###################################################
_check_debug() {
    _print_center_quiet() { { [ $# = 3 ] && printf "%s\n" "${2}"; } || { printf "%s%s\n" "${2}" "${3}"; }; }
    if [ -n "${DEBUG}" ]; then
        set -x && PS4='-> '
        _print_center() { { [ $# = 3 ] && printf "%s\n" "${2}"; } || { printf "%s%s\n" "${2}" "${3}"; }; }
        _clear_line() { :; } && _move_cursor() { :; } && _newline() { :; }
    else
        if [ -z "${QUIET}" ]; then
            # check if running in terminal and support ansi escape sequences
            case "${TERM}" in
                xterm* | rxvt* | urxvt* | linux* | vt* | screen*) ansi_escapes="true" ;;
            esac
            if [ -t 2 ] && [ -n "${ansi_escapes}" ]; then
                ! COLUMNS="$(_get_columns_size)" || [ "${COLUMNS:-0}" -lt 45 ] 2>| /dev/null &&
                    _print_center() { { [ $# = 3 ] && printf "%s\n" "[ ${2} ]"; } || { printf "%s\n" "[ ${2}${3} ]"; }; }
                EXTRA_LOG="_print_center" CURL_PROGRESS="-#" && export CURL_PROGRESS EXTRA_LOG \
                    SUPPORT_ANSI_ESCAPES="true"
            else
                _print_center() { { [ $# = 3 ] && printf "%s\n" "[ ${2} ]"; } || { printf "%s\n" "[ ${2}${3} ]"; }; }
                _clear_line() { :; } && _move_cursor() { :; }
            fi
            _newline() { printf "%b" "${1}"; }
        else
            _print_center() { :; } && _clear_line() { :; } && _move_cursor() { :; } && _newline() { :; }
        fi
        set +x
    fi
}

###################################################
# Check internet connection.
# Probably the fastest way, takes about 1 - 2 KB of data, don't check for more than 10 secs.
# Arguments: None
# Result: On
#   Success - Nothing
#   Error   - print message and exit 1
###################################################
_check_internet() {
    "${EXTRA_LOG}" "justify" "Checking Internet Connection.." "-"
    if ! _timeout 10 curl -Is google.com --compressed; then
        _clear_line 1
        "${QUIET:-_print_center}" "justify" "Error: Internet connection" " not available." "="
        exit 1
    fi
    _clear_line 1
}

###################################################
# Move cursor to nth no. of line and clear it to the begining.
# Arguments: 1
#   ${1} = Positive integer ( line number )
# Result: Read description
###################################################
_clear_line() {
    printf "\033[%sA\033[2K" "${1}"
}

###################################################
# Convert given time in seconds to readable form
# 110 to 1m50s
# Arguments: 1
#   ${1} = Positive Integer ( time in seconds )
# Result: read description
# Reference:
#   https://stackoverflow.com/a/32164707
###################################################
_display_time() {
    t_display_time="${1}" day_display_time="$((t_display_time / 60 / 60 / 24))"
    hr_display_time="$((t_display_time / 60 / 60 % 24))" min_display_time="$((t_display_time / 60 % 60))" sec_display_time="$((t_display_time % 60))"
    [ "${day_display_time}" -gt 0 ] && printf '%dd' "${day_display_time}"
    [ "${hr_display_time}" -gt 0 ] && printf '%dh' "${hr_display_time}"
    [ "${min_display_time}" -gt 0 ] && printf '%dm' "${min_display_time}"
    printf '%ds\n' "${sec_display_time}"
}

###################################################
# print column size
# use bash or zsh or stty or tput
###################################################
_get_columns_size() {
    { command -v bash 1>| /dev/null && bash -c 'shopt -s checkwinsize && (: && :); printf "%s\n" "${COLUMNS}" 2>&1'; } ||
        { command -v zsh 1>| /dev/null && zsh -c 'printf "%s\n" "${COLUMNS}"'; } ||
        { command -v stty 1>| /dev/null && _tmp="$(stty size)" && printf "%s\n" "${_tmp##* }"; } ||
        { command -v tput 1>| /dev/null && tput cols; } ||
        return 1
}

###################################################
# Method to extract specified field data from json
# Arguments: 2
#   ${1} - value of field to fetch from json
#   ${2} - Optional, no of lines to parse for the given field in 1st arg
#   ${3} - Optional, nth number of value from extracted values, default it 1.
# Input: file | pipe
#   _json_value "Arguments" < file
#   echo something | _json_value "Arguments"
# Result: print extracted value
###################################################
_json_value() {
    { [ "${2}" -gt 0 ] 2>| /dev/null && no_of_lines_json_value="${2}"; } || :
    { [ "${3}" -gt 0 ] 2>| /dev/null && num_json_value="${3}"; } || { ! [ "${3}" = all ] && num_json_value=1; }
    # shellcheck disable=SC2086
    _tmp="$(grep -o "\"${1}\"\:.*" ${no_of_lines_json_value:+-m} ${no_of_lines_json_value})" || return 1
    printf "%s\n" "${_tmp}" | sed -e "s/.*\"""${1}""\"://" -e 's/[",]*$//' -e 's/["]*$//' -e 's/[,]*$//' -e "s/^ //" -e 's/^"//' -n -e "${num_json_value}"p || :
    return 0
}

###################################################
# Move cursor to nth no. of line ( above )
# Arguments: 1
#   ${1} = Positive integer ( line number )
# Result: Read description
###################################################
_move_cursor() {
    printf "\033[%sA" "${1:?Error: Num of line}"
}

###################################################
# Print a text to center interactively and fill the rest of the line with text specified.
# This function is fine-tuned to this script functionality, so may appear unusual.
# Arguments: 4
#   If ${1} = normal
#      ${2} = text to print
#      ${3} = symbol
#   If ${1} = justify
#      If remaining arguments = 2
#         ${2} = text to print
#         ${3} = symbol
#      If remaining arguments = 3
#         ${2}, ${3} = text to print
#         ${4} = symbol
# Result: read description
# Reference:
#   https://gist.github.com/TrinityCoder/911059c83e5f7a351b785921cf7ecda
###################################################
_print_center() {
    [ $# -lt 3 ] && printf "Missing arguments\n" && return 1
    term_cols_print_center="${COLUMNS}"
    type_print_center="${1}" filler_print_center=""
    case "${type_print_center}" in
        normal) out_print_center="${2}" && symbol_print_center="${3}" ;;
        justify)
            if [ $# = 3 ]; then
                input1_print_center="${2}" symbol_print_center="${3}" to_print_print_center="" out_print_center=""
                to_print_print_center="$((term_cols_print_center - 5))"
                { [ "${#input1_print_center}" -gt "${to_print_print_center}" ] && out_print_center="[ $(printf "%.${to_print_print_center}s\n" "${input1_print_center}")..]"; } ||
                    { out_print_center="[ ${input1_print_center} ]"; }
            else
                input1_print_center="${2}" input2_print_center="${3}" symbol_print_center="${4}" to_print_print_center="" temp_print_center="" out_print_center=""
                to_print_print_center="$((term_cols_print_center * 47 / 100))"
                { [ "${#input1_print_center}" -gt "${to_print_print_center}" ] && temp_print_center=" $(printf "%.${to_print_print_center}s\n" "${input1_print_center}").."; } ||
                    { temp_print_center=" ${input1_print_center}"; }
                to_print_print_center="$((term_cols_print_center * 46 / 100))"
                { [ "${#input2_print_center}" -gt "${to_print_print_center}" ] && temp_print_center="${temp_print_center}$(printf "%.${to_print_print_center}s\n" "${input2_print_center}").. "; } ||
                    { temp_print_center="${temp_print_center}${input2_print_center} "; }
                out_print_center="[${temp_print_center}]"
            fi
            ;;
        *) return 1 ;;
    esac

    str_len_print_center="${#out_print_center}"
    [ "${str_len_print_center}" -ge "$((term_cols_print_center - 1))" ] && {
        printf "%s\n" "${out_print_center}" && return 0
    }

    filler_print_center_len="$(((term_cols_print_center - str_len_print_center) / 2))"

    i_print_center=1 && while [ "${i_print_center}" -le "${filler_print_center_len}" ]; do
        filler_print_center="${filler_print_center}${symbol_print_center}" && i_print_center="$((i_print_center + 1))"
    done

    printf "%s%s%s" "${filler_print_center}" "${out_print_center}" "${filler_print_center}"
    [ "$(((term_cols_print_center - str_len_print_center) % 2))" -ne 0 ] && printf "%s" "${symbol_print_center}"
    printf "\n"

    return 0
}

###################################################
# Alternative to timeout command
# Arguments: 1 and rest
#   ${1} = amount of time to sleep
#   rest = command to execute
# Result: Read description
# Reference:
#   https://stackoverflow.com/a/24416732
###################################################
_timeout() {
    timeout_timeout="${1:?Error: Specify Timeout}" && shift
    {
        "${@}" &
        child="${!}"
        trap -- "" TERM
        {
            sleep "${timeout_timeout}"
            kill -9 "${child}"
        } &
        wait "${child}"
    } 2>| /dev/null 1>&2
}

###################################################
# Config updater
# Incase of old value, update, for new value add.
# Globals: None
# Arguments: 3
#   ${1} = value name
#   ${2} = value
#   ${3} = config path
# Result: read description
###################################################
_update_config() {
    [ $# -lt 3 ] && printf "Missing arguments\n" && return 1
    value_name_update_config="${1}" value_update_config="${2}" config_path_update_config="${3}"
    ! [ -f "${config_path_update_config}" ] && : >| "${config_path_update_config}" # If config file doesn't exist.
    chmod u+w "${config_path_update_config}"
    printf "%s\n%s\n" "$(grep -v -e "^$" -e "^${value_name_update_config}=" "${config_path_update_config}" || :)" \
        "${value_name_update_config}=\"${value_update_config}\"" >| "${config_path_update_config}"
    chmod u-w+r "${config_path_update_config}"
}
