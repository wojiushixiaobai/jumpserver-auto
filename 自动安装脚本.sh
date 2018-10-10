#!/bin/bash
#

echo -e "\033[31m 本脚本目前仅支持 Centos 7 系统 \033[0m"

serverip=`ip addr |grep inet|grep -v 127.0.0.1|grep -v inet6|grep -v docker|awk '{print $2}'|tr -d "addr:" |head -n 1`
ip=`echo ${serverip%/*}`
echo -e "\033[31m 你的IP是 $ip 如果此处显示的ip信息不正确，请手动编辑 \033[0m"

# 请修改下面参数
Guacamole目录=/opt/guacamole  # guacamole 默认目录
Guacamole端口=8081  # guacamole 默认对外端口
Coco目录=/opt/coco  # coco 默认目录
Py3虚拟环境=/opt/py3  # py3 默认目录
Luna目录=/opt/luna  # luna 默认目录
Jumpserver目录=/opt/jumpserver  # jumpserver 默认目录
Jumpserver端口=8080  # jumpserver 默认对外端口

source $Py3虚拟环境/bin/activate



cd /你的旧jumpserver目录/apps

for d in $(ls);do
    if [ -d $d ] && [ -d $d/migrations ];then
        cp ${d}/migrations/*.py /你的新jumpserver目录/${d}/migrations
    fi
done
