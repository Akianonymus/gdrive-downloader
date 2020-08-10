#!/usr/bin/env sh

###################################################
# Download a gdrive file
# Todo: write doc
###################################################
_download_file() {
    [ $# -lt 3 ] && printf "Missing arguments\n" && return 1
    file_id_download_file="${1}" name_download_file="${2}" server_size_download_file="${3}" parallel_download_file="${4}"
    unset status_download_file old_status_download_file left_download_file downloaded_download_file
    server_size_readable_download_file="$(_bytes_to_human "${server_size_download_file}")"
    _print_center "justify" "${name_download_file}" " | ${server_size_download_file:+${server_size_readable_download_file}}" "="

    # URL="${API_URL}/drive/${API_VERSION}/files/${file_id_download_file}?alt=media&key=${API_KEY}" ( downloading with api )

    if [ -s "${name_download_file}" ]; then
        local_size_download_file="$(wc -c < "${name_download_file}")"

        if [ "${local_size_download_file}" -ge "${server_size_download_file}" ]; then
            "${QUIET:-_print_center}" "justify" "File already present" "=" && _newline "\n"
            _log_in_file
            return 0
        else
            _print_center "justify" "File is partially" " present, resuming.." "-"
            CONTINUE=" -C - "
        fi
    else
        _print_center "justify" "Downloading file.." "-"
    fi
    "${EXTRA_LOG}" "justify" "Fetching" " cookies.." "-"
    # shellcheck disable=SC2086
    curl -c "${TMPFILE}"COOKIE -I ${CURL_PROGRESS} -o /dev/null "https://drive.google.com/uc?export=download&id=${file_id_download_file}" || :
    for _ in 1 2; do _clear_line 1; done
    confirm_string="$(_tmp="$(grep -F 'download_warning' "${TMPFILE}"COOKIE)" && printf "%s\n" "${_tmp##*$(printf '\t')}")" || :
    # shellcheck disable=SC2086
    curl -L -s ${CONTINUE} ${CURL_SPEED} -b "${TMPFILE}"COOKIE -o "${name_download_file}" \
        "https://drive.google.com/uc?export=download&id=${file_id_download_file}${confirm_string:+&confirm=${confirm_string}}" 2>| /dev/null 1>&2 &
    pid="${!}"

    if [ -n "${parallel_download_file}" ]; then
        wait "${pid}" 2>| /dev/null 1>&2
    else
        until [ -f "${name_download_file}" ] && [ -n "${pid}" ]; do sleep 0.5; done

        until ! kill -0 "${pid}" 2>| /dev/null 1>&2; do
            downloaded_download_file="$(wc -c < "${name_download_file}")"
            status_download_file="$(_bytes_to_human "${downloaded_download_file}")"
            left_download_file="$(_bytes_to_human "$((server_size_download_file - downloaded_download_file))")"
            sleep 0.5
            if [ "${status_download_file}" != "${old_status_download_file}" ]; then
                printf '%s\r' "$(_print_center "justify" "Downloaded: ${status_download_file}" " | Left: ${left_download_file}" "=")"
            fi
            old_status_download_file="${status_download_file}"
        done
        _newline "\n"
    fi

    if [ "$(wc -c < "${name_download_file}")" -ge "${server_size_download_file}" ]; then
        for _ in 1 2; do _clear_line 1; done
        "${QUIET:-_print_center}" "justify" "Downloaded" "=" && _newline "\n"
    else
        "${QUIET:-_print_center}" "justify" "Error: Incomplete" " download." "=" 1>&2
        return 1
    fi
    _log_in_file "${name_download_file}" "${server_size_readable_download_file}" "${file_id_download_file}"
    return 0
}

###################################################
# A extra wrapper for _download_file function to properly handle retries
# also handle uploads in case downloading from folder
# Todo: write doc
###################################################
_download_file_main() {
    [ $# -lt 2 ] && printf "Missing arguments\n" && return 1
    unset line_download_file_main fileid_download_file_main name_download_file_main size_download_file_main parallel_download_file_main RETURN_STATUS && retry_download_file_main="${RETRY:-0}"
    [ "${1}" = parse ] && parallel_download_file_main="${3}" line_download_file_main="${2}" fileid_download_file_main="${line_download_file_main%%"|:_//_:|"*}" \
        name_download_file_main="${line_download_file_main##*"|:_//_:|"}" size_download_file_main="$(_tmp="${line_download_file_main#*"|:_//_:|"}" && printf "%s\n" "${_tmp%"|:_//_:|"*}")"
    parallel_download_file_main="${parallel_download_file_main:-${5}}"

    unset RETURN_STATUS && until [ "${retry_download_file_main}" -le 0 ] && [ -n "${RETURN_STATUS}" ]; do
        if [ -n "${parallel_download_file_main}" ]; then
            _download_file "${fileid_download_file_main:-${2}}" "${name_download_file_main:-${3}}" "${size_download_file_main:-${4}}" true 2>| /dev/null 1>&2 && RETURN_STATUS=1 && break
        else
            _download_file "${fileid_download_file_main:-${2}}" "${name_download_file_main:-${3}}" "${size_download_file_main:-${4}}" && RETURN_STATUS=1 && break
        fi
        RETURN_STATUS=2 retry_download_file_main="$((retry_download_file_main - 1))" && continue
    done
    { [ "${RETURN_STATUS}" = 1 ] && printf "%b" "${parallel_download_file_main:+${RETURN_STATUS}\n}"; } || printf "%b" "${parallel_download_file_main:+${RETURN_STATUS}\n}" 1>&2
    return 0
}

###################################################
# Download a gdrive folder along with sub folders
# File IDs are fetched inside the folder, and then downloaded seperately.
# Todo: write doc
###################################################
_download_folder() {
    [ $# = 0 ] && printf "Missing arguments\n" && return 1
    folder_id_download_folder="${1}" name_download_folder="${2}" parallel_download_folder="${3}"
    unset info_download_folder error_status_download_folder success_status_download_folder \
        files_download_folder folders_download_folder files_size_download_folder files_name_download_folder folders_name_download_folder \
        num_of_files_download_folder num_of_folders_download_folder
    _newline "\n"
    "${EXTRA_LOG}" "justify" "${name_download_folder}" "="
    "${EXTRA_LOG}" "justify" "Fetching folder" " details.." "-"
    if ! info_download_folder="$(_fetch "${API_URL}/drive/${API_VERSION}/files?q=%27${folder_id_download_folder}%27+in+parents&fields=files(name,size,id,mimeType)&key=${API_KEY}")"; then
        "${QUIET:-_print_center}" "justify" "Error: Cannot" ", fetch folder details." "="
        printf "%s\n" "${info_download_folder}" && return 1
    fi && _clear_line 1

    # parse the fetched json and make a list containing files size, name and id
    "${EXTRA_LOG}" "justify" "Preparing files list.." "="
    files_download_folder="$(printf "%s\n" "${info_download_folder}" | grep '"size":' -B3 | _json_value id all all)" || :
    files_size_download_folder="$(printf "%s\n" "${info_download_folder}" | _json_value size all all)" || :
    files_name_download_folder="$(printf "%s\n" "${info_download_folder}" | grep size -B2 | _json_value name all all)" || :
    exec 5<< EOF
$(printf "%s\n" "${files_download_folder}")
EOF
    exec 6<< EOF
$(printf "%s\n" "${files_size_download_folder}")
EOF
    exec 7<< EOF
$(printf "%s\n" "${files_name_download_folder}")
EOF
    files_list_download_folder="$(while read -r id <&5 && read -r size <&6 && read -r name <&7; do
        printf "%s\n" "${id}|:_//_:|${size}|:_//_:|${name}"
    done)"
    exec 5<&- && exec 6<&- && exec 7<&-
    _clear_line 1

    # parse the fetched json and make a list containing sub folders name and id
    "${EXTRA_LOG}" "justify" "Preparing sub folders list.." "="
    folders_download_folder="$(printf "%s\n" "${info_download_folder}" | grep '"mimeType":.*folder.*' -B2 | _json_value id all all)" || :
    folders_name_download_folder="$(printf "%s\n" "${info_download_folder}" | grep '"mimeType":.*folder.*' -B1 | _json_value name all all)" || :
    exec 5<< EOF
$(printf "%s\n" "${folders_download_folder}")
EOF
    exec 6<< EOF
$(printf "%s\n" "${folders_name_download_folder}")
EOF
    folders_list_download_folder="$(while read -r id <&5 && read -r name <&6; do
        printf "%s\n" "${id}|:_//_:|${name}"
    done)"
    exec 5<&- && exec 6<&-
    _clear_line 1

    if [ -z "${files_download_folder:-${folders_download_folder}}" ]; then
        for _ in 1 2; do _clear_line 1; done && _print_center "justify" "${name_download_folder}" " | Empty Folder" "=" && _newline "\n" && return 0
    fi
    [ -n "${files_download_folder}" ] && num_of_files_download_folder="$(($(printf "%s\n" "${files_download_folder}" | wc -l)))"
    [ -n "${folders_download_folder}" ] && num_of_folders_download_folder="$(($(printf "%s\n" "${folders_download_folder}" | wc -l)))"

    for _ in 1 2; do _clear_line 1; done
    _print_center "justify" \
        "${name_download_folder}" \
        "${num_of_files_download_folder:+ | ${num_of_files_download_folder} files}${num_of_folders_download_folder:+ | ${num_of_folders_download_folder} sub folders}" "=" &&
        _newline "\n\n"

    if [ -f "${name_download_folder}" ]; then
        name_download_folder="${name_download_folder}$(date +'%s')"
    fi && mkdir -p "${name_download_folder}"

    cd "${name_download_folder}" || exit 1

    if [ -n "${num_of_files_download_folder}" ]; then
        if [ -n "${parallel_download_folder}" ]; then
            NO_OF_PARALLEL_JOBS_FINAL="$((NO_OF_PARALLEL_JOBS > num_of_files_download_folder ? num_of_files_download_folder : NO_OF_PARALLEL_JOBS))"

            [ -f "${TMPFILE}"SUCCESS ] && rm "${TMPFILE}"SUCCESS
            [ -f "${TMPFILE}"ERROR ] && rm "${TMPFILE}"ERROR

            # shellcheck disable=SC2016
            (printf "%s\n" "${files_download_folder}" | xargs -n1 -P"${NO_OF_PARALLEL_JOBS_FINAL}" -i sh -c '
                eval "${SOURCE_UTILS}"
                _download_file_main parse "{}" true
                ' 1>| "${TMPFILE}"SUCCESS 2>| "${TMPFILE}"ERROR) &
            pid="${!}"

            until [ -f "${TMPFILE}"SUCCESS ] || [ -f "${TMPFILE}"ERROR ]; do sleep 0.5; done

            _clear_line 1
            until ! kill -0 "${pid}" 2>| /dev/null 1>&2; do
                success_status_download_folder="$(($(wc -l < "${TMPFILE}"SUCCESS)))"
                error_status_download_folder="$(($(wc -l < "${TMPFILE}"ERROR)))"
                sleep 1
                if [ "$((success_status_download_folder + error_status_download_folder))" != "${TOTAL}" ]; then
                    printf '%s\r' "$(_print_center "justify" "Status" ": ${success_status_download_folder:-0} Downloaded | ${error_status_download_folder:-0} Failed" "=")"
                fi
                TOTAL="$((success_status_download_folder + error_status_download_folder))"
            done
            _newline "\n"
            success_status_download_folder="$(($(wc -l < "${TMPFILE}"SUCCESS)))"
            error_status_download_folder="$(($(wc -l < "${TMPFILE}"ERROR)))"
            _clear_line 1 && _newline "\n"
        else
            while read -r line <&4 && { [ -n "${line}" ] || continue; }; do
                _download_file_main parse "${line}"
                : "$((RETURN_STATUS < 2 ? (success_status_download_folder += 1) : (error_status_download_folder += 1)))"
                if [ -z "${VERBOSE}" ]; then
                    for _ in 1 2 3 4; do _clear_line 1; done
                fi
                _print_center "justify" "Status" ": ${success_status_download_folder:-0} Downloaded | ${error_status_download_folder:-0} Failed" "="
            done 4<< EOF
$(printf "%s\n" "${files_list_download_folder}")
EOF
        fi
    fi

    for _ in 1 2; do _clear_line 1; done
    [ "${success_status_download_folder}" -gt 0 ] && "${QUIET:-_print_center}" "justify" "Downloaded" ": ${success_status_download_folder}" "="
    [ "${error_status_download_folder:-0}" -gt 0 ] && "${QUIET:-_print_center}" "justify" "Failed" ": ${error_status_download_folder}" "="
    _newline "\n"

    if [ -z "${SKIP_SUBDIRS}" ] && [ -n "${num_of_folders_download_folder}" ]; then
        while read -r line <&4 && { [ -n "${line}" ] || continue; }; do
            (_download_folder "${line%%"|:_//_:|"*}" "${line##*"|:_//_:|"}" "${parallel:-}")
        done 4<< EOF
$(printf "%s\n" "${folders_list_download_folder}")
EOF
    fi
    return 0
}

###################################################
# Log downloaded file info in case of -l / --log flag
# Todo: write doc
###################################################
_log_in_file() {
    [ -z "${LOG_FILE_ID}" ] || [ -d "${LOG_FILE_ID}" ] && return 0
    # shellcheck disable=SC2129
    # https://github.com/koalaman/shellcheck/issues/1202#issuecomment-608239163
    {
        printf "%s\n" "Name: ${1}"
        printf "%s\n" "Size: ${2}"
        printf "%s\n\n" "ID: ${3}"
    } >> "${LOG_FILE_ID}"
}
