#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 不同颜色函数
green_font(){
    # 绿色字体 及 白色字体
    echo -e "\033[32m\033[01m$1\033[0m\033[37m\033[01m$2\033[0m"
}

red_font(){
    # 红色字体
	echo -e "\033[31m\033[01m$1\033[0m"
}

white_font(){
    # 白色字体
	echo -e "\033[37m\033[01m$1\033[0m"
}

yello_font(){
    # 黄色字体
	echo -e "\033[33m\033[01m$1\033[0m"
}

# 信息提示字
Info=$(green_font [信息])
Error=$(red_font [错误])
Tips=$(yello_font [注意])
