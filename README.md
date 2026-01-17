<h1 align="center">Google drive downloader</h1>
<p align="center">
<a href="https://github.com/Akianonymus/gdrive-downloader/stargazers"><img src="https://img.shields.io/github/stars/Akianonymus/gdrive-downloader.svg?color=blueviolet&style=for-the-badge" alt="Stars"></a>
</p>
<p align="center">
<a href="https://github.com/Akianonymus/gdrive-downloader/actions"><img alt="Github Action Checks" src="https://img.shields.io/github/actions/workflow/status/Akianonymus/gdrive-downloader/.github/workflows/main.yml?branch=master&label=CI%20Checks&style=for-the-badge"></a>
</p>
<p align="center">
<a href="https://github.com/Akianonymus/gdrive-downloader/blob/master/LICENSE"><img src="https://img.shields.io/github/license/Akianonymus/gdrive-downloader.svg?style=for-the-badge" alt="License"></a>
</p>

 > gdrive-downloader is a collection of shell scripts runnable on Bash 4.x+.
 >
 > It can be used to to download files or folders from google gdrive.

- Minimal
- Authentication support ( not required for public files/folders ).
- Download gdrive files and folders
  - Download subfolders
- Resume Interrupted downloads
- Parallel downloading
- Pretty logging
- Easy to install and update
  - Self update
  - [Auto update](#updation)
  - Can be per-user and invoked per-shell, hence no root access required or global install.

## Table of Contents

- [Compatibility](#compatibility)
  - [Linux or MacOS](#linux-or-macos)
  - [Android](#android)
  - [iOS](#ios)
  - [Windows](#windows)
- [Installing and Updating](#installing-and-updating)
  - [Native Dependencies](#native-dependencies)
  - [Installation](#installation)
    - [Basic Method](#basic-method)
    - [Advanced Method](#advanced-method)
    - [Migrate from old version](#migrate-from-old-version)
  - [Updation](#updation)
- [Usage](#usage)
  - [Download Script Custom Flags](#download-script-custom-flags)
  - [Authentication](#authentication)
  - [Progress Bar](#progress-bar)
  - [Multiple Inputs](#multiple-inputs)
  - [Resuming Interrupted Downloads](#resuming-interrupted-downloads)
- [Uninstall](#Uninstall)
- [How it works](#how-it-works)
- [Reporting Issues](#reporting-issues)
- [Contributing](#contributing)
- [License](#license)

## Breaking Changes

### Version 4.0.0

- **New Dependency**: `jq` is now required for JSON parsing. Install `jq` before upgrading.
- **Internal Changes**: Migrated from custom delimiter system to Bash associative arrays for data handling.
- **JSON Parsing**: Rewrote internal JSON parsing to use `jq` instead of grep/sed for better reliability.

## Compatibility

As this is a collection of shell scripts, there aren't many dependencies. See [Native Dependencies](#native-dependencies) after this section for explicitly required program list.

### Linux or MacOS

For Linux or MacOS, you hopefully don't need to configure anything extra, it should work by default.

### Android

Install [Termux](https://wiki.termux.com/wiki/Main_Page).

Then, `pkg install curl` and done.

It's fully tested for all usecases of this script.

### iOS

Install [iSH](https://ish.app/)

While it has not been officially tested, but should work given the description of the app. Report if you got it working by creating an issue.

### Windows

Use [Windows Subsystem](https://docs.microsoft.com/en-us/windows/wsl/install-win10)

Again, it has not been officially tested on windows, there shouldn't be anything preventing it from working. Report if you got it working by creating an issue.

## Installing and Updating

 ### Native Dependencies
 
 This repo contains bash scripts.
 
 <strong>These programs are required:</strong>
 
 | Program          | Role In Script                                         |
 | ---------------- | ------------------------------------------------------ |
 | curl             | All network requests                                   |
 | xargs            | For parallel downloading                               |
 | mkdir            | To create folders                                      |
 | rm               | To remove files and folders                            |
 | grep             | Miscellaneous                                          |
 | sed              | Miscellaneous                                          |
 | mktemp           | To generate temporary files ( optional )               |
 | sleep            | Self explanatory                                       |
 | ps               | To manage different processes                          |
  | du               | To get actual file sizes                               |
  | jq               | JSON parsing                                           |

### Installation

You can install the script by automatic installation script provided in the repository.

Default values set by automatic installation script, which are changeable:

**Repo:** `Akianonymus/gdrive-downloader`

**Command name:** `gdl`

**Installation path:** `$HOME/.gdrive-downloader`

**Source value:** `master`

**Shell file:** `.bashrc` or `.zshrc` or `.profile`

For custom command name, repo, shell file, etc, see advanced installation method.

**Now, for automatic install script:**

To install gdrive-downloader in your system, you can run the below command:

```shell
curl -Ls --compressed https://github.com/Akianonymus/gdrive-downloader/raw/master/install.sh | sh -s
```

After the scripts have been downloaded, it will ask to add path to shell rc, follow the instructions.

Typically the command look likes this:

```
echo '[ -f "${HOME}/.gdrive-downloader/gdl" ] && [ -x "${HOME}/.gdrive-downloader/gdl" ] && PATH="${HOME}/.gdrive-downloader:${PATH}"' >> ~/.zshrc
```

where `.zshrc` can be `.bashrc` / `.profile` or any other file where you want to add.

Alternatively, to install globaly, run below commands:

```shell
curl -Ls --compressed  https://github.com/Akianonymus/gdrive-downloader/raw/master/install.sh | sudo sh -s -- --path /usr/local/bin
```

Note: Here /usr/local/bin can be /usr/bin or some other path.

#### Advanced Method

This section provides information on how to utilise the install.sh script for custom usescases.

These are the flags that are available in the install.sh script:

<details>

<summary>Click to expand</summary>

-   <strong>-p | --path <dir_name></strong>

    Custom path where you want to install the script.

    Note: For global installs, give path outside of the home dir like /usr/bin and it must be in the executable path already.

    ```shell
    curl -Ls --compressed  https://github.com/Akianonymus/gdrive-downloader/raw/master/install.sh | sudo sh -s -- --path /usr/bin
    ```

    ---

-   <strong>-c | --cmd <command_name></strong>

    Custom command name, after installation, script will be available as the input argument.

    ---

-   <strong>-r | --repo <Username/reponame></strong>

    Install script from your custom repo, e.g --repo Akianonymus/gdrive-downloader, make sure your repo file structure is same as official repo.

    ---

-   <strong>-b | --branch <branch_name></strong>

    Specify branch name for the github repo, applies to custom and default repo both.

    ---

-   <strong>-s | --shell-rc <shell_file></strong>

    Specify custom rc file, where PATH is appended, by default script detects .zshrc, .bashrc. and .profile.

    ---

-   <strong>-t | --time 'no of days'</strong>

    Specify custom auto update time ( given input will taken as number of days ) after which script will try to automatically update itself.

    Default: 5 ( 5 days )

    ---

-   <strong>-q | --quiet</strong>

    Only show critical error/sucess logs.

    ---

-   <strong>--skip-internet-check</strong>

    Do not check for internet connection, recommended to use in sync jobs.

    ---

-   <strong>-U | --uninstall</strong>

    Uninstall the script and remove related files.\n

    ---

-   <strong>-D | --debug</strong>

    Display script command trace.

    ---

-   <strong>-h | --help</strong>

    Display usage instructions.

    ---

Now, run the script and use flags according to your usecase.

E.g:

```shell
curl -Ls --compressed https://github.com/Akianonymus/gdrive-downloader/raw/master/install.sh | bash -s -- -r username/reponame -p somepath -s shell_file -c command_name -b branch_name
```
</details>

### Updation

If you have followed the automatic method to install the script, then you can automatically update the script.

There are three methods:

1.  Automatic updates

    By default, script checks for update after 3 days. Use -t / --time flag of install.sh to modify the interval.

    An update log is saved in "${HOME}/.gdrive-downloader/update.log".

1.  Use the script itself to update the script.

    `gdl -u or gdl --update`

    This will update the script where it is installed.

    <strong>If you use the this flag without actually installing the script,</strong>

    <strong>e.g just by `sh gdl.sh -u` then it will install the script or update if already installed.</strong>

1.  Run the installation script again.

    Yes, just run the installation script again as we did in install section, and voila, it's done.

**Note: Above methods always obey the values set by user in advanced installation,**
**e.g if you have installed the script with different repo, say `myrepo/gdrive-downloader`, then the update will be also fetched from the same repo.**

## Usage

After installation, no more configuration is needed for public files/folders.

But sometimes, downloading files from shared drive ( team drives ) errors. To tackle this, use `--key` flag and bypass that error. In case it still errors out, give your own api key as argument.

To get your own api key, go to `Retrieve API key` section in [auth.md](https://github.com/Akianonymus/gdrive-downloader/blob/master/auth.md).

Note: Even after specifying api key, don't recklessly download a file over and over, it will lead to 24 hr ip ban.

To handle the issue ( more of a abuse ) in above note, use oauth authentication.

Other scenario where oauth authentication is needed would be for downloading private files/folders. Go to [Authentication](#authentication) section for more info.

`gdl gdrive_id/gdrive_url`

Script supports argument as gdrive_url, or a gdrive_id, given those should be publicly available.

Now, we have covered the basics, move on to the next section for extra features and usage, like skipping sub folders, parallel downloads, etc.

### Download Script Custom Flags

These are the custom flags that are currently implemented:

-   <strong>-am | --alternate-method</strong>

    Use this flag to use alternate method of downloading.

    In default mode, all the folder information if fetched recursively and then download is started.

    In alternate mode, downloading is done one folder at a time.

    ---

-   <strong>-aria | --aria-flags 'flags'</strong>

    Use aria2c to download. "-aria" doesn't take arguments.

    To give custom flags as argument, use long flag, --aria-flags. e.g: --aria-flags '-s 10 -x 10'

    Note 1: aria2c can only resume google drive downloads if `-k/--key` or `-o/--oauth` option is used, otherwise, it will use curl.

    Note 2: aria split downloading won't work in normal mode ( without `-k` or `-o` flag ) because it cannot get the remote server size. Same for any other feature which uses remote server size.

    Note 3: By above notes, conclusion is, aria is basically same as curl in normal mode, so it is recommended to be used only with `--key` and `--oauth` flag.

    ---

-   <strong>-o | --oauth</strong>

    Use this flag to trigger oauth authentication.

    Note: If both --oauth and --key flag is used, --oauth flag is preferred.

    ---

-   <strong>--oauth-refetch-refresh-token</strong>

    Use this flag to trigger refetching of refresh token if existing refresh token is expired. 

    ---

-   <strong>-k | --key 'custom api key' ( optional argument )</strong>

    To download with api key. If api key is not specified, then the predefined api key will be used.

    Note: In-script api key surely works, but have less qouta to use, so it is recommended to use your own private key.

    To save your api key in config file, use `gdl --key default="your api key"`. API key will be saved in `${HOME}/.gdl.conf` and will be used from now on.

    Note: If both --key and --oauth flag is used, --oauth flag is preferred.

    ---

-   <strong>-c | --config 'config file path'</strong>

    Override default config file with custom config file.

    Default: ${HOME}/.gdl.conf

    ---

-   <strong>-d | --directory 'foldername'</strong>

    Custom workspace folder where given input will be downloaded.

    ---

-   <strong>-df | --document-format 'document type'</strong>

    Can be used for documents to be downloaded in different formats.

    Available formats are: docx, odt, rtf, pdf, txt, zip, epub, xlsx, ods, csv, tsv, pptx, odp, jpg, png, svg, json

    ---

-   <strong>-dr | --dry-run</strong>

    Just check if the url can be downloaded and exit the script.

    ---

-   <strong>-s | --skip-subdirs</strong>

    Skip downloading of sub folders present in case of folders.

    ---

-   <strong>-p | --parallel "num of parallel downloads"</strong>

    Download multiple files in parallel.

    Note:

    - This command is only helpful if you are downloding many files which aren't big enough to utilise your full bandwidth, using it otherwise will not speed up your download and even error sometimes,
    - 5 to 10 value is recommended. If errors with a high value, use smaller number.
    - Beaware, this isn't magic, obviously it comes at a cost of increased cpu/ram utilisation as it forks multiple bash processes to download ( google how xargs works with -P option ).

    ---

-   <strong>--proxy 'http://user:password@host:port'</strong>

    Specify a proxy to use, should be in the format accepted by curl --proxy and aria2c --all-proxy flag.

    ---

-   <strong>--speed 'speed'</strong>

    Limit the download speed, supported formats: 1K and 1M.

    ---

-   <strong>-ua | --user-agent 'user agent string'</strong>

    Specify custom user agent.

    ---

-   <strong>-R | --retry 'num of retries'</strong>

    Retry the file download if it fails, postive integer as argument. Currently only for file downloads.

    ---

-   <strong>-in | --include 'pattern'</strong>

    Only download the files which contain the given pattern - Applicable for folder downloads.

    e.g: `gdl gdrive_id --include '1'`, will only include with files with pattern '1' in the name.

    Regex can be used which works with grep -E command.

    ---

-   <strong>-ex | --exclude 'pattern'</strong>

    Only download the files which does not contain the given pattern - Applicable for folder downloads.

    e.g: `gdl gdrive_id --exclude '1'`, will only include with files with pattern '1' not present in the name.

    Regex can be used which works with grep -E command.

    ---

-   <strong>-l | --log 'log_file_name'</strong>

    Save downloaded files info to the given filename.

    ---

-   <strong>-q | --quiet</strong>

    Supress the normal output, only show success/error download messages for files, and one extra line at the beginning for folder showing no. of files and sub folders.

    ---

-   <strong>--verbose</strong>

    Display detailed message (only for non-parallel downloads).

    ---

-   <strong>--skip-internet-check</strong>

    Do not check for internet connection, recommended to use in sync jobs.

    ---

-   <strong>-V | --version | --info</strong>

    Show detailed info about script ( if script is installed system wide ).

    ---

-   <strong>-u | --update</strong>

    Update the installed script in your system, if not installed, then install.

    ---

-   <strong>--uninstall</strong>

    Uninstall the installed script in your system.

    ---

-   <strong>-h | --help 'flag name (optional)'</strong>

    Print help for all flags and basic usage instructions.

    To see help for a specific flag, --help flag_name ( with or without dashes )

    e.g: `gdl --help aria`

    ---

-   <strong>-D | --debug</strong>

    Display script command trace.

    ---

### Authentication

For oauth or api key authentication, see [auth.md](https://github.com/Akianonymus/gdrive-downloader/blob/master/auth.md)

#### First Run

On first run, the script asks for all the required credentials, which we have obtained in the previous section.

Execute the script: `gdl gdrive_url/gdrive_id -o`

Note: `-o/ --oauth` flag is needed if file should be downloaded with authentication.

Now, it will ask for following credentials:

**Client ID:** Copy and paste from credentials.json

**Client Secret:** Copy and paste from credentials.json

**Refresh Token:** If you have previously generated a refresh token authenticated to your account, then enter it, otherwise leave blank.
If you don't have refresh token, script outputs a URL on the terminal script, open that url in a web browser and tap on allow. Go back to terminal and press enter.

If everything went fine, all the required credentials have been set.

#### Config

After first run, the credentials are saved in config file. The config file is `${HOME}/.gdl.conf`.

To use a different one temporarily, see `-c / --config` custom in [Download Script Custom Flags](#download-script-custom-flags).

This is the format of a config file:

```shell
ACCOUNT_default_CLIENT_ID="client id"
ACCOUNT_default_CLIENT_SECRET="client secret"
ACCOUNT_default_REFRESH_TOKEN="refresh token"
ACCOUNT_default_ACCESS_TOKEN="access token"
ACCOUNT_default_ACCESS_TOKEN_EXPIRY="access token expiry"
```

where `default` is the name of the account.

You can use a config file in multiple machines, the values that are explicitly required are `CLIENT_ID`, `CLIENT_SECRET` and `REFRESH_TOKEN`.

`ACCESS_TOKEN` and `ACCESS_TOKEN_EXPIRY` are automatically generated using `REFRESH_TOKEN`.

A pre-generated config file can be also used where interactive terminal access is not possible, like Continuous Integration, docker, jenkins, etc

Just have to print values to `"${HOME}/.gdl.conf"`, e.g:

```shell
printf "%s\n" '
ACCOUNT_default_CLIENT_ID="client id"
ACCOUNT_default_CLIENT_SECRET="client secret"
ACCOUNT_default_REFRESH_TOKEN="refresh token"
' >| "${HOME}/.gdl.conf"
```

Note: Don't skip those backslashes before the double qoutes, it's necessary to handle spacing.

Note: If you have an old config, then nothing extra is needed, just need to run the script once and the default config will be automatically converted to the new format.

### Progress Bar

When downloading a file, or a folder ( except parallel downloading ), script shows progress bar for ongoing download.

```shell
================[ Downloaded: 4.6 GB | Left: 44.7 GB ]=================
------------------[ Speed: 48.0 MB/s | ETA: 15m10s ]-------------------
```

### Multiple Inputs

You can use multiple inputs without any extra hassle.

Pass arguments normally, e.g: `gdl url1 url2 id2 id2`

where url1 and url2 are drive urls and rest two are gdrive ids.

### Resuming Interrupted Downloads

Downloads interrupted either due to bad internet connection or manual interruption, can be resumed from the same position.

You can interrupt many times you want, it will resume ( hopefully ).

It will not download again if file is already present, thus avoiding bandwidth waste.

In normal mode of downloading, when aria is used, if interrupted, then it will be resumed by curl because aria cannot detect the remote file size.

But when `--key` or `--oauth` is used, it will resume successfully with aria too.

## Uninstall

If you have followed the automatic method to install the script, then you can automatically uninstall the script.

There are two methods:

1.  Use the script itself to uninstall the script.

    `gdl --uninstall`

    This will remove the script related files and remove path change from shell file.

1.  Run the installation script again with -U/--uninstall flag

    ```shell
    curl -Ls --compressed https://github.com/Akianonymus/gdrive-downloader/raw/master/install.sh | sh -s -- --uninstall
    ```

    Yes, just run the installation script again with the flag and voila, it's done.

**Note: Above methods always obey the values set by user in advanced installation.**

## How it works

In this section, the mechanism of the script it explained, if one is curious how it works to download folders as it is not supported officially.

The main catch here is that the script uses gdrive api to fetch details of a given file or folder id/url. But then how it is without authentication ?

Well, it does uses the api key but i have provided it in script. I have grabbed the api key from their gdrive file page, just open a gdrive folder on browser, open console and see network requests, open one of the POST requests and there you have it.

Also, google api key have a check for referer, so we pass referer with curl as `https://drive.google.com` to properly use the key.

Now, next steps are simple enough:

### Input Check

Main Function: `_check_id`

It parses the input and extract the file_id, then it does a network request to fetch name, size and mimetype of id.

If it's doesn't give http status 40*, then proceed.

In case of:

#### File

Main Function: `_download_file`

Before downloading, the script checks if file is already present. If present compare the file size to remote file size and resume the download if applicable.

Recent updates by google have the made the download links ip specific and very strict about cookies, so it can only be downloaded on the system where cookies was fetched.
Earlier, cookies was only needed for a file greater than 100 MB.

But either the case, the file can be moved to a different system and the script will resume the file from same position.

#### Folder

Main Function: `_download_folder`

First, all the files and sub folder details are fetched. Details include id and mimeType.

Now, it downloads the files using `_download_file` function, and in case of sub-folders, `_download_folder` function is repeated.

## Reporting Issues

| Issues Status | [![GitHub issues](https://img.shields.io/github/issues/Akianonymus/gdrive-downloader.svg?label=&style=for-the-badge)](https://GitHub.com/Akianonymus/gdrive-downloader/issues/) | [![GitHub issues-closed](https://img.shields.io/github/issues-closed/Akianonymus/gdrive-downloader.svg?label=&color=success&style=for-the-badge)](https://GitHub.com/Akianonymus/gdrive-downloader/issues?q=is%3Aissue+is%3Aclosed) |
| :-----------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------: | :-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |

Use the [GitHub issue tracker](https://github.com/Akianonymus/gdrive-downloader/issues) for any bugs or feature suggestions.

## Contributing

| Total Contributers | [![GitHub contributors](https://img.shields.io/github/contributors/Akianonymus/gdrive-downloader.svg?style=for-the-badge&label=)](https://GitHub.com/Akianonymus/gdrive-downloader/graphs/contributors/) |
| :----------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |

| Pull Requests | [![GitHub pull-requests](https://img.shields.io/github/issues-pr/Akianonymus/gdrive-downloader.svg?label=&style=for-the-badge&color=orange)](https://GitHub.com/Akianonymus/gdrive-downloader/issues?q=is%3Apr+is%3Aopen) | [![GitHub pull-requests closed](https://img.shields.io/github/issues-pr-closed/Akianonymus/gdrive-downloader.svg?label=&color=success&style=for-the-badge)](https://GitHub.com/Akianonymus/gdrive-downloader/issues?q=is%3Apr+is%3Aclosed) |
| :-----------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |

Submit patches to code or documentation as GitHub pull requests.

Make sure to run format_and_lint.sh and release.sh before making a new pull request.

If using a code editor, then use shfmt and shellcheck plugin instead of format_and_lint.sh

## License

[UNLICENSE](https://github.com/Akianonymus/gdrive-downloader/blob/master/LICENSE)
