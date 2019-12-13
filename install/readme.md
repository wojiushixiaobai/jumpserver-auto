请保证硬件配置不低于双核4G，仅供新安装 CentOS 7 系统使用

本脚本允许容错，直到jumpserver安装完成并运行以前都可以取消后重新运行本脚本

本脚本安装结束后会自动启动jumpserver

注：本使用脚本非官方给出，脚本代码均未作任何加密，可以自行修改处理。本人非专业脚本工程师，能力有限，如果有更好的执行方式，欢迎指正。

```
$ yum -y install wget
$ cd /opt
$ wget -O jms_install.sh https://demo.jumpserver.org/download/jms_install.sh
$ sh jms_install.sh

```
