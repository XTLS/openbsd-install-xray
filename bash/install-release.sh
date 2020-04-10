#!/bin/bash

# The files installed by this script conform to the layout of the file system in the OpenBSD operating system:
# https://man.openbsd.org/hier

# The URL of the script project is:
# https://github.com/v2fly/openbsd-install-v2ray

# The URL of the script is:
# https://raw.githubusercontent.com/v2fly/openbsd-install-v2ray/master/bash/install-release.sh

# If the script executes incorrectly, go to:
# https://github.com/v2fly/openbsd-install-v2ray/issues

# Judge computer systems and architecture
if [[ "$(uname)" == 'OpenBSD' ]]; then
    case "$(arch -s)" in
        'i686' | 'i386')
            BIT='32'
            ;;
        'x86_64' | 'amd64')
            BIT='64'
            ;;
        *)
            echo "error: The architecture is not supported."
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
        '--remove')
            if [[ "$#" -gt '1' ]]; then
                echo 'error: Please enter the correct command.'
                exit 1
            fi
            REMOVE='1'
            ;;
        '--version')
            if [[ "$#" -gt '2' ]] || [[ -z "$2" ]]; then
                echo 'error: Please specify the correct version.'
                exit 1
            fi
            VERSION="$2"
            ;;
        '-c' | '--check')
            if [[ "$#" -gt '1' ]]; then
                echo 'error: Please enter the correct command.'
                exit 1
            fi
            CHECK='1'
            ;;
        '-f' | '--force')
            if [[ "$#" -gt '1' ]]; then
                echo 'error: Please enter the correct command.'
                exit 1
            fi
            FORCE='1'
            ;;
        '-h' | '--help')
            if [[ "$#" -gt '1' ]]; then
                echo 'error: Please enter the correct command.'
                exit 1
            fi
            HELP='1'
            ;;
        '-l' | '--local')
            if [[ "$#" -gt '2' ]] || [[ -z "$2" ]]; then
                echo 'error: Please specify the correct local file.'
                exit 1
            fi
            LOCAL_FILE="$2"
            LOCAL_INSTALL='1'
            ;;
        '-p' | '--proxy')
            case "$2" in
                'http://'*)
                    ;;
                'https://'*)
                    ;;
                'socks4://'*)
                    ;;
                'socks4a://'*)
                    ;;
                'socks5://'*)
                    ;;
                'socks5h://'*)
                    ;;
                *)
                    echo 'error: Please specify the correct proxy server address.'
                    exit 1
                    ;;
            esac
            PROXY="-x $2"
            # Parameters available through a proxy server
            if [[ "$#" -gt '2' ]]; then
                case "$3" in
                    '--version')
                        if [[ "$#" -gt '4' ]] || [[ -z "$4" ]]; then
                            echo 'error: Please specify the correct version.'
                            exit 1
                        fi
                        VERSION="$2"
                        ;;
                    '-c' | '--check')
                        if [[ "$#" -gt '3' ]]; then
                            echo 'error: Please enter the correct command.'
                            exit 1
                        fi
                        CHECK='1'
                        ;;
                    '-f' | '--force')
                        if [[ "$#" -gt '3' ]]; then
                            echo 'error: Please enter the correct command.'
                            exit 1
                        fi
                        FORCE='1'
                        ;;
                    *)
                        echo "$0: unknown option -- -"
                        exit 1
                        ;;
                esac
            fi
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
        'v'*)
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
        # Determine the version number for V2Ray installed from a local file
        if [[ -f '/usr/local/bin/v2ray' ]]; then
            VERSION="$(/usr/local/bin/v2ray -version)"
            CURRENT_VERSION="$(versionNumber $(echo $VERSION | head -n 1 | awk -F ' ' '{print $2}'))"
            if [[ "$LOCAL_INSTALL" -eq '1' ]]; then
                RELEASE_VERSION="$CURRENT_VERSION"
                return
            fi
        fi
        # Get V2Ray release version number
        TMP_FILE="$(mktemp)"
        installSoftware curl
        curl ${PROXY} -o "$TMP_FILE" https://api.github.com/repos/v2ray/v2ray-core/releases/latest -s
        if [[ "$?" -ne '0' ]]; then
            rm "$TMP_FILE"
            echo 'error: Failed to get release list, please check your network.'
            exit 1
        fi
        RELEASE_LATEST="$(cat $TMP_FILE | sed 'y/,/\n/' | grep 'tag_name' | awk -F '"' '{print $4}')"
        rm "$TMP_FILE"
        RELEASE_VERSION="$(versionNumber $RELEASE_LATEST)"
        # Compare V2Ray version numbers
        if [[ "$RELEASE_VERSION" != "$CURRENT_VERSION" ]]; then
            RELEASE_VERSIONSION_NUMBER="${RELEASE_VERSION#v}"
            RELEASE_MAJOR_VERSION_NUMBER="${RELEASE_VERSIONSION_NUMBER%%.*}"
            RELEASE_MINOR_VERSION_NUMBER="$(echo $RELEASE_VERSIONSION_NUMBER | awk -F '.' '{print $2}')"
            RELEASE_MINIMUM_VERSION_NUMBER="${RELEASE_VERSIONSION_NUMBER##*.}"
            CURRENT_VERSIONSION_NUMBER="$(echo ${CURRENT_VERSION#v} | sed 's/-.*//')"
            CURRENT_MAJOR_VERSION_NUMBER="${CURRENT_VERSIONSION_NUMBER%%.*}"
            CURRENT_MINOR_VERSION_NUMBER="$(echo $CURRENT_VERSIONSION_NUMBER | awk -F '.' '{print $2}')"
            CURRENT_MINIMUM_VERSION_NUMBER="${CURRENT_VERSIONSION_NUMBER##*.}"
            if [[ "$RELEASE_MAJOR_VERSION_NUMBER" -gt "$CURRENT_MAJOR_VERSION_NUMBER" ]]; then
                return 0
            elif [[ "$RELEASE_MAJOR_VERSION_NUMBER" -eq "$CURRENT_MAJOR_VERSION_NUMBER" ]]; then
                if [[ "$RELEASE_MINOR_VERSION_NUMBER" -gt "$CURRENT_MINOR_VERSION_NUMBER" ]]; then
                    return 0
                elif [[ "$RELEASE_MINOR_VERSION_NUMBER" -eq "$CURRENT_MINOR_VERSION_NUMBER" ]]; then
                    if [[ "$RELEASE_MINIMUM_VERSION_NUMBER" -gt "$CURRENT_MINIMUM_VERSION_NUMBER" ]]; then
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
        elif [[ "$RELEASE_VERSION" == "$CURRENT_VERSION" ]]; then
            return 1
        fi
    else
        RELEASE_VERSION="$(versionNumber $VERSION)"
        return 2
    fi
}
downloadV2Ray() {
    mkdir "$TMP_DIRECTORY"
    DOWNLOAD_LINK="https://github.com/v2ray/v2ray-core/releases/download/$RELEASE_VERSION/v2ray-openbsd-$BIT.zip"
    echo "Downloading V2Ray archive: $DOWNLOAD_LINK"
    curl ${PROXY} -L -H 'Cache-Control: no-cache' -o "$ZIP_FILE" "$DOWNLOAD_LINK" -#
    if [[ "$?" -ne '0' ]]; then
        echo 'error: Download failed! Please check your network or try again.'
        return 1
    fi
    echo "Downloading verification file for V2Ray archive: $DOWNLOAD_LINK.dgst"
    curl ${PROXY} -L -H 'Cache-Control: no-cache' -o "$ZIP_FILE.dgst" "$DOWNLOAD_LINK.dgst" -#
    if [[ "$?" -ne '0' ]]; then
        echo 'error: Download failed! Please check your network or try again.'
        return 1
    fi
    if [[ "$(cat $ZIP_FILE.dgst)" == 'Not Found' ]]; then
        echo 'error: This version does not support verification. Please replace with another version.'
        return 1
    fi
    # Verification of V2Ray archive
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
        install -m 755 -g bin "${TMP_DIRECTORY}$NAME" "/usr/local/bin/$NAME"
    elif [[ "$NAME" == 'geoip.dat' ]] || [[ "$NAME" == 'geosite.dat' ]]; then
        install -m 755 -g bin "${TMP_DIRECTORY}$NAME" "/usr/local/lib/v2ray/$NAME"
    fi
}
installV2Ray(){
    # Install V2Ray binary to /usr/local/bin/ and /usr/local/lib/v2ray/
    installFile v2ray
    installFile v2ctl
    install -d /usr/local/lib/v2ray/
    installFile geoip.dat
    installFile geosite.dat

    # Install V2Ray configuration file to /etc/v2ray/
    if [[ ! -d '/etc/v2ray/' ]]; then
        install -d /etc/v2ray/
        for BASE in 00_log 01_api 02_dns 03_routing 04_policy 05_inbounds 06_outbounds 07_transport 08_stats 09_reverse; do
            echo '{}' > "/etc/v2ray/$BASE.json"
        done
    fi

    # Used to store V2Ray log files
    if [[ ! -d '/var/log/v2ray/' ]]; then
        install -do www /var/log/v2ray/
    fi
}
installStartupServiceFile() {
    if [[ ! -f '/etc/rc.d/v2ray' ]]; then
        mkdir "${TMP_DIRECTORY}rc.d/"
        installSoftware curl
        curl ${PROXY} -o "${TMP_DIRECTORY}rc.d/v2ray" https://raw.githubusercontent.workers.dev/v2fly/openbsd-install-v2ray/master/rc.d/v2ray -s
        if [[ "$?" -ne '0' ]]; then
            echo 'error: Failed to start service file download! Please check your network or try again.'
            exit 1
        fi
        install -m 755 -g bin "${TMP_DIRECTORY}rc.d/v2ray" /etc/rc.d/v2ray
    fi
}

startV2Ray() {
    if [[ -f '/etc/rc.d/v2ray' ]]; then
        rcctl start v2ray
    fi
    if [[ "$?" -ne 0 ]]; then
        echo 'error: Failed to start V2Ray service.'
        exit 1
    fi
    echo 'info: Start the V2Ray service.'
}
stopV2Ray() {
    if [[ -f '/etc/rc.d/v2ray' ]]; then
        rcctl stop v2ray
    fi
    if [[ "$?" -ne '0' ]]; then
        echo 'error: Stopping the V2Ray service failed.'
        exit 1
    fi
    echo 'info: Stop the V2Ray service.'
}

checkUpdate() {
    if [[ -f '/etc/rc.d/v2ray' ]]; then
        getVersion
        if [[ "$?" -eq '0' ]]; then
            echo "info: Found the latest release of V2Ray $RELEASE_VERSION . (Current release: $CURRENT_VERSION)"
        elif [[ "$?" -eq '1' ]]; then
            echo "info: No new version. The current version of V2Ray is $CURRENT_VERSION ."
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
        rm -r /usr/local/bin/{v2ray,v2ctl} /usr/local/lib/v2ray/ /etc/rc.d/v2ray
        if [[ "$?" -ne '0' ]]; then
            echo 'error: Failed to remove V2Ray.'
            exit 1
        else
            echo 'removed: /usr/local/bin/v2ray'
            echo 'removed: /usr/local/bin/v2ctl'
            echo 'removed: /usr/local/lib/v2ray/'
            echo 'removed: /etc/rc.d/v2ray'
            echo 'Please execute the command: rcctl disable v2ray'
            echo 'You may need to execute a command to remove dependent software: pkg_delete -c bash curl unzip; pkg_delete -ac'
            echo 'info: V2Ray has been removed.'
            echo 'info: If necessary, manually delete the configuration and log files.'
            echo 'info: e.g., /etc/v2ray/ and /var/log/v2ray/ ...'
            exit 0
        fi
    else
        echo 'error: V2Ray is not installed.'
        exit 1
    fi
}

# Explanation of parameters in the script
showHelp() {
    echo "usage: $0 [--remove | --version number | -c | -f | -h | -l | -p]"
    echo '  [-p address] [--version number | -c | -f]'
    echo '  --remove        Remove V2Ray'
    echo '  --version       Install the specified version of V2Ray, e.g., --version v4.23.0'
    echo '  -c, --check     Check if V2Ray can be updated'
    echo '  -f, --force     Force installation of the latest version of V2Ray'
    echo '  -h, --help      Show help'
    echo '  -l, --local     Install V2Ray from a local file'
    echo '  -p, --proxy     Download through a proxy server, e.g., -p http://127.0.0.1:8118 or -p socks5://127.0.0.1:1080'
    exit 0
}

main() {
    # helping information
    [[ "$HELP" -eq '1' ]] && showHelp
    [[ "$CHECK" -eq '1' ]] && checkUpdate
    [[ "$REMOVE" -eq '1' ]] && removeV2Ray

    # Two very important variables
    TMP_DIRECTORY="$(mktemp -du)/"
    ZIP_FILE="${TMP_DIRECTORY}v2ray-openbsd-$BIT.zip"

    # Install V2Ray from a local file, but still need to make sure the network is available
    if [[ "$LOCAL_INSTALL" -eq '1' ]]; then
        echo 'warn: Install V2Ray from a local file, but still need to make sure the network is available.'
        echo -n 'warn: Please make sure the file is valid because we cannot confirm it. (Press any key) ...'
        read
        installSoftware unzip
        mkdir "$TMP_DIRECTORY"
        decompression "$LOCAL_FILE"
    else
        # Normal way
        getVersion
        NUMBER="$?"
        if [[ "$NUMBER" -eq '0' ]] || [[ "$FORCE" -eq '1' ]] || [[ "$NUMBER" -eq 2 ]]; then
            echo "info: Installing V2Ray $RELEASE_VERSION for $(arch -s)"
            downloadV2Ray
            if [[ "$?" -eq '1' ]]; then
                rm -r "$TMP_DIRECTORY"
                echo "removed: $TMP_DIRECTORY"
                exit 0
            fi
            installSoftware unzip
            decompression "$ZIP_FILE"
        elif [[ "$NUMBER" -eq '1' ]]; then
            echo "info: No new version. The current version of V2Ray is $CURRENT_VERSION ."
            exit 0
        fi
    fi

    # Determine if V2Ray is running
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
    echo 'installed: /etc/v2ray/00_log.json'
    echo 'installed: /etc/v2ray/01_api.json'
    echo 'installed: /etc/v2ray/02_dns.json'
    echo 'installed: /etc/v2ray/03_routing.json'
    echo 'installed: /etc/v2ray/04_policy.json'
    echo 'installed: /etc/v2ray/05_inbounds.json'
    echo 'installed: /etc/v2ray/06_outbounds.json'
    echo 'installed: /etc/v2ray/07_transport.json'
    echo 'installed: /etc/v2ray/08_stats.json'
    echo 'installed: /etc/v2ray/09_reverse.json'
    echo 'installed: /var/log/v2ray/'
    echo 'installed: /etc/rc.d/v2ray'
    if [[ "$V2RAY_RUNNING" -ne '1' ]]; then
        echo 'Please execute the command: rcctl enable v2ray; rcctl start v2ray'
    fi
    echo 'You may need to execute a command to remove dependent software: pkg_delete -c bash curl unzip; pkg_delete -ac'
    if [[ "$V2RAY_RUNNING" -eq '1' ]]; then
        startV2Ray
    fi
    if [[ "$LOCAL_INSTALL" -eq '1' ]]; then
        getVersion
    fi
    rm -r "$TMP_DIRECTORY"
    echo "removed: $TMP_DIRECTORY"
    echo "info: V2Ray $RELEASE_VERSION is installed."
}

main
