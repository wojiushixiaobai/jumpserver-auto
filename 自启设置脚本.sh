#!/bin/bash

systemctl enable mariadb && systemctl enable nginx && systemctl enable redis && systemctl enable docker

echo -e "\033[31m 正在配置脚本 \033[0m"
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
chmod +x /opt/start_jms.sh
chmod +x /opt/stop_jms.sh

echo -e "\033[31m 正在写入开机自启 \033[0m"
if grep -q 'sh /opt/start_jms.sh' /etc/rc.local; then
	echo -e "\033[31m 自启脚本已经存在 \033[0m"
else
	chmod +x /etc/rc.local
	echo "sh /opt/start_jms.sh" >> /etc/rc.local
fi

exit 0
