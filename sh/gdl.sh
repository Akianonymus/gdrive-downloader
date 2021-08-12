#!/usr/bin/env sh
# Download file/folder from google drive.
# shellcheck source=/dev/null

###################################################
# 1st arg - can be flag name
# if 1st arg given, print specific flag help
# otherwise print full help
###################################################
_usage() {
    DEBUG="" _check_debug
    _HELP_BAR="$(_print_center "normal" "_" "_")"
    [ -n "${_HELP_BAR}" ] && export _HELP_BAR="${_HELP_BAR}
"

    ###################################################
    # 1st arg = flags seperated by spaces
    # 2nd arg = Flag argument type if required ( can be empty )
    # 3rd arg = First help line
    # 4rd arg = rest of the help lines
    # export help_flag_name variable and append the help contents to ALL_HELP variable
    # input - "-p --parallel" "num of jobs" "Specify num of parallel jobs" "Must be between 1 to 10"
    # output:
    #    -p | --parallel 'num of jobs' => Specify num of parallel jobs
    #        Must be between 1 to 10
    ###################################################
    _set_help() {
        content1_set_help="${3}" content2_set_help="" all_content_set_help=""
        [ -n "${4}" ] && {
            # add a new line to the start
            content2_set_help="
"
            while read -r line <&4; do
                # 8 spaces
                content2_set_help="${content2_set_help}
        ${line}"
            done 4<< EOF
${4}
EOF
        }

        # add as a prefix on first help line
        start_set_help=""
        for f in ${1}; do
            if [ -n "${start_set_help}" ]; then
                start_set_help="${start_set_help} | ${f}"
            else
                start_set_help="${f}"
            fi
        done

        # append at the end of first help line if 2nd arg is given
        # append 4 spaces
        start_set_help="    ${start_set_help} ${2:+\"${2}\"} => "

        all_content_set_help="${start_set_help}${content1_set_help}${content2_set_help}"
        for f in ${1}; do
            flag_set_help="$(_trim "-" "${f}")"
            _set_value d "help_${flag_set_help}" "${all_content_set_help}"
        done

        ALL_HELP="${ALL_HELP}
${_HELP_BAR}
${all_content_set_help}"
    }
    # create help variables and help content
    _create_help

    [ -n "${1}" ] && {
        tmp_help_usage=""
        _set_value i tmp_help_usage "help_$(_trim "-" "${1}")"

        if [ -z "${tmp_help_usage}" ]; then
            printf "%s\n" "Error: No help found for ${1}"
        else
            printf "%s\n%s\n%s\n" "${_HELP_BAR}" "${tmp_help_usage}" "${_HELP_BAR}"
        fi
        exit 0
    }

    printf "%s\n" "${ALL_HELP}"
    exit 0
}

_short_help() {
    printf "No valid arguments provided, use -h/--help flag to see usage.\n"
    exit 0
}

###################################################
# Print info if installed
###################################################
_version_info() {
    if command -v "${COMMAND_NAME}" 1> /dev/null && [ -n "${REPO:+${COMMAND_NAME:+${INSTALL_PATH:+${TYPE:+${TYPE_VALUE}}}}}" ]; then
        for i in REPO INSTALL_PATH INSTALLATION TYPE TYPE_VALUE LATEST_INSTALLED_SHA CONFIG; do
            printf "%s\n" "${i}=\"$(eval printf "%s" \"\$"${i}"\")\""
        done | sed -e "s/=/: /g"
    else
        printf "%s\n" "gdrive-downloader is not installed system wide."
    fi
    exit 0
}

###################################################
# Function to cleanup config file
# Remove invalid access tokens on the basis of corresponding expiry
# Globals: None
# Arguments: 1
#   ${1} = config file
# Result: read description
###################################################
_cleanup_config() {
    config="${1:?Error: Missing config}" && unset values_regex _tmp

    ! [ -f "${config}" ] && return 0

    while read -r line <&4 && [ -n "${line}" ]; do
        expiry_value_name="${line%%=*}"
        token_value_name="${expiry_value_name%%_EXPIRY}"

        _tmp="${line##*=}" && _tmp="${_tmp%\"}" && expiry="${_tmp#\"}"
        [ "${expiry}" -le "$(date +"%s")" ] &&
            values_regex="${values_regex:+${values_regex}|}${expiry_value_name}=\".*\"|${token_value_name}=\".*\""
    done 4<< EOF
$(grep -F ACCESS_TOKEN_EXPIRY "${config}" || :)
EOF

    chmod u+w "${config}" &&
        printf "%s\n" "$(grep -Ev "^\$${values_regex:+|${values_regex}}" "${config}")" >| "${config}" &&
        chmod "a-w-r-x,u+r" "${config}"
    return 0
}

##################################################
# Process all arguments given to the script
###################################################
_setup_arguments() {
    [ $# = 0 ] && printf "Missing arguments\n" && return 1
    # Internal variables
    # De-initialize if any variables set already.
    unset LIST_ACCOUNTS UPDATE_DEFAULT_ACCOUNT CUSTOM_ACCOUNT_NAME NEW_ACCOUNT_NAME DELETE_ACCOUNT_NAME ACCOUNT_ONLY_RUN
    unset LOG_FILE_ID OAUTH_ENABLED API_KEY_DOWNLOAD FOLDERNAME SKIP_SUBDIRS NO_OF_PARALLEL_JOBS PARALLEL_DOWNLOAD ALL_HELP
    unset DEBUG QUIET VERBOSE SKIP_INTERNET_CHECK RETRY SPEED_LIMIT USER_AGENT PROXY
    unset ID_INPUT_ARRAY FINAL_INPUT_ARRAY INCLUDE_FILES EXCLUDE_FILES
    unset ARIA_FLAGS CURL_FLAGS
    export DOWNLOADER="curl"
    export USER_AGENT_FLAG="--user-agent" # common for both curl and aria2c
    # curl and aria2c specific flags
    export ARIA_SPEED_LIMIT_FLAG="--max-download-limit" \
        CURL_SPEED_LIMIT_FLAG="--limit-rate" \
        ARIA_PROXY_FLAG="--all-proxy" \
        CURL_PROXY_FLAG="--proxy"
    export CURL_PROGRESS="-s" EXTRA_LOG=":"
    CONFIG="${HOME}/.gdl.conf"

    # API
    unset ROOT_FOLDER ROOT_FOLDER_NAME CLIENT_ID CLIENT_SECRET REFRESH_TOKEN ACCESS_TOKEN

    export API_KEY="AIzaSyD2dHsZJ9b4OXuy5B_owiL8W18NaNOM8tk" \
        API_URL="https://www.googleapis.com"
    export API_VERSION="v3" \
        SCOPE="${API_URL}/auth/drive" \
        REDIRECT_URI="urn:ietf:wg:oauth:2.0:oob" \
        TOKEN_URL="https://accounts.google.com/o/oauth2/token"

    _check_longoptions() {
        [ -z "${2}" ] && {
            printf "%s\n" "${0##*/}: ${1}: flag requires an argument."
            printf "\n%s\n" "Help:"
            printf "%s\n" "    $(_usage "${1}")"
            exit 1
        }
        return 0
    }

    while [ "${#}" -gt 0 ]; do
        case "${1}" in
            -h | --help) _usage "${2}" ;;
            -D | --debug) DEBUG="true" && export DEBUG ;;
            -V | --version | --info) _version_info ;;
            -l | --log)
                _check_longoptions "${1}" "${2}"
                export LOG_FILE_ID="${2}" && shift
                ;;
            -aria | --aria-flags)
                command -v aria2c 1>| /dev/null || { printf "%s\n" "Error: aria2c not installed." && exit 1; }
                DOWNLOADER="aria2c"
                [ "${1}" = "--aria-flags" ] && {
                    _check_longoptions "${1}" "${2}"
                    ARIA_FLAGS=" ${ARIA_FLAGS} ${2} " && shift
                }
                ;;
            -o | --oauth) export OAUTH_ENABLED="true" ;;
            -a | --account)
                export OAUTH_ENABLED="true"
                _check_longoptions "${1}" "${2}"
                export CUSTOM_ACCOUNT_NAME="${2##default=}" && shift
                [ -z "${2##default=*}" ] && export UPDATE_DEFAULT_ACCOUNT="_update_config"
                ;;
            -la | --list-account) export LIST_ACCOUNTS="true" ;;
            # this flag is preferred over --account
            -ca | --create-account)
                export OAUTH_ENABLED="true"
                _check_longoptions "${1}" "${2}"
                export NEW_ACCOUNT_NAME="${2}" && shift
                ;;
            -da | --delete-account)
                _check_longoptions "${1}" "${2}"
                export DELETE_ACCOUNT_NAME="${2}" && shift
                ;;
            -k | --key)
                export API_KEY_DOWNLOAD="true"
                _API_KEY="${2##default=}"
                # https://github.com/l4yton/RegHex#Google-Drive-API-Key
                if printf "%s\n" "${_API_KEY}" | grep -qE 'AIza[0-9A-Za-z_-]{35}'; then
                    export API_KEY="${_API_KEY}" && shift
                    [ -z "${2##default=*}" ] && UPDATE_DEFAULT_API_KEY="_update_config"
                fi
                ;;
            -c | --config)
                _check_longoptions "${1}" "${2}"
                CONFIG="${2}" && shift
                ;;
            -d | --directory)
                _check_longoptions "${1}" "${2}"
                export FOLDERNAME="${2}" && shift
                ;;
            -s | --skip-subdirs)
                export SKIP_SUBDIRS="true"
                ;;
            -p | --parallel)
                _check_longoptions "${1}" "${2}"
                if [ "${2}" -gt 0 ] 2>| /dev/null 1>&2; then
                    export NO_OF_PARALLEL_JOBS="${2}"
                else
                    printf "\nError: -p/--parallel accepts values between 1 to 10.\n"
                    exit 1
                fi
                export PARALLEL_DOWNLOAD="parallel" && shift
                ;;
            --proxy)
                _check_longoptions "${1}" "${2}"
                export PROXY="${2}" && shift
                ;;

            --speed)
                _check_longoptions "${1}" "${2}"
                regex='^([0-9]+)([k,K]|[m,M])+$'
                if printf "%s\n" "${2}" | grep -qE "${regex}"; then
                    export SPEED_LIMIT="${2}" && shift
                else
                    printf "Error: Wrong speed limit format, supported formats: 1K and 1M.\n" 1>&2
                    exit 1
                fi
                ;;
            -ua | --user-agent)
                _check_longoptions "${1}" "${2}"
                export USER_AGENT="${2}" && shift
                ;;
            -R | --retry)
                _check_longoptions "${1}" "${2}"
                if [ "$((2))" -gt 0 ] 2>| /dev/null 1>&2; then
                    export RETRY="${2}" && shift
                else
                    printf "Error: -R/--retry only takes positive integers as arguments, min = 1, max = infinity.\n"
                    exit 1
                fi
                ;;
            -in | --include)
                _check_longoptions "${1}" "${2}"
                export INCLUDE_FILES="${INCLUDE_FILES:+${INCLUDE_FILES}|}${2}" && shift
                ;;
            -ex | --exclude)
                _check_longoptions "${1}" "${2}"
                export EXCLUDE_FILES="${EXCLUDE_FILES:+${EXCLUDE_FILES}|}${2}" && shift
                ;;
            -q | --quiet) export QUIET="_print_center_quiet" ;;
            --verbose) export VERBOSE="true" CURL_PROGRESS="" ;;
            --skip-internet-check)
                SKIP_INTERNET_CHECK=":"
                ;;
                # just ignore empty inputs
            '') : ;;
            *) # Check if user meant it to be a flag
                if [ -z "${1##-*}" ]; then
                    [ "${GDL_INSTALLED_WITH}" = script ] && {
                        case "${1}" in
                            -u | --update)
                                _check_debug && _update && { exit 0 || exit 1; }
                                ;;
                            --uninstall)
                                _check_debug && _update uninstall && { exit 0 || exit 1; }
                                ;;
                        esac
                    }
                    printf '%s: %s: Unknown option\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" && exit 1
                else
                    ID_INPUT_ARRAY="${ID_INPUT_ARRAY}
                        $(_extract_id "${1}")"
                fi
                ;;
        esac
        shift
    done

    _check_debug

    [ -n "${QUIET}" ] && export CURL_PROGRESS="-s" ARIA_FLAGS=" ${ARIA_FLAGS} -q "

    # check if extra flags for network requests was given, if present, then add to extra_flags var which later will be suffixed to ARIA_FLAGS and CURL_FLAGS
    ARIA_extra_flags="" CURL_extra_flags=""
    for downloader in CURL ARIA; do
        extra_flags="" flag="" value=""
        for var in SPEED_LIMIT USER_AGENT PROXY; do
            _set_value i value "${var}"
            [ -n "${value}" ] && {
                _set_value i flag "${downloader}_${var}_FLAG"
                extra_flags="${extra_flags} ${flag} ${value}"
            }
        done
        _set_value d "${downloader}_extra_flags" "${extra_flags}"
    done

    # used when downloaded with aria
    export ARIA_FLAGS="${ARIA_FLAGS} --auto-file-renaming=false --continue ${ARIA_extra_flags}"

    # set CURL_FLAGS which will be used with every curl request, including donwloadind the files
    export CURL_FLAGS="${CURL_FLAGS} ${CURL_extra_flags}"

    [ -n "${OAUTH_ENABLED}" ] && unset API_KEY_DOWNLOAD

    [ -n "${API_KEY_DOWNLOAD}" ] && "${UPDATE_DEFAULT_API_KEY:-:}" API_KEY "${API_KEY}" "${CONFIG}"

    # handle account related flags here as we want to use the flags independenlty even with no normal valid inputs
    # delete account, --delete-account flag
    # TODO: add support for deleting multiple accounts
    [ -n "${DELETE_ACCOUNT_NAME}" ] && _delete_account "${DELETE_ACCOUNT_NAME}"
    # list all configured accounts, --list-accounts flag
    [ -n "${LIST_ACCOUNTS}" ] && _all_accounts

    # If no input, then check if either -C option was used.
    [ -z "${ID_INPUT_ARRAY}" ] && {
        # if any account related option was used then don't show short help
        [ -z "${DELETE_ACCOUNT_NAME:-${LIST_ACCOUNTS:-${NEW_ACCOUNT_NAME}}}" ] && _short_help
        # exit right away if --list-accounts or --delete-account flag was used
        [ -n "${DELETE_ACCOUNT_NAME:-${LIST_ACCOUNTS:-}}" ] && exit 0
        # don't exit right away when new account is created but also let the rootdir stuff execute
        [ -n "${NEW_ACCOUNT_NAME}" ] && CONTINUE_WITH_NO_INPUT="true"
    }

    return 0
}

###################################################
# Process all the values in "${ID_INPUT_ARRAY}"
###################################################
_process_arguments() {
    ${FOLDERNAME:+mkdir -p ${FOLDERNAME}}
    cd "${FOLDERNAME:-.}" 2>| /dev/null 1>&2 || exit 1

    unset Aseen && while read -r id <&4 && { [ -n "${id}" ] || continue; } &&
        case "${Aseen}" in
            *"|:_//_:|${id}|:_//_:|"*) continue ;;
            *) Aseen="${Aseen}|:_//_:|${id}|:_//_:|" ;;
        esac do
        _check_id "${id}" || continue
        if [ -n "${FOLDER_ID}" ]; then
            _download_folder "${FOLDER_ID}" "${NAME}" "${PARALLEL_DOWNLOAD:-}"
        else
            _download_file_main noparse "${FILE_ID}" "${NAME}" "${SIZE}"
        fi
    done 4<< EOF
$(printf "%s\n" "${ID_INPUT_ARRAY}")
EOF
    return 0
}

main() {
    [ $# = 0 ] && _short_help

    if [ -z "${SELF_SOURCE}" ]; then
        export UTILS_FOLDER="${UTILS_FOLDER:-${PWD}}"
        export COMMON_UTILS_FILE="${COMMON_UTILS_FILE:-${PWD}/../common/utils.sh}"
        export SOURCE_UTILS='. '${COMMON_UTILS_FILE}' &&
        . '${UTILS_FOLDER}/auth-utils.sh' &&
        . '${UTILS_FOLDER}/common-utils.sh' && 
        . '${UTILS_FOLDER}/drive-utils.sh' &&
        . '${UTILS_FOLDER}/download-utils.sh''
    else
        SCRIPT_PATH="$(cd "$(_dirname "${0}")" && pwd)/${0##*\/}" && export SCRIPT_PATH
        export SOURCE_UTILS='SOURCED_GDL=true . '${SCRIPT_PATH}''
    fi
    eval "${SOURCE_UTILS}" || { printf "Error: Unable to source util files.\n" && exit 1; }

    set -o errexit -o noclobber

    TMPFILE="$(command -v mktemp 1>| /dev/null && mktemp -u)" || TMPFILE="$(pwd)/.$(_t="$(date +"%s")" && printf "%s\n" "$((_t * _t))").tmpfile"

    _setup_arguments "${@}" || exit 1
    "${SKIP_INTERNET_CHECK:-_check_internet}" || exit 1

    { { command -v mktemp 1>| /dev/null && TMPFILE="$(mktemp -u)"; } ||
        TMPFILE="$(pwd)/.$(_t="$(date +'%s')" && printf "%s\n" "$((_t * _t))").LOG"; } || exit 1
    export TMPFILE

    _cleanup() {
        # unhide the cursor if hidden
        [ -n "${SUPPORT_ANSI_ESCAPES}" ] && printf "\033[?25h\033[?7h"
        {
            # update the config with latest ACCESS_TOKEN and ACCESS_TOKEN_EXPIRY only if changed
            [ -f "${TMPFILE}_ACCESS_TOKEN" ] && {
                . "${TMPFILE}_ACCESS_TOKEN"
                [ "${INITIAL_ACCESS_TOKEN}" = "${ACCESS_TOKEN}" ] || {
                    _update_config "ACCOUNT_${ACCOUNT_NAME}_ACCESS_TOKEN" "${ACCESS_TOKEN}" "${CONFIG}"
                    _update_config "ACCOUNT_${ACCOUNT_NAME}_ACCESS_TOKEN_EXPIRY" "${ACCESS_TOKEN_EXPIRY}" "${CONFIG}"
                }
            } || : 1>| /dev/null

            # grab all chidren processes of access token service
            # https://askubuntu.com/a/512872
            [ -n "${ACCESS_TOKEN_SERVICE_PID}" ] && {
                token_service_pids="$(ps --ppid="${ACCESS_TOKEN_SERVICE_PID}" -o pid=)"
                # first kill parent id, then children processes
                kill "${ACCESS_TOKEN_SERVICE_PID}"
            } || : 1>| /dev/null

            # grab all script children pids
            script_children_pids="$(ps --ppid="${MAIN_PID}" -o pid=)"

            # kill all grabbed children processes
            # shellcheck disable=SC2086
            kill ${token_service_pids} ${script_children_pids} 1>| /dev/null

            rm -f "${TMPFILE:?}"*

            export abnormal_exit && if [ -n "${abnormal_exit}" ]; then
                printf "\n\n%s\n" "Script exited manually."
                kill -9 -$$ &
            else
                { _cleanup_config "${CONFIG}" && [ "${GDL_INSTALLED_WITH}" = script ] && _auto_update; } 1>| /dev/null &
            fi
        } 2>| /dev/null || :
        return 0
    }

    trap 'abnormal_exit="1" ; exit' INT TERM
    trap '_cleanup' EXIT
    trap '' TSTP # ignore ctrl + z

    export MAIN_PID="$$"

    if [ -n "${OAUTH_ENABLED}" ]; then
        "${EXTRA_LOG}" "justify" "Checking credentials.." "-"
        { _check_credentials && for _ in 1 2; do _clear_line 1; done; } ||
            { "${QUIET:-_print_center}" "normal" "[ Error: Credentials checking failed ]" "=" && exit 1; }
        "${QUIET:-_print_center}" "normal" " Account: ${ACCOUNT_NAME} " "="

        export API_REQUEST_FUNCTION="_api_request_oauth" OAUTH_ENABLED="true"
    else
        export API_REQUEST_FUNCTION="_api_request"
    fi

    # only execute next blocks if there was some input
    [ -n "${CONTINUE_WITH_NO_INPUT}" ] && exit 0

    START="$(date +'%s')"

    # hide the cursor if ansi escapes are supported
    [ -n "${SUPPORT_ANSI_ESCAPES}" ] && printf "\033[?25l"

    _process_arguments

    END="$(date +'%s')"
    DIFF="$((END - START))"
    "${QUIET:-_print_center}" "normal" " Time Elapsed: ""$((DIFF / 60))"" minute(s) and ""$((DIFF % 60))"" seconds. " "="
}

{ [ -z "${SOURCED_GDL}" ] && main "${@}"; } || :
