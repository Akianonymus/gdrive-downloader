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
      Note 1: aria2c can only resume google drive downloads if '-k/--key' or '-o/--oauth' option is used, otherwise, it will use curl.\n
      Note 2: aria split downloading won't work in normal mode ( without '-k' or '-o' flag ) because it cannot get the remote server size. Same for any other feature which uses remote server size.\n
      Note 3: By above notes, conclusion is, aria is basically same as curl in normal mode, so it is recommended to be used only with '--key' and '--oauth' flag.\n
  -o | --oauth - Use this flag to trigger oauth authentication.\n
      Note: If both --oauth and --key flag is used, --oauth flag is preferred.\n
  -k | --key 'API KEY' ( optional arg ) - To download with api key. If api key is not specified, then the predefined api key will be used.\n
      To save your api key in config file, use 'gdl --key default=your api key'.
      API key will be saved in '${HOME}/.gdl.conf' and will be used from now on.\n
      Note: If both --key and --key oauth is used, --oauth flag is preferred.\n
  -c | --config 'config file path' - Override default config file with custom config file. Default: ${HOME}/.gdl.conf\n
  -d | --directory 'foldername' - option to _download given input in custom directory.\n
  -s | --skip-subdirs - Skip downloading of sub folders present in case of folders.\n
  -p | --parallel 'no_of_files_to_parallely_upload' - Download multiple files in parallel.\n
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
  -u | --update - Update the installed script in your system.\n
  -V | --version | --info - Show detailed info, only if script is installed system wide.\n
  --uninstall - Uninstall script, remove related files.\n
  -D | --debug - Display script command trace.\n
  -h | --help - Display usage instructions.\n"
    exit 0
}

_short_help() {
    printf "No valid arguments provided, use -h/--help flag to see usage.\n"
    exit 0
}

###################################################
# Automatic updater, only update if script is installed system wide.
# Arguments: None
# Result: On
#   Update if AUTO_UPDATE_INTERVAL + LAST_UPDATE_TIME less than printf "%(%s)T\\n" "-1"
###################################################
_auto_update() {
    export REPO
    command -v "${COMMAND_NAME}" 1> /dev/null &&
        if [ -n "${REPO:+${COMMAND_NAME:+${INSTALL_PATH:+${TYPE:+${TYPE_VALUE}}}}}" ]; then
            current_time="$(date +'%s')"
            [ "$((LAST_UPDATE_TIME + AUTO_UPDATE_INTERVAL))" -lt "$(date +'%s')" ] && _update
            _update_value LAST_UPDATE_TIME "${current_time}"
        fi
    return 0
}

###################################################
# Install/Update/uninstall the script.
# Arguments: 1
#   ${1}" = uninstall or update
# Result: On
#   ${1}" = nothing - Update the script if installed, otherwise install.
#   ${1}" = uninstall - uninstall the script
###################################################
_update() {
    job_update="${1:-update}"
    [ "${GLOBAL_INSTALL}" = true ] && ! [ "$(id -u)" = 0 ] && printf "%s\n" "Error: Need root access to update." && return 0
    [ "${job_update}" = uninstall ] && job_string_update="--uninstall"
    _print_center "justify" "Fetching ${job_update} script.." "-"
    repo_update="${REPO:-labbots/gdrive-downloader}" type_value_update="${TYPE_VALUE:-master}" cmd_update="${COMMAND_NAME:-gdl}" path_update="${INSTALL_PATH:-${HOME}/.gdrive-downloader}"
    if script_update="$(curl --compressed -Ls "https://github.com/${repo_update}/raw/${type_value_update}/install.sh")"; then
        _clear_line 1
        printf "%s\n" "${script_update}" | sh -s -- ${job_string_update:-} --skip-internet-check --cmd "${cmd_update}" --path "${path_update}"
        current_time="$(date +'%s')"
        [ -z "${job_string_update}" ] && _update_value LAST_UPDATE_TIME "${current_time}"
    else
        _clear_line 1
        "${QUIET:-_print_center}" "justify" "Error: Cannot download" " ${job_update} script." "=" 1>&2
        exit 1
    fi
    exit "${?}"
}

###################################################
# Print info if installed
###################################################
_version_info() {
    if command -v "${COMMAND_NAME}" 1> /dev/null && [ -n "${REPO:+${COMMAND_NAME:+${INSTALL_PATH:+${TYPE:+${TYPE_VALUE}}}}}" ]; then
        for i in REPO INSTALL_PATH INSTALLATION TYPE TYPE_VALUE LATEST_INSTALLED_SHA; do
            printf "%s\n" "${i}=\"$(eval printf "%s" \"\$"${i}"\")\""
        done | sed -e "s/=/: /g"
    else
        printf "%s\n" "gdrive-downloader is not installed system wide."
    fi
    exit 0
}

###################################################
# Update in-script values
###################################################
_update_value() {
    command_path="${INSTALL_PATH:?}/${COMMAND_NAME}"
    value_name="${1:-}" value="${2:-}"
    script_without_value_and_shebang="$(grep -v "${value_name}=\".*\".* # added values" "${command_path}" | sed 1d)"
    new_script="$(
        sed -n 1p "${command_path}"
        printf "%s\n" "${value_name}=\"${value}\" # added values"
        printf "%s\n" "${script_without_value_and_shebang}"
    )"
    chmod +w "${command_path}" && printf "%s\n" "${new_script}" >| "${command_path}" && chmod -w "${command_path}"
    return 0
}

##################################################
# Process all arguments given to the script
###################################################
_setup_arguments() {
    [ $# = 0 ] && printf "Missing arguments\n" && return 1
    # Internal variables
    # De-initialize if any variables set already.
    unset LOG_FILE_ID OAUTH_ENABLED API_KEY_DOWNLOAD CONFIG FOLDERNAME SKIP_SUBDIRS NO_OF_PARALLEL_JOBS PARALLEL_DOWNLOAD
    unset DOWNLOAD_WITH_ARIA ARIA_EXTRA_FLAGS ARIA_SPEED_LIMIT_FLAG
    unset DEBUG QUIET VERBOSE VERBOSE_PROGRESS SKIP_INTERNET_CHECK RETRY SPEED_LIMIT USER_AGENT
    unset ID_INPUT_ARRAY FINAL_INPUT_ARRAY INCLUDE_FILES EXCLUDE_FILES
    export USER_AGENT_FLAG="--user-agent" # common for both curl and aria2c
    CURL_PROGRESS="-s" CURL_SPEED_LIMIT_FLAG="--limit-rate" CURL_EXTRA_FLAGS="-Ls"
    EXTRA_LOG=":"
    CONFIG="${HOME}/.gdl.conf"

    # API
    API_KEY="AIzaSyD2dHsZJ9b4OXuy5B_owiL8W18NaNOM8tk"
    API_URL="https://www.googleapis.com"
    API_VERSION="v3"
    SCOPE="${API_URL}/auth/drive"
    REDIRECT_URI="urn:ietf:wg:oauth:2.0:oob"
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
                LOG_FILE_ID="${2}" && shift
                ;;
            -aria | --aria-flags)
                DOWNLOAD_WITH_ARIA="true"
                [ "${1}" = "--aria-flags" ] && {
                    _check_longoptions "${1}" "${2}"
                    ARIA_EXTRA_FLAGS=" ${ARIA_EXTRA_FLAGS} ${2} " && shift
                }
                ;;
            -o | --oauth) OAUTH_ENABLED="true" ;;
            -k | --key)
                API_KEY_DOWNLOAD="true"
                _API_KEY="${2##default=}"
                # https://github.com/l4yton/RegHex#Google-Drive-API-Key
                if printf "%s\n" "${_API_KEY}" | grep -qE 'AIza[0-9A-Za-z_-]{35}'; then
                    API_KEY="${_API_KEY}" && shift
                    [ -z "${2##default=*}" ] && UPDATE_DEFAULT_API_KEY="_update_config"
                fi
                ;;
            -c | --config)
                _check_longoptions "${1}" "${2}"
                CONFIG="${2}" && shift
                ;;
            -d | --directory)
                _check_longoptions "${1}" "${2}"
                FOLDERNAME="${2}" && shift
                ;;
            -s | --skip-subdirs)
                SKIP_SUBDIRS="true"
                ;;
            -p | --parallel)
                _check_longoptions "${1}" "${2}"
                if [ "${2}" -gt 0 ] 2>| /dev/null 1>&2; then
                    NO_OF_PARALLEL_JOBS="${2}"
                else
                    printf "\nError: -p/--parallel value ranges between 1 to 10.\n"
                    exit 1
                fi
                PARALLEL_DOWNLOAD="parallel" && shift
                ;;
            --speed)
                _check_longoptions "${1}" "${2}"
                regex='^([0-9]+)([k,K]|[m,M])+$'
                if printf "%s\n" "${2}" | grep -qE "${regex}"; then
                    SPEED_LIMIT="${2}" && shift
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
                    RETRY="${2}" && shift
                else
                    printf "Error: -R/--retry only takes positive integers as arguments, min = 1, max = infinity.\n"
                    exit 1
                fi
                ;;
            -in | --include)
                _check_longoptions "${1}" "${2}"
                INCLUDE_FILES="${INCLUDE_FILES:+${INCLUDE_FILES}|}${2}" && shift
                ;;
            -ex | --exclude)
                _check_longoptions "${1}" "${2}"
                EXCLUDE_FILES="${EXCLUDE_FILES:+${EXCLUDE_FILES}|}${2}" && shift
                ;;
            -q | --quiet) QUIET="_print_center_quiet" ;;
            --verbose) VERBOSE="true" ;;
            --skip-internet-check)
                SKIP_INTERNET_CHECK=":"
                ;;
            '' | *)
                [ -n "${1}" ] && {
                    # Check if user meant it to be a flag
                    if [ -z "${1##-*}" ]; then
                        printf '%s: %s: Unknown option\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" && exit 1
                    else
                        ID_INPUT_ARRAY="${ID_INPUT_ARRAY}
                                    $(_extract_id "${1}")"
                    fi
                }
                ;;
        esac
        shift
    done

    # If no input
    [ -z "${ID_INPUT_ARRAY}" ] && _short_help

    [ -n "${OAUTH_ENABLED}" ] && unset API_KEY_DOWNLOAD

    [ -n "${DOWNLOAD_WITH_ARIA}" ] && {
        command -v aria2c 1>| /dev/null || { printf "%s\n" "Error: aria2c not installed." && exit 1; }
        ARIA_SPEED_LIMIT_FLAG="--max-download-limit"
        ARIA_EXTRA_FLAGS="${ARIA_EXTRA_FLAGS} -q --file-allocation=none --auto-file-renaming=false --continue"
    }

    _check_debug

    return 0
}

###################################################
# Check Oauth credentials and create/update config file
# Client ID, Client Secret, Refesh Token and Access Token
# Globals: 10 variables, 3 functions
#   Variables - API_URL, API_VERSION, TOKEN URL,
#               CONFIG, UPDATE_DEFAULT_CONFIG, INFO_PATH,
#               CLIENT_ID, CLIENT_SECRET, REFRESH_TOKEN and ACCESS_TOKEN
#   Functions - _update_config, _json_value and _print
# Arguments: None
# Result: read description
###################################################
_check_credentials() {
    # Config file is created automatically after first run
    [ -r "${CONFIG}" ] && . "${CONFIG}"

    if [ -n "${OAUTH_ENABLED}" ]; then
        ! [ -t 1 ] && [ -z "${CLIENT_ID:+${CLIENT_SECRET:+${REFRESH_TOKEN}}}" ] && {
            printf "%s\n" "Error: Script is not running in a terminal, cannot ask for credentials."
            printf "%s\n" "Add in config manually if terminal is not accessible. CLIENT_ID, CLIENT_SECRET and REFRESH_TOKEN is required." && return 1
        }

        # Following https://developers.google.com/identity/protocols/oauth2#size
        CLIENT_ID_REGEX='[0-9]+-[0-9A-Za-z_]{32}\.apps\.googleusercontent\.com'
        CLIENT_SECRET_REGEX='[0-9A-Za-z_-]+'
        REFRESH_TOKEN_REGEX='[0-9]//[0-9A-Za-z_-]+'     # 512 bytes
        ACCESS_TOKEN_REGEX='ya29\.[0-9A-Za-z_-]+'       # 2048 bytes
        AUTHORIZATION_CODE_REGEX='[0-9]/[0-9A-Za-z_-]+' # 256 bytes

        until [ -n "${CLIENT_ID}" ] && [ -n "${CLIENT_ID_VALID}" ]; do
            [ -n "${CLIENT_ID}" ] && {
                if printf "%s\n" "${CLIENT_ID}" | grep -qE "${CLIENT_ID_REGEX}"; then
                    [ -n "${client_id}" ] && _update_config CLIENT_ID "${CLIENT_ID}" "${CONFIG}"
                    CLIENT_ID_VALID="true" && continue
                else
                    { [ -n "${client_id}" ] && message="- Try again"; } || message="in config ( ${CONFIG} )"
                    "${QUIET:-_print_center}" "normal" " Invalid Client ID ${message} " "-" && unset CLIENT_ID client_id
                fi
            }
            [ -z "${client_id}" ] && printf "\n" && "${QUIET:-_print_center}" "normal" " Enter Client ID " "-"
            [ -n "${client_id}" ] && _clear_line 1
            printf -- "-> "
            read -r CLIENT_ID && client_id=1
        done

        until [ -n "${CLIENT_SECRET}" ] && [ -n "${CLIENT_SECRET_VALID}" ]; do
            [ -n "${CLIENT_SECRET}" ] && {
                if printf "%s\n" "${CLIENT_SECRET}" | grep -qE "${CLIENT_SECRET_REGEX}"; then
                    [ -n "${client_secret}" ] && _update_config CLIENT_SECRET "${CLIENT_SECRET}" "${CONFIG}"
                    CLIENT_SECRET_VALID="true" && continue
                else
                    { [ -n "${client_secret}" ] && message="- Try again"; } || message="in config ( ${CONFIG} )"
                    "${QUIET:-_print_center}" "normal" " Invalid Client Secret ${message} " "-" && unset CLIENT_SECRET client_secret
                fi
            }
            [ -z "${client_secret}" ] && printf "\n" && "${QUIET:-_print_center}" "normal" " Enter Client Secret " "-"
            [ -n "${client_secret}" ] && _clear_line 1
            printf -- "-> "
            read -r CLIENT_SECRET && client_secret=1
        done

        [ -n "${REFRESH_TOKEN}" ] && {
            ! printf "%s\n" "${REFRESH_TOKEN}" | grep -qE "${REFRESH_TOKEN_REGEX}" &&
                "${QUIET:-_print_center}" "normal" " Error: Invalid Refresh token in config file, follow below steps.. " "-" && unset REFRESH_TOKEN
        }

        [ -z "${REFRESH_TOKEN}" ] && {
            printf "\n" && "${QUIET:-_print_center}" "normal" "If you have a refresh token generated, then type the token, else leave blank and press return key.." " "
            printf "\n" && "${QUIET:-_print_center}" "normal" " Refresh Token " "-" && printf -- "-> "
            read -r REFRESH_TOKEN
            if [ -n "${REFRESH_TOKEN}" ]; then
                "${QUIET:-_print_center}" "normal" " Checking refresh token.. " "-"
                if ! printf "%s\n" "${REFRESH_TOKEN}" | grep -qE "${REFRESH_TOKEN_REGEX}"; then
                    { _get_access_token_and_update && _update_config REFRESH_TOKEN "${REFRESH_TOKEN}" "${CONFIG}"; } || check_error=1
                else
                    check_error=true
                fi
                [ -n "${check_error}" ] && "${QUIET:-_print_center}" "normal" " Error: Invalid Refresh token given, follow below steps to generate.. " "-" && unset REFRESH_TOKEN
            else
                "${QUIET:-_print_center}" "normal" " No Refresh token given, follow below steps to generate.. " "-"
            fi

            [ -z "${REFRESH_TOKEN}" ] && {
                printf "\n" && "${QUIET:-_print_center}" "normal" "Visit the below URL, tap on allow and then enter the code obtained" " "
                URL="https://accounts.google.com/o/oauth2/auth?client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=${SCOPE}&response_type=code&prompt=consent"
                printf "\n%s\n" "${URL}"
                until [ -n "${AUTHORIZATION_CODE}" ] && [ -n "${AUTHORIZATION_CODE_VALID}" ]; do
                    [ -n "${AUTHORIZATION_CODE}" ] && {
                        if printf "%s\n" "${AUTHORIZATION_CODE}" | grep -qE "${AUTHORIZATION_CODE_REGEX}"; then
                            AUTHORIZATION_CODE_VALID="true" && continue
                        else
                            "${QUIET:-_print_center}" "normal" " Invalid CODE given, try again.. " "-" && unset AUTHORIZATION_CODE authorization_code
                        fi
                    }
                    { [ -z "${authorization_code}" ] && printf "\n" && "${QUIET:-_print_center}" "normal" " Enter the authorization code " "-"; } || _clear_line 1
                    printf -- "-> "
                    read -r AUTHORIZATION_CODE && authorization_code=1
                done
                RESPONSE="$(curl --compressed "${CURL_PROGRESS}" -X POST \
                    --data "code=${AUTHORIZATION_CODE}&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&redirect_uri=${REDIRECT_URI}&grant_type=authorization_code" "${TOKEN_URL}")" || :
                _clear_line 1 1>&2

                REFRESH_TOKEN="$(printf "%s\n" "${RESPONSE}" | _json_value refresh_token 1 1 || :)"
                { _get_access_token_and_update "${RESPONSE}" && _update_config REFRESH_TOKEN "${REFRESH_TOKEN}" "${CONFIG}"; } || return 1
            }
            printf "\n"
        }

        { [ -z "${ACCESS_TOKEN}" ] || ! printf "%s\n" "${ACCESS_TOKEN}" | grep -qE "${ACCESS_TOKEN_REGEX}" || [ "${ACCESS_TOKEN_EXPIRY:-0}" -lt "$(date +'%s')" ]; } &&
            { _get_access_token_and_update || return 1; }
        printf "%b\n" "ACCESS_TOKEN=\"${ACCESS_TOKEN}\"\nACCESS_TOKEN_EXPIRY=\"${ACCESS_TOKEN_EXPIRY}\"" >| "${TMPFILE}_ACCESS_TOKEN"

        # launch a background service to check access token and update it
        # checks ACCESS_TOKEN_EXPIRY, try to update before 5 mins of expiry, a fresh token gets 60 mins
        # process will be killed when script exits or "${MAIN_PID}" is killed
        {
            until ! kill -0 "${MAIN_PID}" 2>| /dev/null 1>&2; do
                . "${TMPFILE}_ACCESS_TOKEN"
                CURRENT_TIME="$(date +'%s')"
                REMAINING_TOKEN_TIME="$((CURRENT_TIME - ACCESS_TOKEN_EXPIRY))"
                if [ "${REMAINING_TOKEN_TIME}" -le 300 ]; then
                    # timeout after 30 seconds, it shouldn't take too long anyway, and update tmp config
                    CONFIG="${TMPFILE}_ACCESS_TOKEN" _timeout 30 _get_access_token_and_update || :
                else
                    TOKEN_PROCESS_TIME_TO_SLEEP="$(if [ "${REMAINING_TOKEN_TIME}" -le 301 ]; then
                        printf "0\n"
                    else
                        printf "%s\n" "$((REMAINING_TOKEN_TIME - 300))"
                    fi)"
                    sleep "${TOKEN_PROCESS_TIME_TO_SLEEP}"
                fi
                sleep 1
            done
        } &
        ACCESS_TOKEN_SERVICE_PID="${!}"

    elif [ -n "${API_KEY_DOWNLOAD}" ]; then
        "${UPDATE_DEFAULT_API_KEY:-:}" API_KEY "${API_KEY}" "${CONFIG}"
    fi

    return 0
}

###################################################
# Process all the values in "${ID_INPUT_ARRAY}"
###################################################
_process_arguments() {
    export DEBUG LOG_FILE_ID VERBOSE API_KEY API_URL API_VERSION \
        FOLDERNAME SKIP_SUBDIRS NO_OF_PARALLEL_JOBS PARALLEL_DOWNLOAD SKIP_INTERNET_CHECK \
        COLUMNS TMPFILE CURL_PROGRESS EXTRA_LOG RETRY QUIET SPEED_LIMIT SOURCE_UTILS \
        DOWNLOAD_WITH_ARIA ARIA_EXTRA_FLAGS ARIA_SPEED_LIMIT_FLAG CURL_SPEED_LIMIT_FLAG CURL_EXTRA_FLAGS \
        OAUTH_ENABLED API_KEY_DOWNLOAD INCLUDE_FILES EXCLUDE_FILES

    ${FOLDERNAME:+mkdir -p ${FOLDERNAME}}
    cd "${FOLDERNAME:-.}" 2>| /dev/null 1>&2 || exit 1

    unset Aseen && while read -r id <&4 && { [ -n "${id}" ] || continue; } &&
        case "${Aseen}" in
            *"|:_//_:|${id}|:_//_:|"*) continue ;;
            *) Aseen="${Aseen}|:_//_:|${id}|:_//_:|" ;;
        esac; do
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
        UTILS_FOLDER="${UTILS_FOLDER:-${PWD}}" && SOURCE_UTILS=". '${UTILS_FOLDER}/common-utils.sh' && . '${UTILS_FOLDER}/download-utils.sh' && . '${UTILS_FOLDER}/drive-utils.sh'"
        eval "${SOURCE_UTILS}" || { printf "Error: Unable to source util files.\n" && exit 1; }
    else
        SOURCE_UTILS="SOURCED_GDL=true . \"$({ cd "${0%\/*}" 2>| /dev/null || :; } && pwd)/${0##*\/}\"" && eval "${SOURCE_UTILS}"
    fi

    set -o errexit -o noclobber

    TMPFILE="$(command -v mktemp 1>| /dev/null && mktemp -u)" || TMPFILE="$(pwd)/.$(_t="$(date +"%s")" && printf "%s\n" "$((_t * _t))").tmpfile"

    _setup_arguments "${@}"
    "${SKIP_INTERNET_CHECK:-_check_internet}"

    _cleanup() {
        # unhide the cursor if hidden
        [ -n "${SUPPORT_ANSI_ESCAPES}" ] && printf "\e[?25h"
        {
            [ -n "${OAUTH_ENABLED}" ] && {
                # update the config with latest ACCESS_TOKEN and ACCESS_TOKEN_EXPIRY only if changed
                [ -f "${TMPFILE}_ACCESS_TOKEN" ] && {
                    . "${TMPFILE}_ACCESS_TOKEN"
                    [ "${INITIAL_ACCESS_TOKEN}" = "${ACCESS_TOKEN}" ] || {
                        _update_config ACCESS_TOKEN "${ACCESS_TOKEN}" "${CONFIG}"
                        _update_config ACCESS_TOKEN_EXPIRY "${ACCESS_TOKEN_EXPIRY}" "${CONFIG}"
                    }
                } 1>| /dev/null

                # grab all chidren processes of access token service
                # https://askubuntu.com/a/512872
                [ -n "${ACCESS_TOKEN_SERVICE_PID}" ] && {
                    token_service_pids="$(ps --ppid="${ACCESS_TOKEN_SERVICE_PID}" -o pid=)"
                    # first kill parent id, then children processes
                    kill "${ACCESS_TOKEN_SERVICE_PID}"
                } 1>| /dev/null
            }

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
                _auto_update
            fi
        } 2>| /dev/null || :
        return 0
    }

    trap 'abnormal_exit="1" ; exit' INT TERM
    trap '_cleanup' EXIT

    export MAIN_PID="$$"

    if [ -n "${OAUTH_ENABLED}" ]; then
        "${EXTRA_LOG}" "justify" "Checking credentials.." "-"
        { _check_credentials && for _ in 1 2; do _clear_line 1; done; } ||
            { "${QUIET:-_print_center}" "normal" "[ Error: Credentials checking failed ]" "=" && exit 1; }
        _print_center "justify" "Required credentials available." "="

        export API_REQUEST_FUNCTION="_api_request_oauth" OAUTH_ENABLED="true"
    else
        export API_REQUEST_FUNCTION="_api_request"
    fi

    START="$(date +'%s')"

    # hide the cursor if ansi escapes are supported
    [ -n "${SUPPORT_ANSI_ESCAPES}" ] && printf "\033[?25l"

    _process_arguments

    END="$(date +'%s')"
    DIFF="$((END - START))"
    "${QUIET:-_print_center}" "normal" " Time Elapsed: ""$((DIFF / 60))"" minute(s) and ""$((DIFF % 60))"" seconds. " "="
}

{ [ -z "${SOURCED_GDL}" ] && main "${@}"; } || :
