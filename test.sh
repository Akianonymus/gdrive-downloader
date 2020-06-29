#!/usr/bin/env bash
set -e

# Test gdrive IDs
FILE_ID="1qzA3yqlcOctz_ZDcDaPqsvd7DWozsSHB"
FOLDER_ID="1DbfjPfqDegvNMZBqI3cQvOTEi2KiSBaY"

# Folder
bash gdl.sh "https://drive.google.com/folderview?id=${FOLDER_ID}&usp=sharing" -d Test
rm -rf Test/

bash gdl.sh "https://drive.google.com/drive/u/0/mobile/folders/${FOLDER_ID}" -d Test -p 2

# Do a check for log message when trying to download an existing folder contents
bash gdl.sh "https://drive.google.com/drive/folders/${FOLDER_ID}" -d Test
rm -rf Test/

# File
bash gdl.sh "https://drive.google.com/file/d/${FILE_ID}/view?usp=drivesdk" -d Test
rm -rf Test/

bash gdl.sh "https://drive.google.com/uc?id=${FILE_ID}&export=download" -d Test
rm -rf Test/

bash gdl.sh "https://drive.google.com/open?id=${FILE_ID}" -d Test

# Do a check for log message when trying to download an existing file
bash gdl.sh "https://docs.google.com/file/d/${FILE_ID}/edit" -d Test
rm -rf Test/
