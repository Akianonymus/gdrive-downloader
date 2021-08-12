#!/usr/bin/env sh
# shellcheck source=/dev/null

###################################################
# Create help variables using _set_help function
# export a _HELP_BAR variable which is used in _set_help function
# also export ALL_HELP containing all the help content
###################################################
_create_help() {

    ###################################################

    _set_help "-aria --aria-flags" \
        'flags' \
        "use aria2c to download. '-aria' does not take arguments." \
        "To give custom flags as argument, use long flag, --aria-flags. e.g: --aria-flags '-s 10 -x 10'

Note 1: aria2c can only resume google drive downloads if '-k/--key' or '-o/--oauth' option is used.

Note 2: aria split downloading won't work in normal mode ( without '-k' or '-o' flag ) because it cannot get the remote server size. Same for any other feature which uses remote server size.

Note 3: By above notes, conclusion is, aria is basically same as curl in normal mode, so it is recommended to be used only with '--key' and '--oauth' flag."

    ###################################################

    _set_help "-o --oauth" \
        "" \
        "Use this flag to trigger oauth authentication." \
        "Note: If both --oauth and --key flag is used, --oauth flag is preferred."

    ###################################################

    _set_help "-a --account" \
        "account name" \
        "Use different account than the default one." \
        "To change the default account name, use this format, -a/--account default=account_name"

    ###################################################

    _set_help "-la --list-accounts" \
        "" \
        "Print all configured accounts in the config files."

    ###################################################

    _set_help "-ca --create-account" \
        "account name" \
        "To create a new account with the given name if does not already exists."

    ###################################################

    _set_help "-da --delete-account" \
        "account name" \
        "To delete an account information from config file."

    ###################################################

    _set_help "-k --key" \
        "API KEY( optional )" \
        "To download with api key. If api key is not specified, then the predefined api key will be used." \
        "To save your api key in config file, use 'gdl --key default=your api key'.

     API key will be saved in '/data/data/com.termux/files/home/.gdl.conf' and will be used from now on.

     Note: If both --key and --key oauth is used, --oauth flag is preferred."

    ###################################################

    _set_help "-c --config" \
        "config file path" \
        "Override default config file with custom config file. Default: /data/data/com.termux/files/home/.gdl.conf"

    ###################################################

    _set_help "-d --directory" \
        "foldername" \
        "To download given input in custom directory."

    ###################################################

    _set_help "-s --skip-subdirs" \
        "" \
        "Skip downloading of sub folders present in case of folders."

    ###################################################

    _set_help "-p --parallel" \
        "no of files to parallely download" \
        "Download multiple files in parallel."

    ###################################################

    _set_help "--proxy" \
        "http://user:password@host:port" \
        "Specify a proxy to use, should be in the format accepted by curl --proxy and aria2c --all-proxy flag."

    ###################################################

    _set_help "--speed" \
        "speed" \
        "Limit the download speed, supported formats: 1K and 1M."

    ###################################################

    _set_help "-ua --user-agent" \
        "user agent string" \
        "Specify custom user agent."

    ###################################################

    _set_help "-R --retry" \
        "num of retries" \
        "Retry the file upload if it fails, postive integer as argument. Currently only for file uploads."

    ###################################################

    _set_help "-in --include" \
        "pattern" \
        "Only download the files which contain the given pattern - Applicable for folder downloads." \
        "e.g: gdl local_folder --include '1', will only include with files with pattern '1' in the name. Regex can be used which works with grep -E command."

    ###################################################

    _set_help "-ex --exclude" \
        "pattern" \
        "Only download the files which does not contain the given pattern - Applicable for folder downloads." \
        "e.g: gdl local_folder --exclude '1', will only include with files with pattern '1' not present in the name. Regex can be used which works with grep -E command."

    ###################################################

    _set_help "-l --log" \
        "file to save info" \
        "Save downloaded files info to the given filename."

    ###################################################

    _set_help "-q --quiet" \
        "" \
        "Supress the normal output, only show success/error upload messages for files, and one extra line at the beginning for folder showing no. of files and sub folders."

    ###################################################

    _set_help "--verbose" \
        "" \
        "Display detailed message (only for non-parallel uploads)"

    ###################################################

    _set_help "--skip-internet-check" \
        "" \
        "Do not check for internet connection, recommended to use in sync jobs."

    ###################################################

    _set_help "-V --version --info" \
        "" \
        "Show detailed info, only if script is installed system wide."

    ###################################################

    _set_help "-D --debug" \
        "" \
        "Display script command trace."

    ###################################################

    _set_help "-h --help" \
        "flag name (optional)" \
        "Print help for all flags and basic usage instructions." \
        "To see help for a specific flag, --help flag_name ( with or without dashes )
e.g: ${0##*/} --help aria"

    ###################################################

    # should be only available if installed using install script
    [ "${GDL_INSTALLED_WITH:-}" = script ] && {
        _set_help "-u --update" \
            "" \
            "Update the installed script in your system."

        _set_help "--uninstall" \
            "" \
            "Uninstall script, remove related files."
    }
    ###################################################

    ALL_HELP="
The script can be used to download file/directory from google drive.

Usage: ${0##*/} [options.. ] <file_[url|id]> or <folder[url|id]>

Options:${ALL_HELP}"

}

_short_help() {
    printf "No valid arguments provided, use -h/--help flag to see usage.\n"
    exit 0
}

###################################################
# 1st arg - can be flag name
# if 1st arg given, print specific flag help
# otherwise print full help
###################################################
_usage() {
    DEBUG="" _check_debug
    _HELP_BAR="$(_print_center "normal" "_" "_")"
    [ -n "${_HELP_BAR}" ] && export _HELP_BAR="${_HELP_BAR}
"

    ###################################################
    # 1st arg = flags seperated by spaces
    # 2nd arg = Flag argument type if required ( can be empty )
    # 3rd arg = First help line
    # 4rd arg = rest of the help lines
    # export help_flag_name variable and append the help contents to ALL_HELP variable
    # input - "-p --parallel" "num of jobs" "Specify num of parallel jobs" "Must be between 1 to 10"
    # output:
    #    -p | --parallel 'num of jobs' => Specify num of parallel jobs
    #        Must be between 1 to 10
    ###################################################
    _set_help() {
        content1_set_help="${3}" content2_set_help="" all_content_set_help=""
        [ -n "${4}" ] && {
            # add a new line to the start
            content2_set_help="
"
            while read -r line <&4; do
                # 8 spaces
                content2_set_help="${content2_set_help}
        ${line}"
            done 4<< EOF
${4}
EOF
        }

        # add as a prefix on first help line
        start_set_help=""
        for f in ${1}; do
            start_set_help="${start_set_help:+${start_set_help} | }${f}"
        done

        # append at the end of first help line if 2nd arg is given
        # append 4 spaces
        start_set_help="    ${start_set_help} ${2:+\"${2}\"} => "

        all_content_set_help="${start_set_help}${content1_set_help}${content2_set_help}"
        _flag_help set "${1}" "${all_content_set_help}"

        ALL_HELP="${ALL_HELP}
${_HELP_BAR}
${all_content_set_help}"
    }

    # create help variables and help content
    _create_help

    [ -n "${1}" ] && {
        tmp_help_usage=""
        _flag_help get tmp_help_usage "${1}"

        if [ -z "${tmp_help_usage}" ]; then
            printf "%s\n" "Error: No help found for ${1}"
        else
            printf "%s\n%s\n%s\n" "${_HELP_BAR}" "${tmp_help_usage}" "${_HELP_BAR}"
        fi
        exit 0
    }

    printf "%s\n" "${ALL_HELP}"
    exit 0
}
