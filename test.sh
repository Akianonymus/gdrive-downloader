#!/usr/bin/env bash
set -xe

# Format check
bash format.sh

# Folder
bash drivedl.sh 'https://drive.google.com/folderview?id=1DbfjPfqDegvNMZBqI3cQvOTEi2KiSBaY&usp=sharing'
rm -rf Test/
sleep 4
bash drivedl.sh 'https://drive.google.com/drive/u/0/mobile/folders/1DbfjPfqDegvNMZBqI3cQvOTEi2KiSBaY'
sleep 3
# Do a check for log message when trying to download an existing folder
bash drivedl.sh 'https://drive.google.com/drive/folders/1DbfjPfqDegvNMZBqI3cQvOTEi2KiSBaY'

# Big file
bash drivedl.sh 'https://drive.google.com/file/d/1MdrlBZuOwS1PePCCMIANF3THpJEU5Xfu/view?usp=drivesdk'
rm Bigfile.tgz
sleep 3
bash drivedl.sh 'https://drive.google.com/uc?id=1MdrlBZuOwS1PePCCMIANF3THpJEU5Xfu&export=download'
sleep 3
bash drivedl.sh 'https://drive.google.com/open?id=1MdrlBZuOwS1PePCCMIANF3THpJEU5Xfu'
sleep 3
# Do a check for log message when trying to download an existing file
bash drivedl.sh 'https://docs.google.com/file/d/1MdrlBZuOwS1PePCCMIANF3THpJEU5Xfu/edit'

# Small File
bash drivedl.sh 'https://drive.google.com/file/d/147V1Z2eVrRJrAy9KpqAcxoYLjV8S3qIl/view?usp=sharing'
rm smallfile.dat
sleep 2
bash drivedl.sh 'https://drive.google.com/uc?id=147V1Z2eVrRJrAy9KpqAcxoYLjV8S3qIl&export=download'
rm smallfile.dat
sleep 2
bash drivedl.sh 'https://drive.google.com/open?id=147V1Z2eVrRJrAy9KpqAcxoYLjV8S3qIl'
sleep 2
# Do a check for log message when trying to download an existing file
bash drivedl.sh 'https://docs.google.com/file/d/147V1Z2eVrRJrAy9KpqAcxoYLjV8S3qIl/edit'

set +xe
