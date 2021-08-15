#!/usr/bin/env sh
# shellcheck source=/dev/null

###################################################
# check whether the given flag has been provided the required num of arguments
# to be used within flag functions
# Arguments:
#   ${1} = num of args
#   ${2} = all of the args
# return 0 or 1 with usage for the flag
###################################################
_parser_check_arguments() {
    nargs_parser_check_arguments="$((${1:?_parser_check_arguments}))"
    # because first argunent is num of args and second is the flag itself
    num_parser_check_arguments=$(($# - 2))

    [ "${num_parser_check_arguments}" -lt "${nargs_parser_check_arguments}" ] && {
        printf "%s\n" "${0##*/}: ${2}: flag requires ${nargs_parser_check_arguments} argument."
        printf "\n%s\n" "Help:"
        # print help for the respective flag
        printf "%s\n" "$(_usage "${2}")"
        exit 1
    }
    return 0
}

###################################################
# check if the given flag exists and set function name to a variae
# Arguments:
#   ${1} = flag
#   ${2} = var which will be set to function name
# example:
#   input: -p var1
#   output:
#     set var1 to "__flag_p"
###################################################
_flag_exists() {
    tmp_flag_exists="" option_flag_exists=""
    # use _flag_help function get the help contents and function name
    _flag_help "${1:?}" tmp_flag_exists option_flag_exists
    # then check if help is empty or not
    [ -z "${tmp_flag_exists}" ] && return 1
    _set_value d "${2:?}" "${option_flag_exists}"
}

###################################################
# fetch flag help and set the contents to a variable
# Arguments:
#   ${1} = flag
#   ${2} = var which will be set to help contents
#   ${3} = optional, var which will be set to flag name without dashes
# example:
#   input: -p var1 var2
#   output:
#     set var1 to "${_parser__help_p}"
#     set var2 to p
###################################################
_flag_help() {
    flag_flag_help=""
    # remove the dashes from the flags
    _trim "-" "${1:?_flag_help}" flag_flag_help
    _set_value i "${2:?_flag_help}" "_parser__help_${flag_flag_help}"
    _set_value d "${3:-_}" "${flag_flag_help}"
}

###################################################
# parse the given arguments as flags or normal input
###################################################
_parse_arguments() {
    # to set COLUMNS varibale
    DEBUG="" _check_debug
    # just a variable containing a newline
    __NEWLINE="
"
    # export a __BAR variable which is used in _add_flag function
    __BAR="$(_print_center "normal" "_" "_")"
    __BAR="${__BAR:+${__BAR}${__NEWLINE}}"

    ##########################
    # these global variables are actually used when _parser_setup_flags is running
    # _ALL_HELP contains all the help
    # _PARSER_ARGS_SHIFT contains the num of shift to be done for each arg
    # _PARSER_PREPROCESS_FUNCTION contains preprocess function contents
    unset _ALL_HELP _PARSER_ARGS_SHIFT _PARSER_PREPROCESS_FUNCTION
    # these flags are exported in _parser_setup_flag
    unset _PARSER_FLAGS _PARSER_CURRENT_FLAGS _PARSER_CURRENT_NARGS _PARSER_CURRENT_ARGS _PARSER_CURRENT_ARGS_TYPE
    ##########################

    # this will initialize help text and flag functions
    _parser_setup_flags || return 1
    # run the code required to run before parsing the arguments
    _parser_run_preprocess || return 1

    # TODO: remove usage of shift
    while [ "${#}" -gt 0 ]; do
        case "${1}" in
            # just ignore empty inputs
            '') : ;;
            -*)
                flag_parse_arguments=""
                if _flag_exists "${1}" flag_parse_arguments; then
                    "_parser_process_${flag_parse_arguments}" "${@}" || return 1
                else
                    printf "%s\n\n" "${0##*/}: ${1}: Unknown option"
                    _short_help
                fi
                ;;
                # anything not starting with - is added to be processed later
            *)
                _parser_process_input "${@}" || return 1
                ;;
        esac
        # add 1 shift for the current argument
        _PARSER_ARGS_SHIFT="$((_PARSER_ARGS_SHIFT + 1))"
        # now shift the arguments
        shift "${_PARSER_ARGS_SHIFT}"
        # reset the shift
        _PARSER_ARGS_SHIFT="0"
    done
    return 0
}

###################################################
# Remove the dashes from flags and set some global vars
# Arguments:
#   ${1} = flags seperated by space
#   ${2} = num of args required by the flag
#   ${3} = optional -> argument type - optional or required
#   ${4} = optional -> argument help text
# example:
#   input = "-p --parallel" 1 required "no of parallel downloads"
###################################################
_parser_setup_flag() {
    _PARSER_CURRENT_FLAGS="" tmp_parser_setup_flag=""
    _PARSER_FLAGS="${1:?_parser_setup_flag}"
    for f in ${_PARSER_FLAGS}; do
        _trim "-" "${f}" tmp_parser_setup_flag
        _PARSER_CURRENT_FLAGS="${_PARSER_CURRENT_FLAGS} ${tmp_parser_setup_flag}"
    done
    _PARSER_CURRENT_NARGS="${2:?_parser_setup_flag}"
    _PARSER_CURRENT_ARGS_TYPE="${3}"
    _PARSER_CURRENT_ARGS="${4}"
}

###################################################
# set flag help variable
# uses global variabled exported in _parser_setup_flag function
# Arguments:
#   ${1} = help contents
# set _parser__help_${flag_name} variable with help contents
# example: assuming "-p --parallel-jobs" 1 required "no of parallel downloads" was given to _parser_setup_flag
#   input: _parser_setup_flag_help "Download multiple files in parallel."
#   output: set _parser__help_p and _parser__help_paralleljobs
#   help text:
#      -p | --parallel-jobs "num of parallel downloads" [ Required ]
#
#         Download multiple files in parallel.
###################################################
_parser_setup_flag_help() {
    flags_parser_setup_flag_help="${_PARSER_CURRENT_FLAGS:?_parser_setup_flag_help}"
    nargs_parser_setup_flag_help="${_PARSER_CURRENT_NARGS:?_parser_setup_flag_help}"
    unset start_parser_setup_flag_help \
        help_parser_setup_flag_help \
        arg_parser_setup_flag_help \
        all_parser_setup_flag_help

    # run loop to add the indentation
    while IFS= read -r line <&4; do
        # 8 spaces
        help_parser_setup_flag_help="${help_parser_setup_flag_help}
        ${line}"
    done 4<< EOF
${1:?_parser_setup_flag_help}
EOF

    # add as a prefix on first help line
    for f in ${_PARSER_FLAGS:?_parser_setup_flag_help}; do
        # format as -p | --parallel
        start_parser_setup_flag_help="${start_parser_setup_flag_help:+${start_parser_setup_flag_help} | }${f}"
    done

    # check if to add argument help
    if ! [ "${nargs_parser_setup_flag_help}" = 0 ]; then
        # argument help should be inside double qoutes
        arg_parser_setup_flag_help="\"${_PARSER_CURRENT_ARGS:?_parser_setup_flag_help}\""
        # check if to add optional or required string
        # -p | --parallel-jobs "num of parallel downloads" [ Required ]
        if [ "${_PARSER_CURRENT_ARGS_TYPE}" = optional ]; then
            arg_parser_setup_flag_help="${arg_parser_setup_flag_help} [ Optional ]"
        else
            arg_parser_setup_flag_help="${arg_parser_setup_flag_help} [ Required ]"
        fi
    fi

    # add argument help to help, prepend 4 spaces
    start_parser_setup_flag_help="    ${start_parser_setup_flag_help} ${arg_parser_setup_flag_help}"

    # concatenate all the help text
    all_setup_help_flag="${start_parser_setup_flag_help}${__NEWLINE:?}${help_parser_setup_flag_help}"

    for f in ${flags_parser_setup_flag_help}; do
        # create _parser__help_p or _parser__help_paralleljobs var containing "help contents"
        _set_value d "_parser__help_${f}" "${all_setup_help_flag}"
    done

    # don't add to help of when given flag is input
    [ "${_PARSER_FLAGS}" = input ] && return 0

    # append current flag help content to _ALL_HELP
    _ALL_HELP="${_ALL_HELP}
${__BAR:-}
${all_setup_help_flag}" 2>| /dev/null
    # redirect to /dev/null as this will spam horribly in -x mode
}

###################################################
# append the given input to _PARSER_PREPROCESS_FUNCTION
# will be executed before parsing the arguments in _parser_run_preprocess function
# Arguments:
#   4<<EOF = code to be executed
###################################################
_parser_setup_flag_preprocess() {
    _is_fd_open 4 || return 1

    unset fn_parser_setup_flag_preprocess
    while IFS= read -r line <&4; do
        fn_parser_setup_flag_preprocess="${fn_parser_setup_flag_preprocess}
${line}"
    done

    _PARSER_PREPROCESS_FUNCTION="${_PARSER_PREPROCESS_FUNCTION}
${fn_parser_setup_flag_preprocess}"
}

###################################################
# Create a function which is used when a flag is passed
# add _parser_check_arguments "num of args" "${@}" if flag requires arguments
# funtion name will be _parser_process_${flag_name}
# Arguments:
#   4<<EOF = code to be executed
# example: assuming "-p --parallel-jobs" 1 required "no of parallel downloads" was given to _parser_setup_flag
#    input: _parser_setup_flag_process 4<<'EOF'
#               export NO_OF_PARALLEL_JOBS="${2}"
#               export PARALLEL_DOWNLOAD="parallel"
#               _parser_shift
#           EOF
#    output function:
#           _parser_process_p() {
#               # this added is because required and 1 were given to _parser_setup_flag
#               _parser_check_arguments 1 "${@}"
#               export NO_OF_PARALLEL_JOBS="${2}"
#               export PARALLEL_DOWNLOAD="parallel"
#               # this will shift the argyments list
#               _parser_shift
#           }
#           _parser_process_paralleljobs with contents
# note: a function can access all the later variables, not just ${1} and ${2}
#       _parser_shift should be used to shift the variables with the num of variables used except ${1}
# todo: remove shift usage
###################################################
_parser_setup_flag_process() {
    _is_fd_open 4 || return 1

    unset fn_parser_setup_flag_process

    # check if 1 and required were given to _parser_setup_flag
    if [ "${_PARSER_CURRENT_NARGS:?_parser_setup_flag_process}" -gt 0 ] && ! [ "${_PARSER_CURRENT_ARGS_TYPE}" = optional ]; then
        fn_parser_setup_flag_process="_parser_check_arguments ${_PARSER_CURRENT_NARGS:?_parser_setup_flag_process} \"\${@}\""
    fi

    while IFS= read -r line <&4; do
        fn_parser_setup_flag_process="${fn_parser_setup_flag_process}
${line}"
    done

    for f in ${_PARSER_CURRENT_FLAGS:?_parser_setup_flag_process}; do
        # create _parser_process_p and _parser_process_paralleljobs function, which will execute the function contents
        eval "_parser_process_${f}() { ${fn_parser_setup_flag_process} ; }"
    done
}

###################################################
# run the code required available in _PARSER_PREPROCESS_FUNCTION var
# use eval to make a function, then execute it
###################################################
_parser_run_preprocess() {
    eval "_parser_preprocess_setup() { ${_PARSER_PREPROCESS_FUNCTION:-:} ; }" &&
        _parser_preprocess_setup
}

###################################################
# function to set _PARSER_ARGS_SHIFT, used in _parse_arguments function
# Arguments:
#   ${1} = optional -> num of shifts to do
###################################################
_parser_shift() {
    export _PARSER_ARGS_SHIFT="${1:-1}"
}

_short_help() {
    printf "No valid arguments provided, use -h/--help flag to see usage.\n"
    exit 0
}
