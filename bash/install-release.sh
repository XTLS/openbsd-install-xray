#!/bin/bash

# This file is accessible as https://raw.githubusercontent.com/v2fly/openbsd-install-v2ray/master/bash/install-release.sh
# Original source is located at github.com/v2ray/v2ray-core/release/install-release.sh

# If not specify, default meaning of return value:
# 0: Success
# 1: System error
# 2: Application error
# 3: Network error

# Judge computer systems and architecture
case "$(arch 2> /dev/null)" in
    OpenBSD*)
        case "$(uname -m)" in
            i686 | i386)
                BIT='32'
                ;;
            x86_64 | amd64)
                BIT='64'
                ;;
            *)
                echo "error: The architecture is not supported."
                exit 1
                ;;
        esac
        ;;
    *)
        echo "error: This operating system is not supported."
        exit 1
        ;;
esac

# Judgment parameters
if [[ "$#" -gt '0' ]]; then
    case "$1" in
        --remove)
            if [[ "$#" -gt '1' ]]; then
                echo 'error: Please enter the correct command.'
                exit 1
            fi
            REMOVE='1'
            ;;
        --version)
            if [[ "$#" -gt '2' ]] || [[ -z "$2" ]]; then
                echo 'error: Please specify the correct version.'
                exit 1
            fi
            VERSION="$2"
            ;;
        -c | --check)
            if [[ "$#" -gt '1' ]]; then
                echo 'error: Please enter the correct command.'
                exit 1
            fi
            CHECK='1'
            ;;
        -f | --force)
            if [[ "$#" -gt '1' ]]; then
                echo 'error: Please enter the correct command.'
                exit 1
            fi
            FORCE='1'
            ;;
        -h | --help)
            if [[ "$#" -gt '1' ]]; then
                echo 'error: Please enter the correct command.'
                exit 1
            fi
            HELP='1'
            ;;
        -l | --local)
            if [[ "$#" -gt '2' ]] || [[ -z "$2" ]]; then
                echo 'error: Please specify the correct local file.'
                exit 1
            fi
            LOCAL="$2"
            LOCAL_INSTALL='1'
            ;;
        -p | --proxy)
            if [[ "$#" -gt '2' ]] || [[ -z "$2" ]]; then
                echo 'error: Please specify the correct proxy server address.'
                exit 1
            fi
            PROXY="-x $2"
            ;;
        *)
            echo "$0: unknown option -- -"
            exit 1
            ;;
    esac
fi

VSRC_ROOT='/tmp/v2ray'
ZIP_FILE="/tmp/v2ray/v2ray-openbsd-$BIT.zip"

installSoftware() {
    COMPONENT="$1"
    if [[ -n "$(command -v $COMPONENT)" ]]; then
        return
    fi
    echo "info: Installing $COMPONENT"
    pkg_add "$COMPONENT--"
    if [[ "$?" -ne '0' ]]; then
        echo "error: Installation of $COMPONENT failed, please check your network."
        exit 1
    fi
}
versionNumber() {
    if [[ -n "$1" ]]; then
        case "$1" in
            v*)
                echo "$1"
                ;;
            *)
                echo "v$1"
                ;;
        esac
    fi
}
getVersion() {
    # 0: no. 1: new V2Ray. 2: not installed. 3: check failed. 4: don't check.
    if [[ -n "$VERSION" ]]; then
        NEW_VER="$(versionNumber $VERSION)"
        return 4
    else
        VER="$(/usr/local/bin/v2ray -version 2> /dev/null)"
        RETVAL="$?"
        CUR_VER="$(versionNumber $(echo $VER | head -n 1 | cut -d ' ' -f2))"
        TAG_URL='https://api.github.com/repos/v2ray/v2ray-core/releases/latest'
        NEW_VER="$(versionNumber $(curl $PROXY $TAG_URL --connect-timeout 10 -s | grep 'tag_name' | cut -d \" -f 4))"
        if [[ "$?" -ne '0' ]] || [[ "$NEW_VER" == '' ]]; then
            echo 'error: Failed to get release information, please check your network.'
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
downloadV2Ray() {
    mkdir -p /tmp/v2ray
    DOWNLOAD_LINK="https://github.com/v2ray/v2ray-core/releases/download/$NEW_VER/v2ray-openbsd-$BIT.zip"
    echo "info: Downloading V2Ray: $DOWNLOAD_LINK"
    curl ${PROXY} -L -H 'Cache-Control: no-cache' -o "$ZIP_FILE" "$DOWNLOAD_LINK" -#
    if [[ "$?" -ne '0' ]]; then
        echo 'error: Download failed! Please check your network or try again.'
        shift 1
    fi
    curl ${PROXY} -L -H 'Cache-Control: no-cache' -o "$ZIP_FILE.dgst" "$DOWNLOAD_LINK.dgst" -#
    if [[ "$?" -ne '0' ]]; then
        echo 'error: Download failed! Please check your network or try again.'
        shift 1
    fi
    if [[ "$(cat $ZIP_FILE.dgst)" == 'Not Found' ]]; then
        echo 'error: This version does not support verification. Please replace with another version.'
        shift 1
    fi
    for LISTSUM in 'md5' 'sha1' 'sha256' 'sha512'; do
        SUM="$($LISTSUM $ZIP_FILE | sed 's/.* //')"
        CHECKSUM="$(grep ${LISTSUM^^} $ZIP_FILE.dgst | sed 's/.* //')"
        if [[ "$SUM" != "$CHECKSUM" ]]; then
            echo 'error: Check failed! Please check your network or try again.'
            shift 1
        fi
    done
}
decompression(){
    mkdir -p /tmp/v2ray
    unzip -q "$1" -d "$VSRC_ROOT"
    if [[ "$?" -ne '0' ]]; then
        echo 'error: V2Ray decompression failed.'
        rm -rf /tmp/v2ray
        echo 'removed: /tmp/v2ray'
        exit 1
    fi
    echo 'info: Extract the V2Ray package to /tmp/v2ray and prepare it for installation.'
}
installFile() {
    NAME="$1"
    if [[ "$NAME" == 'v2ray' ]] || [[ "$NAME" == 'v2ctl' ]]; then
        install -m 755 -g bin "$VSRC_ROOT/$NAME" "/usr/local/bin/$NAME"
    elif [[ "$NAME" == 'geoip.dat' ]] || [[ "$NAME" == 'geosite.dat' ]]; then
        install -m 755 -g bin "$VSRC_ROOT/$NAME" "/usr/local/lib/v2ray/$NAME"
    fi
    return 0
}
installV2Ray(){
    # Install V2Ray binary to /usr/local/bin and /usr/local/lib/v2ray
    installFile v2ray
    installFile v2ctl
    install -d /usr/local/lib/v2ray
    installFile geoip.dat
    installFile geosite.dat

    # Install V2Ray server config to /etc/v2ray
    if [[ ! -f '/etc/v2ray/config.json' ]]; then
        install -d /etc/v2ray
        install -m 644 "$VSRC_ROOT/vpoint_vmess_freedom.json" /etc/v2ray/config.json
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

    echo "PORT: $PORT"
    echo "UUID: $UUID"
    fi

    if [[ ! -d '/var/log/v2ray' ]]; then
        install -do www /var/log/v2ray
    fi
}
installStartupServiceFile() {
    if [[ ! -f '/etc/rc.d/v2ray' ]]; then
        mkdir "$VSRC_ROOT/rc.d"
        curl -o "$VSRC_ROOT/rc.d/v2ray" https://raw.githubusercontent.workers.dev/v2fly/openbsd-install-v2ray/master/rc.d/v2ray -s
        install -m 755 -g bin "$VSRC_ROOT/rc.d/v2ray" /etc/rc.d/v2ray
    fi
}

startV2Ray() {
    if [[ -f '/etc/rc.d/v2ray' ]]; then
        rcctl start v2ray
    fi
    if [[ "$?" -ne 0 ]]; then
        echo 'error: Failed to start V2Ray service.'
        return 2
    fi
    echo 'info: Start the V2Ray service.'
    return 0
}
stopV2Ray() {
    if [[ -f '/etc/rc.d/v2ray' ]]; then
        rcctl stop v2ray
    fi
    if [[ "$?" -ne '0' ]]; then
        echo 'error: Stopping the V2Ray service failed.'
        return 2
    fi
    echo 'info: Stop the V2Ray service.'
    return 0
}

showHelp() {
    echo "usage: $0 [--remove] [--version] [-cfhlp]"
    echo '  --remove        Remove V2Ray'
    echo '  --version       Install the specified version, e.g., --version v3.15'
    echo '  -c, --check     Check for updates'
    echo '  -f, --force     Force installation'
    echo '  -h, --help      Show help'
    echo '  -l, --local     Install from local files'
    echo '  -p, --proxy     Download through a proxy server, e.g., -p socks5://127.0.0.1:1080 or -p http://127.0.0.1:8118'
    exit 0
}

remove() {
    if [[ -f '/etc/rc.d/v2ray' ]]; then
        if [[ -n "$(pgrep v2ray)" ]]; then
            stopV2Ray
        fi
        NAME="$1"
        rm -rf /usr/local/bin/{v2ray,v2ctl} /usr/local/lib/v2ray /etc/rc.d/v2ray
        if [[ "$?" -ne '0' ]]; then
            echo 'error: Failed to remove V2Ray.'
            exit 1
        else
            echo 'removed: /usr/local/bin/v2ray'
            echo 'removed: /usr/local/bin/v2ctl'
            echo 'removed: /usr/local/lib/v2ray'
            echo 'removed: /etc/rc.d/v2ray'
            echo 'info: Please execute the command: rcctl disable v2ray'
            echo 'info: V2Ray has been removed.'
            echo 'info: If necessary, manually delete the configuration and log files.'
            echo 'info: e.g., /etc/v2ray and /var/log/v2ray...'
            exit 0
        fi
    else
        echo 'error: V2Ray is not installed.'
        exit 1
    fi
}

checkUpdate() {
    getVersion
    if [[ "$?" -eq '0' ]]; then
        echo "info: No new version. The current version is the latest release $NEW_VER."
    elif [[ "$?" -eq '1' ]]; then
        echo "info: Found the latest release of V2Ray $NEW_VER. (Current release: $CUR_VER)"
    elif [[ "$?" -eq '2' ]]; then
        echo 'error: V2Ray is not installed.'
        echo "info: The latest release of V2Ray is $NEW_VER."
    fi
    exit 0
}

main() {
    # helping information
    [[ "$HELP" -eq '1' ]] && showHelp
    [[ "$CHECK" -eq '1' ]] && checkUpdate
    [[ "$REMOVE" -eq '1' ]] && remove

    # decompression local file
    if [[ "$LOCAL_INSTALL" -eq '1' ]]; then
        echo -n 'warn: Installing V2Ray from a local file. Please make sure the file is valid because we cannot determine it. (Press any key) ...'
        read
        NEW_VER='local'
        installSoftware unzip
        rm -rf /tmp/v2ray
        decompression "$LOCAL"
    else
        # download via network and decompression
        installSoftware curl
        getVersion
        if [[ "$?" -eq '0' ]] && [[ "$FORCE" -ne '1' ]]; then
            echo "info: The latest version $CUR_VER is installed."
            exit 0
        else
            echo "info: Installing V2Ray $NEW_VER for $(arch -s)"
            rm -rf /tmp/v2ray
            downloadV2Ray
            if [[ "$?" -eq '1' ]]; then
                rm -rf /tmp/v2ray
                echo 'removed: /tmp/v2ray'
                shift
            fi
            installSoftware unzip
            decompression "$ZIP_FILE"
        fi
    fi

    if [[ -n "$(pgrep v2ray)" ]]; then
        V2RAY_RUNNING='true'
        stopV2Ray
    fi
    installV2Ray
    installStartupServiceFile
    echo 'installed: /usr/local/bin/v2ray'
    echo 'installed: /usr/local/bin/v2ctl'
    echo 'installed: /usr/local/lib/v2ray/geoip.dat'
    echo 'installed: /usr/local/lib/v2ray/geosite.dat'
    echo 'installed: /etc/v2ray/config.json'
    echo 'installed: /var/log/v2ray'
    echo 'installed: /etc/rc.d/v2ray'
    echo 'Please execute the command: rcctl enable v2ray'
    rm -rf /tmp/v2ray
    echo 'removed: /tmp/v2ray'
    if [[ "$V2RAY_RUNNING" == 'true' ]]; then
        startV2Ray
    fi
    echo "info: V2Ray $NEW_VER is installed."
}

main
