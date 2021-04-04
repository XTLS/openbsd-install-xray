# openbsd-install-xray

> Bash script for installing Xray in the OpenBSD operating system

該腳本安裝的文件符合 OpenBSD 作業系統中文件系統的佈局：

https://man.openbsd.org/hier

```
installed: /usr/local/bin/xray
installed: /usr/local/lib/xray/geoip.dat
installed: /usr/local/lib/xray/geosite.dat
installed: /etc/xray/00_log.json
installed: /etc/xray/01_api.json
installed: /etc/xray/02_dns.json
installed: /etc/xray/03_routing.json
installed: /etc/xray/04_policy.json
installed: /etc/xray/05_inbounds.json
installed: /etc/xray/06_outbounds.json
installed: /etc/xray/07_transport.json
installed: /etc/xray/08_stats.json
installed: /etc/xray/09_reverse.json
installed: /var/log/xray/
installed: /etc/rc.d/xray
```

## 依賴軟體

### 安裝 Bash 和 cURL

```
# pkg_add bash curl
```

## 下載

```
# curl -O https://raw.githubusercontent.com/XTLS/openbsd-install-xray/main/install-release.sh
```

## 使用

* 該腳本在執行時會提供 `info` 和 `error` 等訊息，請仔細閱讀。

### 安裝和更新 Xray

```
# bash install-release.sh
```

### 移除 Xray

```
# bash install-release.sh --remove
```

## 參數

```
usage: install-release.sh [--remove | --version number | -c | -f | -h | -l | -p]
  [-p address] [--version number | -c | -f]
  --remove        Remove Xray
  --version       Install the specified version of Xray, e.g., --version v1.4.2
  -c, --check     Check if Xray can be updated
  -f, --force     Force installation of the latest version of Xray
  -h, --help      Show help
  -l, --local     Install Xray from a local file
  -p, --proxy     Download through a proxy server, e.g., -p http://127.0.0.1:8118 or -p socks5://127.0.0.1:1080
```
