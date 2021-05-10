#!/usr/bin/env sh
set -e

# gdrive IDs
FILE_ID="14eh2_N3rGeGzUMamk2uyoU_CF9O7YUkA"
FOLDER_ID="1AC0UsKfLZfflIkO7Ork78et5VzIvFSDM"

_test() (
    shell="${1:?Error: Specify shell name.}"
    use_key="${2}"

    cd "${shell}/release" || exit 1
    ### Folder ###
    ./gdl "https://drive.google.com/folderview?id=${FOLDER_ID}&usp=sharing" -d Test "${use_key:-}" -aria

    ./gdl "https://drive.google.com/drive/u/0/mobile/folders/${FOLDER_ID}" -d Test -p 2 "${use_key:-}"

    # Do a check for log message when trying to download an existing folder contents
    ./gdl "https://drive.google.com/drive/folders/${FOLDER_ID}" -d Test "${use_key:-}"
    rm -rf Test/

    ### File ###
    ./gdl "https://drive.google.com/file/d/${FILE_ID}/view?usp=drivesdk" -d Test "${use_key:-}" -aria

    #./gdl "https://drive.google.com/uc?id=${FILE_ID}&export=download" -d Test "${use_key:-}"
    #rm -rf Test/

    #./gdl "https://drive.google.com/open?id=${FILE_ID}" -d Test "${use_key:-}"

    # Do a check for log message when trying to download an existing file
    ./gdl "https://docs.google.com/file/d/${FILE_ID}/edit" -d Test "${use_key:-}"
    rm -rf Test/

    # Do a test for invalid url/id
    ./gdl "testid"
)

# Test with sh
_test sh
_test sh --key

# Test with bash
_test bash
_test bash --key
