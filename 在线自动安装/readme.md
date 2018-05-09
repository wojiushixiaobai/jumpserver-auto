本脚本仅供测试环境使用，对于使用本脚本造成任何数据方面的损失，本人均无法负责。

请保证硬件配置不低于双核4G，仅供新安装 CentOS 7 系统使用

本脚本可以配合jumpserver.tar.gz文件一起使用，也可以单独使用

请下载jumpserver.sh与jumpserver.tar.gz并上传到Centos7服务器上(如果不存在jumpserver.tar.gz文件，脚本将会自动下载python jumpserver coco luna到/opt目录)

本脚本允许容错，直到jumpserver安装完成并运行以前都可以取消后重新运行本脚本

本脚本安装结束后会自动启动jumpserver与coco

本脚本会把 /opt/start_jms.sh 脚本写入 /etc/rc.local 达到自启目的

自启动文件为 /opt/start_jms.sh   可手动执行此文件重启jumpserver与coco   ./start_jms.sh


地址：
https://pan.baidu.com/s/1Casz3fZotqe0Pt5qjvulbA

注：本文档及使用脚本非官方给出，脚本代码均未作任何加密，可以自行修改处理。本人非专业脚本工程师，能力有限，如果有更好的执行方式，欢迎指正。
