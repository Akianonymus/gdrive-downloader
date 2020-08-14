#!/usr/bin/env sh
# Download file/folder from google drive.
# shellcheck source=/dev/null

_usage() {
    printf "%b" "
The script can be used to download file/directory from google drive.\n
Usage:\n ${0##*/} [options.. ] <file_[url|id]> or <folder[url|id]>\n
Options:\n
  -d | --directory 'foldername' - option to _download given input in custom directory.\n
  -s | --skip-subdirs - Skip downloading of sub folders present in case of folders.\n
  -p | --parallel 'no_of_files_to_parallely_upload' - Download multiple files in parallel.\n
  --speed 'speed' - Limit the download speed, supported formats: 1K, 1M and 1G.\n
  -R | --retry 'num of retries' - Retry the file upload if it fails, postive integer as argument. Currently only for file uploads.\n
  -l | --log 'file_to_save_info' - Save downloaded files info to the given filename.\n
  -q | --quiet - Supress the normal output, only show success/error upload messages for files, and one extra line at the beginning for folder showing no. of files and sub folders.\n
  -V | --verbose - Display detailed message (only for non-parallel uploads).\n
  --skip-internet-check - Do not check for internet connection, recommended to use in sync jobs.\n
  -u | --update - Update the installed script in your system.\n
  --info - Show detailed info, only if script is installed system wide.\n
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
    (
        command -v "${COMMAND_NAME}" 1> /dev/null &&
            [ -n "${REPO:+${COMMAND_NAME:+${INSTALL_PATH:+${TYPE:+${TYPE_VALUE}}}}}" ] &&
            [ "$((LAST_UPDATE_TIME + AUTO_UPDATE_INTERVAL))" -lt "$(date +'%s')" ] &&
            _update 2>| /dev/null 1>&2
    ) 2>| /dev/null 1>&2 &
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
    repo_update="${REPO:-labbots/gdrive-downloader}" type_value_update="${TYPE_VALUE:-master}"
    if script_update="$(curl --compressed -Ls "https://raw.githubusercontent.com/${repo_update}/${type_value_update}/install.sh")"; then
        _clear_line 1
        printf "%s\n" "${script_update}" | sh -s -- ${job_string_update:-} --skip-internet-check
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
_info() {
    if command -v "${COMMAND_NAME}" 1> /dev/null && [ -n "${REPO:+${COMMAND_NAME:+${INSTALL_PATH:+${TYPE:+${TYPE_VALUE}}}}}" ]; then
        for i in REPO INSTALL_PATH INSTALLATION TYPE TYPE_VALUE LATEST_INSTALLED_SHA; do
            printf "%s\n" "${i}=\"$(eval printf "%s" \"\$"${i}"\")\""
        done
    else
        printf "%s\n" "gdrive-downloader is not installed system wide."
    fi
    exit 0
}

###################################################
# Check if the file ID exists and determine it's type [ folder | Files ].
# Todo: write doc
###################################################
_check_id() {
    [ $# = 0 ] && printf "Missing arguments\n" && return 1
    "${EXTRA_LOG}" "justify" "Validating URL/ID.." "-"
    id_check_id="${1}" json_check_id=""
    if json_check_id="$(_fetch "${API_URL}/drive/${API_VERSION}/files/${id_check_id}?alt=json&fields=name,size,mimeType&key=${API_KEY}")"; then
        if ! printf "%s\n" "${json_check_id}" | _json_value code 1 1 2>| /dev/null 1>&2; then
            NAME="$(printf "%s\n" "${json_check_id}" | _json_value name 1 1 || :)"
            mime_check_id="$(printf "%s\n" "${json_check_id}" | _json_value mimeType 1 1 || :)"
            _clear_line 1
            case "${mime_check_id}" in
                *folder*)
                    FOLDER_ID="${id}"
                    _print_center "justify" "Folder Detected" "=" && _newline "\n"
                    ;;
                *)
                    SIZE="$(printf "%s\n" "${json_check_id}" | _json_value size 1 1 || :)"
                    FILE_ID="${id}"
                    _print_center "justify" "File Detected" "=" && _newline "\n"
                    ;;
            esac
        else
            _clear_line 1 && "${QUIET:-_print_center}" "justify" "Invalid URL/ID" "=" && _newline "\n"
            return 1
        fi
    else
        _clear_line 1
        "${QUIET:-_print_center}" "justify" "Error: Cannot check URL/ID" "="
        printf "%s\n" "${json_check_id}"
        return 1
    fi
    return 0
}

##################################################
# Process all arguments given to the script
###################################################
_setup_arguments() {
    [ $# = 0 ] && printf "Missing arguments\n" && return 1
    # Internal variables
    # De-initialize if any variables set already.
    unset LOG_FILE_ID FOLDERNAME SKIP_SUBDIRS NO_OF_PARALLEL_JOBS PARALLEL_DOWNLOAD
    unset DEBUG QUIET VERBOSE VERBOSE_PROGRESS SKIP_INTERNET_CHECK RETRY
    unset ID_INPUT_ARRAY FINAL_INPUT_ARRAY
    CURL_PROGRESS="-s" EXTRA_LOG=":"

    # API
    API_KEY="AIzaSyD2dHsZJ9b4OXuy5B_owiL8W18NaNOM8tk"
    API_URL="https://www.googleapis.com"
    API_VERSION="v3"

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
            --info) _info ;;
            -l | --log)
                _check_longoptions "${1}" "${2}"
                LOG_FILE_ID="${2}" && shift
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
                regex='^([0-9]+)([k,K]|[m,M]|[g,G])+$'
                if printf "%s\n" "${2}" | grep -qE "${regex}"; then
                    CURL_SPEED="--limit-rate ${2}" && shift
                else
                    printf "Error: Wrong speed limit format, supported formats: 1K , 1M and 1G\n" 1>&2
                    exit 1
                fi
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
            -q | --quiet) QUIET="_print_center_quiet" ;;
            -V | --verbose)
                VERBOSE="true"
                ;;
            --skip-internet-check)
                SKIP_INTERNET_CHECK=":"
                ;;
            *)
                # Check if user meant it to be a flag
                if [ -z "${1##-*}" ]; then
                    printf '%s: %s: Unknown option\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" && exit 1
                else
                    ID_INPUT_ARRAY="${ID_INPUT_ARRAY}
                                    $(_extract_id "${1}")"
                fi
                ;;
        esac
        shift
    done

    # If no input
    [ -z "${ID_INPUT_ARRAY}" ] && _short_help

    _check_debug

    return 0
}

###################################################
# Process all the values in "${ID_INPUT_ARRAY}"
###################################################
_process_arguments() {
    export LOG_FILE_ID VERBOSE API_KEY API_URL API_VERSION \
        FOLDERNAME SKIP_SUBDIRS NO_OF_PARALLEL_JOBS PARALLEL_DOWNLOAD SKIP_INTERNET_CHECK \
        COLUMNS CURL_SPEED TMPFILE CURL_PROGRESS EXTRA_LOG RETRY QUIET SOURCE_UTILS

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
        UTILS_FOLDER="${UTILS_FOLDER:-${PWD}}" && SOURCE_UTILS=". '${UTILS_FOLDER}/common-utils.sh' && . '${UTILS_FOLDER}/download-utils.sh'"
        eval "${SOURCE_UTILS}" || { printf "Error: Unable to source util files.\n" && exit 1; }
    else
        SOURCE_UTILS="SOURCED=true . \"$(cd "${0%\/*}" && pwd)/${0##*\/}\"" && eval "${SOURCE_UTILS}"
    fi

    set -o errexit -o noclobber

    TMPFILE="$(command -v mktemp 1>| /dev/null && mktemp -u)" || TMPFILE="$(pwd)/$(date +'%s').tmpfile"
    export TMPFILE

    _setup_arguments "${@}"
    "${SKIP_INTERNET_CHECK:-_check_internet}"

    _cleanup() {
        {
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

    START="$(date +'%s')"

    _process_arguments

    END="$(date +'%s')"
    DIFF="$((END - START))"
    "${QUIET:-_print_center}" "normal" " Time Elapsed: ""$((DIFF / 60))"" minute(s) and ""$((DIFF % 60))"" seconds. " "="
}

{ [ -z "${SOURCED}" ] && main "${@}"; } || :
