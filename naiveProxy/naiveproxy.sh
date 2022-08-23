#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 检查 wget unzip golang
if [ $(jq 'has("NaiveProxy")' $STATUS_FILE) == "false" ];then
    $osSystemPackage install -y wget unzip golang
    jq '.NaiveProxy.Golang="true"' $STATUS_FILE > tmp.json
    mv tmp.json $STATUS_FILE
fi

# 创建存放 NaiveProxy 的文件夹
Caddy_Dir="${INSATLL_DIR}/NaiveProxy"
source <(curl -sL ${PANGBOBI_URL}/tools/checkDirFile.sh) $Caddy_Dir 1

# 获取 XCaddy 最新版本
Caddy_USER="caddyserver/xcaddy"
source <(curl -sL ${PANGBOBI_URL}/tools/checkVer.sh) $Caddy_USER

# XCaddy 安装
if [ $(jq '.NaiveProxy | has("xcaddy")' $STATUS_FILE) == "false" ];then
    # XCaddy 的下载地址
    Caddy_URL="https://github.com/${Caddy_USER}/releases/download/${LATEST_VER}/xcaddy_${LATEST_VER:1}_linux_${osArchitecture}.tar.gz"

    # 下载 XCaddy 到指定路径并解压
    wget -O ${Caddy_Dir}/xcaddy.tar.gz $Caddy_URL
    tar zxvf ${Caddy_Dir}/xcaddy.tar.gz -C $Caddy_Dir

    jq '.NaiveProxy.xcaddy="true"' $STATUS_FILE > tmp.json
    mv tmp.json $STATUS_FILE
fi

# 执行编译
if [ $(jq '.NaiveProxy | has("caddy")' $STATUS_FILE) == "false" ];then
    ${Caddy_Dir}/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive
    mv caddy ${Caddy_Dir}/caddy

    jq '.NaiveProxy.caddy="true"' $STATUS_FILE > tmp.json
    mv tmp.json $STATUS_FILE
fi

# 下载静态网页到指定路径并解压
if [ $(jq '.NaiveProxy | has("fakeweb")' $STATUS_FILE) == "false" ];then
    wget -O ${Caddy_Dir}/fakeweb.zip ${PANGBOBI_URL}/fake_web.zip
    unzip ${Caddy_Dir}/fakeweb.zip -d ${Caddy_Dir}/fakeweb

    jq '.NaiveProxy.fakeweb="true"' $STATUS_FILE > tmp.json
    mv tmp.json $STATUS_FILE
fi
