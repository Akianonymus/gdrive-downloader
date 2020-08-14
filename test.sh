#!/usr/bin/env sh
set -e

./merge.sh

# gdrive IDs
FILE_ID="1qzA3yqlcOctz_ZDcDaPqsvd7DWozsSHB"
FOLDER_ID="1DbfjPfqDegvNMZBqI3cQvOTEi2KiSBaY"

_test() (
    shell="${1:?Error: Specify shell name.}"
    cd "${shell}/release" || exit 1
    # Folder
    ./gdl "https://drive.google.com/folderview?id=${FOLDER_ID}&usp=sharing" -d Test
    rm -rf Test/

    ./gdl "https://drive.google.com/drive/u/0/mobile/folders/${FOLDER_ID}" -d Test -p 2

    # Do a check for log message when trying to download an existing folder contents
    ./gdl "https://drive.google.com/drive/folders/${FOLDER_ID}" -d Test
    rm -rf Test/

    # File
    ./gdl "https://drive.google.com/file/d/${FILE_ID}/view?usp=drivesdk" -d Test
    rm -rf Test/

    ./gdl "https://drive.google.com/uc?id=${FILE_ID}&export=download" -d Test
    rm -rf Test/

    ./gdl "https://drive.google.com/open?id=${FILE_ID}" -d Test

    # Do a check for log message when trying to download an existing file
    ./gdl "https://docs.google.com/file/d/${FILE_ID}/edit" -d Test
    rm -rf Test/

)

# Test with sh
_test sh

# Test with bash
_test bash
