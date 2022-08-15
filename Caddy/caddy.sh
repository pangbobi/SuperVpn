#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 加载默认参数设置
source <(curl -sL https://raw.githubusercontent.com/pangbobi/SuperVpn/master/tools/defaultSetting.sh)

# 检查是否为 root 权限
if [ $(whoami) != "root" ];then
	echo -e "${Error}您必须以root用户运行此脚本"
	exit 1;
fi

# 检查jq是否安装
source <(curl -sL ${PROJECT_URL}/tools/checkInstall.sh) apt jq
if [ $INSTALL_CHECK == "no" ];then
    echo -e "${Error}$(green_font jq)安装失败，请先自行安装 jq"
    exit 1;
fi

# 检查 wget 是否安装
source <(curl -sL ${PROJECT_URL}/tools/checkInstall.sh) apt wget
if [ $INSTALL_CHECK == "no" ];then
    echo -e "${Error}$(green_font wget)安装失败，请先自行安装 wget"
    exit 1;
fi

# 检查 unzip 是否安装
source <(curl -sL ${PROJECT_URL}/tools/checkInstall.sh) apt unzip
if [ $INSTALL_CHECK == "no" ];then
    echo -e "${Error}$(green_font unzip)安装失败，请先自行安装 unzip"
    exit 1;
fi

# 创建存放 Caddy 的文件夹
Caddy_Dir="${INSATLL_DIR}/Caddy"
source <(curl -sL ${PROJECT_URL}/tools/checkDirFile.sh) $Caddy_Dir 1

# 获取 Caddy 最新版本
Caddy_USER="caddyserver/caddy"
source <(curl -sL ${PROJECT_URL}/tools/checkVer.sh) $Caddy_USER

# Caddy 的下载地址
Caddy_URL="https://github.com/${Caddy_USER}/releases/download/${LATEST_VER}/caddy_${LATEST_VER:1}_linux_amd64.tar.gz"

# 下载 Caddy 到指定路径并解压
wget -O ${Caddy_Dir}/caddy.tar.gz $Caddy_URL
tar zxvf ${Caddy_Dir}/caddy.tar.gz -C $Caddy_Dir

# 下载静态网页到指定路径并解压
wget -O ${Caddy_Dir}/fakeweb.zip ${PROJECT_URL}/fake_web.zip
unzip ${Caddy_Dir}/fakeweb.zip -d ${Caddy_Dir}/fakeweb

# 编辑CaddyFile
cat > ${Caddy_Dir}/Caddyfile <<-EOF
{
    http_port 端口1
    https_port 端口2
}

你的域名 {
    gzip
    root * /etc/SuperVpn/Caddy/fakeweb
    file_server
    # tls 你用来申请 Let's Encrypt 证书的邮箱
    tls 域名对应的证书 域名对应的私钥

    forwardproxy {
        basicauth 用户名 密码
        hide_ip
        hide_via
        probe_resistance www.personalnas.com
        upstream 正向代理地址
    }
}
EOF
