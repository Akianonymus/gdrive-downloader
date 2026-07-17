#!/usr/bin/env bash
set -e

# gdrive IDs
FILE_ID="14eh2_N3rGeGzUMamk2uyoU_CF9O7YUkA"
DOCUMENT_ID="1Dziv2X5_UCMQ2weMI9duSUT6iayMikqRdoftJCwq_vg"
FOLDER_ID="1AC0UsKfLZfflIkO7Ork78et5VzIvFSDM"

_test_unit() (
    count=0
    _error() {
        printf "%s\n" "Error: Unit test $((count += 1)) failed${1:+: $1}."
        exit 1
    }

    _success() {
        printf "\n%s\n\n" "Success: Unit test $((count += 1)) passed${1:+: $1}."
    }

    # shellcheck source=/dev/null
    . src/common/common-utils.sh
    # shellcheck source=/dev/null
    . src/common/auth-utils.sh
    # shellcheck source=/dev/null
    . src/common/drive-utils.sh
    # shellcheck source=/dev/null
    . src/common/download-utils.sh

    _account_name_valid "default" || _error "valid account name default"
    _account_name_valid "my_account" || _error "valid account name with underscore"
    _account_name_valid "Account123" || _error "valid account name alphanumerics"
    if _account_name_valid "my-account"; then
        _error "dash should be invalid"
    fi
    if _account_name_valid "bad name"; then
        _error "space should be invalid"
    fi
    _success "account name validation"

    if output="$(./release/gdl --skip-internet-check "${FOLDER_ID}" -o "123456789012-abcdefghijklmnopqrstuvwxyzABCDEF.apps.googleusercontent.com" "client-secret" 2>&1)"; then
        _error "oauth client id as input should fail"
    fi
    printf "%s\n" "${output}" | grep -q "OAuth Client ID was given as a Drive input" || _error "missing client id guard message"
    printf "%s\n" "${output}" | grep -q "takes no arguments" || _error "missing usage hint"
    _success "reject oauth credentials as positionals"

    export EXTRA_LOG=":"
    unset QUIET
    # shellcheck disable=SC2317
    _api_request_error() {
        printf '%s' '{"error":{"code":404,"message":"File not found."}}'
    }
    export API_REQUEST_FUNCTION="_api_request_error"
    if output="$(_check_id "badid" 2>&1)"; then
        _error "api error should fail"
    fi
    printf "%s\n" "${output}" | grep -q "File not found" || _error "missing api error message"
    _success "drive api error message"

    # shellcheck disable=SC2317
    _api_request_missing_name() {
        printf '%s' '{"size":"1","mimeType":"text/plain"}'
    }
    export API_REQUEST_FUNCTION="_api_request_missing_name"
    if output="$(_check_id "nonameid" 2>&1)"; then
        _error "missing name should fail"
    fi
    printf "%s\n" "${output}" | grep -q "did not include a usable file/folder name" || _error "missing metadata error message"
    _success "drive missing name message"

    # shellcheck disable=SC2317
    _api_request_list_folder() {
        case "${1}" in
            files\?q=*)
                printf '%s' '{"files":[{"id":"childfile1","name":"listed.txt","size":"42","mimeType":"text/plain"},{"id":"childfolder1","name":"listed-sub","mimeType":"application/vnd.google-apps.folder"}]}'
                ;;
            *)
                printf '%s' '{}'
                ;;
        esac
    }
    export API_REQUEST_FUNCTION="_api_request_list_folder"
    export LIST="true" EXTRA_LOG=":" SKIP_SUBDIRS="true"
    unset QUIET DEBUG
    # shellcheck disable=SC2317
    _print_center() { { [[ $# = 3 ]] && printf "%s\n" "${2}"; } || { printf "%s%s\n" "${2}" "${3}"; }; }
    # shellcheck disable=SC2317
    _clear_line() { :; }
    # shellcheck disable=SC2317
    _newline() { :; }
    TMPFILE="$(mktemp -u)"
    export TMPFILE
    list_output="$(_download_folder alt "parentfolder" "ListRoot" "${PWD}" "" 2>&1)" || _error "list folder mock failed"
    printf "%s\n" "${list_output}" | grep -q "listed.txt" || _error "list missing file name"
    printf "%s\n" "${list_output}" | grep -q "listed-sub" || _error "list missing folder name"
    printf "%s\n" "${list_output}" | grep -q "Folder" || _error "list missing folder marker"
    [[ ! -d "${PWD}/ListRoot" ]] || _error "list created local folder"
    unset LIST SKIP_SUBDIRS
    _success "list folder contents without mkdir"
)

_test() (
    use_key="${1:-}"

    cd release || exit 1

    count=0
    _error() {
        printf "%s\n" "Error: Test $((count += 1)) failed for bash ${use_key}."
        exit 1
    }

    _success() {
        printf "\n%s\n\n" "Success: Test $((count += 1)) passed for bash ${use_key}."
    }

    ### Folder ###
    ./gdl --skip-internet-check "https://drive.google.com/folderview?id=${FOLDER_ID}&usp=sharing" -d Test "${use_key}" -aria || _error
    _success

    ./gdl --skip-internet-check "https://drive.google.com/drive/u/0/mobile/folders/${FOLDER_ID}" -d Test -p 2 "${use_key}" || _error
    _success

    # Do a check for log message when trying to download an existing folder contents
    ./gdl --skip-internet-check "https://drive.google.com/drive/folders/${FOLDER_ID}" -d Test "${use_key}" || _error
    _success

    rm -rf Test/

    ### File ###
    ./gdl --skip-internet-check "https://drive.google.com/file/d/${FILE_ID}/view?usp=drivesdk" -d Test "${use_key}" -aria || _error
    _success

    #./gdl --skip-internet-check "https://drive.google.com/uc?id=${FILE_ID}&export=download" -d Test "${use_key}"
    #rm -rf Test/

    #./gdl --skip-internet-check "https://drive.google.com/open?id=${FILE_ID}" -d Test "${use_key}"

    # Do a check for log message when trying to download an existing file
    ./gdl --skip-internet-check "https://docs.google.com/file/d/${FILE_ID}/edit" -d Test "${use_key}" || _error
    _success

    ### Document ###
    ./gdl --skip-internet-check "https://docs.google.com/document/d/${DOCUMENT_ID}/edit?usp=sharing" -d Test "${use_key}" || _error
    _success

    rm -rf Test/

    # Do a test for invalid url/id
    ./gdl --skip-internet-check "testid" || _error
    _success

    ### List ###
    list_file_output="$(./gdl --skip-internet-check "${FILE_ID}" -ls "${use_key}" 2>&1)" || _error "list file failed"
    printf "%s\n" "${list_file_output}" | grep -q "Name:" || _error "list file missing name"
    printf "%s\n" "${list_file_output}" | grep -q "Size:" || _error "list file missing size"
    _success "list file"

    list_folder_output="$(./gdl --skip-internet-check "${FOLDER_ID}" -ls -s "${use_key}" 2>&1)" || _error "list folder failed"
    printf "%s\n" "${list_folder_output}" | grep -q "Name:" || _error "list folder missing name"
    printf "%s\n" "${list_folder_output}" | grep -Eq 'Folder|Size:' || _error "list folder missing contents"
    [[ ! -d Test ]] || _error "list folder created Test directory"
    _success "list folder"

)

# Unit regressions for issue #47 (no real OAuth required)
_test_unit

# Test with bash
_test bash
_test bash --key
