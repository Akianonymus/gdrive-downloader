#!/usr/bin/env sh
# helper functions related to main script
# shellcheck source=/dev/null

###################################################
# Function to cleanup config file
# Remove invalid access tokens on the basis of corresponding expiry
# Globals: None
# Arguments: 1
#   ${1} = config file
###################################################
_cleanup_config() {
    config="${1:?Error: Missing config}" && unset values_regex _tmp

    ! [ -f "${config}" ] && return 0

    while read -r line <&4 && [ -n "${line}" ]; do
        expiry_value_name="${line%%=*}"
        token_value_name="${expiry_value_name%%_EXPIRY}"

        _tmp="${line##*=}" && _tmp="${_tmp%\"}" && expiry="${_tmp#\"}"
        [ "${expiry}" -le "$(_epoch)" ] &&
            values_regex="${values_regex:+${values_regex}|}${expiry_value_name}=\".*\"|${token_value_name}=\".*\""
    done 4<< EOF
$(grep -F ACCESS_TOKEN_EXPIRY -- "${config}" || :)
EOF

    chmod u+w -- "${config}" &&
        printf "%s\n" "$(grep -Ev "^\$${values_regex:+|${values_regex}}" -- "${config}")" >| "${config}" &&
        chmod "a-w-r-x,u+r" -- "${config}"
    return 0
}

##################################################
# Process all arguments given to the script
###################################################
_setup_arguments() {
    [ $# = 0 ] && printf "Missing arguments\n" && return 1
    # Internal variables
    # De-initialize if any variables set already.
    unset _ALL_HELP
    unset CURL_FLAGS
    export DOWNLOADER="curl"
    export CURL_PROGRESS="-s" EXTRA_LOG=":"
    export CONFIG="${HOME}/.gdl.conf"

    # API
    export API_URL="https://www.googleapis.com"
    export API_VERSION="v3" \
        SCOPE="${API_URL}/auth/drive" \
        REDIRECT_URI="urn:ietf:wg:oauth:2.0:oob" \
        TOKEN_URL="https://accounts.google.com/o/oauth2/token"

    _parse_arguments "${@}" || return 1
    _check_debug

    # post processing for --quiet flag
    [ -n "${QUIET}" ] && export CURL_PROGRESS="-s" ARIA_FLAGS=" ${ARIA_FLAGS} -q "

    # post processing for --speed, --proxy and --user-agent flag
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

    # post processing for --oauth flag
    [ -n "${OAUTH_ENABLED}" ] && unset API_KEY_DOWNLOAD

    # post processing for --key flag
    [ -n "${API_KEY_DOWNLOAD}" ] && "${UPDATE_DEFAULT_API_KEY:-:}" API_KEY "${API_KEY:-}" "${CONFIG}"

    # post processing for --account, --delete-account, --create-acount and --list-accounts
    # handle account related flags here as we want to use the flags independenlty even with no normal valid inputs
    # delete account, --delete-account flag
    # TODO: add support for deleting multiple accounts
    [ -n "${DELETE_ACCOUNT_NAME}" ] && _delete_account "${DELETE_ACCOUNT_NAME}"
    # list all configured accounts, --list-accounts flag
    [ -n "${LIST_ACCOUNTS}" ] && _all_accounts

    # If no input, then check if either -C option was used.
    [ -z "${INPUT_ID_1}" ] && {
        # if any account related option was used then don't show short help
        [ -z "${DELETE_ACCOUNT_NAME:-${LIST_ACCOUNTS:-${NEW_ACCOUNT_NAME}}}" ] && _short_help
        # exit right away if --list-accounts or --delete-account flag was used
        [ -n "${DELETE_ACCOUNT_NAME:-${LIST_ACCOUNTS:-}}" ] && exit 0
        # don't exit right away when new account is created but also let the rootdir stuff execute
        [ -n "${NEW_ACCOUNT_NAME}" ] && CONTINUE_WITH_NO_INPUT="true"
    }

    return 0
}

# setup cleanup after exit using traps
_setup_traps() {
    _cleanup() {
        # unhide the cursor if hidden
        [ -n "${SUPPORT_ANSI_ESCAPES}" ] && printf "\033[?25h\033[?7h"
        {
            # update the config with latest ACCESS_TOKEN and ACCESS_TOKEN_EXPIRY only if changed
            [ -f "${TMPFILE}_ACCESS_TOKEN" ] && {
                . "${TMPFILE}_ACCESS_TOKEN"
                export ACCESS_TOKEN ACCESS_TOKEN_EXPIRY INITIAL_ACCESS_TOKEN ACCOUNT_NAME
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
                kill "${_SCRIPT_KILL_SIGNAL:--9}" -$$ &
            else
                { _cleanup_config "${CONFIG}" && [ "${GDL_INSTALLED_WITH:-}" = script ] && _auto_update; } 1>| /dev/null &
            fi
        } 2>| /dev/null || :
        return 0
    }

    trap 'abnormal_exit="1" ; exit' INT TERM
    trap '_cleanup' EXIT
    trap '' TSTP # ignore ctrl + z

    export MAIN_PID="$$"
}

###################################################
# Process all the values in "${ID_INPUT_ARRAY}"
###################################################
_process_arguments() {
    export DRY_RUN FOLDERNAME TOTAL_INPUTS PARALLEL_DOWNLOAD

    # --directory flag
    [ -n "${FOLDERNAME}" ] && mkdir -p -- "${FOLDERNAME}"

    cd -- "${FOLDERNAME:-.}" 2>| /dev/null 1>&2 || exit 1

    _SEEN="" index_process_arguments=0
    # TOTAL_INPUTS and INPUT_ID_* is exported in _parser_process_input function, see flags.sh
    TOTAL_INPUTS="$((TOTAL_INPUTS < 0 ? 0 : TOTAL_INPUTS))"
    until [ "${index_process_arguments}" -eq "${TOTAL_INPUTS}" ]; do
        FILE_ID="" FOLDER_ID="" NAME="" FILE_MIME_TYPE="" SIZE=""
        _set_value i FILE_ID "INPUT_ID_$((index_process_arguments += 1))"
        # check if the arg was already done
        case "${_SEEN}" in
            *"${FILE_ID}"*) continue ;;
            *) _SEEN="${_SEEN}${FILE_ID}" ;;
        esac

        # _check_id exports FILE_ID, FOLDER_ID, NAME, SIZE
        _check_id "${FILE_ID}" || continue
        [ "${DRY_RUN}" = "true" ] && {
            _clear_line 1
            if [ -n "${FOLDER_ID}" ]; then
                _print_center "justify" "Name: ${NAME}" " | ${FOLDER_ID}" "="
            else
                _print_center "justify" "Name: ${NAME}" " | ${FILE_ID} | Size: $({ [ -n "${SIZE}" ] && _bytes_to_human "${SIZE}"; } || printf 'Unknown')" "="
            fi
            printf '\n' && continue
        }

        if [ -n "${FOLDER_ID}" ]; then
            _download_folder "${DOWNLOAD_METHOD:-alt}" "${FOLDER_ID}" "${NAME}" "${PWD}" "${PARALLEL_DOWNLOAD:-}"
        else
            _download_file_main noparse "${FILE_ID}" "${NAME}" "${FILE_MIME_TYPE}" "${SIZE}"
        fi
    done
    return 0
}

# this function is called from _main function for resoective sh and bash scripts
_main_helper() {
    _setup_arguments "${@}" || exit 1
    "${SKIP_INTERNET_CHECK:-_check_internet}" || exit 1

    TMPFILE="$(command -v mktemp 1>| /dev/null && mktemp -u)" || TMPFILE="$(pwd)/.$(_t="$(_epoch)" && printf "%s\n" "$((_t * _t))").tmpfile"
    export TMPFILE

    # setup a cleanup function and use it with traps, also export MAIN_PID
    _setup_traps

    if [ -n "${OAUTH_ENABLED}" ]; then
        "${EXTRA_LOG}" "justify" "Checking credentials.." "-"
        { _check_credentials && _clear_line 1; } ||
            { "${QUIET:-_print_center}" "normal" "[ Error: Credentials checking failed ]" "=" && exit 1; }
        "${QUIET:-_print_center}" "normal" " Account: ${ACCOUNT_NAME} " "="

        export API_REQUEST_FUNCTION="_api_request_oauth" OAUTH_ENABLED="true"
    else
        export API_REQUEST_FUNCTION="_api_request"
    fi

    # only execute next blocks if there was some input
    [ -n "${CONTINUE_WITH_NO_INPUT}" ] && exit 0

    START="$(_epoch)"

    # hide the cursor if ansi escapes are supported
    [ -n "${SUPPORT_ANSI_ESCAPES}" ] && printf "\033[?25l"

    _process_arguments

    END="$(_epoch)"
    DIFF="$((END - START))"
    "${QUIET:-_print_center}" "normal" " Time Elapsed: ""$((DIFF / 60))"" minute(s) and ""$((DIFF % 60))"" seconds. " "="

}
