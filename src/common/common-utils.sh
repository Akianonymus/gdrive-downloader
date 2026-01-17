#!/usr/bin/env bash
# Common functions for bash scripts
# shellcheck source=/dev/null
# shellcheck disable=SC2317,SC2128

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
    { _tmp="$(BLOCK_SIZE=512 BLOCKSIZE=512 du -- "${file_actual_size_in_bytes}")" &&
        _tmp="${_tmp%%"$(printf '\t')"*}" && printf "%s\n" "$((_tmp * 512))"; } || return 1
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
    while [[ "${b_bytes_to_human}" -gt 1024 ]]; do
        d_bytes_to_human="$(printf ".%02d" $((b_bytes_to_human % 1024 * 100 / 1024)))"
        b_bytes_to_human=$((b_bytes_to_human / 1024)) && s_bytes_to_human=$((s_bytes_to_human += 1))
    done
    j=0 && for i in B KB MB GB TB PB EB YB ZB; do
        j="$((j += 1))" && [[ "$((j - 1))" = "${s_bytes_to_human}" ]] && type_bytes_to_human="${i}" && break
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
#   Check QUIET, then check terminal size and enable print functions accordingly.
###################################################
_check_debug() {
    export DEBUG QUIET
    if [[ -n "${DEBUG}" ]]; then
        set -x && PS4='-> '
        _print_center() {
            if [[ $# = 3 ]]; then
                printf "%s\n" "${2}"
            else
                printf "%s%s\n" "${2}" "${3}"
            fi
        }
        _clear_line() { :; }
        _move_cursor() { :; }
        _newline() { :; }
    else
        if [[ -z "${QUIET}" ]]; then
            # check if running in terminal and support ansi escape sequences
            if _support_ansi_escapes; then
                if ! _required_column_size; then
                    _print_center() { { [[ $# = 3 ]] && printf "%s\n" "[ ${2} ]"; } || { printf "%s\n" "[ ${2}${3} ]"; }; }

                fi
                export EXTRA_LOG="_print_center" CURL_PROGRESS="-#" SUPPORT_ANSI_ESCAPES="true"
            else
                _print_center() { { [[ $# = 3 ]] && printf "%s\n" "[ ${2} ]"; } || { printf "%s\n" "[ ${2}${3} ]"; }; }
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
    "${EXTRA_LOG:-}" "justify" "Checking Internet Connection.." "-"
    if ! _timeout 10 _curl -Is https://google.com --compressed; then
        _clear_line 1
        "${QUIET:-_print_center}" "justify" "Error: Internet connection" " not available." "="
        return 1
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
# a curl wrapper to add some flags
###################################################
_curl() {
    # shellcheck disable=SC2086
    curl ${CURL_FLAGS:-} "${@}" || return 1
}

###################################################
# Convert given time in seconds to readable form
# 110 to 1 minute(s) and 50 seconds
# Arguments: 1
#   ${1} = Positive Integer ( time in seconds )
# Result: read description
# Reference:
#   https://stackoverflow.com/a/32164707
###################################################
_display_time() {
    t_display_time="${1}" day_display_time="$((t_display_time / 60 / 60 / 24))"
    hr_display_time="$((t_display_time / 60 / 60 % 24))" min_display_time="$((t_display_time / 60 % 60))" sec_display_time="$((t_display_time % 60))"
    [[ "${day_display_time}" -gt 0 ]] && printf '%d days ' "${day_display_time}"
    [[ "${hr_display_time}" -gt 0 ]] && printf '%d hrs ' "${hr_display_time}"
    [[ "${min_display_time}" -gt 0 ]] && printf '%d minute(s) ' "${min_display_time}"
    [[ "${day_display_time}" -gt 0 ]] || [[ "${hr_display_time}" -gt 0 ]] || [[ "${min_display_time}" -gt 0 ]] && printf 'and '
    printf '%d seconds\n' "${sec_display_time}"
}

###################################################
# Fetch latest commit sha of release or branch
# Do not use github rest api because rate limit error occurs
# Globals: None
# Arguments: 3
#   ${1} = "branch" or "release"
#   ${2} = branch name or release name
#   ${3} = repo name e.g labbots/google-drive-upload
# Result: print fetched sha
###################################################
_get_latest_sha() {
    export TYPE TYPE_VALUE REPO
    unset latest_sha_get_latest_sha raw_get_latest_sha
    case "${1:-${TYPE}}" in
        branch)
            latest_sha_get_latest_sha="$(
                raw_get_latest_sha="$(curl --compressed -s https://github.com/"${3:-${REPO}}"/commits/"${2:-${TYPE_VALUE}}".atom -r 0-2000)"
                _tmp="$(printf "%s\n" "${raw_get_latest_sha}" | grep -o "Commit\\/.*<" -m1 || :)" && _tmp="${_tmp##*\/}" && printf "%s\n" "${_tmp%%<*}"
            )"
            ;;
        release)
            latest_sha_get_latest_sha="$(
                raw_get_latest_sha="$(curl -L --compressed -s https://github.com/"${3:-${REPO}}"/releases/"${2:-${TYPE_VALUE}}")"
                _tmp="$(printf "%s\n" "${raw_get_latest_sha}" | grep "=\"/""${3:-${REPO}}""/commit" -m1 || :)" && _tmp="${_tmp##*commit\/}" && printf "%s\n" "${_tmp%%\"*}"
            )"
            ;;
        *) : ;;
    esac
    printf "%b" "${latest_sha_get_latest_sha:+${latest_sha_get_latest_sha}\n}"
}

###################################################
# check if the given fd is open
# Arguments:
#   ${1} = fd number
# return 1 or 0
###################################################
_is_fd_open() {
    for fd in ${1:?}; do
        # shellcheck disable=SC3021
        if ! { true >&"${fd}"; } 2<> /dev/null; then
            printf "%s\n" "Error: fd ${fd} not open."
            return 1
        fi
    done
}

###################################################
# Extract value from json using jq
# Arguments: 3
#   ${1} - jq filter to apply
#   ${2} - Optional, no of lines to parse
#   ${3} - Optional, nth number of value, default is 1, or "all"
# Input: file | pipe
#   echo json | _json_value "Arguments"
# Result: print extracted value
###################################################
_json_value() {
    local _filter="${1:?}" _no_lines="${2:-1}" _num="${3:-1}" _input _output
    _input="$(cat)"

    if [[ "${_num}" = "all" ]]; then
        _output="$(printf "%s\n" "${_input}" | jq -r ".${_filter}")"
        [[ "${_output}" = "null" ]] && _output=""
    else
        _output="$(printf "%s\n" "${_input}" | jq -r ".${_filter}")"
        [[ "${_output}" = "null" ]] && _output=""
        [[ -n "${_output}" ]] && printf "%s\n" "${_output}" | head -n "${_num}"
    fi
}

###################################################
# Serialize associative array to string for subprocess
# Arguments: 1
#   ${1} = associative array name
# Result: print serialized array string
###################################################
_aarr_to_str() {
    declare -p "${1:?}" | sed 's/^declare -A //'
}

###################################################
# Deserialize JSON string to associative array
# Arguments: 2
#   ${1} = variable name to create
#   ${2} = JSON string
# Result: create associative array in calling scope
###################################################
_str_to_aarr() {
    local _var="${1:?}" _str="${2:?}" _key _val
    declare -gA "${_var}"
    while IFS=: read -r _key _val; do
        _key="${_key#\"}" _key="${_key%\"}"
        _val="${_val#\"}" _val="${_val%\",*}"
        [[ -n "${_key}" ]] && printf -v "${_var}[${_key}]" '%s' "${_val}"
    done < <(jq -r 'to_entries[] | "\(.key):\(.value)"' <<< "${_str}")
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
# Function to parse config in format a=b
# Arguments: 2
#   ${1} - path to config file
#   ${2} - optional, if true will print the config
# Input: file
#   _parse_config file
# Result: all the values in the config file will be exported as variables
###################################################
_parse_config() {
    _config_file_parse_config="${1:?Error: Profile config file}"
    print_parse_config="${2:-false}"

    # check if the config file accessible
    [[ -r "${_config_file_parse_config}" ]] || {
        printf "%s\n" "Error: Given config file ( ${_config_file_parse_config} ) is not readable."
        return 1
    }

    # Setting 'IFS' tells 'read' where to split the string.
    while IFS='=' read -r key val; do
        # Skip Lines starting with '#'
        # Also skip lines if key and val variable is empty
        { [[ -n "${key}" ]] && [[ -n "${val}" ]] && [[ -n "${key##\#*}" ]]; } || continue

        # trim all leading white space
        key="${key#"${key%%[![:space:]]*}"}"
        val="${val#"${val%%[![:space:]]*}"}"

        # trim all trailing white space
        key="${key%"${key##*[![:space:]]}"}"
        val="${val%"${val##*[![:space:]]}"}"

        # trim the first and last qoute if present on both sides
        case "${val}" in
            \"*\") val="${val#\"}" val="${val%\"}" ;;
            \'*\') val="${val#\'}" val="${val%\'}" ;;
            *) : ;;
        esac

        # sanitize API_KEY to remove newlines and whitespace
        [[ "${key}" = "API_KEY" ]] && val="$(_sanitize_api_key "${val}")"

        # '$key' stores the key and '$val' stores the value.
        # Throw a warning if cannot export the variable
        export "${key}=${val}" 2> /dev/null || printf "%s\n" "Warning: ${key} is not a valid variable name."

        [[ "${print_parse_config}" = true ]] && echo "${key}=${val}"
    done < "${_config_file_parse_config}"

    return 0
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
    [[ $# -lt 3 ]] && printf "Missing arguments\n" && return 1
    term_cols_print_center="${COLUMNS:-}"
    type_print_center="${1}" filler_print_center=""
    case "${type_print_center}" in
        normal) out_print_center="${2}" && symbol_print_center="${3}" ;;
        justify)
            if [[ $# = 3 ]]; then
                input1_print_center="${2}" symbol_print_center="${3}" to_print_print_center="" out_print_center=""
                to_print_print_center="$((term_cols_print_center - 5))"
                { [[ "${#input1_print_center}" -gt "${to_print_print_center}" ]] && out_print_center="[ $(printf "%.${to_print_print_center}s\n" "${input1_print_center}")..]"; } ||
                    { out_print_center="[ ${input1_print_center} ]"; }
            else
                input1_print_center="${2}" input2_print_center="${3}" symbol_print_center="${4}" to_print_print_center="" temp_print_center="" out_print_center=""
                to_print_print_center="$((term_cols_print_center * 47 / 100))"
                { [[ "${#input1_print_center}" -gt "${to_print_print_center}" ]] && temp_print_center=" $(printf "%.${to_print_print_center}s\n" "${input1_print_center}").."; } ||
                    { temp_print_center=" ${input1_print_center}"; }
                to_print_print_center="$((term_cols_print_center * 46 / 100))"
                { [[ "${#input2_print_center}" -gt "${to_print_print_center}" ]] && temp_print_center="${temp_print_center}$(printf "%.${to_print_print_center}s\n" "${input2_print_center}").. "; } ||
                    { temp_print_center="${temp_print_center}${input2_print_center} "; }
                out_print_center="[${temp_print_center}]"
            fi
            ;;
        *) return 1 ;;
    esac

    str_len_print_center="${#out_print_center}"
    [[ "${str_len_print_center}" -ge "$((term_cols_print_center - 1))" ]] && {
        printf "%s\n" "${out_print_center}" && return 0
    }

    filler_print_center_len="$(((term_cols_print_center - str_len_print_center) / 2))"

    i_print_center=1 && while [[ "${i_print_center}" -le "${filler_print_center_len}" ]]; do
        filler_print_center="${filler_print_center}${symbol_print_center}" && i_print_center="$((i_print_center + 1))"
    done

    printf "%s%s%s" "${filler_print_center}" "${out_print_center}" "${filler_print_center}"
    [[ "$(((term_cols_print_center - str_len_print_center) % 2))" -ne 0 ]] && printf "%s" "${symbol_print_center}"
    printf "\n"

    return 0
}

###################################################
# print_center arguments but normal print
###################################################
_print_center_quiet() {
    { [[ $# = 3 ]] && printf "%s\n" "${2}"; } ||
        { printf "%s%s\n" "${2}" "${3}"; }
}

###################################################
# Check if script terminal supports ansi escapes
# Result: return 1 or 0
###################################################
_support_ansi_escapes() {
    unset ansi_escapes
    case "${TERM:-}" in
        xterm* | rxvt* | urxvt* | linux* | vt* | screen*) ansi_escapes="true" ;;
        *) : ;;
    esac
    { [[ -t 2 ]] && [[ -n "${ansi_escapes}" ]] && return 0; } || return 1
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
# Arguments: 3
#   ${1} = value name
#   ${2} = value
#   ${3} = config path
# Result: read description
###################################################
_update_config() {
    [[ $# -lt 3 ]] && printf "Missing arguments\n" && return 1
    value_name_update_config="${1}" value_update_config="${2}" config_path_update_config="${3}"
    ! [[ -f "${config_path_update_config}" ]] && : >| "${config_path_update_config}" # If config file doesn't exist.
    chmod u+w -- "${config_path_update_config}" || return 1
    printf "%s\n%s\n" "$(grep -v -e "^$" -e "^${value_name_update_config}=" -- "${config_path_update_config}" || :)" \
        "${value_name_update_config}=\"${value_update_config}\"" >| "${config_path_update_config}" || return 1
    chmod a-w-r-x,u+r -- "${config_path_update_config}" || return 1
    return 0
}

###################################################
# Check if something contains some
# Arguments:
#    ${1} = pattern to match, can be regex
#    ${2} = string where it should match the pattern
# Result: return 0 or 1
###################################################
_assert_regex() {
    declare pattern="${1:-}" string="${2:-}"
    if [[ ${string} =~ ${pattern} ]]; then
        return 0
    else
        return 1
    fi
}

###################################################
# Sanitize API key by removing newlines and whitespace
# Arguments: 1
#   ${1} = API key string to sanitize
# Result: prints sanitized API key
###################################################
_sanitize_api_key() {
    local _key="${1:?}"
    _key="${_key//[$'\t\r\n']/}"
    _key="${_key// /}"
    printf "%s" "${_key}"
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
#   ${1} = direct ( d ) or indirect ( i ) - ( evaluation mode )
#   ${2} = var name
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

###################################################
# remove the given character from the given string
# 1st arg - character
# 2nd arg - string
# 3rd arg - var where to save the output
# print trimmed string if 3rd arg empty else set
###################################################
_trim() {
    declare char="${1}" str="${2}" var="${3}"

    if [[ -n ${var} ]]; then
        _set_value d "${var}" "${str//${char}/}"
    else
        printf "%s" "${str//${char}/}"
    fi
}
