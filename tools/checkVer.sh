#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 接收的第一个参数
OWNER_RES=$1

# 版本 API
LATEST_API="https://api.github.com/repos/${OWNER_RES}/releases/latest"

# 进行 jq 解析 json 返回最新版本
OWNER_RES="caddyserver/caddy"
LATEST_API="https://api.github.com/repos/${OWNER_RES}/releases/latest"
LATEST_VER=$(curl -s $LATEST_API |jq -r '.tag_name')
