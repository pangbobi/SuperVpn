#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 卸载监控的函数
Remove_Shield(){
	#org=$(wget -qO- -t1 -T2 https://ipapi.co/org)
	org=$(curl -s --retry 2 --max-time 2 https://ipapi.co/org)
	if [[ $org =~ "Alibaba" ]];then
		# 阿里云则卸载云盾
		curl -O http://update.aegis.aliyun.com/download/uninstall.sh
		curl -O http://update.aegis.aliyun.com/download/quartz_uninstall.sh

        # 授予执行权限
        chmod +x uninstall.sh quartz_uninstall.sh
        ./uninstall.sh
        ./quartz_uninstall.sh
		pkill aliyun-service

        # 删除文件
		rm -rf /etc/init.d/agentwatch /usr/sbin/aliyun-service /usr/local/aegis*
		rm -f uninstall.sh quartz_uninstall.sh

        # 屏蔽IP
        setFirewall "close" "ip" "140.205.201.0/28"
        setFirewall "close" "ip" "140.205.201.16/29"
        setFirewall "close" "ip" "140.205.201.32/28"
        setFirewall "close" "ip" "140.205.225.183/32"
        setFirewall "close" "ip" "140.205.225.184/29"
        setFirewall "close" "ip" "140.205.225.192/29"
        setFirewall "close" "ip" "140.205.225.195/32"
        setFirewall "close" "ip" "140.205.225.200/30"
        setFirewall "close" "ip" "140.205.225.204/32"
        setFirewall "close" "ip" "140.205.225.205/32"
        setFirewall "close" "ip" "140.205.225.206/32"
	elif [[ $org =~ "Tencent" ]];then
		# 腾讯云则卸载云盾："ps aux |grep -i agent |grep -v grep"
        chmod +x /usr/local/qcloud/stargate/admin/uninstall.sh
        chmod +x /usr/local/qcloud/YunJing/uninst.sh
        chmod +x /usr/local/qcloud/monitor/barad/admin/uninstall.sh

		/usr/local/qcloud/stargate/admin/uninstall.sh
		/usr/local/qcloud/YunJing/uninst.sh
		/usr/local/qcloud/monitor/barad/admin/uninstall.sh
	fi
}

# 执行卸载
Remove_Shield
