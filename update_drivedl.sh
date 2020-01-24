#!/usr/bin/env bash
DIR="$HOME"/.gdrive-downloader
REPO="gdrive-downloader"

URLSTATUS="$(curl -Is --write-out "%{http_code}" --output /dev/null "https://github.com/Akianonymus/$REPO")"
export URLSTATUS
if echo "$URLSTATUS" | grep "000" > /dev/null 2>&1; then
    printf 'Internet connection not available.\n\n'
    exit 1
fi

if [ -d "$DIR" ]; then
    if ! ls -A "$DIR" > /dev/null 2>&1; then
        printf 'gdrive-downloader script not installed\n\n'
        exit 1
    fi
else
    printf 'gdrive-downloader script not installed\n\n'
    exit 1
fi

LATEST_SHA="$(curl -s https://github.com/Akianonymus/"$REPO"/commits/master.atom | grep "Commit\\/" | cut -d "/" -f2 | sed 's|<||')"
export LATEST_SHA
if [ -z "$LATEST_SHA" ]; then
    printf 'Cannot fetch remote version.\n\n'
    exit 1
fi

LATEST_INSTALLED_SHA="$(grep LATEST_CURRENT_SHA "$DIR"/drivedl.sh | cut -d "=" -f2)"
export LATEST_INSTALLED_SHA
if [ -z "$LATEST_INSTALLED_SHA" ]; then
    printf 'Cannot determine local version\n\n'
    exit 1
fi

if [[ "$LATEST_SHA" == "$LATEST_INSTALLED_SHA" ]]; then
    printf 'Latest gdrive-downloader already installed\n\n'
else
    echo 'Updating...'
    wget -q --show-progress --progress=bar:force https://raw.githubusercontent.com/Akianonymus/"$REPO"/master/drivedl.sh -O "$DIR"/drivedl.sh || exit 1
    wget -q --show-progress --progress=bar:force https://raw.githubusercontent.com/Akianonymus/"$REPO"/master/update_drivedl.sh -O "$DIR"/update_drivedl.sh || exit 1
    echo "LATEST_SHA=$LATEST_CURRENT_SHA" >> "$DIR"/drivedl.sh
    printf '\033[1A'
    printf 'Successfully Updated.\n\n'
fi
