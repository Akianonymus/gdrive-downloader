#!/usr/bin/env bash

INPUT=$1
if [ ! "$INPUT" ]; then
    cat << EOS
Usage:
  drivedl "string"

  Where "string" can be file/folder URL or file/folder ID.
  For information on supported URL types and rest, visit https://github.com/Akianonymus/gdrive-downloader .
EOS
    exit 1
fi

# Extract file/folder ID from given input in case of URL.
EXTRACT_ID() {
    ID="$1"
    case "$ID" in
        'http'*'://'*'drive.google.com'*'id='*) ID=$(echo "$ID" | sed 's/^.*id=//' | sed 's|&|\n|' | head -1) ;;
        'http'*'drive.google.com/file/d/'* | 'http'*'docs.google.com/file/d/'*) ID=$(echo "$ID" | sed 's/^.*\/d\///' | sed 's/\/.*//') ;;
        'http'*'drive.google.com'*'drive'*'folders'*) ID=$(echo "$ID" | sed 's/^.*\/folders\///' | sed "s/&.*//" | sed -r 's/(.*)\/.*/\1 /') ;;
    esac
}

# Create a temporary folder.
TMP=".TMP"
export TMP
mkdir -p "$TMP" || exit 1

# Calculation of float integers
calc() {
    awk "BEGIN { print $*}"
}

# Default wget command used everywhere
WGET="wget -q --show-progress --progress=bar:force"

# Check if the file ID exists and determine it's type [ folder | small files | big files ], otherwise exit the script.
CHECK_URL() {
    printf '\nValidating input URL/ID...'
    ID="$1"
    CHECKURL="https://drive.google.com/open?id=$ID"
    FOLDERURL="https://drive.google.com/drive/folders/$ID"
    FILEURL="https://drive.google.com/uc?export=download&id=$ID"
    URLSTATUS="$(curl -Is --write-out "%{http_code}" --output /dev/null "$CHECKURL")"
    # If the internet connection is not available, curl gives "000" output, so add a check for it.
    if ! echo "$URLSTATUS" | grep "000" > /dev/null 2>&1; then
        # Completely non-accesible URLs give 404 http status.
        if ! echo "$URLSTATUS" | grep 404 > /dev/null 2>&1; then
            printf '\033[1A'
            printf '\nValid URL/ID, determining input type folder/file...'

            FOLDERSTATUS="$(curl -Is --write-out "%{http_code}" --output /dev/null "$FOLDERURL")" > /dev/null 2>&1
            FILESTATUS="$(curl -Is "$FILEURL")" > /dev/null 2>&1

            # Folder URLs in the used format give 200 HTTP status.
            if echo "$FOLDERSTATUS" | grep 200 > /dev/null 2>&1; then
                FOLDERID="$ID"

            # smallfile URLs in the used format have a direct download redirect header.
            elif echo "$FILESTATUS" | grep -i location > /dev/null 2>&1; then
                SMALLFILEID="$ID"

            # bigfile URLs in the used format doesn't have a direct download redirect header.
            elif ! echo "$FILESTATUS" | grep -i location > /dev/null 2>&1; then
                BIGFILEID="$ID"
            fi
        else
            printf '\n'
            printf '\033[1A'
            printf 'Invalid URL/ID            \n'
            exit 1
        fi
    else
        printf '\033[1A'
        printf '\nInternet connection not available.\n'
        exit 1
    fi
}

# Type: Small Files [ Files which do not produces "cannot scan big files" warning, so can be downloaded directly ] .
DOWNLOAD_SMALLFILE() {
    SFID="$1"
    export SFID
    if [ -n "$SFID" ] > /dev/null 2>&1; then
        printf '\nFetching Filename...'

        FILENAME="$(curl -s "https://drive.google.com/file/d/""$SFID""/view?usp=sharing" | sed 's|<title>|\n|' | sed 's| - Google Drive</title>|\n|' | sed -n 2p)"
        export FILENAME

        # Check if Filename is exported, else fail.
        if [ -n "$FILENAME" ]; then
            printf '\033[1A'
            printf "\\nFilename: %s           " "$FILENAME"

            if [ -n "$FOLDERNAME" ]; then
                if [ -f "$FOLDERNAME"/"$FILENAME" ]; then
                    printf '\nFile is already present, delete the existing file to download again.\n'
                else
                    printf '\nDownloading...'

                    ${WGET} "https://drive.google.com/uc?export=download&id=$SFID" -O "$FOLDERNAME"/"$FILENAME"

                    printf '\033[1A'
                    printf '\nDownloaded          \n'
                fi
            else
                if [ -f "$FILENAME" ]; then
                    printf '\nFile is already present, delete the existing file to download again.\n'
                else
                    printf '\nDownloading...'

                    ${WGET} "https://drive.google.com/uc?export=download&id=$SFID" -O "$FILENAME"

                    printf '\033[1A'
                    printf '\nDownloaded          \n'
                fi
            fi
        else
            printf '\033[1A'
            # This mostly happens if the given file has qouta limit or the machine IP has been blocked from accessing it.
            printf '\nFailed              \n'
        fi
    fi
}

# Type: Big files [ Files which produces "cannot scan big files" warning, so we need to setup cookies to download it properly ].
DOWNLOAD_BIGFILE() {
    BFID="$1"
    export BFID
    if [ -n "$BFID" ]; then
        sleep 1
        printf '\033[1A'
        printf '\033[1A'
        printf '\nFetching Filename...'

        # This way is much faster than fetching small files names due to low html size, also provides file size.
        FILENAME="$(curl -s "https://drive.google.com/uc?export=download&id=""$BFID""" | sed "s/""$BFID""/\\n/g" | sed 's|too large|\\n|' | sed -n 4p | cut -d ">" -f2 | cut -d "<" -f1)"
        export FILENAME

        # Check if Filename is exported, else fail.
        if [ -n "$FILENAME" ]; then
            FILESIZE="$(curl -s "https://drive.google.com/uc?export=download&id=""$BFID""" | sed "s/""$BFID""/\\n/g" | sed 's|too large|\\n|' | sed -n 4p | cut -d "(" -f2 | cut -d ")" -f1)"
            export FILESIZE
            printf '\033[1A'
            printf '\033[1A'
            printf "\\n\\nFilename: %s           \\n" "$FILENAME"
            printf "Filesize: %s                 " "$FILESIZE"

            if [ -n "$FOLDERNAME" ]; then
                if [ -f "$FOLDERNAME"/"$FILENAME" ]; then
                    SERVER_FILESIZE_NUM="$(calc "$(echo "$FILESIZE" | tr -dc '.0-9')"-1)"
                    case "$(echo "$FILESIZE" | tr -dc 'MG')" in
                        'M') SERVER_FILESIZE=$(calc "$SERVER_FILESIZE_NUM"*1000) ;;
                        'G') SERVER_FILESIZE=$(calc "$SERVER_FILESIZE_NUM"*1000000) ;;
                    esac
                    LOCAL_FILESIZE_NUM="$(du -sh "$FOLDERNAME"/"$FILENAME" | sed 's/\s\+/\n/g' | sed -n 1p | tr -dc '.0-9')"
                    case "$(du -sh "$FOLDERNAME"/"$FILENAME" | sed 's/\s\+/\n/g' | sed -n 1p | tr -dc 'KMG')" in
                        'K') LOCAL_FILESIZE=$LOCAL_FILESIZE_NUM ;;
                        'M') LOCAL_FILESIZE=$(calc "$LOCAL_FILESIZE_NUM"*1000) ;;
                        'G') LOCAL_FILESIZE=$(calc "$LOCAL_FILESIZE_NUM"*1000000) ;;
                    esac
                    if awk 'BEGIN { print ("'"$SERVER_FILESIZE"'" > "'"$LOCAL_FILESIZE"'") }' | grep 1 > /dev/null 2>&1; then
                        printf '\nFile is present, but not fully downloaded, trying to resume...\n'

                        if [ -f "$TMP"/"$BFID"COOKIE ]; then rm "$TMP"/"$BFID"COOKIE; fi

                        # Setup the cookies.
                        wget -q --save-cookies "$TMP"/"$BFID"COOKIE "https://drive.google.com/uc?export=download&id=$BFID"
                        printf '\033[1A'
                        printf '                                                                   '
                        printf '\033[1A'
                        printf '\nDownloading...                                                   '
                        ${WGET} -c --load-cookies "$TMP"/"$BFID"COOKIE -O "$FOLDERNAME"/"$FILENAME" "https://drive.google.com/uc?export=download&id=""$BFID""&confirm=$(tail -1 "$TMP"/"$BFID"COOKIE | sed 's/\s\+/\n/g' | tail -1)"
                        printf '\033[1A'
                        printf '\nDownloaded          \n'

                        # Cleanup the temporary files after download.
                        if [ -f "$BFID" ]; then rm "$BFID"; fi
                        if [ -f "$TMP"/"$BFID"COOKIE ]; then rm "$TMP"/"$BFID"COOKIE; fi
                        for i in ./*uc*"$BFID"*; do
                            if [ -f "$i" ]; then rm ./*uc*"$BFID"*; fi
                        done
                    else
                        printf '\nFile is already downloaded, delete the existing file to download again.\n\n'
                    fi
                else
                    printf '\nDownloading...'

                    if [ -f "$TMP"/"$BFID"COOKIE ]; then rm "$TMP"/"$BFID"COOKIE; fi

                    # Setup the cookies.
                    wget -q --save-cookies "$TMP"/"$BFID"COOKIE "https://drive.google.com/uc?export=download&id=$BFID"
                    ${WGET} --load-cookies "$TMP"/"$BFID"COOKIE -O "$FOLDERNAME"/"$FILENAME" "https://drive.google.com/uc?export=download&id=""$BFID""&confirm=$(tail -1 "$TMP"/"$BFID"COOKIE | sed 's/\s\+/\n/g' | tail -1)"
                    printf '\033[1A'
                    printf '\nDownloaded          \n'

                    # Cleanup the temporary files after download.
                    if [ -f "$BFID" ]; then rm "$BFID"; fi
                    if [ -f "$TMP"/"$BFID"COOKIE ]; then rm "$TMP"/"$BFID"COOKIE; fi
                    for i in ./*uc*"$BFID"*; do
                        if [ -f "$i" ]; then rm ./*uc*"$BFID"*; fi
                    done
                fi
            else
                if [ -f "$FILENAME" ]; then
                    SERVER_FILESIZE_NUM="$(calc "$(echo "$FILESIZE" | tr -dc '.0-9')" - 1)"
                    case "$(echo "$FILESIZE" | tr -dc 'MG')" in
                        'M') SERVER_FILESIZE=$(calc "$SERVER_FILESIZE_NUM"*1000) ;;
                        'G') SERVER_FILESIZE=$(calc "$SERVER_FILESIZE_NUM"*1000000) ;;
                    esac
                    LOCAL_FILESIZE_NUM="$(du -sh "$FILENAME" | sed 's/\s\+/\n/g' | sed -n 1p | tr -dc '.0-9')"
                    case "$(du -sh "$FILENAME" | sed 's/\s\+/\n/g' | sed -n 1p | tr -dc 'KMG')" in
                        'K') LOCAL_FILESIZE=$LOCAL_FILESIZE_NUM ;;
                        'M') LOCAL_FILESIZE=$(calc "$LOCAL_FILESIZE_NUM"*1000) ;;
                        'G') LOCAL_FILESIZE=$(calc "$LOCAL_FILESIZE_NUM"*1000000) ;;
                    esac
                    if awk 'BEGIN { print ("'"$SERVER_FILESIZE"'" > "'"$LOCAL_FILESIZE"'") }' | grep 1 > /dev/null 2>&1; then
                        printf '\nFile is present, but not fully downloaded, trying to resume...\n'

                        if [ -f "$TMP"/"$BFID"COOKIE ]; then rm "$TMP"/"$BFID"COOKIE; fi

                        # Setup the cookies using curl -c flag.
                        wget -q --save-cookies "$TMP"/"$BFID"COOKIE "https://drive.google.com/uc?export=download&id=$BFID"
                        printf '\033[1A'
                        printf '                                                                   '
                        printf '\033[1A'
                        printf '\nDownloading...                                                   '
                        ${WGET} -c --load-cookies "$TMP"/"$BFID"COOKIE -O "$FILENAME" "https://drive.google.com/uc?export=download&id=""$BFID""&confirm=$(tail -1 "$TMP"/"$BFID"COOKIE | sed 's/\s\+/\n/g' | tail -1)"
                        printf '\033[1A'
                        printf '\nDownloaded          \n'

                        # Cleanup the temporary files after download.
                        if [ -f "$BFID" ]; then rm "$BFID"; fi
                        if [ -f "$TMP"/"$BFID"COOKIE ]; then rm "$TMP"/"$BFID"COOKIE; fi
                        for i in ./*uc*"$BFID"*; do
                            if [ -f "$i" ]; then rm ./*uc*"$BFID"*; fi
                        done
                    else
                        printf '\nFile is already downloaded, delete the existing file to download again.\n\n'
                    fi
                else
                    printf '\nDownloading...'
                    if [ -f "$TMP"/"$BFID"COOKIE ]; then rm "$TMP"/"$BFID"COOKIE; fi

                    # Setup the cookies using curl -c flag.
                    wget -q --save-cookies "$TMP"/"$BFID"COOKIE "https://drive.google.com/uc?export=download&id=$BFID"
                    ${WGET} --load-cookies "$TMP"/"$BFID"COOKIE -O "$FILENAME" "https://drive.google.com/uc?export=download&id=""$BFID""&confirm=$(tail -1 "$TMP"/"$BFID"COOKIE | sed 's/\s\+/\n/g' | tail -1)"

                    printf '\033[1A'
                    printf '\nDownloaded          \n'

                    # Cleanup the temporary files after download.
                    if [ -f "$BFID" ]; then rm "$BFID"; fi
                    if [ -f "$TMP"/"$BFID"COOKIE ]; then rm "$TMP"/"$BFID"COOKIE; fi
                    for i in ./*uc*"$BFID"*; do
                        if [ -f "$i" ]; then rm ./*uc*"$BFID"*; fi
                    done
                fi
            fi
        else
            printf '\033[1A'
            # This mostly happens if the given file has qouta limit or the machine IP has been blocked from accessing it.
            printf '\nFailed              \n'
        fi
    fi
}

# Type: Folder [ First, the file IDs are fetched inside the folder, and then downloaded seperately ], currently, sub-folders are ignored.
DOWNLOAD_FOLDER_FILES() {
    FID="$1"
    export FID

    printf "Fetching folder name..."

    # Downloading this html separately because we are going to access it multiple times, provides us page title and sub-folder/file IDs.
    curl -s "https://drive.google.com/drive/folders/$FID" -o "$TMP"/"$FID"HTML

    FOLDERNAME="$(sed 's|<title>|\n|' "$TMP"/"$FID"HTML | sed 's| Google Drive</title>|\n|' | sed -n 2p | sed 's/..$//')"
    export FOLDERNAME

    printf '\033[1A'
    printf "\\nFoldername: %s         \\n" "$FOLDERNAME"

    # Cleanup the temporary files, if exist for some reason.
    if [ -f "$TMP"/"$FID"FOLDERS ]; then rm "$TMP"/"$FID"FOLDERS;  fi
    if [ -f "$TMP"/"$FID"FILES ]; then rm "$TMP"/"$FID"FILES;  fi

    if [ -f "$TMP"/"$FID"BIGFILES ]; then rm "$TMP"/"$FID"BIGFILES;  fi
    if [ -f "$TMP"/"$FID"SMALLFILES ]; then rm "$TMP"/"$FID"SMALLFILES;  fi

    printf "Fetching file IDs..."

    grep _DRIVE_ivd "$TMP"/"$FID"HTML | sed 's|x22|\n|g' | grep "$FID" -B 2 --no-group-separator | sed "/null/d" | grep x5b -B 1 --no-group-separator | sed "/x5/d" | sed 's|\\||g' | sort | uniq -u > "$FID"IDs

    # Using xargs for parallel threading, as we are doing multiple curl requests here, speeding up the process by n times.
    cat "$FID"IDs | xargs -n1 -P"$(($(nproc) * 2))" bash -c 'i=$0;
if curl -Is --write-out "%{http_code}" --output /dev/null "https://drive.google.com/drive/folders/$i" | grep 200 >/dev/null 2>&1; then 
	echo "$i" >> "$TMP"/"$FID"FOLDERS
else
	echo "$i" >> "$TMP"/"$FID"FILES
fi'

    # Print the number of big/small files detected.
    if [ -f "$TMP"/"$FID"FILES ]; then
        printf '\033[1A'
        printf "\\n%s files detected.   \\n" "$(wc -l < "$TMP"/"$FID"FILES)"
    fi

    printf 'Determing number of big|small files...'

    # Using xargs for parallel threading, as we are doing multiple curl requests here, speeding up the process by n times.
    cat "$TMP"/"$FID"FILES | xargs -n1 -P"$(($(nproc) * 2))" bash -c 'i=$0; 
if curl -Is "https://drive.google.com/uc?export=download&id=$i" | grep -i location >/dev/null 2>&1; then 
	echo "$i" >> "$TMP"/"$FID"SMALLFILES
else
	echo "$i" >> "$TMP"/"$FID"BIGFILES
fi'

    printf '\033[1A'
    printf "\\n%s big files, %s small files.           \\n" "$(if [ -f "$TMP"/"$FID"BIGFILES ]; then wc -l < "$TMP"/"$FID"BIGFILES; else echo "0"; fi)" "$(if [ -f "$TMP"/"$FID"SMALLFILES ]; then wc -l < "$TMP"/"$FID"SMALLFILES; else echo "0"; fi)"

    mkdir -p "$FOLDERNAME"

    if [ -f "$TMP"/"$FID"BIGFILES ]; then
        while IFS= read -r BID; do
            DOWNLOAD_BIGFILE "$BID"
        done < "$TMP"/"$FID"BIGFILES
    fi
    if [ -f "$TMP"/"$FID"SMALLFILES ]; then
        while IFS= read -r SID; do
            DOWNLOAD_SMALLFILE "$SID"
        done < "$TMP"/"$FID"SMALLFILES
    fi

    # Cleanup the temporary files after download.
    if [ -f "$TMP"/"$FID"HTML ]; then rm "$TMP"/"$FID"HTML;  fi
    if [ -f "$FID"IDs ]; then rm "$FID"IDs;  fi

    if [ -f "$TMP"/"$FID"FOLDERS ]; then rm "$TMP"/"$FID"FOLDERS;  fi
    if [ -f "$TMP"/"$FID"FILES ]; then rm "$TMP"/"$FID"FILES;  fi

    if [ -f "$TMP"/"$FID"BIGFILES ]; then rm "$TMP"/"$FID"BIGFILES;  fi
    if [ -f "$TMP"/"$FID"SMALLFILES ]; then rm "$TMP"/"$FID"SMALLFILES;  fi

    # This isn't necessary, but just in case of none of files downloaded and folder is empty.
    if ! ls -A "$FOLDERNAME" > /dev/null 2>&1; then rm -rf "$FOLDERNAME";  fi
}

EXTRACT_ID "$INPUT"
CHECK_URL "$ID"

# Type: Folder
if [ -n "$FOLDERID" ] > /dev/null 2>&1; then
    printf '\033[1A'
    printf '\nFolder Detected.                                       \n'
    DOWNLOAD_FOLDER_FILES "$FOLDERID"

# Type: Small Files
elif [ -n "$SMALLFILEID" ] > /dev/null 2>&1; then
    printf '\033[1A'
    printf '\nFile detected.                                         \n'
    DOWNLOAD_SMALLFILE "$SMALLFILEID"

# Type: Big Files
elif [ -n "$BIGFILEID" ] > /dev/null 2>&1; then
    printf '\033[1A'
    printf '\nFile detected.                                         \n'
    DOWNLOAD_BIGFILE "$BIGFILEID"
fi

# Delete the temporary folder only if no files are detected inside.
if ! ls -A "$TMP" > /dev/null 2>&1; then rm -rf "$TMP";  fi
