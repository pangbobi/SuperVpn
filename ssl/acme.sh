#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 保存路径
SSL_DIR=$1
# 系统安装工具
osSystemPackage=$2
# 用来申请的邮箱
YOUR_EMAIL=$3
# 已解析到本机的域名
YOUR_DOMAIN=$4
# CA 供应商
CA_TYPE=$5
# 验证端口
port=$6

# 生成逐级目录
if [ ! -d "$SSL_DIR" ];then
    mkdir -p $SSL_DIR
fi

ACME_SH="/root/.acme.sh/acme.sh"
if [ ! -d "/root/.acme.sh" ];then
    # 安装 socat
    if [ ! "$(which socat)" ];then
        $osSystemPackage install -y socat
    fi
    # 开放端口权限给 socat
    setcap 'cap_net_bind_service=+ep' $(which socat)

    # 官网在线安装
    wget -O -  https://get.acme.sh | sh -s email="$YOUR_EMAIL"

    # 自动更新 acme.sh
    $ACME_SH --upgrade --auto-upgrade
    # 设置证书自动更新
    # $ACME_SH --install-cronjob

    # 设置默认 CA
    $ACME_SH --set-default-ca --server $CA_TYPE
    # 使用邮箱注册 zerossl,letsencrypt 服务
    $ACME_SH --register-account -m $YOUR_EMAIL --server $CA_TYPE

    # 安装 lsof
    if [ ! "$(which lsof)" ];then
        $osSystemPackage install -y lsof
    fi
fi

# 执行申请
ISSUE_CMD="$ACME_SH --issue -d $YOUR_DOMAIN --keylength ec-256 --force"
if [[ $port == "80" && ! "$(lsof -i:80)" ]];then
    # 80端口空闲
    PATTERN="--standalone"
elif [[ $port == "443" && ! "$(lsof -i:443)" ]];then
    # 443端口空闲
    PATTERN="--alpn"
    CA_TYPE="letsencrypt"
else
    case $port in
        "80")
        echo -e "80 端口被占用，请先暂停下面的服务(等证书申请完毕后再恢复该服务)：\n"
        lsof -i:80 | uniq;;
        "443")
        echo -e "443 端口被占用，请先暂停下面的服务(等证书申请完毕后再恢复该服务)：\n"
        lsof -i:443 | uniq;;
        *)
        echo -e "请使用 80 或 443 端口，开放其防火墙并确保其处于空闲状态，再来申请证书";;
    esac
    exit 1;
fi
$ISSUE_CMD $PATTERN --server $CA_TYPE

# 安装到指定路径
$ACME_SH --install-cert \
-d $YOUR_DOMAIN \
--key-file ${SSL_DIR}/${YOUR_DOMAIN}.key \
--fullchain-file ${SSL_DIR}/${YOUR_DOMAIN}.pem \
--ecc
