#!/usr/bin/env bash

set -euo pipefail

if [[ "${NO_COLOR-}" = "" && ( -t 1 || "${FORCE_COLOR-}" != "" ) ]]; then
    C_RESET='\033[0m'
    C_RED='\033[0;31m'
    C_GREEN='\033[0;32m'
    C_YELLOW='\033[0;33m'
    C_DIM='\033[0;37m'
    C_BOLD='\033[1m'
    PROGRESS=-#
else
    C_RESET=
    C_RED=
    C_GREEN=
    C_YELLOW=
    C_DIM=
    C_BOLD=
    PROGRESS=-Ss
fi

announce() {
    echo -e "${C_BOLD}$1${C_RESET}" "$2" >&2
}

fail() {
    echo -e "${C_RED}$1${C_RESET}" "$2" >&2
    exit 1
}

pass() {
    echo -e "${C_GREEN}$1${C_RESET}" "$2" >&2
}

ignore() {
    echo -e "${C_YELLOW}$1${C_RESET}" "$2" >&2
}

start_debug() {
    echo -e "${C_DIM}$1" >&2
}

end_debug() {
    echo -en "${C_RESET}" >&2
}

readonly INST_NAME=goup
readonly LANG_NAME=Go
readonly TOOL_NAME=go
readonly VERSION=0.1.2

readonly INST_DIR="${INST_DIR-$HOME/.$INST_NAME}"
readonly TOOL_DIR=${TOOL_DIR-$HOME/.$TOOL_NAME}
readonly TOOL_URL_LIST=${TOOL_URL_LIST-https://go.dev/dl/?mode=json&include=all}
readonly TOOL_URL_LATEST=${TOOL_URL_LATEST-https://go.dev/dl/?mode=json}
readonly TOOL_URL_DIR=${TOOL_URL_DIR-https://dl.google.com/go}

print_usage_instructions() {
    echo -e "${C_BOLD}$INST_NAME $VERSION${C_RESET} - upgrade to the latest or manage more versions of $LANG_NAME

${C_BOLD}Usage${C_RESET}: $INST_NAME <task> [version]
${C_BOLD}Tasks${C_RESET}:
  current              print the currently selected version of $LANG_NAME
  latest               print the latest version of $LANG_NAME for download
  local                print versions of $LANG_NAME ready to be selected
  remote               print versions of $LANG_NAME available for download
  update               update this tool to the latest version
  upgrade              upgrade $LANG_NAME to the latest and remove the current version
  up                   perform both update and upgrade tasks
  install <version>    add the specified or the latest version of $LANG_NAME
  uninstall <version>  remove the specified version of $LANG_NAME
  use <version>        use the specified or the latest version of $LANG_NAME
  help                 print usage instructions for this tool
  version              print the version of this tool"
}

print_installer_version() {
    echo "$VERSION"
}

if [ $# -eq 0 ]; then
    print_usage_instructions
    exit 1
elif [ $# -gt 2 ]; then
    fail 'command failed' 'because of too many arguments'
fi
TASK=$1
if ! [[ ' current help install latest local remote uninstall up update upgrade use version ' =~ [[:space:]]${TASK}[[:space:]] ]]; then
    fail 'unrecognised task' "$TASK"
fi
if [ $# -eq 1 ]; then
    if [[ ' install uninstall use ' =~ [[:space:]]${TASK}[[:space:]] ]]; then
        fail 'missing version argument' "for task $TASK"
    fi
    ARG=
else
    if [[ ' current help latest local remote up update upgrade version ' =~ [[:space:]]${TASK}[[:space:]] ]]; then
        fail 'unexpected argument' "for task $TASK"
    fi
    ARG=$2
fi
if [[ "$ARG" != "" ]] && ! [[ "$ARG" =~ ^[.[:digit:][:alpha:]]+$ ]] && [[ "$ARG" != "latest" ]]; then
    fail 'invalid version argument' "$ARG"
fi

exists_tool_directory() {
    # TOOL_EXISTS=$(command -v $TOOL_NAME)
    if [ -e "$TOOL_DIR" ]; then
        TOOL_EXISTS=1
    else
        TOOL_EXISTS=
    fi
}

check_tool_directory_exists() {
    exists_tool_directory
    if [ -z "$TOOL_EXISTS" ]; then
        fail missing "$TOOL_DIR"
    fi
}

get_current_tool_version() {
    # TOOL_CUR_VER=$(command $TOOL_NAME tool dist version) ||
    #     fail 'failed getting' 'the current version of $LANG_NAME"
    if [ -e "$TOOL_DIR" ]; then
        cd "$TOOL_DIR" ||
            fail 'failed entering' "$TOOL_DIR"
        TOOL_CUR_VER=$(pwd -P) ||
            fail 'failed reading' "real path of $TOOL_DIR"
        if ! [[ "$TOOL_CUR_VER" =~ /([^/]+)$ ]]; then
            failed 'failed recognising' "version in $TOOL_CUR_VER"
        fi
        TOOL_CUR_VER=${BASH_REMATCH[1]}
    else
        fail 'not found' "any version in $TOOL_DIR"
    fi
}

print_tool_version() {
    check_tool_directory_exists
    get_current_tool_version
    echo "$TOOL_CUR_VER"
}

check_command_exists() {
    local CMD=$1
    local WHY=$2
    command -v "$CMD" >/dev/null ||
        fail missing "${C_BOLD}$CMD${C_RESET} for $WHY"
}

check_uname_exists() {
    check_command_exists uname 'detecting the current platform'
}

check_rm_exists() {
    check_command_exists rm 'removing files and directories'
}

check_ln_exists() {
    check_command_exists ln 'creating links'
}

check_curl_exists() {
    check_command_exists curl 'downloading from the Internet'
}

check_tar_exists() {
    check_command_exists tar 'unpacking tar archives'
}

check_unzip_exists() {
    check_command_exists unzip 'unpacking zip archives'
}

check_jq_exists() {
    check_command_exists jq 'extracting data from JSON'
}

check_sort_exists() {
    check_command_exists sort 'sorting version numbers'
}

detect_platform() {
    check_uname_exists

    read -ra UNAME < <(command uname -ms)
    OS=${UNAME[0],,}
    ARCH=${UNAME[1],,}

    if [[ $OS = dragonflybsd ]]; then
        OS=dragonfly
    elif ! [[ ' aix darwin dragonfly freebsd illumos linux netbsd openbsd plan9 solaris windows ' =~ [[:space:]]${OS}[[:space:]] ]]; then
        fail unsupported "operating system $OS"
    fi

    case $ARCH in
    i386 | i686)
        ARCH=386
        ;;
    aarch64 | armv8 | armv8l)
        ARCH=arm64
        ;;
    armv6 | armv6l)
        ARCH=arm
        ;;
    mips_le)
        ARCH=mipsle
        ;;
    mips64_le)
        ARCH=mips64le
        ;;
    ppc64_le)
        ARCH=ppc64le
        ;;
    s390)
        ARCH=s390x
        ;;
    x86_64)
        ARCH=amd64
        ;;
    esac

    if ! [[ " 386 amd64 arm arm64 i386 i686 loong64 mips mps64 mipsle mips64le ppc64 ppc64le riscv64 s390x " =~ [[:space:]]${ARCH}[[:space:]] ]]; then
        fail unsupported "architecture $ARCH"
    fi

    PLATFORM=$OS-$ARCH

    if [[ $PLATFORM = linux-arm ]]; then
        PLATFORM=linux-armv6l
    elif [[ $PLATFORM = darwin-amd64 ]]; then
        if [[ $(sysctl -n sysctl.proc_translated 2>/dev/null) = 1 ]]; then
            PLATFORM=darwin-arm64
            pass 'changing platform' "to $PLATFORM because Rosetta 2 was detected"
        fi
    fi

    if ! [[ " aix-ppc64 darwin-amd64 darwin-arm64 dragonfly-amd64 freebsd-386 freebsd-amd64 freebsd-arm64 freebsd-arm freebsd-riscv64 illumos-amd64 linux-386 linux-amd64 linux-arm64 linux-armv6l linux-loong64 linux-mips linux-mips64 linux-mips64le linux-mipsle linux-ppc64 linux-ppc64le linux-riscv64 linux-s390x netbsd-386 netbsd-amd64 netbsd-arm64 netbsd-arm openbsd-386 openbsd-amd64 openbsd-arm64 openbsd-arm openbsd-ppc64 plan9-386 plan9-amd64 plan9-arm solaris-amd64 windows-386 windows-amd64 windows-arm64 windows-arm " =~ [[:space:]]${PLATFORM}[[:space:]] ]]; then
        fail unsupported "platform $PLATFORM"
    fi

    if [[ $OS = windows ]]; then
        PKG_EXT=.zip
    else
        PKG_EXT=.tar.gz
    fi

    pass 'detected' "platform $PLATFORM"
}

check_remote_tool_version_exists() {
    local VER=$1
    TOOL_URL_PKG=${TOOL_URL_PKG-$TOOL_URL_DIR/$TOOL_NAME$VER.$PLATFORM$PKG_EXT}
    start_debug "checking $TOOL_URL_PKG"
    TOOL_EXISTS=$(command curl -fI "$PROGRESS" "$TOOL_URL_PKG") ||
        fail 'failed accessing' "$TOOL_URL_PKG"
    end_debug
    if ! [[ "$TOOL_EXISTS" =~ [[:space:]]200 ]]; then
        fail 'not found' "archive $TOOL_URL_PKG in the response:\n$TOOL_EXISTS"
    fi
    pass 'confirmed' "$VER"
}

download_tool_version() {
    local VER=$1
    if [[ " ${INST_LOCAL[*]} " =~ [[:space:]]${VER}[[:space:]] ]]; then
        command rm -r "$INST_DIR/$VER" ||
            fail 'failed deleting' "directory $INST_DIR/$VER"
    fi
    if [[ $OS = windows ]]; then
        local PKG_NAME=go.zip
        command curl -f "$PROGRESS" -o "$PKG_NAME" "$TOOL_URL_PKG" ||
            fail 'failed downloading' "$TOOL_URL_PKG to $PKG_NAME"
        end_debug
        command unzip -q -d "$INST_DIR/$VER" "$PKG_NAME" ||
            fail 'failed unzipping' "$PKG_NAME to $INST_DIR/$VER"
        command rm "$PKG_NAME" ||
            fail 'failed deleting' "$PKG_NAME"
    else
        command mkdir "$INST_DIR/$VER" ||
            fail 'failed creating' "directory $INST_DIR/$VER"
        start_debug "downloading and unpacking $TOOL_URL_PKG'"
        command curl -f "$PROGRESS" "$TOOL_URL_PKG" | command tar -xzf - --strip-components=1 -C "$INST_DIR/$VER" ||
            fail 'failed downloading and unpacking' "$TOOL_URL_PKG to $INST_DIR/$VER"
        end_debug
    fi
    pass 'downloaded and upacked' "$INST_DIR/$VER"
}

exists_installer_directory() {
    if [[ -d "$INST_DIR" ]]; then
        INST_EXISTS=1
    else
        INST_EXISTS=
    fi
}

check_installer_directory_exists() {
    exists_installer_directory
    if [[ "$INST_EXISTS" = "" ]]; then
        fail 'not found' "$INST_DIR"
    fi
}

get_local_tool_versions() {
    local VER_DIR
    local INST_LEN=${#INST_DIR}
    INST_LOCAL=()
    for VER_DIR in "$INST_DIR"/*/; do
        VER_DIR="${VER_DIR:$INST_LEN+1}"
        if [[ "$VER_DIR" != "*/" ]]; then
            INST_LOCAL+=("${VER_DIR%/}")
        fi
    done
}

link_tool_version_directory() {
    local VER=$1
    if [ -L "$TOOL_DIR" ]; then
        command rm "$TOOL_DIR" ||
            fail 'failed deleting' "link $TOOL_DIR"
    fi
    command ln -s "$INST_DIR/$VER" "$TOOL_DIR" ||
        fail 'failed creating' "link $TOOL_DIR to $INST_DIR/$VER"
    pass created "link $TOOL_DIR to $INST_DIR/$VER"
}

get_latest_remote_version() {
    start_debug "downloading $TOOL_URL_LATEST"
    TOOL_LATEST_VER=$(command curl -f "$PROGRESS" "$TOOL_URL_LATEST") ||
        fail 'failed downloading' "from $TOOL_URL_LATEST"
    end_debug
    if ! [[ "$TOOL_LATEST_VER" =~ go([.[:digit:]rcbeta]+)\" ]]; then
        fail 'failed recognising' "version in $TOOL_LATEST_VER"
    fi
    TOOL_LATEST_VER=${BASH_REMATCH[1]}
    TOOL_URL_PKG=${TOOL_URL_PKG-$TOOL_URL_DIR/$TOOL_NAME$TOOL_LATEST_VER.$PLATFORM$PKG_EXT}
}

remove_version_arg_from_local_tool_versions() {
    local OLD_LOCAL=("${INST_LOCAL[@]}")
    INST_LOCAL=()
    for DIR in "${OLD_LOCAL[@]}"; do
        if [[ "$DIR" != "$ARG" ]]; then
            INST_LOCAL+=("$DIR")
        fi
    done
}

get_latest_local_tool_version() {
    check_sort_exists

    if [[ "${INST_LOCAL[*]}" != "" ]]; then
        local SORTED
        SORTED=$(printf '%s\n' "${INST_LOCAL[*]}" | command sort -Vr) ||
            fail 'failed sorting' "versions: ${INST_LOCAL[*]}"
        read -r TOOL_VER < <(echo "${SORTED[@]}")
    else
        TOOL_VER=
    fi
}

get_local_tool_version_by_arg() {
    if [[ "$ARG" = "latest" ]]; then
        get_latest_local_tool_version
    else
        TOOL_VER=$ARG
    fi
}

exists_local_tool_version() {
    local VER=$1
    if [[ " ${INST_LOCAL[*]} " =~ [[:space:]]${VER}[[:space:]] ]]; then
        VER_EXISTS=1
    else
        VER_EXISTS=
    fi
}

check_local_tool_version_exists() {
    exists_local_tool_version "$TOOL_VER"
    if [[ "$VER_EXISTS" = "" ]]; then
        fail 'not found' "$INST_DIR/$TOOL_VER"
    fi
}

ensure_tool_directory_link() {
    local VER=$1
    exists_tool_directory
    if [[ "$TOOL_EXISTS" = "" ]]; then
        link_tool_version_directory "$VER"
    else
        get_current_tool_version
        if [[ "$TOOL_CUR_VER" != "$VER" ]]; then
            link_tool_version_directory "$VER"
        fi
    fi
}

install_tool_version() {
    check_curl_exists
    check_rm_exists
    check_ln_exists
    check_installer_directory_exists

    detect_platform
    if [[ $OS = windows ]]; then
        check_unzip_exists
    else
        check_tar_exists
    fi

    local VER
    if [[ "$ARG" = "latest" ]]; then
        get_latest_remote_version
        VER=$TOOL_LATEST_VER
    else
        VER=$ARG
        check_remote_tool_version_exists "$VER"
    fi

    get_local_tool_versions
    exists_local_tool_version "$VER"
    if [[ "$VER_EXISTS" = "" ]]; then
        download_tool_version "$VER"
    else
        ignore 'already installed' "$VER"
    fi

    ensure_tool_directory_link "$VER"
}

delete_tool_version() {
    local VER=$1
    command rm -r "$INST_DIR/$VER" ||
        fail 'failed deleting' "$INST_DIR/$VER"
    pass deleted "$VER"
}

upgrade_tool_version() {
    check_curl_exists
    check_rm_exists
    check_ln_exists
    check_installer_directory_exists

    detect_platform
    if [[ $OS = windows ]]; then
        check_unzip_exists
    else
        check_tar_exists
    fi

    get_latest_remote_version

    get_local_tool_versions
    exists_local_tool_version "$TOOL_LATEST_VER"
    if [[ "$VER_EXISTS" = "" ]]; then
        pass discovered "$TOOL_LATEST_VER"
        download_tool_version "$TOOL_LATEST_VER"
        get_latest_local_tool_version
        if [ -n "$TOOL_VER" ]; then
            delete_tool_version "$TOOL_VER"
        fi
    else
        ignore 'up to date' "language $TOOL_LATEST_VER"
    fi

    ensure_tool_directory_link "$TOOL_LATEST_VER"
}

update_installer() {
    local LATEST_VER
    local TRACE
    readonly INST_ROOT_URL="${INST_VER_URL-https://raw.githubusercontent.com/prantlf/$INST_NAME/master}"
    readonly INST_VER_URL="${INST_VER_URL-$INST_ROOT_URL/VERSION}"
    start_debug "downloading $INST_VER_URL"
    LATEST_VER=$(command curl -f "$PROGRESS" "$INST_VER_URL") ||
        fail 'failed downloading' "from $INST_VER_URL"
    if [[ "$LATEST_VER" != "$VERSION" ]]; then
        if [[ $- == *x* ]]; then
            TRACE=-x
        else
            TRACE=
        fi
        readonly INST_URL="${INST_URL-$INST_ROOT_URL/$INST_NAME.sh}"
        start_debug "downloading $INST_URL"
        command curl -f "$PROGRESS" "$INST_URL" | NO_INSTRUCTIONS=1 bash $TRACE ||
            fail 'failed downloading and executing' "$INST_URL"
        end_debug
    else
        ignore 'up to date' "installer $LATEST_VER"
    fi
}

update_installer_and_upgrade_tool_version() {
    update_installer
    upgrade_tool_version
}

print_local_tool_versions() {
    check_installer_directory_exists
    get_local_tool_versions
    printf '%s\n' "${INST_LOCAL[@]}" 
}

print_remote_tool_versions() {
    local LIST

    check_curl_exists
    check_jq_exists

    start_debug "downloading $TOOL_URL_LIST"
    LIST=$(command curl -f "$PROGRESS" "$TOOL_URL_LIST" | command jq -r '.[].version') ||
        fail 'failed downloading and processing' "the output from $TOOL_URL_LIST"
        end_debug
    echo "$LIST"
}

uninstall_tool_version() {
    check_rm_exists
    check_ln_exists

    check_installer_directory_exists
    get_local_tool_versions
    get_local_tool_version_by_arg
    check_local_tool_version_exists
    get_current_tool_version

    delete_tool_version "$TOOL_VER"
    if [[ "$TOOL_CUR_VER" = "$TOOL_VER" ]]; then
        command rm "$TOOL_DIR" ||
            fail 'failed deleting' "$TOOL_DIR"
        get_local_tool_versions
        if [[ "${INST_LOCAL[*]}" != "" ]]; then
            get_latest_local_tool_version
            link_tool_version_directory "$TOOL_VER"
        else
            announce deleted "the latest $LANG_NAME version"
        fi
    fi
}

print_latest_remote_version() {
    check_curl_exists
    detect_platform
    get_latest_remote_version
    echo "$TOOL_LATEST_VER"
}

use_tool_version() {
    check_rm_exists
    check_ln_exists

    check_installer_directory_exists
    get_local_tool_versions
    get_local_tool_version_by_arg
    check_local_tool_version_exists

    get_current_tool_version
    if [[ "$TOOL_CUR_VER" != "$TOOL_VER" ]]; then
        link_tool_version_directory "$TOOL_VER"
        pass activated "$TOOL_VER"
    else
        ignore 'already active' "$TOOL_VER"
    fi
}

case $TASK in
current)
    print_tool_version
    ;;
help)
    print_usage_instructions
    ;;
install)
    install_tool_version
    ;;
latest)
    print_latest_remote_version
    ;;
local)
    print_local_tool_versions
    ;;
remote)
    print_remote_tool_versions
    ;;
up)
    update_installer_and_upgrade_tool_version
    ;;
update)
    update_installer
    ;;
upgrade)
    upgrade_tool_version
    ;;
uninstall)
    uninstall_tool_version
    ;;
use)
    use_tool_version
    ;;
version)
    print_installer_version
    ;;
esac