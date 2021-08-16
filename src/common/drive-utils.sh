#!/usr/bin/env sh
# shellcheck source=/dev/null

###################################################
# Default curl command used for gdrivr api requests.
###################################################
_api_request() {
    # shellcheck disable=SC2086
    _curl --compressed ${CURL_PROGRESS:-} \
        -e "https://drive.google.com" \
        "${API_URL:?}/drive/${API_VERSION:?}/${1:?}&key=${API_KEY:?}&supportsAllDrives=true&includeItemsFromAllDrives=true" || return 1
    _clear_line 1 1>&2
}

###################################################
# A simple wrapper to check tempfile for access token and make authorized oauth requests to drive api
###################################################
_api_request_oauth() {
    . "${TMPFILE:?}_ACCESS_TOKEN"

    # shellcheck disable=SC2086
    _curl --compressed ${CURL_PROGRESS:-} \
        -H "Authorization: Bearer ${ACCESS_TOKEN:?}" \
        "${API_URL:?}/drive/${API_VERSION:?}/${1:?}&supportsAllDrives=true&includeItemsFromAllDrives=true" || return 1
    _clear_line 1 1>&2
}

###################################################
# Check if the file ID exists and determine its type ( folder or file)
# Arguments:
#   ${1} = file id
# on success, export FILE_ID, FOLDER_ID, NAME, SIZE
###################################################
_check_id() {
    export EXTRA_LOG API_REQUEST_FUNCTION QUIET
    id_check_id="${1:?_check_id}" json_check_id=""

    __error_check_id() {
        _clear_line 1
        "${QUIET:-_print_center}" "justify" "${1:?__error_check_id}" "="
        [ -n "${2}" ] && {
            if [ -n "${3}" ]; then
                "${QUIET:-_print_center}" "normal" "${2}" " "
            else
                printf "%s\n" "${2}"
            fi
        }
        _newline "\n"
    }

    "${EXTRA_LOG}" "justify" "Validating URL/ID.." "-"

    json_check_id="$("${API_REQUEST_FUNCTION}" "files/${id_check_id}?alt=json&fields=name,size,mimeType")" || {
        __error_check_id "Error: Cannot validate URL/ID" "${json_check_id}"
        return 1
    }

    printf "%s\n" "${json_check_id}" | _json_value code 1 1 2>| /dev/null 1>&2 &&
        __error_check_id "Invalid URL/ID" "${id_check_id}" pretty && return 1

    NAME="$(printf "%s\n" "${json_check_id}" | _json_value name 1 1)" || {
        __error_check_id "Cannot fetch name."
        return 1
    }

    mime_check_id="$(printf "%s\n" "${json_check_id}" | _json_value mimeType 1 1)" || {
        __error_check_id "Cannot fetch mimetype."
        return 1
    }

    _clear_line 1

    case "${mime_check_id}" in
        *folder*)
            FOLDER_ID="${id_check_id}"
            _print_center "justify" "Folder Detected" "="
            ;;
        *)
            SIZE="$(printf "%s\n" "${json_check_id}" | _json_value size 1 1)" || {
                __error_check_id "Cannot fetch size of file."
            }

            FILE_ID="${id_check_id}"
            _print_center "justify" "File Detected" "="
            ;;
    esac

    _newline "\n"

    export NAME SIZE FILE_ID FOLDER_ID
    return 0
}

###################################################
# Extract ID from a googledrive folder/file url.
# Arguments: 2
#   ${1} = googledrive folder/file url.
#   ${2} = var name
# Result: print extracted ID if ${2} not present, else set ${2} = extracted id
###################################################
_extract_id() {
    [ $# = 0 ] && printf "Missing arguments\n" && return 1
    id_extract_id="${1}"
    case "${id_extract_id}" in
        *'drive.google.com'*'id='*) _tmp="${id_extract_id##*id=}" && _tmp="${_tmp%%\?*}" && id_extract_id="${_tmp%%\&*}" ;;
        *'drive.google.com'*'file/d/'* | 'http'*'docs.google.com'*'/d/'*) _tmp="${id_extract_id##*\/d\/}" && _tmp="${_tmp%%\/*}" && _tmp="${_tmp%%\?*}" && id_extract_id="${_tmp%%\&*}" ;;
        *'drive.google.com'*'drive'*'folders'*) _tmp="${id_extract_id##*\/folders\/}" && _tmp="${_tmp%%\?*}" && id_extract_id="${_tmp%%\&*}" ;;
        *) : ;;
    esac
    if [ -n "${2}" ]; then
        _set_value d "${2}" "${id_extract_id}"
    else
        printf "%b" "${id_extract_id:+${id_extract_id}\n}"
    fi
}

# export the required functions when sourced from bash scripts
{
    # shellcheck disable=SC2163
    [ "${_SHELL:-}" = "bash" ] && tmp="-f" &&
        export "${tmp?}" _api_request \
            _api_request_oauth \
            _check_id \
            _extract_id
} 2>| /dev/null 1>&2 || :
