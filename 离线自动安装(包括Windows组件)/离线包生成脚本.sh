#!/bin/bash
# coding: utf-8
set -e

if [ ! -d "/opt/package" ]; then
    echo -e "\033[31m 正在下载rpm包 \033[0m"
    yum -y install yum-plugin-downloadonly
    yum -y install vim wget sqlite-devel xz gcc automake zlib-devel openssl-devel epel-release git --downloadonly --downloaddir=/opt/package/
    yum -y localinstall /opt/package/*.rpm --nogpgcheck
    yum -y install mariadb mariadb-devel mariadb-server --downloadonly --downloaddir=/opt/package/mariadb/
    yum -y localinstall /opt/package/mariadb/*.rpm --nogpgcheck
    yum -y install nginx --downloadonly --downloaddir=/opt/package/nginx/
    yum -y localinstall /opt/package/nginx/*.rpm --nogpgcheck
    yum -y install redis --downloadonly --downloaddir=/opt/package/redis/
    yum -y localinstall /opt/package/redis/*.rpm --nogpgcheck
else
    echo -e "\033[31m package文件夹已经存在 \033[0m"
fi

cd /opt/

if [ ! -f "/opt/Python-3.6.1.tar.xz" ]; then
    echo -e "\033[31m 正在下载Python3.6.1.tar.xz \033[0m"
    wget https://www.python.org/ftp/python/3.6.1/Python-3.6.1.tar.xz
else
    echo -e "\033[31m Python3.6.1.tar.xz已经存在，跳过 \033[0m"
fi

if [ ! -d "/opt/jumpserver" ]; then
    echo -e "\033[31m 正在下载jumpserver \033[0m"
    git clone --depth=1 https://github.com/jumpserver/jumpserver.git
else
    echo -e "\033[31m jumpserver已经存在，正在更新 \033[0m"
    cd /opt/jumpserver && git pull
fi

if [ ! -d "/opt/coco" ]; then
    echo -e "\033[31m 正在下载coco \033[0m"
    git clone https://github.com/jumpserver/coco.git
else
    echo -e "\033[31m coco已经存在，正在更新 \033[0m"
    cd /opt/coco && git pull
fi

cd /opt
if [ ! -f "/opt/luna.tar.gz" ]; then
    echo -e "\033[31m 正在下载luna \033[0m"
    wget https://github.com/jumpserver/luna/releases/download/1.3.1/luna.tar.gz
else
    echo -e "\033[31m luna已经存在，跳过 \033[0m"
fi

if [ ! -d "/opt/autoenv" ]; then
    echo -e "\033[31m 正在下载autoenv \033[0m"
    git clone git://github.com/kennethreitz/autoenv.git
else
    echo -e "\033[31m autoenv已经存在，正在更新 \033[0m"
    cd /opt/autoenv && git pull
fi

if [ ! -d "/opt/Python-3.6.1" ]; then
    echo -e "\033[31m 正在解压安装Python3.6.1 \033[0m"
    cd /opt && tar xf Python-3.6.1.tar.xz
else
    echo -e "\033[31m Python3.6.1已经存在，跳过 \033[0m"
fi

if [ ! -d "/opt/py3" ]; then
    echo -e "\033[31m 正在创建及载入py3虚拟环境 \033[0m"
    cd /opt/Python-3.6.1 && ./configure && make && make install
    python3 -m venv /opt/py3
    source /opt/py3/bin/activate
else
    echo -e "\033[31m 正在载入py3虚拟环境 \033[0m"
    source /opt/py3/bin/activate
fi

cd /opt
yum -y install $(cat /opt/jumpserver/requirements/rpm_requirements.txt) --downloadonly --downloaddir=/opt/package/jumpserver/
yum -y install $(cat /opt/coco/requirements/rpm_requirements.txt) --downloadonly --downloaddir=/opt/package/coco/

yum -y localinstall /opt/package/jumpserver/*.rpm --nogpgcheck
yum -y localinstall /opt/package/coco/*.rpm --nogpgcheck

if [ ! -d "/opt/package/pip" ]; then
    echo -e "\033[31m 正在创建/opt/package/pip目录 \033[0m"
    mkdir /opt/package/pip/
else
    echo -e "\033[31m /opt/package/pip已经存在，跳过 \033[0m"
fi

if [ ! -d "/opt/package/pip/jumpserver" ]; then
    echo -e "\033[31m 正在创建/opt/package/pip/jumpserver目录 \033[0m"
    mkdir /opt/package/pip/jumpserver/
else
    echo -e "\033[31m /opt/package/pip/jumpserver已经存在，跳过 \033[0m"
fi

if [ ! -d "/opt/package/pip/coco" ]; then
    echo -e "\033[31m 正在创建/opt/package/pip/coco目录 \033[0m"
    mkdir /opt/package/pip/coco/
else
    echo -e "\033[31m /opt/package/pip/coco已经存在，跳过 \033[0m"
fi

echo -e "\033[31m 正在下载pip包 \033[0m"
pip download pip -d /opt/package/pip/
pip install --no-index --find-links="/opt/package/pip/" --upgrade pip

pip download -r /opt/jumpserver/requirements/requirements.txt -d /opt/package/pip/jumpserver/
pip install --no-index --find-links="/opt/package/pip/jumpserver/" pyasn1 six cffi
pip install -r /opt/jumpserver/requirements/requirements.txt --no-index --find-links="/opt/package/pip/jumpserver/"

pip download -r /opt/coco/requirements/requirements.txt -d /opt/package/pip/coco/
pip install -r /opt/coco/requirements/requirements.txt --no-index --find-links="/opt/package/pip/coco/"

deactivate

echo -e "\033[31m 正在下载docker \033[0m"
yum install -y yum-utils device-mapper-persistent-data lvm2 --downloadonly --downloaddir=/opt/package/docker
yum -y localinstall /opt/package/docker/*.rpm --nogpgcheck
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
rpm --import http://mirrors.aliyun.com/docker-ce/linux/centos/gpg
yum makecache fast
yum install -y docker-ce --downloadonly --downloaddir=/opt/package/docker/docker-ce
yum -y localinstall /opt/package/docker/docker-ce/*.rpm --nogpgcheck

curl -sSL https://get.daocloud.io/daotools/set_mirror.sh | sh -s http://3e8fcfbd.m.daocloud.io

systemctl restart docker

echo -e "\033[31m 正在下载windows组件 \033[0m"
docker pull jumpserver/guacamole:latest

docker save jumpserver/guacamole:latest > /opt/guacamole.tar

cd /opt/
if [ ! -f "/tmp/jumpserver.tar.gz" ]; then
    echo -e "\033[31m 正在打包到/tmp/jumpserver.tar.gz \033[0m"
    tar -zcvf /tmp/jumpserver.tar.gz * --exclude=py3 --exclude=Python-3.6.1
else
    echo -e "\033[31m 正在打包到/tmp/jumpserver.tar.gz，原文件将重命名 \033[0m"
    mv /tmp/jumpserver.tar.gz /tmp/jumpserver$(date -d "today" +"%Y%m%d_%H%M%S").tar.gz
    tar -zcvf /tmp/jumpserver.tar.gz * --exclude=py3 --exclude=Python-3.6.1
fi

exit 0
