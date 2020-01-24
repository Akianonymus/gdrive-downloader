#!/usr/bin/env bash
CURRENT_SHELL="$(echo "$SHELL" | sed "s/\//\n/g" | tail -1)"
case "$CURRENT_SHELL" in
    'bash') SHELL_FILE="$(ls "$HOME"/.bashrc)" ;;
    'zsh') SHELL_FILE="$(ls "$HOME"/.zshrc)" ;;
esac
PROFILE_FILE="$HOME"/.profile

case "$(uname -a | sed 's/\s\+/\n/g' | tail -2 | sed -n 1p)" in
    'armv7l') ARCH=arm ;;
    'i386') ARCH=386 ;;
    'x86_64') ARCH=amd64 ;;
esac

if ! which shfmt > /dev/null; then
    if [ ! -f "$HOME"/.shf/shfmt ]; then
        printf 'shfmt not installed\n'
        printf 'Fetching latest release...\n'
        LATEST_RELEASE="$(curl https://github.com/mvdan/sh/releases.atom -s | sed -n 12p | cut -d ">" -f2 | cut -d "<" -f1)"
        printf '\033[1A'
        printf "Latest Release: %s         \\n" "$LATEST_RELEASE"
        LINK=https://github.com/mvdan/sh/releases/download/"$LATEST_RELEASE"/shfmt_"$LATEST_RELEASE"_linux_"$ARCH"
        mkdir -p "$HOME"/.shfmt
        printf "Architecture=%s detected, downloading...\\n" "$ARCH"
        wget --show-progress -q "$LINK" -O "$HOME"/.shfmt/shfmt
        chmod +x "$HOME"/.shfmt/shfmt
        PATH="$HOME/.shfmt/:$PATH"
        export PATH
        if [ -n "$SHELL_FILE" ]; then
            if [ -f "$SHELL_FILE" ]; then
                echo "export PATH=$HOME/.shfmt/:$PATH" >> "$SHELL_FILE"
            elif [ -f "$PROFILE_FILE" ]; then
                echo "export PATH=$HOME/.shfmt/:$PATH" >> "$PROFILE_FILE"
            fi
        fi
        echo "shfmt installed"
        echo "shfmt --help"
    else
        echo "Cannot install, not compatible shell file found"
    fi
else
    echo "shfmt already installed"
    echo "Path: $(which shfmt)"
fi
