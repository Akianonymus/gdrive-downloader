[![Actions Status](https://github.com/Akianonymus/gdrive-downloader/workflows/Checks/badge.svg)](https://github.com/akianonymus/Checks/actions)
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/f524510e62654ab5bcd2ec460e9efcf9)](https://www.codacy.com/manual/Akianonymus/gdrive-downloader?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=Akianonymus/gdrive-downloader&amp;utm_campaign=Badge_Grade)

# gdrive-downloader

## Why

The main reason i wrote this script is to download files inside the gdrive folders, without authentication.

But, since the new update, it uses gdrive api key to authenticate. Don't be sad, because here is the catch..
I have provided the api key for your use, but here is another fun fact, that api key belongs to google, so win win.
For more info on how i got the api key, go to [how it works](https://github.com/Akianonymus/gdrive-downloader#how-it-works) section.

See "old" branch for the ugly implementation.( try not to.. )

## Features

1.  Download files inside gdrive folders/files.
2.  Downloading files from recursive folders.
3.  Download files parallely.
4.  No dependencies at all.
5.  Resume partially downloaded files, just make sure you run command from same location and the file is there.
6.  Some custom flags.

## Installation

### Automatic

To install the script, just run the below commands in your terminal, either with wget or curl.

**Note:** The script assumes that current shell is either or bash or zsh, and respectively run the commands, if neither the case, do it manually.

`wget -qO- https://raw.githubusercontent.com/Akianonymus/gdrive-downloader/master/install | bash`

`curl -o- https://raw.githubusercontent.com/Akianonymus/gdrive-downloader/master/install | bash`

### Manual

git clone `https://github.com/Akianonymus/gdrive-downloader path/gdrive-downloader`

`alias gdl='bash path/gdrive-downloader/gdl'`

or Add gdl script to your PATH.

Done

## Usage

`gdl input`

 **Where "input" can be file/folder url or file/folder id.**

Usage: gdl options.. <file_url|id> or <folderurl|id>.

Options:

    -d | --directory <foldername> - option to download given input in custom directory.
  
    -s | --skip-subdirs - Skip download of sub folders present in case of folders.
  
    -p | --parallel <no_of_files_to_parallely_upload> - Download multiple files in parallel, Max value = 10.
  
    -i | --input - Specify multiple URLs/IDs in one command.
  
    -l | --log <file_to_save_info> - Save downloaded files info to the given filename.
  
    -v | --verbose - Display detailed message (only for non-parallel uploads).
  
    -V | --verbose-progress - Display detailed message and detailed upload progress(only for non-parallel uploads).

    -D | --debug - Display script command trace.
  
    -u | --update - Update gdrive downloader.

    -h | --help - Display usage instructions.
  
### Supported input types

You can either give url or file id as input, both works.
See the [test script](https://github.com/Akianonymus/gdrive-downloader/test) to see which URL formats are supported.

 **Note: Use single or double qoutes on urls having special characters like `&` .**

If some URL format isn't working, make to sure create an issue.

## Updates

For updating, just run gdl --update/-U.

It will update the script to the latest version available on github automatically.

## Compatibility

Basically it will run on every unix based system, and have a proper bash setup, and i am assuming that you don't have old enough system which doesn't ship basic tools like **curl**, **wget**, **awk**, **sed**, etc...

Problem arises in case of android, because android isn't shipped with wget or **gawk**(awk), or if you have an old android system, even your curl will be of old version and may create problems.

For this, just install **termux**, it comes with these tools and latest compiled, just make sure to configure your shell file before running the automatic script, also make sure to install wget and curl, if missing.
`pkg install curl wget`

But for curiosity, here are the tools explicitly required:

1.  Bash ( 4.x )
2.  wget and curl
3.  grep
4.  sed
5.  xargs

## How it works

The catch here is that i use drive v3 api, but without oauth authentication, enabling us to fetch the details with just the api key, which can be shared publicly because it belongs to google.

### API KEY

I have grabbed the api key from their gdrive file page, just open a gdrive folder on browser, open console and see network requests, open one of the POST requests and there you have it.

Also, google api key have a check for referer, so we pass referer with curl/wget as `https://drive.google.com` to use the key.

### URL Check

Intially, it parses the input and extract the fileid, check if it's public/available, then proceed.

Afterwards, in case of:

### Folder

First it fetches the name of the folder, then all the id and mimeType of files and sub-folders.

Then it downloads the individual files using `downloadFolder` function.

In case of sub-folders, just repeat the process and download subfiles inside it, which can be skipped by -s/--skip-subdirs option.

### Files

Fetches the id, name and size of files, then simply download it using the api key.

  **Also**, **another** **feature** the script has is to resume the partially downloaded files if already present in the path, but not full size, script checks for the size and compare to the size reported by server and [execute the script accordingly](https://github.com/Akianonymus/gdrive-downloader/blob/master/gdl#L176).

  **How do i achieve this ?**
   By using wget -c flag which gives the ability to resume partially downloaded files.

## To do list

As i am using the official api, there can be many features, here are some of which i have thought about.

1.  Give direct download links of file URLs, and print to the user, which could be downloaded externally ( not possible now because links are IP specific ).
2.  You tell me :).

## Sane pull requests / suggestions / issues reports are always welcome

**Note:** Before submitting a pull request, make sure to run [format](https://github.com/Akianonymus/gdrive-downloader/blob/master/format) script and it should pass shellcheck warnings.

If you would like to query something, contact me at [telegram](https://t.me/Akianonymus).
