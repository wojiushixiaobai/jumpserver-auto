#!/bin/bash
# coding: utf-8
#

set -e

echo -e "\033[31m 请先看readme.txt说明 \033[0m"
echo -e "\033[31m 本脚本仅用于测试环境使用 \033[0m"
echo -e "\033[31m 本脚本为第三方使用脚本，非官方作品 \033[0m"
echo -e "\033[31m 如果使用本脚本造成任何数据方面的损失，本人均无法负责 \033[0m"
echo -e "\033[31m 目前本脚本仅支持CentOS 7系统 \033[0m"
echo -e "\033[31m 请确定你当前的网络正常 \033[0m"
echo -e "\033[31m 本脚本将会删除/opt目录下的文件 \033[0m"
echo -e "\033[31m 本程序将于10秒后开始运行，祝您好运！ \033[0m"

sleep 10s
setenforce 0 || true
sed -i "s/enforcing/disabled/g" `grep enforcing -rl /etc/selinux/config` || true
systemctl stop iptables.service || true
systemctl stop firewalld.service || true
systemctl disable iptables.service || true
systemctl disable firewalld.service || true

if grep -q 'LANG="zh_CN.UTF-8"' /etc/locale.conf; then
echo -e "\033[31m 当前已经是zh_CN.UTF-8 \033[0m"
else
localedef -c -f UTF-8 -i zh_CN zh_CN.UTF-8 && export LC_ALL=zh_CN.UTF-8 && echo 'LANG="zh_CN.UTF-8"' > /etc/locale.conf
fi

sleep 1s

yum -y update || true
yum -y install vim wget sqlite-devel xz gcc automake zlib-devel openssl-devel epel-release git || true
yum -y install mariadb mariadb-devel mariadb-server || true
yum -y install nginx redis || true

sleep 1s

systemctl enable mariadb && systemctl enable nginx && systemctl enable redis || true
systemctl restart mariadb && systemctl restart redis || true

sleep 1s

rm -rf /opt/jumpserver || true
rm -rf /opt/coco || true
rm -rf /opt/luna* || true
rm -rf /opt/Py* || true
rm -rf /opt/py* || true

sleep 1s

if [ ! -f "jumpserver.tar.gz" ]; then
cd /opt  || true
wget https://www.python.org/ftp/python/3.6.1/Python-3.6.1.tar.xz || true
git clone --depth=1 https://github.com/jumpserver/jumpserver.git || true
git clone https://github.com/jumpserver/coco.git || true
wget https://github.com/jumpserver/luna/releases/download/1.3.2/luna.tar.gz || true
tar xf Python-3.6.1.tar.xz && tar xf luna.tar.gz || true
chown -R root:root luna || true
else
tar xf jumpserver.tar.gz -C /opt || true
fi

sleep 1s

cd /opt/jumpserver && git checkout master && git pull || true
cd /opt/coco && git checkout master && git pull || true
cd /opt/Python-3.6.1 && ./configure && make && make install || true

sleep 1s

cd /opt || true
python3 -m venv /opt/py3 || true
source /opt/py3/bin/activate || true
yum -y install $(cat /opt/jumpserver/requirements/rpm_requirements.txt) && yum -y install $(cat /opt/coco/requirements/rpm_requirements.txt) || true
pip install --upgrade pip && pip install -r /opt/jumpserver/requirements/requirements.txt &&  pip install -r /opt/coco/requirements/requirements.txt || true

sleep 1s

if [ ! -d "/var/lib/mysql/jumpserver" ]; then
mysql -uroot -e "
create database jumpserver default charset 'utf8';
grant all on jumpserver.* to 'jumpserver'@'127.0.0.1' identified by 'somepassword';
flush privileges;
quit"
else
mysql -uroot -e "
drop database jumpserver;
drop user jumpserver@127.0.0.1;
flush privileges;
create database jumpserver default charset 'utf8';
grant all on jumpserver.* to 'jumpserver'@'127.0.0.1' identified by 'somepassword';
flush privileges;
quit"
fi

sleep 1s

cd /opt || true
if [ ! -f "/opt/jumpserver/config.py" ]; then
cp /opt/jumpserver/config_example.py /opt/jumpserver/config.py || true
else
rm -rf /opt/jumpserver/config.py || true
cp /opt/jumpserver/config_example.py /opt/jumpserver/config.py || true
fi

if [ ! -f "/opt/coco/conf.py" ]; then
cp /opt/coco/conf_example.py /opt/coco/conf.py || true
else
rm -rf /opt/coco/conf.py || true
cp /opt/coco/conf_example.py /opt/coco/conf.py || true
fi

sleep 1s

sed -i "s/DB_ENGINE = 'sqlite3'/# DB_ENGINE = 'sqlite3'/g" `grep "DB_ENGINE = 'sqlite3'" -rl /opt/jumpserver/config.py` || true
sed -i "s/DB_NAME = os.path.join/# DB_NAME = os.path.join/g" `grep "DB_NAME = os.path.join" -rl /opt/jumpserver/config.py` || true
sed -i "s/# DB_ENGINE = 'mysql'/DB_ENGINE = 'mysql'/g" `grep "# DB_ENGINE = 'mysql'" -rl /opt/jumpserver/config.py` || true
sed -i "s/# DB_HOST = '127.0.0.1'/DB_HOST = '127.0.0.1'/g" `grep "# DB_HOST = '127.0.0.1'" -rl /opt/jumpserver/config.py` || true
sed -i "s/# DB_PORT = 3306/DB_PORT = 3306/g" `grep "# DB_PORT = 3306" -rl /opt/jumpserver/config.py` || true
sed -i "s/# DB_USER = 'root'/DB_USER = 'jumpserver'/g" `grep "# DB_USER = 'root'" -rl /opt/jumpserver/config.py` || true
sed -i "s/# DB_PASSWORD = ''/DB_PASSWORD = 'somepassword'/g" `grep "# DB_PASSWORD = ''" -rl /opt/jumpserver/config.py` || true
sed -i "s/# DB_NAME = 'jumpserver'/DB_NAME = 'jumpserver'/g" `grep "# DB_NAME = 'jumpserver'" -rl /opt/jumpserver/config.py` || true

sleep 1s

cd /opt/jumpserver/utils && bash make_migrations.sh || true
cd /opt  || true

sleep 1s

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

systemctl restart nginx || true

cat << EOF > /opt/start_jms.sh
#!/bin/bash

ps -ef | egrep '(gunicorn|celery|beat|cocod)' | grep -v grep
if [ \$? -ne 0 ]; then
  echo -e "\033[31m 不存在Jumpserver进程，正常启动 \033[0m"
else
  echo -e "\033[31m 检测到Jumpserver进程未退出，结束中 \033[0m"
  cd /opt && sh stop_jms.sh
  sleep 5s
  ps aux | egrep '(gunicorn|celery|beat|cocod)' | awk '{ print \$2 }' | xargs kill -9
fi
source /opt/py3/bin/activate
cd /opt/jumpserver && ./jms start -d
sleep 5s
cd /opt/coco && ./cocod start -d
docker start jms_guacamole
exit 0
EOF

sleep 1s
cat << EOF > /opt/stop_jms.sh
#!/bin/bash

source /opt/py3/bin/activate
cd /opt/coco && ./cocod stop
docker stop jms_guacamole
sleep 5s
cd /opt/jumpserver && ./jms stop
exit 0
EOF

sleep 1s
cat << EOF > /opt/upgrade_jms.sh
#!/bin/bash

source /opt/py3/bin/activate
cd /opt/jumpserver
git pull && pip install -r requirements/requirements.txt && cd utils && sh make_migrations.sh
cd /opt/coco
git pull && pip install -r requirements/requirements.txt
exit 0
EOF

sleep 1s
chmod +x /opt/start_jms.sh
chmod +x /opt/stop_jms.sh
chmod +x /opt/upgrade_jms.sh

if grep -q 'bash /opt/start_jms.sh' /etc/rc.local; then
echo -e "\033[31m 自启脚本已经存在 \033[0m"
else
chmod +x /etc/rc.local || true
echo "bash /opt/start_jms.sh" >> /etc/rc.local
fi

if grep -q 'source /opt/autoenv/activate.sh' ~/.bashrc; then
    echo -e "\033[31m 自动 python 环境已经存在 \033[0m"
else
    echo 'source /opt/autoenv/activate.sh' >> ~/.bashrc
fi

source ~/.bashrc
echo "source /opt/py3/bin/activate" > /opt/jumpserver/.env
echo "source /opt/py3/bin/activate" > /opt/coco/.env

cd /opt && ./start_jms.sh

exit 0
