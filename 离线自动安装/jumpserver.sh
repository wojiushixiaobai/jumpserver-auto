#!/bin/bash
# coding: utf-8
#

set -e

echo -e "\033[31m 欢迎使用本脚本安装 Jumpserver \033[0m"
echo -e "\033[31m 本脚本属于全自动安装脚本，无需人工干预及输入 \033[0m"
echo -e "\033[31m 本脚本仅适用于测试环境，如需用作生产，请自行修改相应配置 \033[0m"
echo -e "\033[31m 本脚本暂时只支持全新安装的 Centos7.4 \033[0m"
echo -e "\033[31m 本脚本将会把 Jumpserver 安装在 /opt 目录下 \033[0m"
echo -e "\033[31m 10秒后安装将开始，祝你好运 \033[0m"

sleep 10s

if [ ! -f "jumpserver.tar.gz" ]; then
	echo -e "\033[31m 不存在离线安装包 jumpserver.tar.gz \033[0m"
	echo -e "\033[31m 脚本自动退出 \033[0m"
	exit 1
else
	echo -e "\033[31m 检测到离线安装包 jumpserver.tar.gz \033[0m"
fi

if grep -q 'CentOS Linux release 7.4' /etc/redhat-release; then
	echo -e "\033[31m 检测到系统是 Centos7.4 \033[0m"
else
	echo -e "\033[31m 检测到系统不是 Centos7.4 \033[0m"
	echo -e "\033[31m 脚本自动退出 \033[0m"
	exit 1
fi

echo -e "\033[31m 正在关闭Selinux \033[0m"
setenforce 0 || true
sed -i "s/enforcing/disabled/g" `grep enforcing -rl /etc/selinux/config` || true

echo -e "\033[31m 正在关闭防火墙 \033[0m"
systemctl stop iptables.service || true
systemctl stop firewalld.service || true

if grep -q 'LANG="zh_CN.UTF-8"' /etc/locale.conf; then
	echo -e "\033[31m 当前环境已经是zh_CN.UTF-8 \033[0m"
else
	echo -e "\033[31m 设置环境zh_CN.UTF-8 \033[0m"
	localedef -c -f UTF-8 -i zh_CN zh_CN.UTF-8 && export LC_ALL=zh_CN.UTF-8 && echo 'LANG="zh_CN.UTF-8"' > /etc/locale.conf
fi

echo -e "\033[31m 正在解压离线包到 /opt 目录 \033[0m"
tar zxf jumpserver.tar.gz -C /opt
cd /opt && tar xf Python-3.6.1.tar.xz && tar xf dist.tar.gz && mv dist/ luna/
chown -R root:root luna/

echo -e "\033[31m 正在安装依赖包 \033[0m"
yum -y -q localinstall /opt/package/*.rpm --nogpgcheck

echo -e "\033[31m 正在安装 mariadb \033[0m"
yum -y -q localinstall /opt/package/mariadb/*.rpm --nogpgcheck

echo -e "\033[31m 正在安装 nginx \033[0m"
yum -y -q localinstall /opt/package/nginx/*.rpm --nogpgcheck

echo -e "\033[31m 正在安装 redis \033[0m"
yum -y -q localinstall /opt/package/redis/*.rpm --nogpgcheck

echo -e "\033[31m 正在配置 mariadb、nginx、rdis 服务自启 \033[0m"
systemctl enable mariadb && systemctl enable nginx && systemctl enable redis
systemctl restart mariadb && systemctl restart redis

echo -e "\033[31m 正在配置编译 python3 \033[0m"
cd /opt/Python-3.6.1 && ./configure >> /tmp/build.log && make >> /tmp/build.log && make install >> /tmp/build.log

echo -e "\033[31m 正在配置 python3 虚拟环境 \033[0m"
cd /opt
python3 -m venv /opt/py3
source /opt/py3/bin/activate || true

echo -e "\033[31m 正在安装依赖包 \033[0m"
yum -y -q localinstall /opt/package/jumpserver/*.rpm --nogpgcheck && yum -y -q localinstall /opt/package/coco/*.rpm --nogpgcheck
pip install --no-index --find-links="/opt/package/pip/jumpserver/" pyasn1 six cffi >> /tmp/build.log
pip install -r /opt/jumpserver/requirements/requirements.txt --no-index --find-links="/opt/package/pip/jumpserver/" >> /tmp/build.log
pip install -r /opt/coco/requirements/requirements.txt --no-index --find-links="/opt/package/pip/coco/" >> /tmp/build.log

echo -e "\033[31m 正在配置数据库 \033[0m"
mysql -uroot -e "
create database jumpserver default charset 'utf8';
grant all on jumpserver.* to 'jumpserver'@'127.0.0.1' identified by 'somepassword';
flush privileges;
quit"

echo -e "\033[31m 正在处理 jumpserver 与 coco 配置文件 \033[0m"
cd /opt
cp /opt/jumpserver/config_example.py /opt/jumpserver/config.py
cp /opt/coco/conf_example.py /opt/coco/conf.py

sed -i "s/DB_ENGINE = 'sqlite3'/# DB_ENGINE = 'sqlite3'/g" `grep "DB_ENGINE = 'sqlite3'" -rl /opt/jumpserver/config.py`
sed -i "s/DB_NAME = os.path.join/# DB_NAME = os.path.join/g" `grep "DB_NAME = os.path.join" -rl /opt/jumpserver/config.py`
sed -i "s/# DB_ENGINE = 'mysql'/DB_ENGINE = 'mysql'/g" `grep "# DB_ENGINE = 'mysql'" -rl /opt/jumpserver/config.py`
sed -i "s/# DB_HOST = '127.0.0.1'/DB_HOST = '127.0.0.1'/g" `grep "# DB_HOST = '127.0.0.1'" -rl /opt/jumpserver/config.py`
sed -i "s/# DB_PORT = 3306/DB_PORT = 3306/g" `grep "# DB_PORT = 3306" -rl /opt/jumpserver/config.py`
sed -i "s/# DB_USER = 'root'/DB_USER = 'jumpserver'/g" `grep "# DB_USER = 'root'" -rl /opt/jumpserver/config.py`
sed -i "s/# DB_PASSWORD = ''/DB_PASSWORD = 'somepassword'/g" `grep "# DB_PASSWORD = ''" -rl /opt/jumpserver/config.py`
sed -i "s/# DB_NAME = 'jumpserver'/DB_NAME = 'jumpserver'/g" `grep "# DB_NAME = 'jumpserver'" -rl /opt/jumpserver/config.py`

echo -e "\033[31m 正在初始化数据库 \033[0m"
cd /opt/jumpserver/utils && bash make_migrations.sh >> /tmp/build.log
cd /opt

echo -e "\033[31m 正在配置 nginx \033[0m"
cat << EOF > /etc/nginx/nginx.conf
# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - $remote_user [\$time_local] "\$request" '
                      '\$status $body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80 default_server;
        listen       [::]:80 default_server;
        server_name  _;
        root         /usr/share/nginx/html;

        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;

    proxy_set_header X-Real-IP \$remote_addr;
       proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

    location /luna/ {
        try_files \$uri / /index.html;
        alias /opt/luna/;
    }

    location /media/ {
        add_header Content-Encoding gzip;
        root /opt/jumpserver/data/;
    }

    location /static/ {
        root /opt/jumpserver/data/;
    }

    location /socket.io/ {
        proxy_pass       http://localhost:5000/socket.io/;  # 如果coco安装在别的服务器，请填写它的ip
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /guacamole/ {
        proxy_pass       http://localhost:8081/;  # 请填写运行docker服务的服务器ip，不更改此处Windows组件无法正常使用
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$http_connection;
        access_log off;
    }

    location / {
        proxy_pass http://localhost:8080;  # 如果jumpserver安装在别的服务器，请填写它的ip
    }

        error_page 404 /404.html;
            location = /40x.html {
        }

        error_page 500 502 503 504 /50x.html;
            location = /50x.html {
        }
    }
}

EOF

sleep 1s

systemctl restart nginx

echo -e "\033[31m 正在配置脚本 \033[0m"
cat << EOF > /opt/start_jms.sh
#!/bin/bash

source /opt/py3/bin/activate
cd /opt/jumpserver && ./jms start all -d
sleep 5s
cd /opt/coco && ./cocod start -d
exit 0
EOF

sleep 1s
cat << EOF > /opt/stop_jms.sh
#!/bin/bash

source /opt/py3/bin/activate
cd /opt/coco && ./cocod stop
sleep 5s
cd /opt/jumpserver && ./jms stop
exit 0
EOF

sleep 1s
chmod +x /opt/start_jms.sh
chmod +x /opt/stop_jms.sh

echo -e "\033[31m 正在写入开机自启 \033[0m"
if grep -q 'bash /opt/start_jms.sh' /etc/rc.local; then
	echo -e "\033[31m 自启脚本已经存在 \033[0m"
else
	chmod +x /etc/rc.local
	echo "bash /opt/start_jms.sh" >> /etc/rc.local
fi

echo -e "\033[31m 正在配置autoenv \033[0m"
if grep -q 'source /opt/autoenv/activate.sh' ~/.bashrc; then
	echo -e "\033[31m autoenv 已经配置 \033[0m"
else
	echo 'source /opt/autoenv/activate.sh' >> ~/.bashrc
fi

echo 'source /opt/py3/bin/activate' > /opt/jumpserver/.env
echo 'source /opt/py3/bin/activate' > /opt/coco/.env

echo -e "\033[31m 正在配置防火墙 \033[0m"
systemctl start firewalld
firewall-cmd --zone=public --add-port=8080/tcp --permanent
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --zone=public --add-port=2222/tcp --permanent
firewall-cmd --zone=public --add-port=5000/tcp --permanent
firewall-cmd --zone=public --add-port=8081/tcp --permanent
firewall-cmd --reload

echo -e "\033[31m 安装完成，请到 /opt 目录下手动执行 start_jms.sh 启动 Jumpserver \033[0m"
echo -e "\033[31m 安装 log 请查看 /tmp/build.log \033[0m"

exit 0
