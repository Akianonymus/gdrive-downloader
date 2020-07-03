<h1 align="center">Google drive downloader</h1>
<p align="center">
<a href="https://github.com/Akianonymus/gdrive-downloader/stargazers"><img src="https://img.shields.io/github/stars/Akianonymus/gdrive-downloader.svg?color=blueviolet&style=for-the-badge" alt="Stars"></a>
</p>
<p align="center">
<a href="https://www.codacy.com/manual/Akianonymus/gdrive-downloader?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=Akianonymus/gdrive-downloader&amp;utm_campaign=Badge_Grade"><img alt="Codacy grade" src="https://img.shields.io/codacy/grade/f524510e62654ab5bcd2ec460e9efcf9/master?style=for-the-badge"></a>
<a href="https://github.com/Akianonymus/gdrive-downloader/actions"><img alt="Github Action Checks" src="https://img.shields.io/github/workflow/status/Akianonymus/gdrive-downloader/Checks/master?label=CI%20Checks&style=for-the-badge"></a>
</p>
<p align="center">
<a href="https://github.com/Akianonymus/gdrive-downloader/blob/master/LICENSE"><img src="https://img.shields.io/github/license/Akianonymus/gdrive-downloader.svg?style=for-the-badge" alt="License"></a>
</p>

> gdrive-downloader is a collection of bash compliant scripts to download google drive files and folders.

- Minimal
- No authentication required
- Download gdrive files and folders
  - Download subfolders
- Resume Interrupted downloads
- Parallel downloading
- Pretty logging
- Easy to install and update
  - Auto update

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
  - [Multiple Inputs](#multiple-inputs)
  - [Resuming Interrupted Downloads](#resuming-interrupted-downloads)
- [Uninstall](#Uninstall)
- [How it works](#how-it-works)
- [Reporting Issues](#reporting-issues)
- [Contributing](#contributing)
- [License](#license)

## Compatibility

As this repo is bash compliant, there aren't many dependencies. See [Native Dependencies](#native-dependencies) after this section for explicitly required program list.

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

The script explicitly requires the following programs:

| Program       | Role In Script                                         |
| ------------- | ------------------------------------------------------ |
| bash          | Execution of script                                    |
| curl          | All network requests in the script                     |
| xargs         | For parallel downloading                               |
| mkdir         | To create folders                                      |
| rm            | To remove temporary files                              |
| grep          | Miscellaneous                                          |
| sed           | Miscellaneous                                          |

### Installation

You can install the script by automatic installation script provided in the repository.

Default values set by automatic installation script, which are changeable:

**Repo:** `Akianonymus/gdrive-downloader`

**Command name:** `gdl`

**Installation path:** `$HOME/.gdrive-downloader`

**Source value:** `master`

**Shell file:** `.bashrc` or `.zshrc` or `.profile`

For custom command name, repo, shell file, etc, see advanced installation method.

**Now, for automatic install script, there are two ways:**

#### Basic Method

To install gdrive-downloader in your system, you can run the below command:

```shell
bash <(curl --compressed -s https://raw.githubusercontent.com/Akianonymus/gdrive-downloader/master/install.sh)
```

and done.

#### Advanced Method

This section provides information on how to utilise the install.sh script for custom usescases.

These are the flags that are available in the install.sh script:

<details>

<summary>Click to expand</summary>

-   <strong>-i | --interactive</strong>

    Install script interactively, will ask for all the variables one by one.

    Note: This will disregard all arguments given with below flags.

    ---

-   <strong>-p | --path <dir_name></strong>

    Custom path where you want to install the script.

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

-   <strong>--skip-internet-check</strong>

    Do not check for internet connection, recommended to use in sync jobs.

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
bash <(curl --compressed -s https://raw.githubusercontent.com/Akianonymus/gdrive-downloader/master/install.sh) -r username/reponame -p somepath -s shell_file -c command_name -b branch_name
```
</details>

#### Migrate from old version

If you have old gdrive-downloader installed in your system, then run below command and then do the installation command

```shell
rm -rf "${HOME}/.gdrive-downloader"
```

Remove any previously set alias to the gdl command.

### Updation

If you have followed the automatic method to install the script, then you can automatically update the script.

There are three methods:

1.  Use the script itself to update the script.

    `gdl -u or gdl --update`

    This will update the script where it is installed.

    <strong>If you use the this flag without actually installing the script,</strong>

    <strong>e.g just by `bash gdl.sh -u` then it will install the script or update if already installed.</strong>

1.  Run the installation script again.

    Yes, just run the installation script again as we did in install section, and voila, it's done.

1.  Automatic updates

    By default, script checks for update after 3 days. Use -t / --time flag of install.sh to modify the interval.

    An update log is saved in "${HOME}/.gdrive-downloader/update.log".

**Note: Above methods always obey the values set by user in advanced installation,**
**e.g if you have installed the script with different repo, say `myrepo/gdrive-downloader`, then the update will be also fetched from the same repo.**

## Usage

After installation, no more configuration is needed.

`gdl gdrive_id/gdrive_url`

Script supports argument as gdrive_url, or a gdrive_id, given those should be publicly available.

Now, we have covered the basics, move on to the next section for extra features and usage, like skipping sub folders, parallel downloads, etc.

### Download Script Custom Flags

These are the custom flags that are currently implemented:

-   <strong>-d | --directory 'foldername'</strong>

    Custom workspace folder where given input will be downloaded.

    ---

-   <strong>-s | --skip-subdirs</strong>

    Skip downloading of sub folders present in case of folders.

    ---

-   <strong>-p | --parallel <no_of_files_to_parallely_download></strong>

    Download multiple files in parallel.

    Note:

    - This command is only helpful if you are downloding many files which aren't big enough to utilise your full bandwidth, using it otherwise will not speed up your download and even error sometimes,
    - 5 to 10 value is recommended. If errors with a high value, use smaller number.
    - Beaware, this isn't magic, obviously it comes at a cost of increased cpu/ram utilisation as it forks multiple bash processes to download ( google how xargs works with -P option ).

    ---

-   <strong>--speed 'speed'</strong>

    Limit the download speed, supported formats: 1K, 1M and 1G.

    ---

-   <strong>-l | --log 'log_file_name'</strong>

    Save downloaded files info to the given filename.

    ---

-   <strong>-v | --verbose</strong>

    Display detailed message (only for non-parallel uploads).

    ---

-   <strong>--skip-internet-check</strong>

    Do not check for internet connection, recommended to use in sync jobs.

    ---

-   <strong>-V | --version</strong>

    Show detailed info, only if script is installed system wide.

    ---

-   <strong>-u | --update</strong>

    Update the installed script in your system, if not installed, then install.

    ---

-   <strong>--uninstall</strong>

    Uninstall the installed script in your system.

    ---

-   <strong>-h | --help</strong>

    Display usage instructions.

    ---

-   <strong>-D | --debug</strong>

    Display script command trace.

    ---

### Multiple Inputs

You can use multiple inputs without any extra hassle.

Pass arguments normally, e.g: `gdl url1 url2 id2 id2`

where usr1 and usr2 is drive urls and rest two are gdrive ids.

### Resuming Interrupted Downloads

Downloads interrupted either due to bad internet connection or manual interruption, can be resumed from the same position.

You can interrupt many times you want, it will resume ( hopefully ).

It will not download again if file is already present, thus avoiding bandwidth waste.

## Uninstall

If you have followed the automatic method to install the script, then you can automatically uninstall the script.

There are two methods:

1.  Use the script itself to uninstall the script.

    `gdl --uninstall`

    This will remove the script related files and remove path change from shell file.

1.  Run the installation script again with -U/--uninstall flag

    ```shell
    bash <(curl --compressed -s https://raw.githubusercontent.com/Akianonymus/gdrive-downloader/master/install.sh) --uninstall
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

Submit patches to code or documentation as GitHub pull requests. Make sure to run format.sh before making a new pull request.

## License

[UNLICENSE](https://github.com/Akianonymus/gdrive-downloader/blob/master/LICENSE)
