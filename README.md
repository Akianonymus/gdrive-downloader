# gdrive-downloader

## Why ?

The main reason i wrote this script is to download files inside the gdrive folders, without authentication, just as a [POC](https://en.m.wikipedia.org/wiki/Proof_of_concept).

There are great tools like [gdrive](https://github.com/gdrive-org/gdrive) which can recursively download folders, but as i mentioned earlier, needs authentication. 

## Features.

1. Download files inside gdrive folders.
2. Download files, both small and big files [ for more info, go to [How it works](#how-it-works-) section ].
3. Doesn't need any extra dependency, just barebone tools which almost every unix based system is shipped with. Analyze the script and find out.
4. Resume partially downloaded files, just make sure you run command from same location and the file is there.

## Installation.

### Automatic
To install the script, just run the below commands in your terminal, either with wget or curl.

**Note:** The script assumes that current shell is either or bash or zsh, and respective [bash|zsh]rc files, if neither the case, if available, it tries to write to .profile file.

`wget -qO- https://raw.githubusercontent.com/Akianonymus/gdrive-downloader/master/install.sh | bash`

`curl -o- https://raw.githubusercontent.com/Akianonymus/gdrive-downloader/master/install.sh | bash`

### Manual
git clone https://github.com/Akianonymus/gdrive-downloader path/gdrive-downloader
            
`alias drivedl='bash path/gdrive-downloader/drivedl.sh'`
            
Done

## Usage.

`drivedl input`

 **Where "input" can be file/folder url or file/folder id.**
 
### Supported input types
You can either give url or file id as input, both works.
See the [test script](https://github.com/Akianonymus/gdrive-downloader/test.sh) to see which URL formats are supported.

**Note: Use single or double qoutes on urls having  `&` or `-`.**
```
curl gdrive.sh | bash -s 'https://drive.google.com/folderview?id=0B7EVK8r0v71peklHb0pGdDl6R28--b&usp=sharing'
```
or
```
curl gdrive.sh | bash -s "https://drive.google.com/folderview?id=0B7EVK8r0v71peklHb0pGdDl6R28--b&usp=sharing"
```
If some URL format isn't working, make to sure create a issue.

## Compatibility

Basically it will run on every unix based system, and have a proper shell setup, and i am assuming that you don't have old enough system which doesn't ship basic tools like **curl**, **wget**, **awk**, **sed**, etc...

Problem arises in case of android, because android isn't shipped with wget or **gawk**(awk), or if you have an old android system, even your curl will be of old version and may create problems.

For this, just install **termux**, it comes with these tools and latest compiled, just make sure to configure you shell file before running the automatic script, also make sure to install wget and curl, if missing.
`pkg install curl wget`

## Updates

If you have followed the automatic way of installation, then just run `update_drivedl`.
If will fetch if any updates available.

But for manual way, just git pull the repo.

## How it works ?

Well, here comes the ugly part.

[**Folder:**](https://github.com/Akianonymus/gdrive-downloader/blob/master/drivedl.sh#L270)
The script scrapes the html of given folder ID/URL to get the IDs of files and folders inside it.
Currently script only supports download files, not the files inside the sub-folders, added to my to do list.

As it's scraping html files, it comes with limitations **:(**.

**Files:**
Gdrive files can be categorised in two types:

1. [**Small Files**](https://github.com/Akianonymus/gdrive-downloader/blob/master/drivedl.sh#L82)
 `Files ≤ 100 MB`

 These files can be directly downloaded if you just place   the **ID** in below url format:
 `https://drive.google.com/uc?id=ID&export=download`
 
 Then just  `wget url` and done.
 
2. [**Big Files**](https://github.com/Akianonymus/gdrive-downloader/blob/master/drivedl.sh#L128)
 `Files > 100 MB`

  The method i mentioned above won't work in this case. 
 
   **Why ?**
        Because gdrive adds an extra authentication for these big files.
        If you have downloaded big files before, you must have come across the "Cannot scan this file bla bla bla" page, then an extra tap and it downloads".

   **How the script does it ?**
       It uses a great tool called wget to setup the cookies and do the [required process](https://github.com/Akianonymus/gdrive-downloader/blob/master/drivedl.sh#L174).

   **Note**: Same can be achieved with curl too.
   
   **Also**, **another** **feature** the script has is to resume the partially downloaded files if already present in the path, but not full size, script checks for the size and compare to the size reported by server and [execute script accordingly](https://github.com/Akianonymus/gdrive-downloader/blob/master/drivedl.sh#L163).
   
   **How do i achieve this ?** 
   By using wget -c flag which gives the ability to resume partially downloaded files.

## To do list.
1. Downloading files from recursive folders.
2. Multiple Threading for download.
3. Download directory.
4. Specifying multiple URLs.
5. Give direct download links of file URLs, and print to the user, which could be downloaded externally.
6. Remove the below limitation.

## Limitation.
We already know the script uses HTML scraping for doing folder work [ get the file IDs and stuff ].

But actually, that only works if your folder contain less or equal to **49** files, yes 49, not the other number.

**Why 49 ?** 
Because google only loads 49 files at time when a request is made for the folder page, hence the downloaded HTML containing those IDs.
I don't know how am i supposed to fetch the next chunk of files, so...
 
If you would like to help, contact me at [telegram](https://t.me/Akianonymus)

## Sane pull requests / suggestions / issues reports are always welcome.
**Note:** Before submitting a pull request, make sure to run [format.sh](https://github.com/Akianonymus/gdrive-downloader/blob/master/format.sh) script.
