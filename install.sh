#!/usr/bin/env bash
DIR="$HOME"/.gdrive-downloader
REPO="gdrive-downloader"

LATEST_CURRENT_SHA="$(curl -s https://github.com/Akianonymus/"$REPO"/commits/master.atom | grep "Commit\\/" | cut -d "/" -f2 | sed 's|<||')"
mkdir -p "$DIR" || exit 1
wget -q --show-progress --progress=bar:force https://raw.githubusercontent.com/Akianonymus/"$REPO"/master/drivedl.sh -O "$DIR"/drivedl.sh || exit 1
wget -q --show-progress --progress=bar:force https://raw.githubusercontent.com/Akianonymus/"$REPO"/master/update_drivedl.sh -O "$DIR"/update_drivedl.sh || exit 1

CURRENT_SHELL="$(echo "$SHELL" | sed "s/\//\n/g" | tail -1)"
case "$CURRENT_SHELL" in
    'bash') SHELL_FILE="$(ls "$HOME"/.bashrc)" ;;
    'zsh') SHELL_FILE="$(ls "$HOME"/.zshrc)" ;;
esac
PROFILE_FILE="$HOME"/.profile

if [ -n "$SHELL_FILE" ]; then
    if [ -f "$SHELL_FILE" ]; then
        echo "alias drivedl='""${CURRENT_SHELL}"" ""$DIR""/drivedl.sh'" >> "$SHELL_FILE"
        echo "alias update_drivedl='""${CURRENT_SHELL}"" ""$DIR""/update_drivedl.sh'" >> "$SHELL_FILE"
        echo "LATEST_CURRENT_SHA=$LATEST_CURRENT_SHA" >> "$DIR"/drivedl.sh
        echo "Installed Successfully, Command name: drivedl"
        echo "Reload your shell by"
        echo "source $SHELL_FILE"
        echo "To update script in future, just run update_drivedl , and it will update the script"
    elif [ -f "$PROFILE_FILE" ]; then
        echo "$SHELL_FILE not found, script will write to ""$PROFILE_FILE"" file instead."
        echo "alias drivedl='""${CURRENT_SHELL}"" ""$DIR""/drivedl.sh'" >> "$PROFILE_FILE"
        echo "alias update_drivedl='""${CURRENT_SHELL}"" ""$DIR""/update_drivedl.sh'" >> "$PROFILE_FILE"
        echo "LATEST_CURRENT_SHA=$LATEST_CURRENT_SHA" >> "$DIR"/drivedl.sh
        echo "Installed Successfully, Command name: drivedl"
        echo "Reload your profile file by"
        echo "source $PROFILE_FILE"
        echo "To update script in future, just run update_drivedl , and it will update the script"

    fi
else
    echo "Automatic script is not compatible with your system, try the Manual method from README"
fi
