#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 文件夹或文件
DirFile=$1

# 0表示文件，1表示文件夹
Df_Type=$2

# 创建文件或文件夹
if [ $Df_Type == "0" ];then
    if [ ! -f $DirFile ];then
        # 先创建文件所在文件夹
        Df_Path=${DirFile%/*}
        if [ $Df_Path != $DirFile ];then
            mkdir -p $Df_Path
        fi
        # 文件不存在则创建
        touch $DirFile
    fi
else
    if [ ! -d $DirFile ];then
        # 文件夹不存在则创建
        mkdir -p $DirFile
    fi
fi
