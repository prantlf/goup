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

readonly VERSION=0.0.1

print_usage_description() {
    echo -e "Installs or updates ${C_BOLD}goup $VERSION${C_RESET} - upgrader and version manager for Go.

${C_BOLD}Usage${C_RESET}: install [task]
${C_BOLD}Tasks${C_RESET}:
  help     print usage instructions for this tool
  version  print the version of this tool"
}

print_goup_version() {
    echo "$VERSION"
}

check_command_exists() {
    local CMD=$1
    local WHY=$2
    command -v "$CMD" >/dev/null ||
        fail missing "${C_BOLD}$CMD${C_RESET} for $WHY"
}

check_chmod_exists() {
    check_command_exists chmod 'changing file mode'
}

check_curl_exists() {
    check_command_exists curl 'downloading files'
}

check_mkdir_exists() {
    check_command_exists mkdir 'creating directories'
}

create_directory() {
    local DIR=$1
    if [ ! -d "$DIR" ]; then
        mkdir "$DIR" ||
            fail failed creating" '$DIR'"
        pass created "'$DIR'"
    else
        ignore 'no need to create' "'$DIR'"
   fi
}

readonly GOUP_DIR="${GOUP_DIR-$HOME/.goup}"

download_goup() {
    readonly GOUP_URL="${GOUP_URL-https://raw.githubusercontent.com/prantlf/goup/master/goup.sh}"
    local GOUP
    GOUP="$GOUP_DIR/goup"
    start_debug "downloading '$GOUP_URL'"
    command curl $PROGRESS "$GOUP_URL" > "$GOUP" ||
        fail 'failed downloading' "'$GOUP_URL' to '$GOUP'"
    end_debug
    pass written "'$GOUP'"
    command chmod a+x "$GOUP" ||
        fail 'failed chaging mode' "of '$GOUP' to executable"
}

populate_goup_directory() {
    check_mkdir_exists
    check_curl_exists
    check_chmod_exists
    create_directory "$GOUP_DIR"
    download_goup
}

declare SHRC
declare FISH=0

determine_current_shell_rc() {
    local SH_VER
    # shellcheck disable=SC2016 # need to pass vanilla code
    SH_VER=$($SHELL -c 'echo $BASH_VERSION')
    if [ -n "$SH_VER" ]; then
        SHRC="$HOME/.bashrc"
    else
        # shellcheck disable=SC2016 # need to pass vanilla code
        SH_VER=$($SHELL -c 'echo $ZSH_VERSION')
        if [ -n "$SH_VER" ]; then
            SHRC="$HOME/.zshrc"
        else
            # shellcheck disable=SC2016 # need to pass vanilla code
            SH_VER=$($SHELL -c 'echo $FISH_VERSION')
            if [ -n "$SH_VER" ]; then
                SHRC="$HOME/.config/fish/config.fish"
                FISH=1
            else
                # shellcheck disable=SC2016 # need to pass vanilla code
                ignore 'unrecognised shell' 'needs you to extend the PATH: PATH="$HOME/.goup:$HOME/.go/bin:$PATH'
                SHRC=
            fi
        fi
    fi
}

update_shell_rc() {
    local CONTENT
    if [ -f "$SHRC" ]; then
        CONTENT=$(<"$SHRC")
        if [[ ! "$CONTENT" =~ /\.goup: ]]; then
            if [ $FISH -eq 0 ]; then
                # shellcheck disable=SC2016 # need to append vanilla code
                echo '
# goup
export PATH="$HOME/.goup:$HOME/.go/bin:$PATH"' >> "$SHRC"
            else
                # shellcheck disable=SC2016 # need to append vanilla code
                echo '
# goup
set -xp PATH "$HOME/.goup:$HOME/.go/bin:$PATH"' >> "$SHRC"
            fi
            pass updated "'$SHRC'"
        else
            ignore 'no need to update' "'$SHRC'"
        fi
    else
        ignore 'not found' "'$SHRC'"
    fi
}

print_introduction() {
    echo ''
    if [ $FISH -eq 0 ]; then
        echo -e "Start a new shell or update this one: ${C_BOLD}export PATH=\"\$HOME/.goup:\$HOME/.go/bin:\$PATH\"${C_RESET}"
    else
        echo -e "Start a new shell or update this one: ${C_BOLD}set -xp PATH \"\$HOME/.goup:\$HOME/.go/bin:\$PATH\"${C_RESET}"
    fi
    echo -e "Continue by installing Go:            ${C_BOLD}goup install latest${C_RESET}
Upgrade regularly:                    ${C_BOLD}goup upgrade${C_RESET}
See usage instructions:               ${C_BOLD}goup help${C_RESET}"
}

install_goup() {
    announce 'installing' "goup $VERSION - upgrader and version manager for Go"
    populate_goup_directory
    determine_current_shell_rc
    if [ -n "$SHRC" ]; then
        update_shell_rc
    fi
    announce 'done' ''
    print_introduction
}

readonly TASK="${1-}"
case $TASK in
help)
    print_usage_description
    ;;
version)
    print_goup_version
    ;;
'')
    install_goup
    ;;
*)
    fail 'unrecognised task' "'$TASK'"
    ;;
esac
