#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 安装工具
PKM=$1

# 工具包名
PKG=$2

# 检查 PKG 是否安装
INSTALL_CHECK=$(which $PKG)
if [ "$?" == "0" ];then
	INSTALL_CHECK="yes"
else
    INSTALL_CHECK=$($PKM install -y $PKG)
	if [ "$?" == "0" ];then
	    INSTALL_CHECK="yes"
    else
        INSTALL_CHECK="no"
    if
fi
