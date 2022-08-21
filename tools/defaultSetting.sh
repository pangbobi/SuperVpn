#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 默认变量
HOME_DIR="/root"
INSATLL_DIR="/etc/SuperVpn"
SCIRIPT_DIR="${INSATLL_DIR}/sh"
STATUS_FILE="${HOME_DIR}/SuperVpnStatus.json"

# 不同颜色函数
source <(curl -sL ${PANGBOBI_URL}/tools/color.sh)

# 检查工具包是否已经安装
checkPKG(){
	# 安装工具
	osSystemPackage=$1
	# 工具包名
	PKG=$2

	if [ ! $(which $PKG) ];then
		isInstall=$($osSystemPackage install -y $PKG)
		if [ "$?" != "0" ];then
			echo -e "${Error}$(green_font $PKG)安装失败，请先自行安装 $PKG"
    		exit 1;
		fi
	fi
}

# 获取保存的系统信息
getSystemInfo(){
	# 对文件只读一次
	OsInfo=$(jq -r '.OsInfo' $STATUS_FILE)

	# 从变量提取信息
	osRelease=$(echo $OsInfo | jq -r '.osRelease')
	osReleaseVersion=$(echo $OsInfo | jq -r '.osReleaseVersion')
	osSystemPackage=$(echo $OsInfo | jq -r '.osSystemPackage')
	osArchitecture=$(echo $OsInfo | jq -r '.osArchitecture')
	osBit=$(echo $OsInfo | jq -r '.osBit')
}

# 等待输入
waitInput(){
	SAVEDSTTY=`stty -g`
	stty -echo
	stty cbreak
	dd if=/dev/tty bs=1 count=1 2> /dev/null
	stty -raw
	stty echo
	stty $SAVEDSTTY
}

# 端口有效性检查及生成函数
getPort(){
	# 检测并安装 lsof 来检测端口占用
	checkPKG $osSystemPackage lsof

	# 随机/手动输入
	if [ "$1" == "random" ];then
		while true;do
			port=$(shuf -i 4000-9000 -n1)
			if [ ! "$(lsof -i:$port)" ];then
				break
			fi
		done
	else
		clear && echo
		while true;do
			read -p "${Info}请输入要使用的端口号[0-65535]：" port
			if [[ $port -ge "0" && $port -le "65535" && ! "$(lsof -i:$port)" ]];then
				break
			fi
			echo -e "${Error}端口$(green_font $port)不合法或已被占用"
		done
	fi
	
	echo $port
}

# 满足系统/版本/位数要求
checkSysVerBit(){
	# 提示信息
	msgSysVerBit(){
		echo -e "${Error}当前系统：$osRelease 版本：$osReleaseVersion 位数：$osBit 不满足以下使用要求："
		echo -e "${Tips}系统：debian 版本>=10 位数=64"
		echo -e "${Tips}系统：ubuntu 版本>=18 位数=64"
		echo -e "${Tips}系统：centos 版本>=8 位数=64"
		exit 1;
	}

	if [ "$osBit" == "64" ];then
		case "$osRelease" in
			"debian")
				if [ "$osReleaseVersion" -lt "10" ];then
					msgSysVerBit
				fi;;
			"ubuntu")
				if [ "$osReleaseVersion" -lt "18" ];then
					msgSysVerBit
				fi;;
			"centos")
				if [ "$osReleaseVersion" -lt "8" ];then
					msgSysVerBit
				fi;;
			*) msgSysVerBit;;
		esac
	else
		msgSysVerBit
	fi
}

# 防火墙设置
setFirewall(){
	# 开放/关闭
	openType=$1
	if [ $openType != "show" ];then
		# 网络类型(ip/port)
		netType=$2
		# 操作对象
		port=$3
	fi

	# 开放
	openFirewall(){
		if [ $netType == "port" ];then
			# 允许从端口入站
			case $firewallTool in
				"ufw")
				ufw allow $port
				ufw reload;;
				"firewall-cmd")
				firewall-cmd --permanent --zone=public --add-port=${port}/tcp > /dev/null 2>&1
				firewall-cmd --permanent --zone=public --add-port=${port}/udp > /dev/null 2>&1
				firewall-cmd --reload;;
				*)
				# iptables
				iptables -I INPUT -p tcp -m tcp --dport $port -j ACCEPT
				iptables -I INPUT -p udp -m udp --dport $port -j ACCEPT
				service iptables restart
				# ip6tables
				if [ $firewallTool == "ip6tables" ];then
					ip6tables -I INPUT -p tcp -m tcp --dport $port -j ACCEPT
					ip6tables -I INPUT -p udp -m udp --dport $port -j ACCEPT
					service ip6tables restart
				fi
				netfilter-persistent save;;
			esac
		else
			# 允许指定 IP 访问
			case $firewallTool in
				"ufw")
				ufw allow from $port
				ufw reload;;
				"firewall-cmd")
				firewall-cmd --permanent --zone=public --add-rich-rule="rule family='ipv4' source address='$port' accept" > /dev/null 2>&1
				firewall-cmd --reload;;
				*)
				# iptables
				iptables -I INPUT -s $port -j ACCEPT
				service iptables restart
				# ip6tables
				if [ $firewallTool == "ip6tables" ];then
					ip6tables -I INPUT -s $port -j ACCEPT
					service ip6tables restart
				fi
				netfilter-persistent save;;
			esac
		fi
	}

	# 关闭
	closeFirewall(){
		if [ $netType == "port" ];then
			# 禁止从端口入站
			case $firewallTool in
				"ufw")
				ufw deny $port
				ufw reload;;
				"firewall-cmd")
				firewall-cmd --permanent --zone=public --remove-port=${port}/tcp > /dev/null 2>&1
				firewall-cmd --permanent --zone=public --remove-port=${port}/udp > /dev/null 2>&1
				firewall-cmd --reload;;
				*)
				# iptables
				iptables -I INPUT -p tcp -m tcp --dport $port -j DROP
				iptables -I INPUT -p udp -m udp --dport $port -j DROP
				service iptables restart
				# ip6tables
				if [ $firewallTool == "ip6tables" ];then
					ip6tables -I INPUT -p tcp -m tcp --dport $port -j DROP
					ip6tables -I INPUT -p udp -m udp --dport $port -j DROP
					service ip6tables restart
				fi
				netfilter-persistent save;;
			esac
		else
			# 禁止指定 IP 访问
			case $firewallTool in
				"ufw")
				ufw deny from $port
				ufw reload;;
				"firewall-cmd")
				firewall-cmd --permanent --zone=public --add-rich-rule="rule family='ipv4' source address='$port' drop" > /dev/null 2>&1
				firewall-cmd --reload;;
				*)
				# iptables
				iptables -I INPUT -s $port -j DROP
				service iptables restart
				# ip6tables
				if [ $firewallTool == "ip6tables" ];then
					ip6tables -I INPUT -s $port -j DROP
					service ip6tables restart
				fi
				netfilter-persistent save;;
			esac
		fi
	}

	# 查看防火墙规则
	showFirewall(){
		clear && echo
		case $firewallTool in
			"ufw")
			ufw status;;
			"firewall-cmd")
			firewall-cmd --zone=public --list-ports
			firewall-cmd --zone=public --list-rich-rules;;
			*)
			iptables -L;;
		esac
	}

	# 入口
	case $openType in
		"open")
		openFirewall;;
		"close")
		closeFirewall;;
		"show")
		showFirewall;;
	esac
}
