# gdrive-downloader

## Why

The main reason i wrote this script is to download files inside the gdrive folders, without authentication.

But, since the new update, it uses gdrive api key to authenticate, but still doesn't need Oauth.
In simple words, it still doesn't need any authentication from your side, my api key is in the script, and limit is literally unlimited, so win win.

See "old" branch for the ugly implementation.

## Features

 1. Download files inside gdrive folders.
 2. Download files.
 3. Doesn't need any extra dependency, just barebone tools which almost every unix based system is shipped with. Analyze the script and find out.
 4. Resume partially downloaded files, just make sure you run command from same location and the file is there.
 5. Uses google drive v3 api, but without Oauth authentication, see [How it works](#how-it-works) section.

## Installation

### Automatic

To install the script, just run the below commands in your terminal, either with wget or curl.

**Note:** The script assumes that current shell is either or bash or zsh, and respective run commands files, if neither the case, do it manually.

`wget -qO- https://raw.githubusercontent.com/Akianonymus/gdrive-downloader/master/install.sh | bash`

`curl -o- https://raw.githubusercontent.com/Akianonymus/gdrive-downloader/master/install.sh | bash`

### Manual

git clone `https://github.com/Akianonymus/gdrive-downloader path/gdrive-downloader`

`alias gdl='bash path/gdrive-downloader/gdl.sh'`

Done

## Usage

`gdl input`

 **Where "input" can be file/folder url or file/folder id.**

### Supported input types

You can either give url or file id as input, both works.
See the [test script](https://github.com/Akianonymus/gdrive-downloader/test.sh) to see which URL formats are supported.

**Note: Use single or double qoutes on urls having special characters like `&` .**

If some URL format isn't working, make to sure create a issue.

## Compatibility

Basically it will run on every unix based system, and have a proper shell setup, and i am assuming that you don't have old enough system which doesn't ship basic tools like **curl**, **wget**, **awk**, **sed**, etc...

Problem arises in case of android, because android isn't shipped with wget or **gawk**(awk), or if you have an old android system, even your curl will be of old version and may create problems.

For this, just install **termux**, it comes with these tools and latest compiled, just make sure to configure you shell file before running the automatic script, also make sure to install wget and curl, if missing.
`pkg install curl wget`

## Updates

If you have followed the automatic way of installation, then just run `update_gdl`.
If will fetch if any updates available.

But for manual way, just git pull the repo.

## How it works

The catch here is i use the drive v3 api, but without oauth authentication, enabling us to fetch the details with just the api key, which can be shared publicly without harming my account.

At first, it does,

[URL Check](https://github.com/Akianonymus/gdrive-downloader/blob/master/gdl.sh#L43-#L77)
Intially, it parses the input and extract the fileid, check if it's public/available, then proceed.

then
In case of:

[**Folder:**](https://github.com/Akianonymus/gdrive-downloader/blob/master/gdl.sh#L172-#L233)
First it fetches all the id, name and size of files and name and id of sub-folders, then, name of the folder of given id/url.
Currently script only supports download files inside the folder, not the files inside the sub-folders, added to my to do list.

[**Files:**](https://github.com/Akianonymus/gdrive-downloader/blob/master/gdl.sh#L80-#L133)
Fetches the id, name and size of files, then simply download it using the api key.

  **Also**, **another** **feature** the script has is to resume the partially downloaded files if already present in the path, but not full size, script checks for the size and compare to the size reported by server and [execute the script accordingly](https://github.com/Akianonymus/gdrive-downloader/blob/master/gdl.sh#L142).

  **How do i achieve this ?**
   By using wget -c flag which gives the ability to resume partially downloaded files.

## To do list

As i am using the official api, there can be tons of features, here are some of which i have thought about.

 1. Downloading files from recursive folders.
 2. Multiple Threading for download, probably by using axel.
 3. Specifying download directory.
 4. Specifying multiple URLs.
 5. Give direct download links of file URLs, and print to the user, which could be downloaded externally.

## Sane pull requests / suggestions / issues reports are always welcome

**Note:** Before submitting a pull request, make sure to run [format.sh](https://github.com/Akianonymus/gdrive-downloader/blob/master/format.sh) script.

If you would like to query something, contact me at [telegram](https://t.me/Akianonymus).
