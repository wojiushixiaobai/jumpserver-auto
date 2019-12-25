#!/bin/bash
#
set -e

# 如果你不知道下面的配置有什么用，请保持默认

Version=1.5.5

# Jms 加密配置
SECRET_KEY=
BOOTSTRAP_TOKEN=

# 数据库 配置
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=jumpserver
DB_PASSWORD=
DB_NAME=jumpserver

# Redis 配置
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=

# 修改到此结束
#----------------------------

install_dir=/opt
script_file=jms_localinstall.sh

echo -e "\033[31m 请勿在任何已经部署了其他服务的生产服务器上面运行此脚本 \033[0m"
echo -e "\033[31m 如果你有已经配置好的 数据库 和 redis , 请先编辑此脚本修改对应的变量, 后再继续安装 \033[0m"
read -p "任意键回车继续安装, 按 q 退出 :" a
if [ "$a" == q -o "$a" == Q ];then
    exit 1
fi

if grep -q 'CentOS Linux release 7' /etc/redhat-release; then
	  echo -e "\033[31m 检测到 Centos7 系统 \033[0m"
else
	  echo -e "\033[31m 检测到系统不是 Centos7 \033[0m"
	  echo -e "\033[31m 脚本自动退出 \033[0m"
	  exit 1
fi

echo -e "\033[31m 设置 防火墙 \033[0m"
if [ "$(systemctl status firewalld | grep running)" ]; then
    if [ ! "$(firewall-cmd --list-all | grep 80)" ]; then
        firewall-cmd --zone=public --add-port=80/tcp --permanent
        firewall-cmd --reload
    fi
    if [ ! "$(firewall-cmd --list-all | grep 2222)" ]; then
        firewall-cmd --zone=public --add-port=2222/tcp --permanent
        firewall-cmd --reload
    fi
    if [ ! "$(firewall-cmd --list-all | grep 8080)" ]; then
        firewall-cmd --permanent --add-rich-rule="rule family="ipv4" source address="172.17.0.0/16" port protocol="tcp" port="8080" accept"
        firewall-cmd --reload
    fi
fi

echo -e "\033[31m 设置 Selinux \033[0m"
if [ "$(getenforce)" != "Disabled" ]; then
    setsebool -P httpd_can_network_connect 1
fi

echo -e "\033[31m 设置 Yum 源 \033[0m"
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo || {
    yum install -y wget
    wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
}
sed -i -e '/mirrors.cloud.aliyuncs.com/d' -e '/mirrors.aliyuncs.com/d' /etc/yum.repos.d/CentOS-Base.repo
if [ ! "$(rpm -qa | grep epel-release)" ]; then
    yum -y install epel-release
    wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
fi

echo -e "\033[31m 安装基本依赖 \033[0m"
yum update -y
yum -y install wget gcc git

echo -e "\033[31m 配置 Mariadb \033[0m"
if [ $DB_HOST == 127.0.0.1 ]; then
    if [ ! "$(rpm -qa | grep mariadb-server)" ]; then
        yum -y install mariadb mariadb-devel mariadb-server
        systemctl enable mariadb
    fi
    if [ $DB_PORT != 3306 ]; then
        sed -i "10i port=$DB_PORT" $install_dir/$script_file
    fi
    if [ "$(systemctl status mariadb | grep running)" == "" ]; then
        systemctl start mariadb
    fi
    if [ ! $DB_PASSWORD ]; then
        DB_PASSWORD=`cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 24`
        sed -i "0,/DB_PASSWORD=/s//DB_PASSWORD=$DB_PASSWORD/" $install_dir/$script_file
    fi
    if [ ! -d "/var/lib/mysql/jumpserver" ]; then
        mysql -uroot -e "create database $DB_NAME default charset 'utf8';grant all on $DB_NAME.* to '$DB_USER'@'127.0.0.1' identified by '$DB_PASSWORD';flush privileges;"
    else
        mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASSWORD -e "use $DB_NAME;" || {
            echo -e "\033[31m 检测到数据库用户或者密码设置不当, 正在重新设置 \033[0m"
            mysql -uroot -e "drop database $DB_NAME;drop user $DB_USER@127.0.0.1;"
            mysql -uroot -e "create database $DB_NAME default charset 'utf8';grant all on $DB_NAME.* to '$DB_USER'@'127.0.0.1' identified by '$DB_PASSWORD';flush privileges;"
            flag=1
        }
    fi
fi

echo -e "\033[31m 配置 Redis \033[0m"
if [ $REDIS_HOST == 127.0.0.1 ]; then
    if [ "$(rpm -qa | grep redis)" == "" ]; then
        yum -y install redis
        systemctl enable redis
    fi
    if [ ! $REDIS_PORT != 6379 ]; then
        sed -i "s/port 6379/port $REDIS_PORT/g" /etc/redis.conf
    fi
    if [ ! $REDIS_PASSWORD ]; then
          if [ "$(cat /etc/redis.conf | grep -v ^\# | grep requirepass | awk '{print $2}')" == "" ]; then
              REDIS_PASSWORD=`cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 24`
              sed -i "481i requirepass $REDIS_PASSWORD" /etc/redis.conf
              sed -i "0,/REDIS_PASSWORD=/s//REDIS_PASSWORD=$REDIS_PASSWORD/" $install_dir/$script_file
          else
              REDIS_PASSWORD=`cat /etc/redis.conf | grep -v ^\# | grep requirepass | awk '{print $2}'`
              sed -i "0,/REDIS_PASSWORD=/s//REDIS_PASSWORD=$REDIS_PASSWORD/" $install_dir/$script_file
          fi
    else
          REDIS_PASSWORD=`cat /etc/redis.conf | grep -v ^\# | grep requirepass | awk '{print $2}'`
          sed -i '23d' $install_dir/$script_file
          sed -i "23i REDIS_PASSWORD=$REDIS_PASSWORD" $install_dir/$script_file
    fi
    if [ ! "$(systemctl status redis | grep running)" ]; then
        systemctl start redis
    fi
    if [ "$flag" == "1" ]; then
        redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD flushall
    fi
fi

echo -e "\033[31m 配置 Nginx \033[0m"
if [ ! -f "/etc/yum.repos.d/nginx.repo" ]; then
    echo -e "[nginx-stable]\nname=nginx stable repo\nbaseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/\ngpgcheck=1\nenabled=1\ngpgkey=https://nginx.org/keys/nginx_signing.key\nmodule_hotfixes=true" > /etc/yum.repos.d/nginx.repo
fi
if [ ! "$(rpm -qa | grep nginx)" ]; then
    yum install -y nginx || {
        yum -y localinstall --nogpgcheck https://demo.jumpserver.org/download/centos/7/nginx-1.16.1-1.el7.ngx.x86_64.rpm
    }
    systemctl enable nginx
    if [ ! -f "/etc/nginx/conf.d/jumpserver.conf" ]; then
        echo > /etc/nginx/conf.d/default.conf
        wget -O /etc/nginx/conf.d/jumpserver.conf https://demo.jumpserver.org/download/nginx/conf.d/jumpserver.conf
        if [ $install_dir != "/opt" ]; then
            sed -i "s@/opt@$install_dir@g" /etc/nginx/conf.d/jumpserver.conf
        fi
    fi
    if [ ! "$(systemctl status nginx | grep running)" ]; then
        systemctl start nginx
    fi
else
    if [ ! "$(systemctl status nginx | grep running)" ]; then
        systemctl start nginx
    fi
fi

echo -e "\033[31m 配置 Python3.6 \033[0m"
if [ ! "$(rpm -qa | grep python3-3.6)" ] || [ ! "$(rpm -qa | grep python3-devel-3.6)" ]; then
    yum -y install python36 python36-devel
fi
if [ ! -d "$install_dir/py3" ]; then
    python3.6 -m venv $install_dir/py3
fi
if [ ! -f "~/.pydistutils.cfg" ]; then
    echo -e "[easy_install]\nindex_url = https://mirrors.aliyun.com/pypi/simple/" > ~/.pydistutils.cfg
fi
if [ ! -f "~/.pip/pip.conf" ]; then
    mkdir -p ~/.pip
    echo -e "[global]\nindex-url = https://mirrors.aliyun.com/pypi/simple/\n\n[install]\ntrusted-host=mirrors.aliyun.com" > ~/.pip/pip.conf
fi

echo -e "\033[31m 下载组件 \033[0m"
cd $install_dir
if [ ! -d "$install_dir/jumpserver" ]; then
    git clone --depth=1 https://github.com/jumpserver/jumpserver.git || {
        rm -rf $install_dir/jumpserver
        wget -O $install_dir/jumpserver.tar.gz https://demo.jumpserver.org/download/jumpserver/$Version/jumpserver.tar.gz
        tar xf $install_dir/jumpserver.tar.gz -C $install_dir
        rm -rf $install_dir/jumpserver.tar.gz
    }
fi
if [ ! -d "$install_dir/luna" ]; then
    if [ ! -f "$install_dir/luna.tar.gz" ]; then
        wget -O $install_dir/luna.tar.gz https://github.com/jumpserver/luna/releases/download/$Version/luna.tar.gz || {
            rm -rf $install_dir/luna.tar.gz
            wget -O $install_dir/luna.tar.gz https://demo.jumpserver.org/download/luna/$Version/luna.tar.gz
        }
    fi
    tar xf $install_dir/luna.tar.gz -C $install_dir
    chown -R nginx:nginx $install_dir/luna
    rm -rf $install_dir/luna.tar.gz
fi

if [ ! -d "$install_dir/kokodir" ]; then
    if [ ! -f "$install_dir/koko-master-linux-amd64.tar.gz" ]; then
        wget -O $install_dir/koko-master-linux-amd64.tar.gz https://github.com/jumpserver/koko/releases/download/$Version/koko-master-linux-amd64.tar.gz || {
            rm -rf $install_dir/koko-master-linux-amd64.tar.gz
            wget -O $install_dir/koko-master-linux-amd64.tar.gz https://demo.jumpserver.org/download/koko/$Version/koko-master-linux-amd64.tar.gz
        }
    fi
    tar xf $install_dir/koko-master-linux-amd64.tar.gz -C $install_dir
    chown -R root:root $install_dir/kokodir
    rm -rf $install_dir/koko-master-linux-amd64.tar.gz
fi

if [ ! -d "$install_dir/docker-guacamole" ]; then
    git clone --depth=1 https://github.com/jumpserver/docker-guacamole.git || {
        rm -rf $install_dir/docker-guacamole
        wget -O $install_dir/guacamole.tar.gz https://demo.jumpserver.org/download/guacamole/$Version/guacamole.tar.gz
        tar xf $install_dir/guacamole.tar.gz -C $install_dir
        rm -rf $install_dir/guacamole.tar.gz
    }
fi

echo -e "\033[31m 配置 Jumpser 依赖 \033[0m"
yum -y install $(cat $install_dir/jumpserver/requirements/rpm_requirements.txt)
source $install_dir/py3/bin/activate
pip install wheel
pip install --upgrade pip setuptools
pip install -r $install_dir/jumpserver/requirements/requirements.txt

echo -e "\033[31m 配置 Guacamole 依赖 \033[0m"
if [ ! -d "/config" ]; then
    mkdir -p /config/guacamole /config/guacamole/extensions /config/guacamole/record /config/guacamole/drive
    chown daemon:daemon /config/guacamole/record /config/guacamole/drive
fi
if [ ! -d "/usr/local/lib/freerdp" ]; then
    mkdir /usr/local/lib/freerdp/
    ln -s /usr/local/lib/freerdp /usr/lib64/freerdp
fi
if [ ! "$(rpm -qa | grep rpmfusion-free)" ]; then
    yum -y localinstall --nogpgcheck https://mirrors.aliyun.com/rpmfusion/free/el/rpmfusion-free-release-7.noarch.rpm
    wget -O /etc/yum.repos.d/rpmfusion-free-updates.repo https://demo.jumpserver.org/download/centos/7/rpmfusion-free-updates.repo
fi
if [ ! "$(rpm -qa | grep rpmfusion-nonfree)" ]; then
    yum -y localinstall --nogpgcheck https://mirrors.aliyun.com/rpmfusion/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm
    wget -O /etc/yum.repos.d/rpmfusion-nonfree-updates.repo https://demo.jumpserver.org/download/centos/7/rpmfusion-nonfree-updates.repo
fi
if [ ! "$(rpm -qa | grep java-1.8.0)" ]; then
    yum install -y java-1.8.0-openjdk libtool
fi
yum install -y cairo-devel libjpeg-turbo-devel libpng-devel uuid-devel
yum install -y ffmpeg-devel freerdp1.2-devel libvncserver-devel pulseaudio-libs-devel openssl-devel libvorbis-devel libwebp-devel

cd /config
if [ ! -d "/config/tomcat9" ]; then
    if [ ! -f "/config/apache-tomcat-9.0.30.tar.gz" ]; then
        wget -O /config/apache-tomcat-9.0.30.tar.gz https://mirrors.tuna.tsinghua.edu.cn/apache/tomcat/tomcat-9/v9.0.30/bin/apache-tomcat-9.0.30.tar.gz || {
            rm -rf /config/apache-tomcat-9.0.30.tar.gz
            wget -O /config/apache-tomcat-9.0.30.tar.gz https://demo.jumpserver.org/download/apache/tomcat/tomcat-9/v9.0.30/bin/apache-tomcat-9.0.30.tar.gz
        }
    fi
    tar xf /config/apache-tomcat-9.0.30.tar.gz -C /config
    mv /config/apache-tomcat-9.0.30 /config/tomcat9
    rm -rf /config/tomcat9/webapps/*
    rm -rf /config/apache-tomcat-9.0.30.tar.gz
    sed -i 's/Connector port="8080"/Connector port="8081"/g' /config/tomcat9/conf/server.xml
    sed -i 's/level = FINE/level = OFF/g' /config/tomcat9/conf/logging.properties
    sed -i 's/level = INFO/level = OFF/g' /config/tomcat9/conf/logging.properties
    sed -i 's@CATALINA_OUT="$CATALINA_BASE"/logs/catalina.out@CATALINA_OUT=/dev/null@g' /config/tomcat9/bin/catalina.sh
    echo "java.util.logging.ConsoleHandler.encoding = UTF-8" >> /config/tomcat9/conf/logging.properties
fi
if [ ! -f "/config/tomcat9/webapps/ROOT.war" ]; then
    ln -sf $install_dir/docker-guacamole/guacamole-1.0.0.war /config/tomcat9/webapps/ROOT.war
fi
if [ ! -f "/config/guacamole/extensions/guacamole-auth-jumpserver-1.0.0.jar" ]; then
    ln -sf $install_dir/docker-guacamole/guacamole-auth-jumpserver-1.0.0.jar /config/guacamole/extensions/guacamole-auth-jumpserver-1.0.0.jar
fi
if [ ! -f "/config/guacamole/guacamole.properties" ]; then
    ln -sf $install_dir/docker-guacamole/root/app/guacamole/guacamole.properties /config/guacamole/guacamole.properties
fi
if [ ! -f "/usr/lib/systemd/system/jms_guacd.service" ]; then
    cd $install_dir/docker-guacamole
    if [ ! -d "$install_dir/docker-guacamole/guacamole-server-1.0.0" ]; then
        tar xf guacamole-server-1.0.0.tar.gz
    fi
    cd guacamole-server-1.0.0
    autoreconf -fi
    ./configure
    make
    make install
    ldconfig
    cd ..
    rm -rf guacamole-server-1.0.0
    wget -O /usr/lib/systemd/system/jms_guacd.service https://demo.jumpserver.org/download/shell/centos/jms_guacd.service
    chmod 755 /usr/lib/systemd/system/jms_guacd.service
    systemctl enable jms_guacd
fi
if [ ! -f "/bin/ssh-forward" ]; then
    wget -O $install_dir/linux-amd64.tar.gz https://github.com/ibuler/ssh-forward/releases/download/v0.0.5/linux-amd64.tar.gz || {
        rm -rf $install_dir/linux-amd64.tar.gz
        wget -O $install_dir/linux-amd64.tar.gz https://demo.jumpserver.org/download/ssh-forward/v0.0.5/linux-amd64.tar.gz
    }
    tar xf $install_dir/linux-amd64.tar.gz -C /bin/
    chown root:root /bin/ssh-forward
    chmod +x /bin/ssh-forward
    rm -rf $install_dir/linux-amd64.tar.gz
fi

cd $install_dir

echo -e "\033[31m 处理 Jumpser 配置文件 \033[0m"
if [ ! "$SECRET_KEY" ]; then
    SECRET_KEY=`cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 50`
    sed -i "0,/SECRET_KEY=/s//SECRET_KEY=$SECRET_KEY/" $install_dir/$script_file
fi
if [ ! "$BOOTSTRAP_TOKEN" ]; then
    BOOTSTRAP_TOKEN=`cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 16`
    sed -i "0,/BOOTSTRAP_TOKEN=/s//BOOTSTRAP_TOKEN=$BOOTSTRAP_TOKEN/" $install_dir/$script_file
fi
if [ ! "$Server_IP" ]; then
    Server_IP=`ip addr | grep 'state UP' -A2 | grep inet | egrep -v '(127.0.0.1|inet6|docker)' | awk '{print $2}' | tr -d "addr:" | head -n 1 | cut -d / -f1`
fi

function config_jumpserver {
    cp $install_dir/jumpserver/config_example.yml $install_dir/jumpserver/config.yml
    sed -i "s/SECRET_KEY:/SECRET_KEY: $SECRET_KEY/g" $install_dir/jumpserver/config.yml
    sed -i "s/BOOTSTRAP_TOKEN:/BOOTSTRAP_TOKEN: $BOOTSTRAP_TOKEN/g" $install_dir/jumpserver/config.yml
    sed -i "s/# DEBUG: true/DEBUG: false/g" $install_dir/jumpserver/config.yml
    sed -i "s/# LOG_LEVEL: DEBUG/LOG_LEVEL: ERROR/g" $install_dir/jumpserver/config.yml
    sed -i "s/# SESSION_EXPIRE_AT_BROWSER_CLOSE: false/SESSION_EXPIRE_AT_BROWSER_CLOSE: true/g" $install_dir/jumpserver/config.yml
    sed -i "s/DB_HOST: 127.0.0.1/DB_HOST: $DB_HOST/g" $install_dir/jumpserver/config.yml
    sed -i "s/DB_PORT: 3306/DB_PORT: $DB_PORT/g" $install_dir/jumpserver/config.yml
    sed -i "s/DB_USER: jumpserver/DB_USER: $DB_USER/g" $install_dir/jumpserver/config.yml
    sed -i "s/DB_PASSWORD: /DB_PASSWORD: $DB_PASSWORD/g" $install_dir/jumpserver/config.yml
    sed -i "s/DB_NAME: jumpserver/DB_NAME: $DB_NAME/g" $install_dir/jumpserver/config.yml
    sed -i "s/REDIS_HOST: 127.0.0.1/REDIS_HOST: $REDIS_HOST/g" $install_dir/jumpserver/config.yml
    sed -i "s/REDIS_PORT: 6379/REDIS_PORT: $REDIS_PORT/g" $install_dir/jumpserver/config.yml
    sed -i "s/# REDIS_PASSWORD: /REDIS_PASSWORD: $REDIS_PASSWORD/g" $install_dir/jumpserver/config.yml
}

if [ ! -f "$install_dir/jumpserver/config.yml" ]; then
    config_jumpserver
else
    echo -e "\033[31m 修正 Jumpserver 配置文件 \033[0m"
    if [ "$(cat $install_dir/jumpserver/config.yml | grep -v ^\# | grep SECRET_KEY | awk '{print $2}')" != "$SECRET_KEY" ] || [ "$(cat $install_dir/jumpserver/config.yml | grep -v ^\# | grep BOOTSTRAP_TOKEN | awk '{print $2}')" != "$BOOTSTRAP_TOKEN" ] || [ "$(cat $install_dir/jumpserver/config.yml | grep -v ^\# | grep DB_PASSWORD | awk '{print $2}')" != "$DB_PASSWORD" ] || [ "$(cat $install_dir/jumpserver/config.yml | grep -v ^\# | grep REDIS_PASSWORD | awk '{print $2}')" != "$REDIS_PASSWORD" ]; then
        rm -rf $install_dir/jumpserver/config.yml
        config_jumpserver
    fi
fi

function config_koko {
    cp $install_dir/kokodir/config_example.yml $install_dir/kokodir/config.yml
    sed -i "s/BOOTSTRAP_TOKEN: <PleasgeChangeSameWithJumpserver>/BOOTSTRAP_TOKEN: $BOOTSTRAP_TOKEN/g" $install_dir/kokodir/config.yml
    sed -i "s/# LOG_LEVEL: INFO/LOG_LEVEL: ERROR/g" $install_dir/kokodir/config.yml
    sed -i "s@# SFTP_ROOT: /tmp@SFTP_ROOT: /@g" $install_dir/kokodir/config.yml
}

echo -e "\033[31m 处理 Koko 配置文件 \033[0m"
if [ ! -f "$install_dir/kokodir/config.yml" ]; then
    config_koko
else
    if [ "$(cat $install_dir/kokodir/config.yml | grep -v ^\# | grep $BOOTSTRAP_TOKEN)" == "" ] || [ "$flag" == "1" ]; then
        rm -rf $install_dir/kokodir/config.yml
        rm -rf $install_dir/kokodir/data/keys/.access_key
        config_koko
    fi
fi

echo -e "\033[31m 启动 Jumpserver \033[0m"
if [ ! -f "/usr/lib/systemd/system/jms_core.service" ]; then
    wget -O /usr/lib/systemd/system/jms_core.service https://demo.jumpserver.org/download/shell/centos/jms_core.service
    if [ $install_dir != "/opt" ]; then
        sed -i "s@/opt@$install_dir@g" /usr/lib/systemd/system/jms_core.service
    fi
    if [ $DB_HOST != 127.0.0.1 ]; then
        sed -i "s/mariadb.service //g" /usr/lib/systemd/system/jms_core.service
    fi
    if [ $REDIS_HOST != 127.0.0.1 ]; then
        sed -i "s/redis.service //g" /usr/lib/systemd/system/jms_core.service
    fi
    chmod 755 /usr/lib/systemd/system/jms_core.service
    systemctl daemon-reload
    systemctl enable jms_core
fi

systemctl start jms_core || {
    systemctl stop jms_core
    systemctl start jms_core
}

sleep 10s
echo -e "\033[31m 启动 Koko \033[0m"
if [ ! -f "/usr/lib/systemd/system/jms_koko.service" ]; then
    wget -O /usr/lib/systemd/system/jms_koko.service https://demo.jumpserver.org/download/shell/centos/jms_koko.service
    chmod 755 /usr/lib/systemd/system/jms_koko.service
    if [ $install_dir != "/opt" ]; then
        sed -i "s@/opt@$install_dir@g" /usr/lib/systemd/system/jms_koko.service
    fi
    systemctl daemon-reload
    systemctl enable jms_koko
    systemctl start jms_koko
fi

function config_guacamole {
    wget -O /usr/lib/systemd/system/jms_guacamole.service https://demo.jumpserver.org/download/shell/centos/jms_guacamole.service
    chmod 755 /usr/lib/systemd/system/jms_guacamole.service
    if grep -q '# Environment=' /usr/lib/systemd/system/jms_guacamole.service ; then
        sed -i "s@# Environment=@Environment=\"JUMPSERVER_SERVER=http://127.0.0.1:8080\" \"BOOTSTRAP_TOKEN=$BOOTSTRAP_TOKEN\" \"JUMPSERVER_KEY_DIR=/config/guacamole/keys\" \"GUACAMOLE_HOME=/config/guacamole\" \"GUACAMOLE_LOG_LEVEL=ERROR\" \"JUMPSERVER_CLEAR_DRIVE_SESSION=true\" \"JUMPSERVER_ENABLE_DRIVE=true\"@g" /usr/lib/systemd/system/jms_guacamole.service
    fi
    systemctl daemon-reload
    systemctl enable jms_guacamole
    systemctl start jms_guacd
    systemctl start jms_guacamole
}

echo -e "\033[31m 启动Guacamole \033[0m"
if [ ! -f "/usr/lib/systemd/system/jms_guacamole.service" ]; then
    config_guacamole
else
    if [ ! "$(cat /usr/lib/systemd/system/jms_guacamole.service | grep -v ^\# | grep $BOOTSTRAP_TOKEN)" ] || [ "$flag" == "1" ]; then
        rm -rf /usr/lib/systemd/system/jms_guacamole.service
        rm -rf /config/guacamole/keys/*
        config_guacamole
    fi
fi

if [ ! "$(systemctl status jms_koko | grep running)" ]; then
    systemctl start jms_koko
fi
if [ ! "$(systemctl status jms_guacamole | grep running)" ]; then
    systemctl start jms_guacamole
fi

echo -e "\033[31m 请打开浏览器访问 http://$Server_IP 用户名:admin 密码:admin \033[0m"
