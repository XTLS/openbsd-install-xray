#!/usr/bin/env bash

set -euxo pipefail

# The files installed by this script conform to the layout of the file system in the OpenBSD operating system:
# https://man.openbsd.org/hier

# The URL of the script project is:
# https://github.com/XTLS/openbsd-install-xray

# The URL of the script is:
# https://raw.githubusercontent.com/XTLS/openbsd-install-xray/main/install-release.sh

# If the script executes incorrectly, go to:
# https://github.com/XTLS/openbsd-install-xray/issues

identify_the_operating_system_and_architecture() {
    if [[ "$(uname)" == 'OpenBSD' ]]; then
        case "$(arch -s)" in
            'i386' | 'i686')
                BIT='32'
                ;;
            'amd64' | 'x86_64')
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
}

judgment_parameters() {
    if [[ "$#" -gt '0' ]]; then
        case "$1" in
            '--remove')
                if [[ "$#" -gt '1' ]]; then
                    echo 'error: Please enter the correct parameters.'
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
                    echo 'error: Please enter the correct parameters.'
                    exit 1
                fi
                CHECK='1'
                ;;
            '-f' | '--force')
                if [[ "$#" -gt '1' ]]; then
                    echo 'error: Please enter the correct parameters.'
                    exit 1
                fi
                FORCE='1'
                ;;
            '-h' | '--help')
                if [[ "$#" -gt '1' ]]; then
                    echo 'error: Please enter the correct parameters.'
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
                                echo 'error: Please enter the correct parameters.'
                                exit 1
                            fi
                            CHECK='1'
                            ;;
                        '-f' | '--force')
                            if [[ "$#" -gt '3' ]]; then
                                echo 'error: Please enter the correct parameters.'
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
}

install_software() {
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

version_number() {
    case "$1" in
        'v'*)
            echo "$1"
            ;;
        *)
            echo "v$1"
            ;;
    esac
}

get_version() {
    # 0: Install or update Xray.
    # 1: Installed or no new version of Xray.
    # 2: Install the specified version of Xray.
    if [[ -z "$VERSION" ]]; then
        # Determine the version number for Xray installed from a local file
        if [[ -f '/usr/local/bin/xray' ]]; then
            VERSION="$(/usr/local/bin/xray version)"
            CURRENT_VERSION="$(version_number $(echo $VERSION | head -n 1 | awk -F ' ' '{print $2}'))"
            if [[ "$LOCAL_INSTALL" -eq '1' ]]; then
                RELEASE_VERSION="$CURRENT_VERSION"
                return
            fi
        fi
        # Get Xray release version number
        TMP_FILE="$(mktemp)"
        install_software curl
        curl ${PROXY} -o "$TMP_FILE" https://api.github.com/repos/XTLS/Xray-core/releases/latest -s
        if [[ "$?" -ne '0' ]]; then
            rm "$TMP_FILE"
            echo 'error: Failed to get release list, please check your network.'
            exit 1
        fi
        RELEASE_LATEST="$(cat $TMP_FILE | sed 'y/,/\n/' | grep 'tag_name' | awk -F '"' '{print $4}')"
        rm "$TMP_FILE"
        RELEASE_VERSION="$(version_number $RELEASE_LATEST)"
        # Compare Xray version numbers
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
        RELEASE_VERSION="$(version_number $VERSION)"
        return 2
    fi
}

download_xray() {
    mkdir "$TMP_DIRECTORY"
    DOWNLOAD_LINK="https://github.com/XTLS/Xray-core/releases/download/$RELEASE_VERSION/Xray-openbsd-$BIT.zip"
    echo "Downloading Xray archive: $DOWNLOAD_LINK"
    curl ${PROXY} -L -H 'Cache-Control: no-cache' -o "$ZIP_FILE" "$DOWNLOAD_LINK" -#
    if [[ "$?" -ne '0' ]]; then
        echo 'error: Download failed! Please check your network or try again.'
        return 1
    fi
    echo "Downloading verification file for Xray archive: $DOWNLOAD_LINK.dgst"
    curl ${PROXY} -L -H 'Cache-Control: no-cache' -o "$ZIP_FILE.dgst" "$DOWNLOAD_LINK.dgst" -#
    if [[ "$?" -ne '0' ]]; then
        echo 'error: Download failed! Please check your network or try again.'
        return 1
    fi
    if [[ "$(cat $ZIP_FILE.dgst)" == 'Not Found' ]]; then
        echo 'error: This version does not support verification. Please replace with another version.'
        return 1
    fi

    # Verification of Xray archive
    for LISTSUM in 'md5' 'sha1' 'sha256' 'sha512'; do
        SUM="$($LISTSUM $ZIP_FILE | sed 's/.* //')"
        CHECKSUM="$(grep ${LISTSUM^^} $ZIP_FILE.dgst | sed 's/.* //')"
        if [[ "$SUM" != "$CHECKSUM" ]]; then
            echo 'error: Check failed! Please check your network or try again.'
            return 1
        fi
    done
}

decompression() {
    unzip -q "$1" -d "$TMP_DIRECTORY"
    if [[ "$?" -ne '0' ]]; then
        echo 'error: Xray decompression failed.'
        rm -r "$TMP_DIRECTORY"
        echo "removed: $TMP_DIRECTORY"
        exit 1
    fi
    echo "info: Extract the Xray package to $TMP_DIRECTORY and prepare it for installation."
}

install_file() {
    NAME="$1"
    if [[ "$NAME" == 'xray' ]]; then
        install -m 755 -g bin "${TMP_DIRECTORY}$NAME" "/usr/local/bin/$NAME"
    elif [[ "$NAME" == 'geoip.dat' ]] || [[ "$NAME" == 'geosite.dat' ]]; then
        install -m 755 -g bin "${TMP_DIRECTORY}$NAME" "/usr/local/lib/xray/$NAME"
    fi
}

install_xray() {
    # Install Xray binary to /usr/local/bin/ and /usr/local/lib/xray/
    install_file xray
    install -d /usr/local/lib/xray/
    install_file geoip.dat
    install_file geosite.dat

    # Install Xray configuration file to /etc/xray/
    if [[ ! -d '/etc/xray/' ]]; then
        install -d /etc/xray/
        for BASE in 00_log 01_api 02_dns 03_routing 04_policy 05_inbounds 06_outbounds 07_transport 08_stats 09_reverse; do
            echo '{}' > "/etc/xray/$BASE.json"
        done
        CONFDIR='1'
    fi

    # Used to store Xray log files
    if [[ ! -d '/var/log/xray/' ]]; then
        install -do www /var/log/xray/
        LOG='1'
    fi
}

install_startup_service_file() {
    if [[ ! -f '/etc/rc.d/xray' ]]; then
        mkdir "${TMP_DIRECTORY}rc.d/"
        install_software curl
        curl ${PROXY} -o "${TMP_DIRECTORY}rc.d/xray" https://raw.githubusercontent.com/XTLS/openbsd-install-xray/main/rc.d/xray -s
        if [[ "$?" -ne '0' ]]; then
            echo 'error: Failed to start service file download! Please check your network or try again.'
            exit 1
        fi
        install -m 755 -g bin "${TMP_DIRECTORY}rc.d/xray" /etc/rc.d/xray
        RC_D='1'
    fi
}

start_xray() {
    if [[ -f '/etc/rc.d/xray' ]]; then
        rcctl start xray
    fi
    if [[ "$?" -ne 0 ]]; then
        echo 'error: Failed to start Xray service.'
        exit 1
    fi
    echo 'info: Start the Xray service.'
}

stop_xray() {
    if [[ -f '/etc/rc.d/xray' ]]; then
        rcctl stop xray
    fi
    if [[ "$?" -ne '0' ]]; then
        echo 'error: Stopping the Xray service failed.'
        exit 1
    fi
    echo 'info: Stop the Xray service.'
}

check_update() {
    if [[ -f '/etc/rc.d/xray' ]]; then
        get_version
        if [[ "$?" -eq '0' ]]; then
            echo "info: Found the latest release of Xray $RELEASE_VERSION . (Current release: $CURRENT_VERSION)"
        elif [[ "$?" -eq '1' ]]; then
            echo "info: No new version. The current version of Xray is $CURRENT_VERSION ."
        fi
        exit 0
    else
        echo 'error: Xray is not installed.'
        exit 1
    fi
}

remove_xray() {
    if [[ -f '/etc/rc.d/xray' ]]; then
        if [[ -n "$(pgrep xray)" ]]; then
            stop_xray
        fi
        NAME="$1"
        rm /usr/local/bin/xray
        rm -r /usr/local/lib/xray/
        rm /etc/rc.d/xray
        if [[ "$?" -ne '0' ]]; then
            echo 'error: Failed to remove Xray.'
            exit 1
        else
            echo 'removed: /usr/local/bin/xray'
            echo 'removed: /usr/local/lib/xray/'
            echo 'removed: /etc/rc.d/xray'
            echo 'Please execute the command: rcctl disable xray'
            echo 'You may need to execute a command to remove dependent software: pkg_delete -c bash curl unzip; pkg_delete -ac'
            echo 'info: Xray has been removed.'
            echo 'info: If necessary, manually delete the configuration and log files.'
            echo 'info: e.g., /etc/xray/ and /var/log/xray/ ...'
            exit 0
        fi
    else
        echo 'error: Xray is not installed.'
        exit 1
    fi
}

# Explanation of parameters in the script
show_help() {
    echo "usage: $0 [--remove | --version number | -c | -f | -h | -l | -p]"
    echo '  [-p address] [--version number | -c | -f]'
    echo '  --remove        Remove Xray'
    echo '  --version       Install the specified version of Xray, e.g., --version v1.4.2'
    echo '  -c, --check     Check if Xray can be updated'
    echo '  -f, --force     Force installation of the latest version of Xray'
    echo '  -h, --help      Show help'
    echo '  -l, --local     Install Xray from a local file'
    echo '  -p, --proxy     Download through a proxy server, e.g., -p http://127.0.0.1:8118 or -p socks5://127.0.0.1:1080'
    exit 0
}

main() {
    identify_the_operating_system_and_architecture
    judgment_parameters "$@"

    # Parameter information
    [[ "$HELP" -eq '1' ]] && show_help
    [[ "$CHECK" -eq '1' ]] && check_update
    [[ "$REMOVE" -eq '1' ]] && remove_xray

    # Two very important variables
    TMP_DIRECTORY="$(mktemp -du)/"
    ZIP_FILE="${TMP_DIRECTORY}Xray-openbsd-$BIT.zip"

    # Install Xray from a local file, but still need to make sure the network is available
    if [[ "$LOCAL_INSTALL" -eq '1' ]]; then
        echo 'warn: Install Xray from a local file, but still need to make sure the network is available.'
        echo -n 'warn: Please make sure the file is valid because we cannot confirm it. (Press any key) ...'
        read
        install_software unzip
        mkdir "$TMP_DIRECTORY"
        decompression "$LOCAL_FILE"
    else
        # Normal way
        get_version
        NUMBER="$?"
        if [[ "$NUMBER" -eq '0' ]] || [[ "$FORCE" -eq '1' ]] || [[ "$NUMBER" -eq 2 ]]; then
            echo "info: Installing Xray $RELEASE_VERSION for $(arch -s)"
            download_xray
            if [[ "$?" -eq '1' ]]; then
                rm -r "$TMP_DIRECTORY"
                echo "removed: $TMP_DIRECTORY"
                exit 0
            fi
            install_software unzip
            decompression "$ZIP_FILE"
        elif [[ "$NUMBER" -eq '1' ]]; then
            echo "info: No new version. The current version of Xray is $CURRENT_VERSION ."
            exit 0
        fi
    fi

    # Determine if Xray is running
    if [[ -n "$(pgrep xray)" ]]; then
        stop_xray
        XRAY_RUNNING='1'
    fi
    install_xray
    install_startup_service_file
    echo 'installed: /usr/local/bin/xray'
    echo 'installed: /usr/local/lib/xray/geoip.dat'
    echo 'installed: /usr/local/lib/xray/geosite.dat'
    if [[ "$CONFDIR" -eq '1' ]]; then
        echo 'installed: /etc/xray/00_log.json'
        echo 'installed: /etc/xray/01_api.json'
        echo 'installed: /etc/xray/02_dns.json'
        echo 'installed: /etc/xray/03_routing.json'
        echo 'installed: /etc/xray/04_policy.json'
        echo 'installed: /etc/xray/05_inbounds.json'
        echo 'installed: /etc/xray/06_outbounds.json'
        echo 'installed: /etc/xray/07_transport.json'
        echo 'installed: /etc/xray/08_stats.json'
        echo 'installed: /etc/xray/09_reverse.json'
    fi
    if [[ "$LOG" -eq '1' ]]; then
        echo 'installed: /var/log/xray/'
    fi
    if [[ "$RC_D" -eq '1'  ]]; then
        echo 'installed: /etc/rc.d/xray'
    fi
    rm -r "$TMP_DIRECTORY"
    echo "removed: $TMP_DIRECTORY"
    if [[ "$LOCAL_INSTALL" -eq '1' ]]; then
        get_version
    fi
    echo "info: Xray $RELEASE_VERSION is installed."
    echo 'You may need to execute a command to remove dependent software: pkg_delete -c bash curl unzip; pkg_delete -ac'
    if [[ "$XRAY_RUNNING" -eq '1' ]]; then
        start_xray
    else
        echo 'Please execute the command: rcctl enable xray; rcctl start xray'
    fi
}

main "$@"
