#!/bin/bash

# This file is accessible as https://raw.githubusercontent.com/v2fly/openbsd-install-v2ray/master/bash/install-release.sh
# Original source is located at github.com/v2fly/openbsd-install-v2ray/bash/install-release.sh

# If not specify, default meaning of return value:
# 0: Success
# 1: System error
# 2: Application error
# 3: Network error

# Judge computer systems and architecture
if [[ -f /usr/bin/arch ]]; then
    case "$(arch)" in
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
else
    echo "error: This operating system is not supported."
    exit 1
fi

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
            LOCAL_FILE="$2"
            LOCAL_INSTALL='1'
            ;;
        -p | --proxy)
            case "$2" in
                http://*)
                    ;;
                https://*)
                    ;;
                socks4://*)
                    ;;
                socks4a://*)
                    ;;
                socks5://*)
                    ;;
                socks5h://*)
                    ;;
                *)
                    echo 'error: Please specify the correct proxy server address.'
                    exit 1
                    ;;
            esac
            PROXY="-x $2"
            case "$3" in
                --version)
                    if [[ "$#" -gt '4' ]] || [[ -z "$4" ]]; then
                        echo 'error: Please specify the correct version.'
                        exit 1
                    fi
                    VERSION="$2"
                    ;;
                -c | --check)
                    if [[ "$#" -gt '3' ]]; then
                        echo 'error: Please enter the correct command.'
                        exit 1
                    fi
                    CHECK='1'
                    ;;
                -f | --force)
                    if [[ "$#" -gt '3' ]]; then
                        echo 'error: Please enter the correct command.'
                        exit 1
                    fi
                    FORCE='1'
                    ;;
            esac
            ;;
        *)
            echo "$0: unknown option -- -"
            exit 1
            ;;
    esac
fi

installSoftware() {
    COMPONENT="$1"
    if [[ -n "$(command -v $COMPONENT)" ]]; then
        return
    fi
    pkg_add "$COMPONENT--"
    if [[ "$?" -ne '0' ]]; then
        echo "error: Installation of $COMPONENT failed, please check your network."
        exit 1
    fi
    echo "info: $COMPONENT is installed."
}
versionNumber() {
    case "$1" in
        v*)
            echo "$1"
            ;;
        *)
            echo "v$1"
            ;;
    esac
}
getVersion() {
    # 0: Install or update V2Ray.
    # 1: Installed or no new version of V2Ray.
    # 2: Install the specified version of V2Ray.
    if [[ -z "$VERSION" ]]; then
        if [[ -f '/usr/local/bin/v2ray' ]]; then
            VERSION="$(/usr/local/bin/v2ray -version)"
            CURRENT_VERSION="$(versionNumber $(echo $VERSION | head -n 1 | cut -d ' ' -f 2))"
            if [[ "$LOCAL_INSTALL" -eq '1' ]]; then
                NEW_VERSION="$CURRENT_VERSION"
                return
            fi
        fi
        RELEASE_LATEST="$(curl $PROXY https://api.github.com/repos/v2ray/v2ray-core/releases/latest --connect-timeout 10 > $TMP_DIRECTORY)"
        if [[ "$?" -ne '0' ]]; then
            rm "$TMP_DIRECTORY"
            echo 'error: Failed to get release list, please check your network.'
            exit 1
        fi
        RELEASE_LATEST="$(cat $RELEASE_LATEST | grep 'tag_name' | cut -d '"' -f 4)"
        rm "$TMP_DIRECTORY"
        NEW_VERSION="$(versionNumber $RELEASE_LATEST)"
        if [[ "$NEW_VERSION" != "$CURRENT_VERSION" ]]; then
            NEW_VERSIONSION_NUMBER="${NEW_VERSION#v}"
            NEW_MAJOR_VERSION_NUMBER="${NEW_VERSIONSION_NUMBER%%.*}"
            NEW_MINOR_VERSION_NUMBER="$(echo $NEW_VERSIONSION_NUMBER | awk -F '.' '{print $2}')"
            NEW_MINIMUM_VERSION_NUMBER="${NEW_VERSIONSION_NUMBER##*.}"
            CURRENT_VERSIONSION_NUMBER="$(echo ${CURRENT_VERSION#v} | sed 's/-.*//')"
            CURRENT_MAJOR_VERSION_NUMBER="${CURRENT_VERSIONSION_NUMBER%%.*}"
            CURRENT_MINOR_VERSION_NUMBER="$(echo $CURRENT_VERSIONSION_NUMBER | awk -F '.' '{print $2}')"
            CURRENT_MINIMUM_VERSION_NUMBER="${CURRENT_VERSIONSION_NUMBER##*.}"
            if [[ "$NEW_MAJOR_VERSION_NUMBER" -gt "$CURRENT_MAJOR_VERSION_NUMBER" ]]; then
                return 0
            elif [[ "$NEW_MAJOR_VERSION_NUMBER" -eq "$CURRENT_MAJOR_VERSION_NUMBER" ]]; then
                if [[ "$NEW_MINOR_VERSION_NUMBER" -gt "$CURRENT_MINOR_VERSION_NUMBER" ]]; then
                    return 0
                elif [[ "$NEW_MINOR_VERSION_NUMBER" -eq "$CURRENT_MINOR_VERSION_NUMBER" ]]; then
                    if [[ "$NEW_MINIMUM_VERSION_NUMBER" -gt "$CURRENT_MINIMUM_VERSION_NUMBER" ]]; then
                        return 0
                    else
                        return 1
                    fi
                else
                    return 1
                fi
            else
                return 1
            fi
        elif [[ "$NEW_VERSION" == "$CURRENT_VERSION" ]]; then
            return 1
        fi
    else
        NEW_VERSION="$(versionNumber $VERSION)"
        return 2
    fi
}
downloadV2Ray() {
    mkdir "$TMP_DIRECTORY"
    DOWNLOAD_LINK="https://github.com/v2ray/v2ray-core/releases/download/$NEW_VERSION/v2ray-openbsd-$BIT.zip"
    echo "Downloading V2Ray: $DOWNLOAD_LINK"
    curl ${PROXY} -L -H 'Cache-Control: no-cache' -o "$ZIP_FILE" "$DOWNLOAD_LINK" -#
    if [[ "$?" -ne '0' ]]; then
        echo 'error: Download failed! Please check your network or try again.'
        return 1
    fi
    echo "Downloading V2Ray verification file: $DOWNLOAD_LINK.dgst"
    curl ${PROXY} -L -H 'Cache-Control: no-cache' -o "$ZIP_FILE.dgst" "$DOWNLOAD_LINK.dgst" -#
    if [[ "$?" -ne '0' ]]; then
        echo 'error: Download failed! Please check your network or try again.'
        return 1
    fi
    if [[ "$(cat $ZIP_FILE.dgst)" == 'Not Found' ]]; then
        echo 'error: This version does not support verification. Please replace with another version.'
        return 1
    fi
    for LISTSUM in 'md5' 'sha1' 'sha256' 'sha512'; do
        SUM="$($LISTSUM $ZIP_FILE | sed 's/.* //')"
        CHECKSUM="$(grep ${LISTSUM^^} $ZIP_FILE.dgst | sed 's/.* //')"
        if [[ "$SUM" != "$CHECKSUM" ]]; then
            echo 'error: Check failed! Please check your network or try again.'
            return 1
        fi
    done
}
decompression(){
    unzip -q "$1" -d "$TMP_DIRECTORY"
    if [[ "$?" -ne '0' ]]; then
        echo 'error: V2Ray decompression failed.'
        rm -r "$TMP_DIRECTORY"
        echo "removed: $TMP_DIRECTORY"
        exit 1
    fi
    echo "info: Extract the V2Ray package to $TMP_DIRECTORY and prepare it for installation."
}
installFile() {
    NAME="$1"
    if [[ "$NAME" == 'v2ray' ]] || [[ "$NAME" == 'v2ctl' ]]; then
        install -m 755 -g bin "$TMP_DIRECTORY/$NAME" "/usr/local/bin/$NAME"
    elif [[ "$NAME" == 'geoip.dat' ]] || [[ "$NAME" == 'geosite.dat' ]]; then
        install -m 755 -g bin "$TMP_DIRECTORY/$NAME" "/usr/local/lib/v2ray/$NAME"
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
        install -m 644 "$TMP_DIRECTORY/vpoint_vmess_freedom.json" /etc/v2ray/config.json
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
        mkdir "$TMP_DIRECTORY/rc.d"
        curl -o "$TMP_DIRECTORY/rc.d/v2ray" https://raw.githubusercontent.workers.dev/v2fly/openbsd-install-v2ray/master/rc.d/v2ray -s
        install -m 755 -g bin "$TMP_DIRECTORY/rc.d/v2ray" /etc/rc.d/v2ray
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

checkUpdate() {
    if [[ -f '/etc/rc.d/v2ray' ]]; then
        getVersion
        if [[ "$?" -eq '0' ]]; then
            echo "info: Found the latest release of V2Ray $NEW_VERSION. (Current release: $CURRENT_VERSION)"
        elif [[ "$?" -eq '1' ]]; then
            echo "info: No new version. The current version is the latest release $NEW_VERSION."
        fi
        exit 0
    else
        echo 'error: V2Ray is not installed.'
        exit 1
    fi
}

removeV2Ray() {
    if [[ -f '/etc/rc.d/v2ray' ]]; then
        if [[ -n "$(pgrep v2ray)" ]]; then
            stopV2Ray
        fi
        NAME="$1"
        rm -r /usr/local/bin/{v2ray,v2ctl} /usr/local/lib/v2ray /etc/rc.d/v2ray
        if [[ "$?" -ne '0' ]]; then
            echo 'error: Failed to remove V2Ray.'
            exit 1
        else
            echo 'removed: /usr/local/bin/v2ray'
            echo 'removed: /usr/local/bin/v2ctl'
            echo 'removed: /usr/local/lib/v2ray'
            echo 'removed: /etc/rc.d/v2ray'
            echo 'Please execute the command: rcctl disable v2ray'
            echo 'Dependent software you may need to remove manually: pkg_del -c curl unzip'
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

showHelp() {
    echo "usage: $0 [--remove | --version number | -c | -f | -h | -l | -p]"
    echo '  [-p address] [--version number | -c | -f]'
    echo '  --remove        Remove V2Ray'
    echo '  --version       Install the specified version of V2Ray, e.g., --version v4.18.0'
    echo '  -c, --check     Check if V2Ray can be updated'
    echo '  -f, --force     Force installation of the latest version of V2Ray'
    echo '  -h, --help      Show help'
    echo '  -l, --local     Install V2Ray from a local file'
    echo '  -p, --proxy     Download through a proxy server, e.g., -p socks5://127.0.0.1:1080 or -p http://127.0.0.1:8118'
    exit 0
}

main() {
    # helping information
    [[ "$HELP" -eq '1' ]] && showHelp
    [[ "$CHECK" -eq '1' ]] && checkUpdate
    [[ "$REMOVE" -eq '1' ]] && removeV2Ray

    TMP_DIRECTORY="$(mktemp -du)"
    ZIP_FILE="$TMP_DIRECTORY/v2ray-openbsd-$BIT.zip"

    # Install V2Ray from a local file, but still need to make sure the network is available
    if [[ "$LOCAL_INSTALL" -eq '1' ]]; then
        echo -n 'warn: Install V2Ray from a local file, but still need to make sure the network is available. Please make sure the file is valid because we cannot confirm it. (Press any key) ...'
        read
        installSoftware unzip
        mkdir "$TMP_DIRECTORY"
        decompression "$LOCAL_FILE"
    else
        # Normal way
        installSoftware curl
        getVersion
        NUMBER="$?"
        if [[ "$NUMBER" -eq '0' ]] || [[ "$FORCE" -eq '1' ]] || [[ "$NUMBER" -eq 2 ]]; then
            echo "info: Installing V2Ray $NEW_VERSION for $(arch -s)"
            downloadV2Ray
            if [[ "$?" -eq '1' ]]; then
                rm -r "$TMP_DIRECTORY"
                echo "removed: $TMP_DIRECTORY"
                exit 0
            fi
            installSoftware unzip
            decompression "$ZIP_FILE"
        elif [[ "$NUMBER" -eq '1' ]]; then
            echo "info: The latest version $CURRENT_VERSION is installed."
            exit 0
        fi
    fi

    if [[ -n "$(pgrep v2ray)" ]]; then
        V2RAY_RUNNING='1'
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
    echo 'Dependent software you may need to remove manually: pkg_del -c curl unzip'
    rm -r "$TMP_DIRECTORY"
    echo "removed: $TMP_DIRECTORY"
    if [[ "$V2RAY_RUNNING" -eq '1' ]]; then
        startV2Ray
    fi
    if [[ "$LOCAL_INSTALL" -eq '1' ]]; then
        getVersion
    fi
    echo "info: V2Ray $NEW_VERSION is installed."
}

main
