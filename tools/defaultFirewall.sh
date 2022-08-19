#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 初始化防火墙设置
Set_Firewall(){
	# SSH 端口
	sshPort=$(cat /etc/ssh/sshd_config | grep 'Port '|awk '{print $2}')

	# 检测是否支持 IPV6
	if [ "$(ifconfig | grep inet6)" ];then
		IPV6="yes"
	else
		IPV6="no"
	fi

	# 开放 SSH 端口并设置防火墙开机启动
	if [[ "$osSystemPackage" =~ "apt" ]];then
		$osSystemPackage install -y ufw
		if [ -f "/usr/sbin/ufw" ];then
			ufw allow $sshPort

			# 允许开机自启
			if [ "$IPV6" == "yes" ];then
				sed -i 's/IPV6=no/IPV6=yes/g' /etc/default/ufw
				sed -i 's/ENABLED=no/ENABLED=yes/g' /etc/ufw/ufw.conf
			fi
			echo y|ufw enable
			
			# 默认允许出站，拒绝入站
			ufw default deny
			ufw reload
		fi
		firewallTool="ufw"
	else
		if [ -f "/etc/init.d/iptables" ];then
			choseIp6tables(){
				iptableType=$1

				# $iptableType -I INPUT -p tcp -m state --state NEW -m tcp --dport $sshPort -j ACCEPT
				$iptableType -I INPUT -p tcp -m tcp --dport $sshPort -j ACCEPT
				$iptableType -I INPUT -p udp -m udp --dport $sshPort -j ACCEPT
				
				# 保持已连接的会话不断开
				$iptableType -A INPUT -p icmp --icmp-type any -j ACCEPT
				$iptableType -A INPUT -s localhost -d localhost -j ACCEPT
				$iptableType -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
				$iptableType -P INPUT DROP
				service $iptableType save
			}

			# 持久化保存
			clear && echo
			echo -e "${Info}如有弹框，请务必选择 yes，按任意键继续..."
			char=$(waitInput)
			$osSystemPackage install -y iptables-persistent
			
			choseIp6tables 'iptables'
			service iptables restart
			firewallTool="iptables"

			if [ "$IPV6" == "yes" ];then
				choseIp6tables 'ip6tables'
				service ip6tables restart
				firewallTool="ip6tables"
			fi
			
			netfilter-persistent save
		else
			AliyunCheck=$(cat /etc/redhat-release|grep "Aliyun Linux")
			[ "$AliyunCheck" ] && return
			$osSystemPackage install -y firewalld
			Centos8Check=$(cat /etc/redhat-release | grep ' 8.' | grep -iE 'centos|Red Hat')
			[ "$Centos8Check" ] && $osSystemPackage reinstall -y python3-six

			systemctl enable firewalld
			systemctl start firewalld
			firewall-cmd --set-default-zone=public > /dev/null 2>&1
			firewall-cmd --permanent --zone=public --add-port=${sshPort}/tcp > /dev/null 2>&1
			firewall-cmd --permanent --zone=public --add-port=${sshPort}/udp > /dev/null 2>&1
			firewall-cmd --reload
			firewallTool="firewall-cmd"
		fi
	fi

	# 保存到配置文件
	tmp=$(jq '.LoginInfo.sshPort="'$sshPort'"' $STATUS_FILE)
	tmp=$(echo $tmp | jq '.IPV6="'$IPV6'"')
	echo $tmp | jq '.FirewallTool="'$firewallTool'"' > tmp.json
	mv tmp.json $STATUS_FILE
}

# 执行防火墙初始设置
Set_Firewall
