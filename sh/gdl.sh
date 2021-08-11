#!/usr/bin/env sh
# Download file/folder from google drive.
# shellcheck source=/dev/null

_usage() {
    printf "%b" "
The script can be used to download file/directory from google drive.\n
Usage:\n ${0##*/} [options.. ] <file_[url|id]> or <folder[url|id]>\n
Options:\n
  -aria | --aria-flags 'flags' - Use aria2c to download. '-aria' does not take arguments.\n
      To give custom flags as argument, use long flag, --aria-flags. e.g: --aria-flags '-s 10 -x 10'\n
      Note 1: aria2c can only resume google drive downloads if '-k/--key' or '-o/--oauth' option is used.\n
      Note 2: aria split downloading won't work in normal mode ( without '-k' or '-o' flag ) because it cannot get the remote server size. Same for any other feature which uses remote server size.\n
      Note 3: By above notes, conclusion is, aria is basically same as curl in normal mode, so it is recommended to be used only with '--key' and '--oauth' flag.\n
  -o | --oauth - Use this flag to trigger oauth authentication.\n
      Note: If both --oauth and --key flag is used, --oauth flag is preferred.\n
  -a | --account 'account name' - Use different account than the default one.\n
      To change the default account name, use this format, -a/--account default=account_name\n
  -la | --list-accounts - Print all configured accounts in the config files.\n
  -ca | --create-account 'account name' - To create a new account with the given name if does not already exists.\n
  -da | --delete-account 'account name' - To delete an account information from config file. \n
  -k | --key 'API KEY' ( optional arg ) - To download with api key. If api key is not specified, then the predefined api key will be used.\n
      To save your api key in config file, use 'gdl --key default=your api key'.\n
      API key will be saved in '${HOME}/.gdl.conf' and will be used from now on.\n
      Note: If both --key and --key oauth is used, --oauth flag is preferred.\n
  -c | --config 'config file path' - Override default config file with custom config file. Default: ${HOME}/.gdl.conf\n
  -d | --directory 'foldername' - option to _download given input in custom directory.\n
  -s | --skip-subdirs - Skip downloading of sub folders present in case of folders.\n
  -p | --parallel 'no_of_files_to_parallely_upload' - Download multiple files in parallel.\n
  --proxy 'http://user:password@host:port' - Specify a proxy to use, should be in the format accepted by curl --proxy and aria2c --all-proxy flag.\n
  --speed 'speed' - Limit the download speed, supported formats: 1K, and 1M.\n
  -ua | --user-agent 'user agent string' - Specify custom user agent.\n
  -R | --retry 'num of retries' - Retry the file upload if it fails, postive integer as argument. Currently only for file uploads.\n
  -in | --include 'pattern' - Only download the files which contain the given pattern - Applicable for folder downloads.\n
      e.g: ${0##*/} local_folder --include '1', will only include with files with pattern '1' in the name. Regex can be used which works with grep -E command.\n
  -ex | --exclude 'pattern' - Exclude the files with the given pattern from downloading. - Applicable for folder downloads.\n
      e.g: ${0##*/} local_folder --exclude '1', will exclude all the files pattern '1' in the name. Regex can be used which works with grep -E command.\n
  -l | --log 'file_to_save_info' - Save downloaded files info to the given filename.\n
  -q | --quiet - Supress the normal output, only show success/error upload messages for files, and one extra line at the beginning for folder showing no. of files and sub folders.\n
  -V | --verbose - Display detailed message (only for non-parallel uploads).\n
  --skip-internet-check - Do not check for internet connection, recommended to use in sync jobs.\n
  $([ "${GDL_INSTALLED_WITH}" = script ] && printf '%s\n' '-u | --update - Update the installed script in your system.\n
  -U | --uninstall - Uninstall script, remove related files.\n
  -V | --version | --info - Show detailed info, only if script is installed system wide.\n')
  -D | --debug - Display script command trace.\n
  -h | --help - Display usage instructions.\n"
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
    unset LOG_FILE_ID OAUTH_ENABLED API_KEY_DOWNLOAD FOLDERNAME SKIP_SUBDIRS NO_OF_PARALLEL_JOBS PARALLEL_DOWNLOAD
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
        [ -z "${2}" ] &&
            printf '%s: %s: option requires an argument\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" &&
            exit 1
        return 0
    }

    while [ "${#}" -gt 0 ]; do
        case "${1}" in
            -h | --help) _usage ;;
            -D | --debug) DEBUG="true" && export DEBUG ;;
            -u | --update) _check_debug && _update ;;
            -U | --uninstall) _check_debug && _update uninstall ;;
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
                    printf "\nError: -p/--parallel value ranges between 1 to 10.\n"
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
        export SOURCE_UTILS='. '${UTILS_FOLDER}/auth-utils.sh' && . '${UTILS_FOLDER}/common-utils.sh' && . '${UTILS_FOLDER}/drive-utils.sh' && . '${UTILS_FOLDER}/download-utils.sh''
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
