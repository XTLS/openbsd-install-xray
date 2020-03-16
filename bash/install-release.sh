#!/bin/bash

# This file is accessible as https://raw.githubusercontent.com/v2fly/openbsd-install-v2ray/master/bash/install-release.sh
# Original source is located at github.com/v2ray/v2ray-core/release/install-release.sh

# If not specify, default meaning of return value:
# 0: Success
# 1: System error
# 2: Application error
# 3: Network error

# CLI arguments
CHECK=''
DIST_SRC='github'
ERROR_IF_UPTODATE=''
EXTRACT_ONLY=''
FORCE=''
HELP=''
LOCAL=''
LOCAL_INSTALL=''
PROXY=''
REMOVE=''
VERSION=''
VSRC_ROOT='/tmp/v2ray'

CUR_VER=''
NEW_VER=''
V2RAY_RUNNING='0'
VDIS=''
ZIPFILE='/tmp/v2ray/v2ray.zip'

CMD_INSTALL=''

RCCTL_CMD="$(command -v rcctl 2>/dev/null)"

####### color code ########
BLUE='36m' # Info message
GREEN='32m' # Success message
RED='31m' # Error message

###########################
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --errifuptodate)
            ERROR_IF_UPTODATE='1'
            ;;
        --extract)
            VSRC_ROOT="$2"
            ;;
        --extractonly)
            EXTRACT_ONLY='1'
            ;;
        --remove)
            REMOVE='1'
            ;;
        --source)
            DIST_SRC="$2"
            ;;
        --version)
            if [[ -z "$2" ]]; then
                echo 'error: Please specify the version.'
                exit 1
            fi
            VERSION="$2"
            ;;
        -c | --check)
            CHECK='1'
            ;;
        -f | --force)
            FORCE='1'
            ;;
        -h | --help)
            HELP='1'
            ;;
        -l | --local)
            if [[ -z "$2" ]]; then
                echo 'error: Please specify a local file.'
                exit 1
            fi
            LOCAL="$2"
            LOCAL_INSTALL='1'
            ;;
        -p | --proxy)
            if [[ -z "$2" ]]; then
                echo 'error: Please specify a proxy address.'
                exit 1
            fi
            PROXY="-x $2"
            ;;
        *)
            # unknown option
            echo "$0: unknown option -- -"
            exit 1
            ;;
    esac
    shift # past argument or value
done

###############################
colorEcho() {
    echo -e "\033[${1}${@:2}\033[0m"
}

archAffix() {
    case "${1:-$(uname -m)}" in
        i686 | i386)
            echo '32'
            ;;
        x86_64 | amd64)
            echo '64'
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}

downloadV2Ray() {
    rm -rf /tmp/v2ray
    mkdir -p /tmp/v2ray
    if [[ "$DIST_SRC" == 'jsdelivr' ]]; then
        DOWNLOAD_LINK="https://cdn.jsdelivr.net/gh/v2ray/dist/v2ray-openbsd-$VDIS.zip"
    else
        DOWNLOAD_LINK="https://github.com/v2ray/v2ray-core/releases/download/$NEW_VER/v2ray-openbsd-$VDIS.zip"
    fi
    colorEcho "$BLUE" "Downloading V2Ray: $DOWNLOAD_LINK"
    curl ${PROXY} -L -H 'Cache-Control: no-cache' -o "$ZIPFILE" "$DOWNLOAD_LINK"
    curl ${PROXY} -L -H 'Cache-Control: no-cache' -o "$ZIPFILE.dgst" "$DOWNLOAD_LINK.dgst"
    if [[ "$?" -ne '0' ]]; then
        colorEcho "$RED" 'Download failed! Please check your network or try again.'
        return 3
    fi
    for LISTSUM in 'md5' 'sha1' 'sha256' 'sha512'; do
        SUM="$($LISTSUM $ZIPFILE | sed 's/.* //')"
        CHECKSUM="$(grep ${LISTSUM^^} $ZIPFILE.dgst | sed 's/.* //')"
        if [[ "$SUM" != "$CHECKSUM" ]]; then
            colorEcho "$RED" 'Check failed! Please check your network or try again.'
            return 3
        fi
    done
    return 0
}

installSoftware() {
    COMPONENT="$1"
    if [[ -n "$(command -v $COMPONENT)" ]]; then
        return 0
    fi

    getPMT
    if [[ "$?" -eq '1' ]]; then
        colorEcho "$RED" "The system package manager tool isn't pkg_add, please install $COMPONENT manually."
        return 1
    fi

    colorEcho "$BLUE" "Installing $COMPONENT"
    ${CMD_INSTALL} "$COMPONENT--"
    if [[ "$?" -ne '0' ]]; then
        colorEcho "$RED" "Failed to install $COMPONENT. Please install it manually."
        return 1
    fi
    return 0
}

# return 1: not pkg_add
getPMT() {
    if [[ -n "$(command -v pkg_add)" ]]; then
        CMD_INSTALL='pkg_add'
    else
        return 1
    fi
    return 0
}

extract(){
    mkdir -p /tmp/v2ray
    unzip -q "$1" -d "$VSRC_ROOT"
    if [[ "$?" -ne '0' ]]; then
        colorEcho "$RED" 'Failed to extract V2Ray.'
        return 2
    fi
    echo '---'
    colorEcho "$BLUE" 'Extract the V2Ray package to /tmp/v2ray and prepare it for installation.'
    if [[ -d "/tmp/v2ray/v2ray-$NEW_VER-openbsd-$VDIS" ]]; then
        VSRC_ROOT="/tmp/v2ray/v2ray-$NEW_VER-openbsd-$VDIS"
    fi
    return 0
}

normalizeVersion() {
    if [[ -n "$1" ]]; then
        case "$1" in
            v*)
                echo "$1"
                ;;
            *)
                echo "v$1"
                ;;
        esac
    else
        echo ''
    fi
}

# 1: new V2Ray. 0: no. 2: not installed. 3: check failed. 4: don't check.
getVersion() {
    if [[ -n "$VERSION" ]]; then
        NEW_VER="$(normalizeVersion $VERSION)"
        return 4
    else
        VER="$(/usr/local/bin/v2ray -version 2> /dev/null)"
        RETVAL="$?"
        CUR_VER="$(normalizeVersion $(echo $VER | head -n 1 | cut -d ' ' -f2))"
        TAG_URL='https://api.github.com/repos/v2ray/v2ray-core/releases/latest'
        NEW_VER="$(normalizeVersion $(curl $PROXY -s $TAG_URL --connect-timeout 10 | grep 'tag_name' | cut -d \" -f 4))"
        if [[ "$?" -ne '0' ]] || [[ "$NEW_VER" == '' ]]; then
            colorEcho "$RED" 'Failed to fetch release information. Please check your network or try again.'
            return 3
        elif [[ "$RETVAL" -ne '0' ]];then
            return 2
        elif [[ "$NEW_VER" != "$CUR_VER" ]]; then
            IF_VER="$(echo "$NEW_VER $CUR_VER" | awk '{ if ( $1 > $2 ) print $1; else print $2 }')"
            if [[ "$IF_VER" == "$NEW_VER" ]]; then
                return 1
            fi
        fi
        return 0
    fi
}

stopV2Ray() {
    if [[ -n "$RCCTL_CMD" ]] || [[ -f '/etc/rc.d/v2ray' ]]; then
        "$RCCTL_CMD" stop v2ray
    fi
    if [[ "$?" -ne '0' ]]; then
        echo 'error: Stopping the V2Ray service failed.'
        return 2
    fi
    colorEcho "$BLUE" 'Stop the V2Ray service.'
    return 0
}

startV2Ray() {
    if [[ -n "$RCCTL_CMD" ]] && [[ -f '/etc/rc.d/v2ray' ]]; then
        "$RCCTL_CMD" start v2ray
    fi
    if [[ "$?" -ne 0 ]]; then
        echo 'error: Failed to start V2Ray service.'
        return 2
    fi
    colorEcho "$BLUE" 'Start the V2Ray service.'
    return 0
}

installFile() {
    NAME="$1"
    if [[ "$NAME" == 'v2ray' ]] || [[ "$NAME" == 'v2ctl' ]]; then
        ERROR="$(install -m 755 -g bin $VSRC_ROOT/$NAME /usr/local/bin/$NAME)"
    elif [[ "$NAME" == 'geoip.dat' ]] || [[ "$NAME" == 'geosite.dat' ]]; then
        ERROR="$(install -m 755 -g bin $VSRC_ROOT/$NAME /usr/local/lib/v2ray/$NAME)"
    fi
    if [[ "$?" -ne '0' ]]; then
        echo "error: $ERROR."
        return 1
    fi
    return 0
}

installV2Ray(){
    # Install V2Ray binary to /usr/local/bin and /usr/local/lib/v2ray
    installFile v2ray
    if [[ "$?" -ne '0' ]]; then
        colorEcho "$RED" 'Failed to copy V2Ray binary and resources.'
        return 1
    fi
    installFile v2ctl
    install -d /usr/local/lib/v2ray
    installFile geoip.dat
    installFile geosite.dat

    # Install V2Ray server config to /etc/v2ray
    if [[ ! -f '/etc/v2ray/config.json' ]]; then
        install -d /etc/v2ray
        install -m 644 "$VSRC_ROOT/vpoint_vmess_freedom.json" /etc/v2ray/config.json
        if [[ "$?" -ne '0' ]]; then
            echo 'error: Unable to create V2Ray profile, please create it manually.'
            return 1
        fi
        let PORT="$RANDOM+10000"
        uuid() {
            C='89ab'
            for (( N='0'; N<'16'; ++N )); do
                B="$(( RANDOM%256 ))"
                case "$N" in
                    6)
                        printf '4%x' "$(( B%16 ))"
                        ;;
                    8)
                        printf '%c%x' "$C:$RANDOM%$#C:1" "$(( B%16 ))"
                        ;;
                    3 | 5 | 7 | 9)
                        printf '%02x-' "$B"
                        ;;
                    *)
                        printf '%02x' "$B"
                        ;;
                esac
            done
            printf '\n'
        }
    UUID="$(uuid)"

    sed -i "s/10086/$PORT/g" /etc/v2ray/config.json
    sed -i "s/23ad6b10-8d1a-40f7-8ad0-e3e35cd38297/$UUID/g" /etc/v2ray/config.json

    colorEcho "$BLUE" "PORT: $PORT"
    colorEcho "$BLUE" "UUID: $UUID"
    fi
    if [[ ! -d '/var/log/v2ray' ]]; then
        install -do www /var/log/v2ray
    fi
    return 0
}

installInitScript() {
    if [[ -n "$RCCTL_CMD" ]] && [[ ! -f '/etc/rc.d/v2ray' ]]; then
        mkdir "$VSRC_ROOT/rc.d"
        curl -o "$VSRC_ROOT/rc.d/v2ray" https://raw.githubusercontent.workers.dev/v2fly/openbsd-install-v2ray/master/rc.d/v2ray
        install -m 755 -g bin "$VSRC_ROOT/rc.d/v2ray" /etc/rc.d/v2ray
    fi
}

showHelp() {
    echo "usage: $0 [--remove] [--version] [-cfhlp]"
    echo '      --remove    Remove V2Ray'
    echo '      --version   Install the specified version, e.g., --version v3.15'
    echo '  -c, --check     Check for updates'
    echo '  -f, --force     Force installation'
    echo '  -h, --help      Show help'
    echo '  -l, --local     Install from local files'
    echo '  -p, --proxy     Download through a proxy server, e.g., -p socks5://127.0.0.1:1080 or -p http://127.0.0.1:8118'
}

remove() {
    if [[ -n "$RCCTL_CMD" ]] && [[ -f '/etc/rc.d/v2ray' ]]; then
        if [[ -n "$(pgrep v2ray)" ]]; then
            stopV2Ray
        fi
        NAME="$1"
        rm -rf /usr/local/bin/{v2ray,v2ctl} /usr/local/lib/v2ray /etc/rc.d/v2ray
        if [[ "$?" -ne '0' ]]; then
            colorEcho "$RED" 'Failed to remove V2Ray.'
            return 0
        else
            echo 'Removed: /usr/local/bin/v2ray'
            echo 'Removed: /usr/local/bin/v2ctl'
            echo 'Removed: /usr/local/lib/v2ray'
            echo 'Removed: /etc/rc.d/v2ray'
            echo 'Please execute the command: rcctl disable v2ray'
            colorEcho "$GREEN" 'V2Ray has been removed.'
            colorEcho "$BLUE" 'If necessary, manually delete the configuration and log files.'
            colorEcho "$BLUE" 'e.g., /etc/v2ray and /var/log/v2ray...'
            return 0
        fi
    else
        echo 'error: V2Ray is not installed.'
        return 0
    fi
}

checkUpdate() {
    echo 'Checking for update.'
    VERSION=''
    getVersion
    RETVAL="$?"
    if [[ $RETVAL -eq '0' ]]; then
        colorEcho "$BLUE" "No new version. The current version is the latest release $NEW_VER."
    elif [[ "$RETVAL" -eq '1' ]]; then
        colorEcho "$BLUE" "Found the latest release of V2Ray $NEW_VER. (Current release: $CUR_VER)"
    elif [[ $RETVAL -eq '2' ]]; then
        echo 'error: V2Ray is not installed.'
        colorEcho "$BLUE" "The latest release of V2Ray is $NEW_VER."
    fi
    return 0
}

main() {
    #helping information
    [[ "$HELP" -eq '1' ]] && showHelp && return
    [[ "$CHECK" -eq '1' ]] && checkUpdate && return
    [[ "$REMOVE" -eq '1' ]] && remove && return

    local ARCH="$(uname -m)"
    VDIS="$(archAffix)"

    # extract local file
    if [[ "$LOCAL_INSTALL" -eq '1' ]]; then
        echo 'error: Installing V2Ray from a local file. Please make sure the file is valid because we cannot determine it.'
        NEW_VER='local'
        installSoftware unzip || return "$?"
        rm -rf /tmp/v2ray
        extract "$LOCAL" || return "$?"
    else
        # download via network and extract
        installSoftware curl || return "$?"
        getVersion
        RETVAL="$?"
        if [[ "$RETVAL" -eq '0' ]] && [[ "$FORCE" -ne '1' ]]; then
            colorEcho "$BLUE" "The latest version $CUR_VER is installed."
            if [[ -n "$ERROR_IF_UPTODATE" ]]; then
                return 10
            fi
            return
        elif [[ "$RETVAL" -eq '3' ]]; then
            return 3
        else
            colorEcho "$BLUE" "Installing V2Ray $NEW_VER for $ARCH"
            downloadV2Ray || return "$?"
            installSoftware unzip || return "$?"
            extract "$ZIPFILE" || return "$?"
        fi
    fi

    if [[ -n "$EXTRACT_ONLY" ]]; then
        colorEcho "$GREEN" "V2Ray has been extracted to $VSRC_ROOT and is exiting..."
        return 0
    fi

    if [[ -n "$(pgrep v2ray)" ]]; then
        V2RAY_RUNNING='1'
        stopV2Ray
    fi
    installV2Ray || return "$?"
    installInitScript || return "$?"
    echo 'installed: /usr/local/bin/v2ray'
    echo 'installed: /usr/local/bin/v2ctl'
    echo 'installed: /usr/local/lib/v2ray/geoip.dat'
    echo 'installed: /usr/local/lib/v2ray/geosite.dat'
    echo 'installed: /etc/v2ray/config.json'
    echo 'installed: /var/log/v2ray'
    echo 'installed: /etc/rc.d/v2ray'
    echo 'Please execute the command: rcctl enable v2ray'
    rm -rf /tmp/v2ray
    echo 'Removed: /tmp/v2ray'
    if [[ "$V2RAY_RUNNING" -eq '1' ]]; then
        startV2Ray
    fi
    colorEcho "$GREEN" "V2Ray $NEW_VER is installed."
    return 0
}

main
