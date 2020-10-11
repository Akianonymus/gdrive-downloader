#!/usr/bin/env bash

###################################################
# Download a gdrive file
# Todo: write doc
###################################################
_download_file() {
    [[ $# -lt 3 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare file_id="${1}" name="${2}" server_size="${3}" parallel="${4}"
    declare status old_status left downloaded
    server_size_readable="$(_bytes_to_human "${server_size}")"
    _print_center "justify" "${name}" " | ${server_size:+${server_size_readable}}" "="

    # URL="${API_URL}/drive/${API_VERSION}/files/${file_id}?alt=media&key=${API_KEY}" ( downloading with api )

    if [[ -s ${name} ]]; then
        declare local_size && local_size="$(wc -c < "${name}")"

        if [[ ${local_size} -ge "${server_size}" ]]; then
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
    curl -c "${TMPFILE}"COOKIE -I ${CURL_PROGRESS} -o /dev/null "https://drive.google.com/uc?export=download&id=${file_id}" || :
    for _ in 1 2; do _clear_line 1; done
    confirm_string="$(: "$(grep -F 'download_warning' "${TMPFILE}"COOKIE)" && printf "%s\n" "${_//*$'\t'/}")" || :
    # shellcheck disable=SC2086
    curl -L -s ${CONTINUE} ${CURL_SPEED} -b "${TMPFILE}"COOKIE -o "${name}" "https://drive.google.com/uc?export=download&id=${file_id}${confirm_string:+&confirm=${confirm_string}}" 2>| /dev/null 1>&2 &
    pid="${!}"

    if [[ -n ${parallel} ]]; then
        wait "${pid}" 2>| /dev/null 1>&2
    else
        until [[ -f ${name} && -n ${pid} ]]; do sleep 0.5; done

        until ! kill -0 "${pid}" 2>| /dev/null 1>&2; do
            downloaded="$(wc -c < "${name}")"
            status="$(_bytes_to_human "${downloaded}")"
            left="$(_bytes_to_human "$((server_size - downloaded))")"
            sleep 0.5
            if [[ ${status} != "${old_status}" ]]; then
                printf '%s\r' "$(_print_center "justify" "Downloaded: ${status}" " | Left: ${left}" "=")"
            fi
            old_status="${status}"
        done
        _newline "\n"
    fi

    if [[ $(wc -c < "${name}") -ge "${server_size}" ]]; then
        for _ in 1 2; do _clear_line 1; done
        "${QUIET:-_print_center}" "justify" "Downloaded" "=" && _newline "\n"
    else
        "${QUIET:-_print_center}" "justify" "Error: Incomplete" " download." "=" 1>&2
        return 1
    fi
    _log_in_file "${name}" "${server_size_readable}" "${file_id}"
    return 0
}

###################################################
# A extra wrapper for _download_file function to properly handle retries
# also handle uploads in case downloading from folder
# Todo: write doc
###################################################
_download_file_main() {
    [[ $# -lt 2 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" 1>&2 && return 1
    declare line fileid name size parallel retry="${RETRY:-0}" && unset RETURN_STATUS
    [[ ${1} = parse ]] && parallel="${3}" line="${2}" fileid="${line%%"|:_//_:|"*}" \
        name="${line##*"|:_//_:|"}" size="$(_tmp="${line#*"|:_//_:|"}" && printf "%s\n" "${_tmp%"|:_//_:|"*}")"
    parallel="${parallel:-${5}}"

    unset RETURN_STATUS && until [[ ${retry} -le 0 && -n ${RETURN_STATUS} ]]; do
        if [[ -n ${parallel} ]]; then
            _download_file "${fileid:-${2}}" "${name:-${3}}" "${size:-${4}}" true 2>| /dev/null 1>&2 && RETURN_STATUS=1 && break
        else
            _download_file "${fileid:-${2}}" "${name:-${3}}" "${size:-${4}}" && RETURN_STATUS=1 && break
        fi
        RETURN_STATUS=2 retry="$((retry - 1))" && continue
    done
    { [[ ${RETURN_STATUS} = 1 ]] && printf "%b" "${parallel:+${RETURN_STATUS}\n}"; } || printf "%b" "${parallel:+${RETURN_STATUS}\n}" 1>&2
    return 0
}

###################################################
# Download a gdrive folder along with sub folders
# File IDs are fetched inside the folder, and then downloaded seperately.
# Todo: write doc
###################################################
_download_folder() {
    [[ $# -lt 2 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare folder_id="${1}" name="${2}" parallel="${3}"
    declare info error_status success_status files=() folders=() \
    files_size files_name files_list num_of_files folders_list num_of_folders
    _newline "\n"
    "${EXTRA_LOG}" "justify" "${name}" "="
    "${EXTRA_LOG}" "justify" "Fetching folder" " details.." "-"
    if ! info="$(_fetch "${API_URL}/drive/${API_VERSION}/files?q=%27${folder_id}%27+in+parents&fields=files(name,size,id,mimeType)&key=${API_KEY}&supportsAllDrives=true&includeItemsFromAllDrives=true")"; then
        "${QUIET:-_print_center}" "justify" "Error: Cannot" ", fetch folder details." "="
        printf "%s\n" "${info}" && return 1
    fi && _clear_line 1

    # parse the fetched json and make a list containing files size, name and id
    "${EXTRA_LOG}" "justify" "Preparing files list.." "="
    mapfile -t files <<< "$(printf "%s\n" "${info}" | grep '"size":' -B3 | _json_value id all all)" || :
    files_size="$(_json_value size all all <<< "${info}")" || :
    files_name="$(printf "%s\n" "${info}" | grep size -B2 | _json_value name all all)" || :
    files_list="$(while read -r -u 4 _id && read -r -u 5 _size && read -r -u 6 _name; do
        printf "%s\n" "${_id}|:_//_:|${_size}|:_//_:|${_name}"
    done 4<<< "$(printf "%s\n" "${files[@]}")" 5<<< "${files_size}" 6<<< "${files_name}")"
    _clear_line 1

    # parse the fetched json and make a list containing sub folders name and id
    "${EXTRA_LOG}" "justify" "Preparing sub folders list.." "="
    mapfile -t folders <<< "$(printf "%s\n" "${info}" | grep '"mimeType":.*folder.*' -B2 | _json_value id all all)" || :
    folders_name="$(printf "%s\n" "${info}" | grep '"mimeType":.*folder.*' -B1 | _json_value name all all)" || :
    folders_list="$(while read -r -u 4 _id && read -r -u 5 _name; do
        printf "%s\n" "${_id}|:_//_:|${_name}"
    done 4<<< "$(printf "%s\n" "${folders[@]}")" 5<<< "${folders_name}")"
    _clear_line 1

    for _ in 1 2; do _clear_line 1; done

    [[ -z ${files[*]:-${folders[*]}} ]] && _print_center "justify" "${name}" " | Empty Folder" "=" && _newline "\n" && return 0

    [[ -n ${files[*]} ]] && num_of_files="${#files[@]}"
    [[ -n ${folders[*]} ]] && num_of_folders="${#folders[@]}"

    _print_center "justify" "${name}" "${num_of_files:+ | ${num_of_files} files}${num_of_folders:+ | ${num_of_folders} sub folders}" "=" && _newline "\n\n"

    if [[ -f ${name} ]]; then
        name="${name}${RANDOM}"
    fi && mkdir -p "${name}"

    cd "${name}" || exit 1

    if [[ -n "${num_of_files}" ]]; then
        if [[ -n ${parallel} ]]; then
            NO_OF_PARALLEL_JOBS_FINAL="$((NO_OF_PARALLEL_JOBS > num_of_files ? num_of_files : NO_OF_PARALLEL_JOBS))"

            [[ -f "${TMPFILE}"SUCCESS ]] && rm "${TMPFILE}"SUCCESS
            [[ -f "${TMPFILE}"ERROR ]] && rm "${TMPFILE}"ERROR

            # shellcheck disable=SC2016
            printf "%s\n" "${files_list}" | xargs -n1 -P"${NO_OF_PARALLEL_JOBS_FINAL}" -i bash -c '
                _download_file_main parse "{}" true
            ' 1>| "${TMPFILE}"SUCCESS 2>| "${TMPFILE}"ERROR &
            pid="${!}"

            until [[ -f "${TMPFILE}"SUCCESS || -f "${TMPFILE}"ERROR ]]; do sleep 0.5; done

            _clear_line 1
            until ! kill -0 "${pid}" 2>| /dev/null 1>&2; do
                success_status="$(_count < "${TMPFILE}"SUCCESS)"
                error_status="$(_count < "${TMPFILE}"ERROR)"
                sleep 1
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
            while read -r -u 4 line; do
                _download_file_main parse "${line}"
                : "$((RETURN_STATUS < 2 ? (success_status += 1) : (error_status += 1)))"
                if [[ -z ${VERBOSE} ]]; then
                    for _ in 1 2 3 4; do _clear_line 1; done
                fi
                _print_center "justify" "Status" ": ${success_status:-0} Downloaded | ${error_status:-0} Failed" "="
            done 4<<< "${files_list}"
        fi
    fi

    for _ in 1 2; do _clear_line 1; done
    [[ ${success_status} -gt 0 ]] && "${QUIET:-_print_center}" "justify" "Downloaded" ": ${success_status}" "="
    [[ ${error_status} -gt 0 ]] && "${QUIET:-_print_center}" "justify" "Failed" ": ${error_status}" "="
    _newline "\n"

    if [[ -z ${SKIP_SUBDIRS} && -n ${num_of_folders} ]]; then
        while read -r -u 4 line; do
            (_download_folder "${line%%"|:_//_:|"*}" "${line##*"|:_//_:|"}" "${parallel:-}")
        done 4<<< "${folders_list}"
    fi
    return 0
}

###################################################
# Log downloaded file info in case of -l / --log flag
# Todo: write doc
###################################################
_log_in_file() {
    [[ -z ${LOG_FILE_ID} || -d ${LOG_FILE_ID} ]] && return 0
    # shellcheck disable=SC2129
    # https://github.com/koalaman/shellcheck/issues/1202#issuecomment-608239163
    {
        printf "%s\n" "Name: ${1}"
        printf "%s\n" "Size: ${2}"
        printf "%s\n\n" "ID: ${3}"
    } >> "${LOG_FILE_ID}"
}
