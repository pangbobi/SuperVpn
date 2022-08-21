#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 配置文件
STATUS_FILE=$1
# 更改类型
Modify_Type=$2

# 载入颜色
source <(curl -sL https://raw.githubusercontent.com/pangbobi/SuperVpn/master/tools/color.sh)

# 设置 root 密码或更改 SSH 端口
modifyPS(){
    # 重启 SSH 服务
    restartSshd(){
        if [ "$(setenforce)" ];then
            # 暂时关闭SELINUX
            setenforce 0
            # 永久关闭SELINUX
            sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
        fi
        service sshd restart
    }

    # 设置 root 密码
    modifyPassword(){
        clear && echo
        num="y"

        #启用 root 密码登陆
        if [ $(jq '.LoginInfo | has("password")' $STATUS_FILE) == "false" ];then
		    sed -i '1,/PermitRootLogin/{s/.*PermitRootLogin.*/PermitRootLogin yes/}' /etc/ssh/sshd_config
		    sed -i '1,/PasswordAuthentication/{s/.*PasswordAuthentication.*/PasswordAuthentication yes/}' /etc/ssh/sshd_config
        else
            old_password=$(jq -r '.LoginInfo.password' $STATUS_FILE)

            echo -e "\n${Info}您之前的 root 登录密码是：$(red_font ${old_password})"
            unset num && read -p "${Info}是否修改 root 登录密码[y/n](默认:n)：" num
		    [ -z $num ] && num='n'
        fi

        if [ "$num" == "n" ];then
            new_password=$old_password
        else
            # 生成17位随机密码
            new_password=$(tr -dc 'A-Za-z0-9!@#$%^&*()[]{}+=_,' < /dev/urandom | head -c 17)
        
            # 执行更改
            echo root:${new_password} | chpasswd
        fi

        # 进行记录并输出
        jq '.LoginInfo.password="'$new_password'"' $STATUS_FILE > tmp.json
        mv tmp.json $STATUS_FILE
        echo -e "\n${Info}您当前的 root 登录密码是：$(red_font ${new_password})"

        # 重启 SSH 服务
        [ ! "$num" == "n" ] && restartSshd
    }

    # 更改 SSH 端口
    modifySshPort(){
        old_port=$(cat /etc/ssh/sshd_config | grep 'Port '| awk '{print $2}')

        if [ "$old_port" != "$sshPort" ];then
            sed -i "s/.*Port ${old_port}/Port ${sshPort}/g" /etc/ssh/sshd_config
            if [ "$(which semanage)" ];then
                semanage port -a -t ssh_port_t -p tcp $sshPort
                restartSshd
                semanage port -d -t ssh_port_t -p tcp $old_port
            else
                restartSshd
            fi
        fi

        jq '.LoginInfo.sshPort="'$sshPort'"' $STATUS_FILE > tmp.json
        mv tmp.json $STATUS_FILE

        echo -e "${Info}您当前的 SSH 端口是：$(green_font $sshPort)"
    }

    # 入口
    case $Modify_Type in
        "password")
        modifyPassword;;
        "sshPort")
        modifySshPort;;
    esac
}

# 选择修改
modifyPS
