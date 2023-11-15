
# my_debian_server_config

我的Debian服务器配置，使用以下命令下载脚本：

	git clone --depth 1 --shallow-submodules --recurse-submodules https://github.com/756yang/my_debian_server_config.git

使用前请在当前目录执行命令：`. encrypt.code`

1. `./server_reinstall.sh` Debian服务器重装系统，执行前请配置好SSH服务，比如SSH端口
2. `./server_init.sh` Debian服务器初始化配置，会创建普通用户并设置密钥登录，使用acme申请letsencrypt证书并设置ufw防火墙
3. `./config_xray_blog.sh` xray和nginx服务配置，做好sni分流的xray服务并设置一个最简单的网页服务
4. `./config_xray_blog.sh n` 仅打印xray的vless分享链接
5. `./config_email.sh` mailu服务配置，Selenium爬取mailu设置并全自动配置以nginx做sni代理
6. `./config_email.sh n` 仅打印mailu的管理员账号信息
