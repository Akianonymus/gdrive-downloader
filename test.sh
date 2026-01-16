#!/usr/bin/env bash
set -e

# gdrive IDs
FILE_ID="14eh2_N3rGeGzUMamk2uyoU_CF9O7YUkA"
DOCUMENT_ID="1Dziv2X5_UCMQ2weMI9duSUT6iayMikqRdoftJCwq_vg"
FOLDER_ID="1AC0UsKfLZfflIkO7Ork78et5VzIvFSDM"

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

)

# Test with bash
_test bash
_test bash --key
