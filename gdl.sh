#!/usr/bin/env bash
# Download file/folder from google drive.

_usage() {
    printf "
The script can be used to _download file/directory from google drive.\n
Usage:\n %s [options.. ] <file_[url|id]> or <folder[url|id]>\n
Options:\n
  -d | --directory 'foldername' - option to _download given input in custom directory.\n
  -s | --skip-subdirs - Skip downloading of sub folders present in case of folders.\n
  -p | --parallel 'no_of_files_to_parallely_upload' - Download multiple files in parallel, Max value = 10.\n
  -l | --log 'file_to_save_info' - Save downloaded files info to the given filename.\n
  -v | --verbose - Display detailed message (only for non-parallel uploads).\n
  --skip-internet-check - Do not check for internet connection, recommended to use in sync jobs.\n
  -u | --update - Update the installed script in your system.\n
  -V | --version - Show detailed info, only if script is installed system wide.\n
  --uninstall - Uninstall script, remove related files.\n
  -D | --debug - Display script command trace.\n
  -h | --help - Display usage instructions.\n\n" "${0##*/}"
    exit 0
}

_short_help() {
    printf "No valid arguments provided, use -h/--help flag to see usage.\n"
    exit 0
}

###################################################
# Install/Update/uninstall the script.
###################################################
_update() {
    declare job="${1:-update}"
    [[ ${job} =~ uninstall ]] && job_string="--uninstall"
    _print_center "justify" "Fetching ${job} script.." "-"
    # shellcheck source=/dev/null
    if [[ -f "${HOME}/.gdrive-downloader/gdrive-downloader.info" ]]; then
        source "${HOME}/.gdrive-downloader/gdrive-downloader.info"
    fi
    declare repo="${REPO:-Akianonymus/gdrive-downloader}" type_value="${TYPE_VALUE:-master}"
    if script="$(curl --compressed -Ls "https://raw.githubusercontent.com/${repo}/${type_value}/install.sh")"; then
        _clear_line 1
        bash <(printf "%s\n" "${script}") ${job_string:-} --skip-internet-check
    else
        _print_center "justify" "Error: Cannot download ${job} script." "=" 1>&2
        exit 1
    fi
    exit "${?}"
}

###################################################
# Print the contents of info file if scipt is installed system wide.
# Path is "${HOME}/.gdrive-downloader/gdrive-downloader.info"
###################################################
_version_info() {
    if [[ -r "${HOME}/.gdrive-downloader/gdrive-downloader.info" ]]; then
        printf "%s\n" "$(< "${HOME}/.gdrive-downloader/gdrive-downloader.info")"
    else
        _print_center "justify" "gdrive-downloader is not installed system wide." "="
    fi
    exit 0
}

###################################################
# Default curl command use everywhere.
###################################################
_fetch() {
    curl -e "https://drive.google.com" -s --compressed "${@}" || return 1
}

###################################################
# Check if the file ID exists and determine it's type [ folder | Files ].
# otherwise exit the script.
###################################################
_check_id() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    _print_center "justify" "Validating URL/ID.." "-"
    declare id="${1}" code
    if JSON="$(_fetch "${API_URL}/drive/${API_VERSION}/files/${id}?alt=json&fields=name,size,mimeType&key=${API_KEY}")"; then
        mime="$(_json_value mimeType 1 1 <<< "${JSON}")"
        code="$(_json_value code 1 1 <<< "${JSON}")"
        if [[ -z ${code} ]]; then
            for _ in {1..2}; do _clear_line 1; done
            if [[ ${mime} =~ folder ]]; then
                FOLDER_ID="${id}"
                _print_center "justify" "Folder Detected" "=" && _newline "\n"
            else
                FILE_ID="${id}"
                _print_center "justify" "File Detected" "=" && _newline "\n"
            fi
        else
            for _ in {1..2}; do _clear_line 1; done && _newline "\n" && _print_center "justify" "Invalid URL/ID" "=" && _newline "\n"
            return 1
        fi
    else
        _clear_line 1
        _print_center "justify" "Error: Cannot check URL/ID" "="
        printf "%s\n" "${JSON}"
        exit 1
    fi
    export JSON
}

###################################################
# Download a gdrive file
###################################################
_download_file() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare file_id="${1}" parallel="${2}"
    declare name server_size error_status success_status
    name="$(_json_value name 1 1 <<< "${JSON}")"
    if [[ -n ${name} ]]; then
        server_size="$(_json_value size <<< "${JSON}")" || :
        server_size_readable="$(_bytes_to_human "${server_size}")"
        [[ -z ${parallel} ]] && _print_center "justify" "${name}" " | ${server_size:+${server_size_readable}}" "="

        # URL="${API_URL}/drive/${API_VERSION}/files/${file_id}?alt=media&key=${API_KEY}" ( downloading with api )

        _log_in_file() {
            if [[ -n ${LOG_FILE_ID} && ! -d ${LOG_FILE_ID} ]]; then
                # shellcheck disable=SC2129
                # https://github.com/koalaman/shellcheck/issues/1202#issuecomment-608239163
                {
                    printf "%s\n" "Name: ${name}"
                    printf "%s\n" "Size: ${server_size_readable}"
                    printf "%s\n\n" "ID: ${file_id}"
                } >> "${LOG_FILE_ID}"
            fi
        }

        if [[ -s ${name} ]]; then
            declare local_size && local_size="$(wc -c < "${name}")"

            if [[ ${local_size} -ge "${server_size}" ]]; then
                _print_center "justify" "File already present" "=" && [[ -z ${parallel} ]] && _newline "\n"
                _log_in_file
                return
            else
                [[ -z ${parallel} ]] && _print_center "justify" "File is partially" " present, resuming.." "-"
                CONTINUE=" -C - "
            fi
        else
            [[ -z ${parallel} ]] && _print_center "justify" "Downloading file.." "-"
        fi
        [[ -z ${parallel} ]] && _print_center "justify" "Fetching" " cookies.." "-"
        curl -c "${TMPFILE}"COOKIE -I -s -o /dev/null "https://drive.google.com/uc?export=download&id=${file_id}" || :
        [[ -z ${parallel} ]] && _clear_line 1
        confirm_string="$(: "$(_tail 2 < "${TMPFILE}"COOKIE | _head 1)" && : "${_//$'\t'/$'\n'}" && _tail 1 <<< "${_}")" || :
        # shellcheck disable=SC2086 # Unnecessary to another check because ${CONTINUE} won't be anything problematic.
        curl -L -s ${CONTINUE} -b "${TMPFILE}"COOKIE -o "${name}" "https://drive.google.com/uc?export=download&id=${file_id}${confirm_string:+&confirm=${confirm_string}}" &> /dev/null &
        pid="${!}" && printf "%s\n" "${pid}" >| "${TMPFILE}pid${pid}"

        if [[ -n ${parallel} ]]; then
            wait "${pid}" &> /dev/null
        else
            until [[ -f ${name} && -n ${pid} ]]; do _bash_sleep 0.5; done

            until [[ -z $(jobs -pr) ]]; do
                downloaded="$(wc -c < "${name}")"
                STATUS="$(_bytes_to_human "${downloaded}")"
                LEFT="$(_bytes_to_human "$((server_size - downloaded))")"
                _bash_sleep 0.5
                if [[ ${STATUS} != "${OLD_STATUS}" ]]; then
                    printf '%s\r' "$(_print_center "justify" "Downloaded: ${STATUS}" " | Left: ${LEFT}" "=")"
                fi
                OLD_STATUS="${STATUS}"
            done
            _newline "\n"
        fi

        if [[ $(wc -c < "${name}") -ge "${server_size}" ]]; then
            [[ -z ${parallel} ]] && for _ in {1..2}; do _clear_line 1; done
            _print_center "justify" "Downloaded" "=" && [[ -z ${parallel} ]] && _newline "\n"
        else
            _print_center "justify" "Error: Incomplete" " download." "=" 1>&2
            DOWNLOAD_STATUS="ERROR" && export DOWNLOAD_STATUS # Send a error status, used in folder downloads.
            return 1
        fi
        _log_in_file
        return
    else
        _print_center "justify" "Failed some" ", unknown error." "=" 1>&2
        DOWNLOAD_STATUS="ERROR" && export DOWNLOAD_STATUS # Send a error status, used in folder downloads.
        [[ -z ${parallel} ]] && printf "%s\n" "${info}"
        return 1
    fi
}

###################################################
# Download a gdrive folder along with sub folders
# File IDs are fetched inside the folder, and then downloaded seperately.
###################################################
_download_folder() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare folder_id="${1}" parallel="${2}"
    declare info name files=() folders=() error_status success_status num_of_files num_of_folders
    name="$(_json_value name 1 1 <<< "${JSON}")"
    if [[ -n ${name} ]]; then
        _newline "\n"
        _print_center "justify" "${name}" "="
        _print_center "justify" "Fetching folder" " details.." "-"
        if ! info="$(_fetch "${API_URL}/drive/${API_VERSION}/files?q=%27${folder_id}%27+in+parents&fields=files(id,mimeType)&key=${API_KEY}")"; then
            _print_center "justify" "Error: Cannot" ", fetch folder details." "="
            printf "%s\n" "${info}" && return 1
        fi

        mapfile -t files <<< "$(_json_value id all all <<< "$(grep -v folder <<< "${info}" | grep mimeType -B1)")" || :
        mapfile -t folders <<< "$(_json_value id all all <<< "$(grep folder -B1 <<< "${info}")")" || :

        if [[ -z ${files[*]:-${folders[*]}} ]]; then
            for _ in {1..3}; do _clear_line 1; done && _print_center "justify" "${name}" " | Empty Folder" "=" && _newline "\n" && return 0
        fi
        [[ -n ${files[*]} ]] && num_of_files="${#files[@]}"
        [[ -n ${folders[*]} ]] && num_of_folders="${#folders[@]}"

        for _ in {1..3}; do _clear_line 1; done
        _print_center "justify" "${name}" "${num_of_files:+ | ${num_of_files} files}${num_of_folders:+ | ${num_of_folders} sub folders}" "=" && _newline "\n\n"

        if [[ -f ${name} ]]; then
            name="${name}${RANDOM}"
            mkdir -p "${name}"
        else
            mkdir -p "${name}"
        fi

        cd "${name}" || exit 1

        if [[ -n "${num_of_files}" ]]; then
            if [[ -n ${parallel} ]]; then
                if [[ ${NO_OF_PARALLEL_JOBS} -gt ${num_of_files} ]]; then
                    NO_OF_PARALLEL_JOBS_FINAL="${num_of_files}"
                else
                    NO_OF_PARALLEL_JOBS_FINAL="${NO_OF_PARALLEL_JOBS}"
                fi

                [[ -f "${TMPFILE}"SUCCESS ]] && rm "${TMPFILE}"SUCCESS
                [[ -f "${TMPFILE}"ERROR ]] && rm "${TMPFILE}"ERROR

                export TMPFILE
                # shellcheck disable=SC2016
                printf "\"%s\"\n" "${files[@]}" | xargs -n1 -P"${NO_OF_PARALLEL_JOBS_FINAL}" -i bash -c '
                printf "%s\n" "$$" >| "${TMPFILE}"pid"$$"
                id="{}"
                if JSON="$(_fetch "${API_URL}/drive/${API_VERSION}/files/${id}?alt=json&fields=name,size&key=${API_KEY}")"; then
                    _download_file "${id}" true
                else
                    printf "1\n" 1>&2
                fi
                ' 1>| "${TMPFILE}"SUCCESS 2>| "${TMPFILE}"ERROR &

                until [[ -f "${TMPFILE}"SUCCESS || -f "${TMPFILE}"ERROR ]]; do _bash_sleep 0.5; done

                _clear_line 1
                until [[ -z $(jobs -p) ]]; do
                    success_status="$(_count < "${TMPFILE}"SUCCESS)"
                    error_status="$(_count < "${TMPFILE}"ERROR)"
                    _bash_sleep 1
                    if [[ $(((success_status + error_status))) != "${TOTAL}" ]]; then
                        printf '%s\r' "$(_print_center "justify" "Status" ": ${success_status:-0} Downloaded | ${error_status:-0} Failed" "=")"
                    fi
                    TOTAL="$(((success_status + error_status)))"
                done
                _newline "\n"
                success_status="$(_count < "${TMPFILE}"SUCCESS)"
                error_status="$(_count < "${TMPFILE}"ERROR)"
                _clear_line 1 && _newline "\n"
            else
                for file in "${files[@]}"; do
                    _print_center "justify" "Fetching file" " details.." "-"
                    if JSON="$(_fetch "${API_URL}/drive/${API_VERSION}/files/${file}?alt=json&fields=name,size&key=${API_KEY}")"; then
                        _clear_line 1
                        _download_file "${file}"
                    else
                        DOWNLOAD_STATUS="ERROR"
                        _clear_line 1
                        _print_center "justify" "Cannot fetch" "file details" "=" 1>&2
                        printf "%s\n" "${JSON}" 1>&2
                    fi
                    [[ ${DOWNLOAD_STATUS} = ERROR ]] && error_status="$((error_status + 1))" || success_status="$((success_status + 1))" || :
                    if [[ -z ${VERBOSE} ]]; then
                        for _ in {1..4}; do _clear_line 1; done
                    fi
                    _print_center "justify" "Status" ": ${success_status:-0} Downloaded | ${error_status:-0} Failed" "="
                done
            fi
        fi

        for _ in {1..2}; do _clear_line 1; done
        _newline "\n"
        [[ ${success_status} -gt 0 ]] && _print_center "justify" "Downloaded" ": ${success_status}" "="
        [[ ${error_status} -gt 0 ]] && _print_center "justify" "Failed" ": ${error_status}" "="
        _newline "\n"

        if [[ -z ${SKIP_SUBDIRS} && -n ${num_of_folders} ]]; then
            for folder in "${folders[@]}"; do
                _print_center "justify" "Fetching folder" " name.." "-"
                if JSON="$(_fetch "${API_URL}/drive/${API_VERSION}/files/${folder}?alt=json&fields=name&key=${API_KEY}")"; then
                    _clear_line 1
                    _download_folder "${folder}" "${parallel:-}"
                else
                    _clear_line 1
                    _print_center "justify" "Cannot fetch" "folder name" "=" 1>&2
                    printf "%s\n" "${JSON}" 1>&2
                fi
            done
        fi
    else
        _clear_line 1
        _print_center "justify" "Error: some" " unknown error." "="
        printf "%s\n" "${JSON}" && return 1
    fi
    return 0
}

##################################################
# Process all arguments given to the script
###################################################
_setup_arguments() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    # Internal variables
    # De-initialize if any variables set already.
    unset LOG_FILE_ID FOLDERNAME SKIP_SUBDIRS NO_OF_PARALLEL_JOBS PARALLEL_DOWNLOAD
    unset DEBUG QUIET VERBOSE VERBOSE_PROGRESS SKIP_INTERNET_CHECK
    unset ID_INPUT_ARRAY FINAL_INPUT_ARRAY
    INFO_PATH="${HOME}/.gdrive-downloader"

    # API
    API_KEY="AIzaSyD2dHsZJ9b4OXuy5B_owiL8W18NaNOM8tk"
    API_URL="https://www.googleapis.com"
    API_VERSION="v3"

    _check_longoptions() {
        [[ -z ${2} ]] &&
            printf '%s: %s: option requires an argument\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" &&
            exit 1
        return 0
    }

    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -h | --help)
                _usage
                ;;
            -D | --debug)
                DEBUG="true"
                ;;
            -u | --update)
                _check_debug && _update
                ;;
            --uninstall)
                _check_debug && _update uninstall
                ;;
            -V | --version)
                _version_info
                ;;
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
                NO_OF_PARALLEL_JOBS="${2}"
                case "${NO_OF_PARALLEL_JOBS}" in
                    '' | *[!0-9]*)
                        printf "\nError: -p/--parallel value can only be a positive integer.\n"
                        exit 1
                        ;;
                    *)
                        NO_OF_PARALLEL_JOBS="${2}"
                        ;;
                esac
                PARALLEL_DOWNLOAD="true" && shift
                ;;
            -v | --verbose)
                VERBOSE="true"
                ;;
            --skip-internet-check)
                SKIP_INTERNET_CHECK=":"
                ;;
            *)
                # Check if user meant it to be a flag
                if [[ ${1} = -* ]]; then
                    printf '%s: %s: Unknown option\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" && exit 1
                else
                    ID_INPUT_ARRAY+=("$(_extract_id "${1}")")
                fi
                ;;
        esac
        shift
    done

    # If no input
    [[ -z ${ID_INPUT_ARRAY[*]} ]] && _short_help

    # Remove duplicates
    mapfile -t FINAL_INPUT_ARRAY <<< "$(_remove_array_duplicates "${ID_INPUT_ARRAY[@]}")"

    _check_debug

    export DEBUG LOG_FILE_ID VERBOSE API_KEY API_URL API_VERSION
    export INFO_PATH FOLDERNAME SKIP_SUBDIRS NO_OF_PARALLEL_JOBS PARALLEL_DOWNLOAD SKIP_INTERNET_CHECK
    export -f _print_center _clear_line _newline _bash_sleep _tail _head _count _json_value _bytes_to_human
    export -f _fetch _check_id _download_file _download_folder

    return 0
}

###################################################
# Process all the values in "${FINAL_INPUT_ARRAY[@]}"
###################################################
_process_arguments() {
    ${FOLDERNAME:+mkdir -p ${FOLDERNAME}}
    cd "${FOLDERNAME:-.}" &> /dev/null || exit 1

    for id in "${FINAL_INPUT_ARRAY[@]}"; do
        _check_id "${id}" "${API_KEY}" || continue
        if [[ -n ${FOLDER_ID} ]]; then
            _download_folder "${FOLDER_ID}" "${PARALLEL_DOWNLOAD:-}"
        else
            _download_file "${FILE_ID}"
        fi
    done
    return 0
}

main() {
    [[ $# = 0 ]] && _short_help

    UTILS_FILE="${UTILS_FILE:-./utils.sh}"
    if [[ -r ${UTILS_FILE} ]]; then
        # shellcheck source=/dev/null
        source "${UTILS_FILE}" || { printf "Error: Unable to source utils file ( %s ) .\n" "${UTILS_FILE}" && exit 1; }
    else
        printf "Error: Utils file ( %s ) not found\n" "${UTILS_FILE}"
        exit 1
    fi

    _cleanup() {
        if ! [[ $(printf "%b\n" "${TMPFILE}"pid*) = "${TMPFILE}pid*" ]]; then
            for pid in "${TMPFILE}"pid*; do
                kill "$(< "${pid}")" &> /dev/null || :
            done
        fi
        rm -f "${TMPFILE}"* &> /dev/null || :
        if [[ -z "${intrap}" ]]; then
            { export intrap=1 && kill -- -$$ &> /dev/null; } || :
        fi
    }

    trap 'printf "\n" ; exit' SIGINT
    trap '_cleanup' SIGTERM EXIT

    _check_bash_version && set -o errexit -o noclobber -o pipefail

    _setup_arguments "${@}"

    "${SKIP_INTERNET_CHECK:-_check_internet}"

    _setup_tempfile

    _print_center "justify" "Starting script" "-"
    START="$(printf "%(%s)T\\n" "-1")"

    _process_arguments

    END="$(printf "%(%s)T\\n" "-1")"
    DIFF="$((END - START))"
    _print_center "normal" " Time Elapsed: ""$((DIFF / 60))"" minute(s) and ""$((DIFF % 60))"" seconds. " "="
}

main "${@}"
