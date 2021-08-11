#!/usr/bin/env sh
# shellcheck source=/dev/null

###################################################
# Default curl command used for gdrivr api requests.
###################################################
_api_request() {
    # shellcheck disable=SC2086
    _curl --compressed ${CURL_PROGRESS} \
        -e "https://drive.google.com" \
        "${API_URL}/drive/${API_VERSION}/${1:?}&key=${API_KEY}&supportsAllDrives=true&includeItemsFromAllDrives=true" || return 1
    _clear_line 1 1>&2
}

###################################################
# A simple wrapper to check tempfile for access token and make authorized oauth requests to drive api
###################################################
_api_request_oauth() {
    . "${TMPFILE}_ACCESS_TOKEN"

    # shellcheck disable=SC2086
    _curl --compressed ${CURL_PROGRESS} \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        "${API_URL}/drive/${API_VERSION}/${1:?}&supportsAllDrives=true&includeItemsFromAllDrives=true" || return 1
    _clear_line 1 1>&2
}

###################################################
# Check if the file ID exists and determine it's type [ folder | Files ].
# Todo: write doc
###################################################
_check_id() {
    [ $# = 0 ] && printf "Missing arguments\n" && return 1
    "${EXTRA_LOG}" "justify" "Validating URL/ID.." "-"
    id_check_id="${1}" json_check_id=""
    if json_check_id="$("${API_REQUEST_FUNCTION}" "files/${id_check_id}?alt=json&fields=name,size,mimeType")"; then
        if ! printf "%s\n" "${json_check_id}" | _json_value code 1 1 2>| /dev/null 1>&2; then
            NAME="$(printf "%s\n" "${json_check_id}" | _json_value name 1 1 || :)"
            mime_check_id="$(printf "%s\n" "${json_check_id}" | _json_value mimeType 1 1 || :)"
            _clear_line 1
            case "${mime_check_id}" in
                *folder*)
                    FOLDER_ID="${id_check_id}"
                    _print_center "justify" "Folder Detected" "=" && _newline "\n"
                    ;;
                *)
                    SIZE="$(printf "%s\n" "${json_check_id}" | _json_value size 1 1 || :)"
                    FILE_ID="${id_check_id}"
                    _print_center "justify" "File Detected" "=" && _newline "\n"
                    ;;
            esac
            export NAME SIZE FILE_ID FOLDER_ID
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

###################################################
# Extract ID from a googledrive folder/file url.
# Arguments: 1
#   ${1} = googledrive folder/file url.
# Result: print extracted ID
###################################################
_extract_id() {
    [ $# = 0 ] && printf "Missing arguments\n" && return 1
    LC_ALL=C id_extract_id="${1}"
    case "${id_extract_id}" in
        *'drive.google.com'*'id='*) _tmp="${id_extract_id##*id=}" && _tmp="${_tmp%%\?*}" && id_extract_id="${_tmp%%\&*}" ;;
        *'drive.google.com'*'file/d/'* | 'http'*'docs.google.com'*'/d/'*) _tmp="${id_extract_id##*\/d\/}" && _tmp="${_tmp%%\/*}" && _tmp="${_tmp%%\?*}" && id_extract_id="${_tmp%%\&*}" ;;
        *'drive.google.com'*'drive'*'folders'*) _tmp="${id_extract_id##*\/folders\/}" && _tmp="${_tmp%%\?*}" && id_extract_id="${_tmp%%\&*}" ;;
    esac
    printf "%b" "${id_extract_id:+${id_extract_id}\n}"
}
