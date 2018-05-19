#!/bin/bash
#

echo -e "\033[31m 本脚本目前仅支持 Centos 7 系统 \033[0m"
echo -e "\033[31m 按序列号选择你的问题，本脚本只试用于按照官方文档进行安装的用户使用 \033[0m"
echo -e "\033[31m 1. coco 不在线或者提示 Failed register terminal xxx exist already \033[0m"
echo -e "\033[31m 2. guacamole 不在线或者 终端管理没有出现 guacamole 的注册 \033[0m"
echo -e "\033[31m 3. log 提示 base WARNING 或者 资产测试连接、推送显示 ........ \033[0m"
echo -e "\033[31m 4. 更新 1.3.0 支持 Windows 录像 (请一定要先备份 jumpserver 目录与 数据库 ) \033[0m"
echo -e "\033[31m 5. 访问 luna 页面显示 403 Forbidden 或者无法正常显示 luna 页面 \033[0m"
echo -e "\033[31m 6. 访问 luna 页面提示 Luna 是单独部署的一个程序，你需要部署luna \033[0m"
echo -e "\033[31m 7. 新建用户无法收到邮件或者邮件 url 为 localhost \033[0m"
echo -e "\033[31m 8. luna 页面无法显示资产 \033[0m"
echo -e "\033[31m 其他问题请参考 http://docs.jumpserver.org/zh/docs/ \033[0m"

serverip=`ip addr |grep inet|grep -v 127.0.0.1|grep -v inet6|grep -v docker|awk '{print $2}'|tr -d "addr:" |head -n 1`
ip=`echo ${serverip%/*}`
echo -e "\033[31m 你的IP是 $ip 如果此处显示的ip信息不正确，请手动编辑 \033[0m"
guacamoleimages=`docker images | grep jumpserver | awk '{ print $1 }'`

# 请修改下面参数
Guacamole_DIR=/opt/guacamole  # guacamole 默认目录
Guacamole_Port=8081  # guacamole 默认对外端口
Coco_DIR=/opt/coco  # coco 默认目录
Py3_DIR=/opt/py3  # py3 默认目录
Luna_DIR=/opt/luna  # luna 默认目录
Jumpserver_DIR=/opt/jumpserver  # jumpserver 默认目录
Jumpserver_Port=8080  # jumpserver 默认对外端口

source $Py3_DIR/bin/activate

# stty erase ^H
read -p "请输入问题的序列号并回车 " a

if [ "$a" == 1 ];then

  # stty erase ^?
  echo -e "\033[31m Coco 默认目录为 $Coco_DIR，如不对请自行修改 Coco_DIR 内容 \033[0m"
  echo -e "\033[31m 请自行处理防火墙的问题 \033[0m"
  echo -e "\033[31m 如有其他问题请参考 http://docs.jumpserver.org/zh/docs/faq.html \033[0m"
  echo -e "\033[31m 请到 http://$ip/terminal/terminal 删除 Coco 的授权 \033[0m"
  sleep 10s

    if [ ! -d "$Coco_DIR" ]; then
      echo -e "\033[31m Coco 目录不正确，脚本自动退出 \033[0m"
      exit 0
    fi

  cd $Coco_DIR/ && ./cocod stop
  sleep 5s
  ps axu | grep coco | awk '{ print $2 }' | xargs kill -9

  mv conf.py conf.py.bak && cp conf_example.py conf.py
  if [ ! -f "$Coco_DIR/keys/.access_key" ]; then
    echo -e "\033[31m Coco key 目录正常 \033[0m"
  else
    rm $Coco_DIR/keys/.access_key
  fi
  ./cocod start -d

  echo -e "\033[31m 请到 http://$ip/terminal/terminal 接受 coco 的注册 \033[0m"
  echo -e "\033[31m 如果接受注册后任然显示不在线，请过几秒钟后重新刷新页面或者重启一下 coco \033[0m"

elif [ "$a" == 2 ];then

  echo -e "\033[31m Guacamole 默认目录为 $Guacamole_DIR，如不对请自行修改 Guacamole_DIR 内容 \033[0m"
  echo -e "\033[31m 请自行处理防火墙的问题 \033[0m"
  echo -e "\033[31m 如有其他问题请参考 http://docs.jumpserver.org/zh/docs/faq.html \033[0m"

  if [ ! -d "$Guacamole_DIR" ]; then
    echo -e "\033[31m Guacamole 目录不正确，脚本自动退出 \033[0m"
    exit 0
  fi

  echo -e "\033[31m 请到 http://$ip/terminal/terminal 删除 guacamole 的授权 \033[0m"
  sleep 10s

  echo -e "\033[31m 正在删除授权 key \033[0m"
  rm -rf $Guacamole_DIR/key/*

  echo -e "\033[31m 正在重新生成 guacamole \033[0m"
  docker stop jms_guacamole
  docker rm jms_guacamole

  systemctl stop docker
  systemctl start docker

  docker run --name jms_guacamole -d -p $Guacamole_Port:8080 -v /opt/guacamole/key:/config/guacamole/key -e JUMPSERVER_KEY_DIR=/config/guacamole/key -e JUMPSERVER_SERVER=http://$ip:$Jumpserver_Port $guacamoleimages:latest
  # registry.jumpserver.org/public/guacamole:latest 和 jumpserver/guacamole:latest 镜像请自己选择

  echo -e "\033[31m 请到 http://$ip/terminal/terminal 接受 gua 的注册 \033[0m"
  echo -e "\033[31m 如果接受注册后任然显示不在线，请过几秒钟后重新刷新页面或者重启一下 guacamole \033[0m"

  exit 0

elif [ "$a" == 3 ];then

  if grep -q 'LANG="zh_CN.UTF-8"' /etc/locale.conf; then
     echo -e "\033[31m 当前环境已经是zh_CN.UTF-8 \033[0m"
  else
  	 echo -e "\033[31m 设置环境zh_CN.UTF-8 \033[0m"
  	 localedef -c -f UTF-8 -i zh_CN zh_CN.UTF-8 && export LC_ALL=zh_CN.UTF-8 && echo 'LANG="zh_CN.UTF-8"' > /etc/locale.conf
     cd $Jumpserver_DIR/ && ./jms restart -d
     echo -e "\033[31m 请访问 http://$ip/ 测试 \033[0m"
     exit 0
  fi

exit 0

elif [ "$a" == 4 ];then

  if [ ! -d "$Jumpserver_DIR" ]; then
    echo -e "\033[31m Jumpserver 目录不正确 \033[0m"
    exit 0
  else
    echo -e "\033[31m Jumpserver 目录正确 \033[0m"

  fi
  echo -e "\033[31m 正在更新 jumpserver \033[0m"
  cd $Jumpserver_DIR/ && ./jms stop
  git pull && pip install -r requirements/requirements.txt && cd utils && sh make_migrations.sh
  sleep 5s
  cd $Jumpserver_DIR/ && ./jms start -d

  if [ ! -d "$Coco_DIR" ]; then
    echo -e "\033[31m Coco 目录不正确 \033[0m"
    exit 0
  else
    echo -e "\033[31m Coco 目录正确 \033[0m"
  fi
  echo -e "\033[31m 正在更新 coco \033[0m"
  cd $Coco_DIR/ && ./cocod stop
  git pull && pip install -r requirements/requirements.txt
  cd $Coco_DIR/ && ./cocod start -d

  if [ ! -d "$Luna_DIR" ]; then
    echo -e "\033[31m Luna 目录不正确，跳过 \033[0m"
  else
    echo -e "\033[31m Luna 目录正确 \033[0m"
    if grep -q "var version = '1.3.0-101 GPLv2.'" $Luna_DIR/main.bundle.js; then
      echo -e "\033[31m 当前 luna 版本已经是1.3.0 \033[0m"
    else
      echo -e "\033[31m 正在更新 luna \033[0m"
      cd /opt && rm -rf dist* && rm -rf luna
      wget https://github.com/jumpserver/luna/releases/download/1.3.0/dist.tar.gz
      tar xf dist.tar.gz
      mv dist luna
      chown -R root:root luna
    fi
  fi
  echo -e "\033[31m 更新 Guacamole \033[0m"
  docker pull
  docker stop jms_guacamole
  docker rm jms_guacamole
  docker run --name jms_guacamole -d -p $Guacamole_Port:8080 -v /opt/guacamole/key:/config/guacamole/key -e JUMPSERVER_KEY_DIR=/config/guacamole/key -e JUMPSERVER_SERVER=http://$ip:$Jumpserver_Port $guacamoleimages:latest

echo -e "\033[31m 更新完成，请访问 http://$ip 检查 \033[0m"

exit 0

elif [ "$a" == 5 ];then

  if [ ! -d "$Luna_DIR" ]; then
    echo -e "\033[31m Luna 目录不正确，跳过 \033[0m"
  else
    echo -e "\033[31m 正在更新 luna \033[0m"
    cd /opt && rm -rf dist* && rm -rf luna
    wget https://github.com/jumpserver/luna/releases/download/1.3.0/dist.tar.gz
    tar xf dist.tar.gz
    mv dist luna
    chown -R root:root luna
    echo -e "\033[31m 更新 luna 完成 \033[0m"
  fi

exit 0

elif [ "$a" == 6 ];then

  echo -e "\033[31m 不要通过 $Jumpserver_Port 端口来访问，请直接访问 http://$ip \033[0m"

exit 0

elif [ "$a" == 7 ];then

  echo -e "\033[31m 系统设置 里面的设置变更后需要重启 jumpserver 才能生效（暂时） \033[0m"
  echo -e "\033[31m 邮箱收到的 url 连接是 localhost，请在 系统设置-基本设置 里修改 \033[0m"
  echo -e "\033[31m 系统设置的地址是 $ip/settings \033[0m"

exit 0

elif [ "$a" == 8 ];then

  echo -e "\033[31m 请确定当前登陆用户已经被授权了资产 \033[0m"
  echo -e "\033[31m ssh 登陆有资产但是 luna 页面没有请更换浏览器 \033[0m"

exit 0

else
  echo -e "\033[31m 输入错误，脚本自动退出 \033[0m"
  exit 0

fi

exit 0
