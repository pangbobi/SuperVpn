#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#stty erase ^H

#################
#适用于Debian 8+#
#################

#版本
sh_ver=6.8.7
#Github地址
Github_U='https://raw.githubusercontent.com/pangbobi/SuperVpn/master'
#脚本名
SCRIPT_N='tvb.sh'
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
		#wget -qO $SCRIPT_N $UPDATE_U
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

#防火墙配置
add_firewall(){
	ufw allow $1
}
del_firewall(){
	ufw delete allow $1
}
uninstall_sheild(){
	#org=$(wget -qO- -t1 -T2 https://ipapi.co/org)
	org=$(curl -s --retry 2 --max-time 2 https://ipapi.co/org)
	if [[ $org =~ 'Alibaba' ]];then
		#是阿里云则卸载云盾
		curl -O http://update.aegis.aliyun.com/download/uninstall.sh && chmod +x uninstall.sh && ./uninstall.sh
		curl -O http://update.aegis.aliyun.com/download/quartz_uninstall.sh && chmod +x quartz_uninstall.sh && ./quartz_uninstall.sh
		pkill aliyun-service
		rm -rf /etc/init.d/agentwatch /usr/sbin/aliyun-service /usr/local/aegis*
		rm -f uninstall.sh quartz_uninstall.sh
		ufw deny from 140.205.201.0/28
		ufw deny from 140.205.201.16/29
		ufw deny from 140.205.201.32/28
		ufw deny from 140.205.225.183/32
		ufw deny from 140.205.225.184/29
		ufw deny from 140.205.225.192/29
		ufw deny from 140.205.225.195/32
		ufw deny from 140.205.225.200/30
		ufw deny from 140.205.225.204/32
		ufw deny from 140.205.225.205/32
		ufw deny from 140.205.225.206/32
	elif [[ $org =~ 'Tencent' ]];then
		#是腾讯云则卸载云盾ps aux|grep -i agent|grep -v grep
		/usr/local/qcloud/stargate/admin/uninstall.sh
		/usr/local/qcloud/YunJing/uninst.sh
		/usr/local/qcloud/monitor/barad/admin/uninstall.sh
	fi
}
clean_iptables(){
	iptables -D INPUT 1
	iptables -D INPUT 1
}
ufw_default(){
	#UFW默认设置
	ufw default deny incoming
	ufw default allow outgoing
	uninstall_sheild
	clear && echo -e "\n${Info}请输入$(red_font y)"
	ufw allow $ssh_port
	#是否启用UFW管理IPV6
	check_ipv6=$(curl -s --retry 2 --max-time 2 ipv6.icanhazip.com)
	if [ -z $check_ipv6 ];then
		sed -i 's/IPV6=yes/IPV6=no/g' /etc/default/ufw
	else
		sed -i 's/IPV6=no/IPV6=yes/g' /etc/default/ufw
	fi
	#强制修改配置文件开机启动
	sed -i 's/ENABLED=no/ENABLED=yes/g' /etc/ufw/ufw.conf
	#UFW开机启动
	ufw enable
}

#获取各组件安装状态
get_status(){
	if [ -e $CUR_D/.bash_profile ];then
		bbr_status=$(cat $CUR_D/.bash_profile|grep bbr_status|awk -F '=' '{print$2}')
		trojan_status=$(cat $CUR_D/.bash_profile|grep trojan_status|awk -F '=' '{print$2}')
		v2ray_status=$(cat $CUR_D/.bash_profile|grep v2ray_status|awk -F '=' '{print$2}')
		wg_status=$(cat $CUR_D/.bash_profile|grep wg_status|awk -F '=' '{print$2}')
		bt_status=$(cat $CUR_D/.bash_profile|grep bt_status|awk -F '=' '{print$2}')
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
	buster_V=$(apt search linux-image|grep headers|grep buster-backports|grep cloud|head -1|awk -F '/' '{print$1}'|awk -F 'rs-' '{print$2}')
	if [[ `uname -r` != ${buster_V} ]];then
		apt -y install linux-image-${buster_V}
		apt -y install linux-headers-${buster_V}
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
	#第二行插入BBR FQ状态
	sed -i 's/^bbr_status.*/bbr_status=true/' $CUR_D/.bash_profile
	sleep 2s
	apt update
	apt -y install jq lsof unzip expect resolvconf autoconf
	apt --fix-broken install
	#更改系统时间并防止重启失效
	#cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
	timedatectl set-timezone Asia/Shanghai
	hwclock -w
	#安装UFW防火墙管理程序
	apt -y install ufw
	#UFW默认设置
	ufw_default
	ufw reload
	if [[ `ufw status` =~ 'inactive' ]];then
		clear && echo -e "\n${Error}防火墙启动失败！"
		echo -e "${Info}请手动执行命令：ufw enable && ufw reload && ./$SCRIPT_N"
		exit 1
	else
		exec $CUR_D/.bash_profile
	fi
}
#安装并启用BBR FQ
if [ -z $bbr_status ];then
	install_bbr_fq
elif [ $bbr_status == 'false' ];then
	finish_bbr_fq
fi

#域名解析检测
check_domain(){
	clear && echo
	read -p "${Info}请输入已成功解析到本机的域名：" domain
	PING_T=$(ping -c 1 $domain|awk -F '(' '{print $2}'|awk -F ')' '{print $1}'|sed -n '1p')
	if [[ $PING_T != $SER_IP ]];then
		echo -e "${Error}该域名并未解析成功！请检查后重试！"
		sleep 2s && check_domain
	fi
}
#安装Trojan
TROJAN_U="https://git.io/trojan-install"
install_trojan(){
	if [ -z $trojan_status ];then
		check_domain
		add_firewall 80
		add_firewall 443
		ufw reload
		source <(curl -sL $TROJAN_U)
		sed -i '2itrojan_status=true' $CUR_D/.bash_profile
		trojan_status='true'
		clear && echo
		trojan info
		echo -e "${Info}可访问$(green_font https://${domain})进入网页面板，按任意键继续..."
		char=`get_char`
	else
		clear && echo
		bash <(curl -sL $TROJAN_U)
		sleep 2s
	fi
	get_status
	manage_trojan
}

#V2Ray用户信息生成
general_v2ray_user_info(){
	alterId=$[$[RANDOM%3]*16]
	email="$(tr -dc 'A-Za-z' </dev/urandom|head -c8)@163.com"
}
#安装V2Ray
V2RAY_INFO_P='/etc/v2ray/config.json'
V2RAY_U='https://multi.netlify.com/v2ray.sh'
install_v2ray(){
	if [ -z $v2ray_status ];then
		bash <(curl -sL $V2RAY_U) --zh
		port=$(jq '.inbounds[0].port' $V2RAY_INFO_P)
		add_firewall $port
		clean_iptables
		general_v2ray_user_info
		jq '.inbounds[0].settings.clients[0].email="'${email}'"' $V2RAY_INFO_P >temp.json
		mv -f temp.json $V2RAY_INFO_P
		expect <<-EOF
	set time 30
	spawn v2ray stream
	expect {
		"选择新的" { send "3\n"; exp_continue }
		"伪装域名" { send "www.bilibili.com\n" }
	}
	expect eof
EOF
		sed -i '2iv2ray_status=true' $CUR_D/.bash_profile
		v2ray_status='true'
		clear && echo
		v2ray info
		echo -e "${Info}V2Ray安装完毕，按任意键继续..."
		char=`get_char`
	else
		bash <(curl -sL $V2RAY_U) -k
		echo -e "${Info}V2Ray更新完毕，按任意键继续..."
		char=`get_char`
	fi
	get_status
	manage_v2ray
}

#WireGuard安装文件夹
WG_P='/etc/wireguard'
#speeder2v和udp2raw安装文件夹
SPD_UDP_P="$WG_P/speed_udp"
#生成未被占用的端口
check_port(){
	while :;do
		TP_P=$(shuf -i 1000-9999 -n1)
		[[ -z `lsof -i:$TP_P` ]] && break
	done
	add_firewall $TP_P >/dev/null
	echo $TP_P
}
#查看是否存在用户文件夹
check_wg_user(){
	cd $WG_P/clients
	i=1
	while :;do
		if [ ! -d client$i ];then
			mkdir client$i
			echo $i
			break
		fi
		i=$((i+1))
	done
}
#WireGuard密钥生成函数
get_wireguard_key(){
	wg genkey |tee ${1}_pri_k |wg pubkey > ${1}_pub_k
}
#录入本地网关
get_gate(){
	while :;do
		clear && echo
		read -p "${Info}请输入你终端的默认网关：" default_gate
		[ ! -z $default_gate ] && break
	done
}
#安装WireGuard
install_wg(){
	if [ -z $wg_status ];then
		#生成WireGuard文件夹
		mkdir -p $WG_P/{key,clients,speed_udp}
		#下载WireGuard
		apt -y install wireguard
		cd $SPD_UDP_P
		#speeder与udp版本
		SPD_V='20200818.1'
		UDP_V='20200818.0'
		#下载udpspeeder和udp2raw
		curl -O https://github.com/wangyu-/UDPspeeder/releases/download/$SPD_V/speederv2_binaries.tar.gz
		curl -O https://github.com/wangyu-/udp2raw-tunnel/releases/download/$UDP_V/udp2raw_binaries.tar.gz
		tar zxvf speederv2_binaries.tar.gz
		tar zxvf udp2raw_binaries.tar.gz
		#产生udpspeeder和udp2raw使用的端口
		speed_udp_port=`check_port`
		udp_port=`check_port`
		password=$(tr -dc 'A-Za-z' </dev/urandom|head -c8)
		#允许端口转发
		sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
		echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
		echo '1'> /proc/sys/net/ipv4/ip_forward
		sysctl -p
		#获取网卡
		eth=$(ls /sys/class/net|awk '/^e/{print}')
		port=`check_port`
		#生成密钥
		cd $WG_P/key
		get_wireguard_key 's'
		get_wireguard_key 'c1'
		#添加服务端配置
		cat > $WG_P/wg0.conf <<-EOF
[Interface]
PrivateKey = $(cat $WG_P/key/s_pri_k)
Address = 10.0.0.1/24
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $eth -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $eth -j MASQUERADE
ListenPort = $port
DNS = 8.8.8.8
MTU = 1420

[Peer]
PublicKey = $(cat $WG_P/key/c1_pub_k)
AllowedIPs = 10.0.0.2/32
EOF
		#客户端配置文件
		CLE_D="$WG_P/clients/client1"
		mkdir -p $CLE_D
		#获取网关
		get_gate
		cat > $CLE_D/client.conf <<-EOF
[Interface]
PrivateKey = $(cat $WG_P/key/c1_pri_k)
PostUp = route add $SER_IP mask 255.255.255.255 $default_gate METRIC 20
PostDown = route delete $SER_IP
Address = 10.0.0.2/24
DNS = 8.8.8.8
MTU = 1420

[Peer]
PublicKey = $(cat $WG_P/key/s_pub_k)
Endpoint = $SER_IP:$port
AllowedIPs = 0.0.0.0/0, ::0/0
PersistentKeepalive = 25
EOF
		#运行前的准备
		ln -s /usr/bin/resolvectl /usr/local/bin/resolvconf >/dev/null
		systemctl enable systemd-resolved.service
		systemctl start systemd-resolved.service
		#设置开机启动
		systemctl enable wg-quick@wg0
		#开启speed守护进程
		cat > /etc/systemd/system/speederv2.service <<-EOF
[Unit]
Description=Speederv2 Service
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
StandardError=journal
ExecStart=$SPD_UDP_P/speederv2_amd64 -s -l0.0.0.0:$speed_udp_port -r127.0.0.1:$port -f10:10 --mode 0
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF
		#开启udp2raw守护进程
		cat > /etc/systemd/system/udp2raw.service <<-EOF
[Unit]
Description=Udp2raw Service
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
StandardError=journal
ExecStart=$SPD_UDP_P/udp2raw_amd64 -s -l0.0.0.0:$udp_port -r127.0.0.1:$speed_udp_port --raw-mode faketcp -a -k $password
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF
		#设置开机启动
		systemctl enable speederv2.service
		systemctl enable udp2raw.service
		#增加游戏加速配置
		cp $CLE_D/client.conf $CLE_D/game.conf
		sed -i '/Post/d' $CLE_D/game.conf
		sed -i "3iPostUp = mshta vbscript:CreateObject(\"WScript.Shell\").Run(\"cmd /c route add $SER_IP mask 255.255.255.255 $default_gate METRIC 20 & cd /d E:\\\Wireguard\\\udp_speed & start udp2raw_mp.exe -c -l127.0.0.1:8855 -r$SER_IP:$udp_port --raw-mode faketcp -k $password & start speederv2.exe -c -l0.0.0.0:1080 -r127.0.0.1:8855 -f10:10 --mode 0 --report 10\",0)(window.close)" $CLE_D/game.conf
		sed -i "4iPostDown = route delete $SER_IP & taskkill /f /im udp2raw_mp.exe & taskkill /f /im speederv2.exe" $CLE_D/game.conf
		sed -i 's/^Endpoint.*/Endpoint = 127.0.0.1:1080/g' $CLE_D/game.conf
		#启动WireGuard+Speederv2+Udp2raw
		wg-quick up wg0
		systemctl start speederv2.service
		systemctl start udp2raw.service
		sed -i "2iwg_status=$port:$udp_port:$speed_udp_port.$password" $CUR_D/.bash_profile
		wg_status=$port:$udp_port:$speed_udp_port.$password
		cd $CUR_D
		#结束反馈
		clear && echo
		if [[ -n $(wg) ]];then
			echo -e "${Info}WireGuard安装$(green_font 成功)！"
			echo -e "${Info}用户配置文件在文件夹$(green_font $CLE_D)下！"
			echo -e "${Info}client.conf用来科学上网  game.conf用来加速游戏"
		else
			echo -e "${Error}WireGuard安装$(red_font 失败)！"
			echo -e "${Tip}错误内容如下："
			wg-quick up wg0
			echo -e "${Info}按任意键继续..."
			char=`get_char`
			uninstall_wg
			start_menu
		fi
	else
		clear && echo -e "\n${Info}已安装WireGuard！"
	fi
	echo -e "${Info}按任意键继续..."
	char=`get_char`
}

#安装宝塔面板
BT_U="${Github_U}/install_bt_panel.sh"
install_bt(){
	clear
	if [ -z $bt_status ];then
		bash <(curl -sL $BT_U)
		sed -i '2ibt_status=true' $CUR_D/.bash_profile
		bt_status='true'
		echo -e "\n${Info}BT Panel安装完毕，按任意键继续..."
		char=`get_char`
	else
		echo -e "\n${Info}已安装有BT Panel,即将跳转到BT Panel管理页..."
		sleep 2s
	fi
	get_status
	manage_bt
}

#没有安装的展示信息
check_install(){
	NAME=$1
	if [ $NAME == 'Trojan' ];then
		cmd='trojan'
	elif [ $NAME == 'V2Ray' ];then
		cmd='v2ray'
	elif [ $NAME == 'WireGuard' ];then
		cmd='wg'
	else
		cmd='bt'
	fi
	echo -e "${Info}暂未安装${NAME}!!!"
	read -p "${Info}是否安装${NAME}[y/n](默认:y)：" num
	[ -z $num ] && num='y'
	[ $num != 'n' ] && install_$cmd
}
#开启/关闭端口防火墙
manage_v2ray_port(){
	V2RAY_PORT=($(cat $V2RAY_INFO_P|jq '.inbounds'|jq .[].port))
	for ele in ${V2RAY_PORT[@]};do
		$1 allow $ele
	done
}
#管理Trojan
manage_trojan(){
	add_user_trojan(){
		n=`trojan info|tail -9|head -1|awk -F '.' '{print$1}'`
		read -p "${Info}当前用户数$(red_font $n)，请输入要添加的用户个数(默认:1)：" num
		[ -z $num ] && num=1
		for((i=0;i<$num;i++));do
			uuid=$(cat /proc/sys/kernel/random/uuid)
			expect <<-EOF
	set time 30
	spawn trojan add
	expect {
		"义用户名" { send "\n"; exp_continue }
		"定义密码" { send "$uuid\n" }
	}
	expect eof
EOF
		done
		clear && echo
		trojan info|tail -$((num*9))
		echo -e "${Info}按任意键继续..."
		char=`get_char`
	}
	update_trojan(){
		trojan update
		trojan updateWeb
		echo -e "${Info}Trojan已成功更新..."
		sleep 2s
	}
	change_trojan_port(){
		Trojan_config_path='/usr/local/etc/trojan/config.json'
		read -p "${Info}请输入要修改为的端口号[443-65535]：" newport
		oldport=$(jq '.local_port' $Trojan_config_path)
		if [ $newport -eq $oldport >/dev/null 2>&1 -o $newport -lt 443 >/dev/null 2>&1 -a $newport -gt 65535 >/dev/null 2>&1 ];then
			echo -e "${Error}输入错误！有效端口范围：不为${oldport}且[443-65535]..."
			sleep 2s
			clear && echo
			change_trojan_port
		else
			sed -i "s/: ${oldport}/: ${newport}/g" $Trojan_config_path
			trojan restart
			del_firewall $oldport
			add_firewall $newport
			echo -e "${Info}防火墙添加成功！"
			ufw reload
			sleep 2s
		fi
	}
	transport_userfile(){
		white_font "   ————胖波比————\n"
		yello_font '——————方式选择——————'
		green_font ' 1.' '  导出用户'
		green_font ' 2.' '  导入用户'
		yello_font '————————————————————'
		green_font ' 0.' '  返回管理页'
		yello_font "————————————————————\n"
		read -p "${Info}请输入数字[0-2](默认:1)：" num
		[ -z $num ] && num=1
		clear && echo
		case $num in
			0)
			manage_trojan;;
			1)
			trojan export /root/trojanuserfile
			echo -e "${Info}用户文件已导出至$(green_font /root/trojanuserfile)..."
			sleep 2s;;
			2)
			echo -e "${Info}请将用户文件放为$(green_font /root/trojanuserfile)..."
			trojan import /root/trojanuserfile
			sleep 2s;;
			*)
			echo -e "${Error}请输入正确数字[0-2]"
			sleep 2s
			transport_userfile;;
		esac
	}
	clear && echo
	if [ -z $trojan_status ];then
		check_install 'Trojan'
	else
		white_font "   ————胖波比————\n"
		yello_font '——————用户管理——————'
		green_font ' 1.' '  添加用户'
		green_font ' 2.' '  删除用户'
		yello_font '——————信息查看——————'
		green_font ' 3.' '  查看链接'
		yello_font '—————Trojan设置—————'
		green_font ' 4.' '  更新trojan'
		green_font ' 5.' '  更改端口'
		green_font ' 6.' '  导出(入)用户'
		green_font ' 7.' '  原版管理窗口'
		yello_font '————————————————————'
		green_font ' 8.' '  返回主页'
		green_font ' 0.' '  退出脚本'
		yello_font "————————————————————\n"
		read -p "${Info}请输入数字[0-8](默认:1)：" num
		[ -z $num ] && num=1
		clear && echo
		case $num in
			0)
			exit 0;;
			1)
			add_user_trojan;;
			2)
			trojan del;;
			3)
			trojan info
			echo -e "${Info}按任意键继续..."
			char=`get_char`;;
			4)
			update_trojan;;
			5)
			change_trojan_port;;
			6)
			transport_userfile;;
			7)
			trojan;;
			8)
			start_menu;;
			*)
			echo -e "${Error}请输入正确数字[0-8]"
			sleep 2s
			manage_trojan;;
		esac
		manage_trojan
	fi
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
		i=$((num-1))
		uuid_old=$(jq ".inbounds[$i].settings.clients[0].id" $V2RAY_INFO_P|sed 's/"//g')
		sed -i "s#${uuid_old}#${uuid}#g" $V2RAY_INFO_P
		v2ray restart
		clear && echo
		#更改UUID后显示新信息
		v2ray info|head -$((12*num))|tail -12
		echo -e "${Info}按任意键继续..."
		char=`get_char`
	}
	add_user_v2ray(){
		#获取当前multi-v2ray版本号
		v2ray_ver=$(echo `v2ray -v`|sed 's,\x1B\[[0-9;]*[a-zA-Z],,g'|awk -F 'til: ' '{print$2}')
		if [[ '3.9.0.1' > $v2ray_ver ]];then
			echo -e "${Info}正在更新V2Ray..."
			bash <(curl -sL $V2RAY_U) -k
			clear && echo
		fi
		#当前用户数
		n=$(jq '.inbounds|length' $V2RAY_INFO_P)
		read -p "${Info}当前用户数$(red_font $n)，请输入要添加的用户个数(默认:1)：" num
		[ -z $num ] && num=1
		#循环添加用户
		for((i=0;i<$num;i++));do
			expect <<-EOF
	set time 30
	spawn v2ray add
	expect {
		"定义端口" { send "\n"; exp_continue }
		"传输方式" { send "3\n"; exp_continue }
		"伪装域名" { send "www.bilibili.com\n" }
	}
	expect eof
EOF
		done
		#开放端口防火墙
		V2RAY_PORT=($(cat $V2RAY_INFO_P|jq '.inbounds'|jq .[].port))
		end=$((n+num))
		for((i=$n;i<$end;i++));do
			general_v2ray_user_info
			jq '.inbounds['$i'].settings.clients[0].email="'${email}'"' $V2RAY_INFO_P|jq '.inbounds['$i'].settings.clients[0].alterId='${alterId}'' >temp.json
			mv -f temp.json $V2RAY_INFO_P
			add_firewall ${V2RAY_PORT[$i]}
			clean_iptables
		done
		ufw reload
		v2ray restart
		clear && echo
		v2ray info|tail -$((12*num+1))
		echo -e "${Info}按任意键继续..."
		char=`get_char`
	}
	v2ray_del(){
		port_o=($(cat $V2RAY_INFO_P|jq '.inbounds'|jq .[].port))
		v2ray del
		port_n=($(cat $V2RAY_INFO_P|jq '.inbounds'|jq .[].port))
		port=`echo ${port_o[@]} ${port_n[@]}|xargs -n1|sort|uniq -u`
		del_firewall $port
	}
	change_v2ray_port(){
		manage_v2ray_port 'ufw delete'
		v2ray port
		clean_iptables
		manage_v2ray_port 'ufw'
		clear && echo
		show_v2ray_info
	}
	clear && echo
	if [ -z $v2ray_status ];then
		check_install 'V2Ray'
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
			v2ray_del;;
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
#管理WireGuard+Speederv2+Udp2raw
manage_wg(){
	wg_info(){
		cd $WG_P/clients
		CLE_ARY=($(ls -l|grep '^d'|awk '{print$9}'))
		for ele in ${CLE_ARY[@]};do
			echo -e "${Info}${ele}的科学上网配置："
			cat $ele/client.conf
			echo -e "$(red_font [信息])${ele}的游戏加速配置："
			cat $ele/game.conf
			echo
		done
		cd $CUR_D
		echo -e "${Info}按任意键继续..."
		char=`get_char`
	}
	add_user_wg(){
		cd $WG_P/clients
		n=$(ls -l|grep '^d'|wc -l)
		read -p "${Info}当前用户数$(red_font $n)，请输入要添加的用户个数(默认:1)：" num
		[ -z $num ] && num=1
		port=$(echo $wg_status|awk -F ':' '{print$1}')
		password=$(echo $wg_status|awk -F '.' '{print$2}')
		udp_port=$(echo $wg_status|awk -F ':' '{print$2}')
		cd $WG_P/key
		for((j=0;j<$num;j++));do
			USR_ID=$(check_wg_user)
			CLE_D="$WG_P/clients/client$USR_ID"
			get_wireguard_key "c$USR_ID"
			get_gate
			cat > $CLE_D/client.conf <<-EOF
[Interface]
PrivateKey = $(cat c${USR_ID}_pri_k)
PostUp = route add $SER_IP mask 255.255.255.255 $default_gate METRIC 20
PostDown = route delete $SER_IP
Address = 10.0.0.$[$USR_ID+1]/24
DNS = 8.8.8.8
MTU = 1420

[Peer]
PublicKey = $(cat s_pub_k)
Endpoint = $SER_IP:$port
AllowedIPs = 0.0.0.0/0, ::0/0
PersistentKeepalive = 25
EOF
			wg set wg0 peer $(cat c${USR_ID}_pub_k) allowed-ips 10.0.0.$[$USR_ID+1]/32
			cp $CLE_D/client.conf $CLE_D/game.conf
			sed -i '/Post/d' $CLE_D/game.conf
			sed -i "3iPostUp = mshta vbscript:CreateObject(\"WScript.Shell\").Run(\"cmd /c route add $SER_IP mask 255.255.255.255 $default_gate METRIC 20 & cd /d E:\\\Wireguard\\\udp_speed & start udp2raw_mp.exe -c -l127.0.0.1:8855 -r$SER_IP:$udp_port --raw-mode faketcp -k $password & start speederv2.exe -c -l0.0.0.0:1080 -r127.0.0.1:8855 -f10:10 --mode 0 --report 10\",0)(window.close)" $CLE_D/game.conf
			sed -i "4iPostDown = route delete $SER_IP & taskkill /f /im udp2raw_mp.exe & taskkill /f /im speederv2.exe" $CLE_D/game.conf
			sed -i 's/^Endpoint.*/Endpoint = 127.0.0.1:1080/g' $CLE_D/game.conf
		done
		wg-quick save wg0
		clear && echo
		wg_info
	}
	del_user_wg(){
		cd $WG_P/clients
		CLE_ARY=($(ls -l|grep '^d'|awk '{print$9}'|sed s'/client//g'))
		echo -e "${Info}当前用户序号为："
		echo ${CLE_ARY[@]}
		read -p "${Info}请输入上面出现的序号(默认:1)：" USR_ID
		[ -z $USR_ID ] && USR_ID=1
		wg set wg0 peer $(cat $WG_P/key/c${USR_ID}_pub_k) remove
		wg-quick save wg0
		rm -rf client$USR_ID
		rm -f $WG_P/key/c$USR_ID*
		cd $CUR_D
		echo -e "${Info}用户已删除！"
		sleep 2s
	}
	clear && echo
	if [ -z $wg_status ];then
		check_install 'WireGuard'
	else
		white_font "   ————胖波比————\n"
		yello_font '——————用户管理——————'
		green_font ' 1.' '  添加用户'
		green_font ' 2.' '  删除用户'
		yello_font '——————信息查看——————'
		green_font ' 3.' '  查看配置'
		yello_font '————————————————————'
		green_font ' 4.' '  返回主页'
		green_font ' 0.' '  退出脚本'
		yello_font "————————————————————\n"
		read -p "${Info}请输入数字[0-4](默认:1)：" num
		[ -z $num ] && num=1
		clear && echo
		case $num in
			0)
			exit 0;;
			1)
			add_user_wg;;
			2)
			del_user_wg;;
			3)
			wg_info;;
			4)
			start_menu;;
			*)
			echo -e "${Error}请输入正确数字[0-4]"
			sleep 2s
			manage_wg;;
		esac
		manage_wg
	fi
}
#管理BT Panel
manage_bt(){
	clear && echo
	if [ -z $bt_status ];then
		check_install '宝塔面板'
	else
		bt
	fi
	sleep 2s
	manage_bt
}

#卸载Trojan
uninstall_trojan(){
	clear && echo
	if [ -z $trojan_status ];then
		echo -e "${Info}暂未安装Trojan!!!"
	else
		bash <(curl -sL $TROJAN_U) --remove
		del_firewall 80
		del_firewall 443
		ufw reload
		sed -i '/trojan_status/d' $CUR_D/.bash_profile
		unset trojan_status
		echo -e "${Info}Trojan卸载完毕！"
	fi
	sleep 2s
}
#卸载V2Ray
uninstall_v2ray(){
	clear && echo
	if [ -z $v2ray_status ];then
		echo -e "${Info}暂未安装V2Ray!!!"
	else
		manage_v2ray_port 'ufw delete'
		#开始卸载
		bash <(curl -sL $V2RAY_U) --remove
		sed -i '/v2ray_status/d' $CUR_D/.bash_profile
		unset v2ray_status
		echo -e "${Info}V2Ray卸载完毕！"
	fi
	sleep 2s
}
#卸载WireGuard
uninstall_wg(){
	clear && echo
	if [ -z $wg_status ];then
		echo -e "${Info}暂未安装WireGuard!!!"
	else
		#关闭WireGuard端口防火墙
		WG_PORT=($(echo $wg_status|awk -F '.' '{print$1}'|sed 's/:/ /g'))
		for ele in ${WG_PORT[@]};do
			ufw delete allow $ele
		done
		#关闭WireGuard相关进程
		wg-quick down wg0
		systemctl stop speederv2.service
		systemctl stop udp2raw.service
		apt -y remove wireguard
		rm -rf $WG_P
		sed -i '/wg_status/d' $CUR_D/.bash_profile
		unset wg_status
		echo -e "${Info}WireGuard卸载完毕！"
	fi
	sleep 2s
}
#卸载宝塔面板
uninstall_bt(){
	clear && echo
	if [ -z $bt_status ];then
		echo -e "${Info}暂未安装宝塔面板!!!"
	else
		/etc/init.d/bt stop && chkconfig --del bt
		rm -f /etc/init.d/bt && rm -rf /www/server/panel /www/*
		del_firewall '20,21,80,443,888,8888/tcp'
		del_firewall '20,21,80,443,888,8888/udp'
		ufw reload
		sed -i '/bt_status/d' $CUR_D/.bash_profile
		unset bt_status
		echo -e "${Info}宝塔面板卸载完毕！"
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
	if [ $SSH_PORT != $ssh_port ];then
		#开放安全权限
		if type sestatus >/dev/null 2>&1 && [ $(getenforce) != "Disabled" ]; then
			semanage port -a -t ssh_port_t -p tcp $SSH_PORT
		fi
		#修改SSH端口
		sed -i "s/.*Port ${ssh_port}/Port ${SSH_PORT}/g" /etc/ssh/sshd_config
		#更改SSH端口防火墙策略
		add_firewall $SSH_PORT
		del_firewall $ssh_port
		ufw reload
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
	pw=`grep "${ssh_port}:" $CUR_D/.bash_profile |awk -F ':' '{print$3}'`
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
		sed -i "2i#$SER_IP:$ssh_port:$pw" $CUR_D/.bash_profile
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
#设置防火墙
set_firewall(){
	get_single_port(){
		read -p "${Info}请输入端口[1-65535](默认:80)：" port
		[ -z $port ] && port=80
	}
	get_multi_port(){
		echo -e "${Tip}多端口输入格式：$(green_font 21,22,80,443,8888)"
		read -p "${Info}请输入端口[1-65535](默认:$(green_font 21,22,80,443,8888))：" port
		[ -z $port ] && port='21,22,80,443,8888'
	}
	open_single_port(){
		get_single_port
		add_firewall $port
		echo -e "${Info}防火墙添加成功！"
	}
	open_multi_port(){
		get_multi_port
		ufw allow $port/tcp
		ufw allow $port/udp
		echo -e "${Info}防火墙添加成功！"
	}
	close_single_port(){
		get_single_port
		ufw deny $port
		echo -e "${Info}防火墙关闭成功！"
	}
	close_multi_port(){
		get_multi_port
		ufw deny $port/tcp
		ufw deny $port/udp
		echo -e "${Info}防火墙关闭成功！"
	}
	view_ufw_rules(){
		ufw status
		echo -e "${Info}防火墙规则如上，按任意键继续..."
		char=`get_char`
		set_firewall
	}
	reset_ufw(){
		echo -e "${Info}请输入$(red_font y)"
		ufw reset
		ufw_default
		echo -e "${Info}防火墙重置成功！"
	}
	clear
	white_font "\n    ————胖波比————\n"
	yello_font '—————————开放————————'
	green_font ' 1.' '  开放单个端口'
	green_font ' 2.' '  开放多个端口'
	yello_font '—————————关闭————————'
	green_font ' 3.' '  关闭单个端口'
	green_font ' 4.' '  关闭多个端口'
	yello_font '—————————————————————'
	green_font ' 5.' '  查看规则'
	green_font ' 6.' '  重置规则'
	yello_font '—————————————————————'
	green_font ' 7.' '  返回主页'
	green_font ' 0.' '  退出脚本'
	yello_font "—————————————————————\n"
	read -p "${Info}请输入数字[0-6](默认:1)：" num
	[ -z $num ] && num=1
	clear && echo
	case $num in
		0)
		exit 0;;
		1)
		open_single_port;;
		2)
		open_multi_port;;
		3)
		close_single_port;;
		4)
		close_multi_port;;
		5)
		view_ufw_rules;;
		6)
		reset_ufw;;
		7)
		start_menu;;
		*)
		echo -e "${Error}请输入正确数字[0-7]"
		sleep 2s
		set_firewall;;
	esac
	ufw reload
	sleep 2s
	set_firewall
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
	white_font "\nSuper Vpn One Key Plus $(red_font \[v$sh_ver\])"
	white_font '	 -- 胖波比 --'
	white_font "      执行脚本：$(green_font ./$SCRIPT_N)"
	white_font "  终止正在进行的操作：Ctrl+C\n"
	yello_font '—————————————管理—————————————'
	green_font ' 1.' '  管理Trojan'
	green_font ' 2.' '  管理V2Ray'
	green_font ' 3.' '  管理BT Panel'
	green_font ' 4.' '  管理WireGuard'
	yello_font '—————————————安装—————————————'
	green_font ' 5.' '  安装/更新Trojan(需要域名)'
	green_font ' 6.' '  安装/更新V2Ray (无需域名)'
	green_font ' 7.' '  安装WireGuard(游戏加速器)'
	green_font ' 8.' '  安装BT Panel'
	yello_font '—————————————卸载—————————————'
	green_font ' 9.' '  卸载Trojan'
	green_font ' 10.' ' 卸载V2Ray'
	green_font ' 11.' ' 卸载WireGuard'
	green_font ' 12.' ' 卸载BT Panel'
	yello_font '—————————————系统—————————————'
	green_font ' 13.' ' 设置SSH端口'
	green_font ' 14.' ' 设置/查看Root密码'
	green_font ' 15.' ' 设置防火墙'
	yello_font '——————————————————————————————'
	green_font ' 16.' ' 脚本自启管理'
	green_font ' 0.' '  退出脚本'
	yello_font "——————————————————————————————\n"
	read -p "${Info}请输入数字[0-16](默认:1)：" num
	[ -z $num ] && num=1
	case $num in
		0)
		exit 0;;
		1)
		manage_trojan;;
		2)
		manage_v2ray;;
		3)
		manage_bt;;
		4)
		manage_wg;;
		5)
		install_trojan;;
		6)
		install_v2ray;;
		7)
		install_wg;;
		8)
		install_bt;;
		9)
		uninstall_trojan;;
		10)
		uninstall_v2ray;;
		11)
		uninstall_wg;;
		12)
		uninstall_bt;;
		13)
		set_ssh;;
		14)
		set_root;;
		15)
		set_firewall;;
		16)
		start_shell;;
		*)
		clear
		echo -e "\n${Error}请输入正确数字[0-16]"
		sleep 2s
		start_menu;;
	esac
	start_menu
}
start_menu