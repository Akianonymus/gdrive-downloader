#!/usr/bin/env sh
set -e

# gdrive IDs
FILE_ID="1qzA3yqlcOctz_ZDcDaPqsvd7DWozsSHB"
FOLDER_ID="1DbfjPfqDegvNMZBqI3cQvOTEi2KiSBaY"

_test() (
    shell="${1:?Error: Specify shell name.}"
    cd "${shell}" || exit 1
    # Folder
    "${shell}" gdl."${shell}" "https://drive.google.com/folderview?id=${FOLDER_ID}&usp=sharing" -d Test
    rm -rf Test/

    "${shell}" gdl."${shell}" "https://drive.google.com/drive/u/0/mobile/folders/${FOLDER_ID}" -d Test -p 2

    # Do a check for log message when trying to download an existing folder contents
    "${shell}" gdl."${shell}" "https://drive.google.com/drive/folders/${FOLDER_ID}" -d Test
    rm -rf Test/

    # File
    "${shell}" gdl."${shell}" "https://drive.google.com/file/d/${FILE_ID}/view?usp=drivesdk" -d Test
    rm -rf Test/

    "${shell}" gdl."${shell}" "https://drive.google.com/uc?id=${FILE_ID}&export=download" -d Test
    rm -rf Test/

    "${shell}" gdl."${shell}" "https://drive.google.com/open?id=${FILE_ID}" -d Test

    # Do a check for log message when trying to download an existing file
    "${shell}" gdl."${shell}" "https://docs.google.com/file/d/${FILE_ID}/edit" -d Test
    rm -rf Test/

    cd ../
)

# Test with sh
_test sh

# Test with bash
_test bash
