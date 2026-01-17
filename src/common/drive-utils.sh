#!/usr/bin/env bash
# shellcheck source=/dev/null

###################################################
# Default curl command used for gdrivr api requests.
###################################################
_api_request() {
    # shellcheck disable=SC2086,SC2154
    _curl --compressed ${CURL_PROGRESS:-} \
        -e "https://drive.google.com" \
        "${API_URL:?}/drive/${API_VERSION:?}/${1:?}&key=${API_KEY//[[:space:]]/}&supportsAllDrives=true&includeItemsFromAllDrives=true" || return 1
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
        [[ -n "${2}" ]] && {
            if [[ -n "${3}" ]]; then
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

    error_code="$(printf "%s\n" "${json_check_id}" | jq -r '.error.code' 2>| /dev/null)"
    [[ "${error_code}" != "null" ]] && [[ -n "${error_code}" ]] && {
        __error_check_id "Invalid URL/ID" "${id_check_id}" pretty && return 1
    }

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
        "application/vnd.google-apps.folder")
            FOLDER_ID="${id_check_id}"
            _print_center "justify" "Folder Detected" "="
            ;;
        "application/vnd.google-apps.document")
            FILE_ID="${id_check_id}" FILE_MIME_TYPE="${mime_check_id}"
            _print_center "justify" "Document Detected" "="
            ;;
        *)
            SIZE="$(printf "%s\n" "${json_check_id}" | _json_value size 1 1)" || {
                printf "\n" && __error_check_id "Cannot fetch size of file." && return 1
            }

            FILE_ID="${id_check_id}" FILE_MIME_TYPE="${mime_check_id}"
            _print_center "justify" "File Detected" "="
            ;;
    esac

    _newline "\n"

    export NAME SIZE FILE_ID FILE_MIME_TYPE FOLDER_ID
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
    [[ $# = 0 ]] && printf "Missing arguments\n" && return 1
    id_extract_id="${1}"
    case "${id_extract_id}" in
        *'drive.google.com'*'id='*) _tmp="${id_extract_id##*id=}" && _tmp="${_tmp%%\?*}" && id_extract_id="${_tmp%%\&*}" ;;
        *'drive.google.com'*'file/d/'* | 'http'*'docs.google.com'*'/d/'*) _tmp="${id_extract_id##*\/d\/}" && _tmp="${_tmp%%\/*}" && _tmp="${_tmp%%\?*}" && id_extract_id="${_tmp%%\&*}" ;;
        *'drive.google.com'*'drive'*'folders'*) _tmp="${id_extract_id##*\/folders\/}" && _tmp="${_tmp%%\?*}" && id_extract_id="${_tmp%%\&*}" ;;
        *) : ;;
    esac
    if [[ -n "${2}" ]]; then
        _set_value d "${2}" "${id_extract_id}"
    else
        printf "%b" "${id_extract_id:+${id_extract_id}\n}"
    fi
}

###################################################
# Get mimetype for document format url escaped.
# Arguments: 1
#   ${1} = format.
###################################################
_get_export_mime() {
    [[ $# = 0 ]] && printf "Missing arguments\n" && return 1
    type_get_export_mime="${1}"
    given_format_get_export_mime="${2}"
    ext_get_export_mime=""
    format_get_export_mime=""
    case "${given_format_get_export_mime}" in
        docx | application/vnd.google-apps.document | application/vnd.openxmlformats-officedocument.wordprocessingml.document) format_get_export_mime="application%2Fvnd.openxmlformats-officedocument.wordprocessingml.document" ext_get_export_mime="docx" ;;
        odt | application/vnd.oasis.opendocument.text) format_get_export_mime="application%2Fvnd.oasis.opendocument.text" ext_get_export_mime="odt" ;;
        rtf | application/rtf) format_get_export_mime="application%2Frtf" ext_get_export_mime="rtf" ;;
        pdf | application/pdf) format_get_export_mime="application%2Fpdf" ext_get_export_mime="pdf" ;;
        txt | text/plain) format_get_export_mime="text%2Fplain" ext_get_export_mime="plain" ;;
        zip | application/zip) format_get_export_mime="application%2Fzip" ext_get_export_mime="zip" ;;
        epub | "application/epub+zip") format_get_export_mime="application%2Fepub%2Bzip" ext_get_export_mime="epub" ;;
        xlsx | application/vnd.google-apps.spreadsheet | application/vnd.openxmlformats-officedocument.spreadsheetml.sheet) format_get_export_mime="application%2Fvnd.openxmlformats-officedocument.spreadsheetml.sheet" ext_get_export_mime="xlsx" ;;
        ods | application/x-vnd.oasis.opendocument.spreadsheet) format_get_export_mime="application%2Fx-vnd.oasis.opendocument.spreadsheet" ext_get_export_mime="ods" ;;
        csv | text/csv) format_get_export_mime="text%2Fcsv" ext_get_export_mime="csv" ;;
        tsv | text/tab-separated-values) format_get_export_mime="text%2Ftab-separated-values" ext_get_export_mime="tsv" ;;
        pptx | application/vnd.openxmlformats-officedocument.presentationml.presentation) format_get_export_mime="application%2Fvnd.openxmlformats-officedocument.presentationml.presentation" ext_get_export_mime="pptx" ;;
        odp | application/vnd.oasis.opendocument.presentation) format_get_export_mime="application%2Fvnd.oasis.opendocument.presentation" ext_get_export_mime="odp" ;;
        jpg | image/jpeg) format_get_export_mime="image%2Fjpeg" ext_get_export_mime="jpg" ;;
        png | image/png) format_get_export_mime="image%2Fpng" ext_get_export_mime="png" ;;
        svg | image/svg+xml) format_get_export_mime="image%2Fsvg%2Bxml" ext_get_export_mime="svg" ;;
        json | application/vnd.google-apps.script+json) format_get_export_mime="application%2Fvnd.google-apps.script%2Bjson" ext_get_export_mime="json" ;;
        *) format_get_export_mime="" ext_get_export_mime="" ;;
    esac

    if [[ "${type_get_export_mime}" = "ext" ]]; then
        printf "%s" "${ext_get_export_mime}"
    elif [[ "${type_get_export_mime}" = "mime" ]]; then
        printf "%s" "${format_get_export_mime}"
    fi
}
