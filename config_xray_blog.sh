#!/bin/bash

[ -x "$0" -a "$0" != "bash" ] && {
	scp_dir="$(dirname "$(readlink -f "$0")")"
	[ "$(ls "$scp_dir/shell_common")" ] && [ "$(ls "$scp_dir/script")" ]
} && {
	IFS='' read -r -d '' checkcmd_install < "$scp_dir/shell_common/checkcmd_install.sh"
	IFS='' read -r -d '' nginx_http_redirect < "$scp_dir/script/nginx/http_redirect.conf"
	IFS='' read -r -d '' nginx_https_from_xray < "$scp_dir/script/nginx/https_from_xray.conf"
	IFS='' read -r -d '' nginx_stream_sni_proxy < "$scp_dir/script/nginx/stream_sni_proxy.conf"
	IFS='' read -r -d '' xray_config < "$scp_dir/script/xray/config.json"
} || {
	checkcmd_install="$(wget -qO- https://github.com/756yang/shell_common/raw/main/checkcmd_install.sh)"
	nginx_http_redirect="$(wget -qO- https://github.com/756yang/my_debian_server_config/raw/main/script/nginx/http_redirect.conf)"
	nginx_https_from_xray="$(wget -qO- https://github.com/756yang/my_debian_server_config/raw/main/script/nginx/https_from_xray.conf)"
	nginx_stream_sni_proxy="$(wget -qO- https://github.com/756yang/my_debian_server_config/raw/main/script/nginx/stream_sni_proxy.conf)"
	xray_config="$(wget -qO- https://github.com/756yang/my_debian_server_config/raw/main/script/xray/config.json)"
}

bash -c "$checkcmd_install" @ ssh sshpass openssl grep "gawk|awk" sed xargs find sponge tar gzip
[ $? -ne 0 ] && exit 1

read -p "please input you server address:port ? " myserver
read -p "please input you server username:password ? " username
[[ "$myserver" =~ ":" ]] && mysshport="${myserver##*:}" && myserver="${myserver%:*}"
[ -z "$mysshport" ] && mysshport=22
[[ "$username" =~ ":" ]] && mypassword="${username#*:}" && username="${username%%:*}"
[ -n "$mypassword" ] && sshcmd='sshpass -p "'"$mypassword"'" ssh' || sshcmd=ssh

IFS='' read -r -d '' SSH_COMMAND <<EOT
function checkcmd_install { $checkcmd_install }
checkcmd_install wget grep git sponge find
EOT
eval "$sshcmd" $username@$myserver -p $mysshport -t '"$SSH_COMMAND"'
[ $? -ne 0 ] && exit 1


echo "please input your server_domain:"
server_domain=`code_decrypt C8CzPgrRq++AcGs=`
echo "please input your websocket_path:"
websocket_path=`code_decrypt V5mNBjXC8ame`
echo "please input your vless_reality_id:"
vless_reality_id=`code_decrypt SprlZE7S8fPZKSLl4/eEgOroPZkqcqHKBfP3+ost3IJdbXi8` # REALITY配置的用户id，需生成
echo "please input your vless_reality_prk:"
vless_reality_prk=`code_decrypt QOjrFgnGqPPHb1GLtImAxbezJpZ/cLOxZMeEqtQAv4p1Q1X2FqRhku7EZA==` # REALITY配置的私钥，需生成
echo "please input your vless_reality_pbk:"
vless_reality_pbk=`code_decrypt GvCkB0bTvPmQfk7gv+qH/fjkRbQlX6iCfqWmrI5/i9ZIVFG3H4lSm9HWYA==` # REALITY配置的公钥，需生成
echo "please input your vless_reality_sid1:"
vless_reality_sid1=`code_decrypt QMjkZh2H8/bFLyzkteLV1g==` # REALITY配置的爬虫客户端shortId(长)，需生成
echo "please input your vless_reality_sid2:"
vless_reality_sid2=`code_decrypt HJ2zaUuG8KI=` # REALITY配置的爬虫客户端shortId(短)，需生成
echo "please input your vless_h2c_id:"
vless_h2c_id=`code_decrypt ScjlMUeCoqPZJiPrsfeE1rvpPcF9Lv3KCqCtqo932NldPSm1` # H2C配置的用户id，需生成
echo "please input your vless_websocket_id:"
vless_websocket_id=`code_decrypt QcrgZUfR9KDZeSi2tveEgrjrPZpwJ6DKUa76/oAq3d5dPy/g` # WebSocket配置的用户id，需生成

IFS='' read -r -d '' SSH_COMMANDS <<"EOT"
# 安装xray-core
sudo bash -c "$(wget -O - https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# 配置tcp_bbr加速网络
if ! { lsmod | grep tcp_bbr >/dev/null; }; then
	if ! { grep '^[^#]*net\.ipv4\.tcp_congestion_control' /etc/sysctl.conf >/dev/null; }; then
		awk '{print}END{print "net.ipv4.tcp_congestion_control=bbr"}' /etc/sysctl.conf | sudo sponge /etc/sysctl.conf
		if ! { grep '^[^#]*net\.core\.default_qdisc' /etc/sysctl.conf >/dev/null; }; then
			awk '{print}END{print "net.core.default_qdisc=fq"}' /etc/sysctl.conf | sudo sponge /etc/sysctl.conf
		fi
		sudo sysctl -p
	fi
fi

EOT

# 删除nginx的http 80端口的default_server标识
IFS='' read -r -d '' SSH_COMMAND <<"EOT"
{
	find /etc/nginx/conf.d -name "*.conf"
	find /etc/nginx/sites-enabled ! -type d
} | while read line; do [ "$line" ] && {
	sudo sed -i 's/listen 80 default_server/listen 80/' "$line"
	sudo sed -i 's/listen \[::\]:80 default_server/listen [::]:80/' "$line"
}; done

EOT
SSH_COMMANDS="$SSH_COMMANDS""$SSH_COMMAND"

# 配置http跳转https
eval "$nginx_http_redirect"
# 配置https服务
eval "$nginx_https_from_xray"
# 配置sni分流
eval "$nginx_stream_sni_proxy"
# 配置xray服务
eval "$xray_config"

IFS='' read -r -d '' SSH_COMMAND <<"EOT"
# 设置最简单网页
mkdir -p ~/www/hexoblog
echo "This simple html test!" > ~/www/hexoblog/index.html
# 重启xray和nginx服务
sudo systemctl restart xray
sudo systemctl restart nginx

# 配置网页的git服务器
mkdir -p ~/git/repo
git init --bare ~/git/repo/hexoblog.git
echo '#!/bin/bash
git --work-tree=$HOME/www/hexoblog --git-dir=$HOME/git/repo/hexoblog.git checkout -f' > ~/git/repo/hexoblog.git/hooks/post-receive
chmod +x ~/git/repo/hexoblog.git/hooks/post-receive

EOT
SSH_COMMANDS="$SSH_COMMANDS""$SSH_COMMAND"


eval "$sshcmd" $username@$myserver -p $mysshport -t '"$SSH_COMMANDS"'


# 生成vless分享链接

function vless_link ()
{
	local awk_script='{
		for(i=1;i<=NF;i++){
			ch=$i+0;
			if((ch>=48&&ch<=57)||(ch>=97&&ch<=122)||(ch>=65&&ch<=90)||ch==45||ch==95||ch==46)
				printf("%c",ch);
			else{
				cs=ch/16;
				cc=ch%16;
				cs+=47+(cs>9?8:1);
				cc+=47+(cc>9?8:1);
				printf("%%%c%c",cs,cc);
			}
		}
	}'
	id=$(echo -n "$id" | od -tu1 -An -v | LC_ALL=C awk "$awk_script")
	address=$(echo -n "$address" | od -tu1 -An -v | LC_ALL=C awk "$awk_script")
	port=$(echo -n "$port" | od -tu1 -An -v | LC_ALL=C awk "$awk_script")
	encryption=$(echo -n "$encryption" | od -tu1 -An -v | LC_ALL=C awk "$awk_script")
	flow=$(echo -n "$flow" | od -tu1 -An -v | LC_ALL=C awk "$awk_script")
	security=$(echo -n "$security" | od -tu1 -An -v | LC_ALL=C awk "$awk_script")
	headerType=$(echo -n "$headerType" | od -tu1 -An -v | LC_ALL=C awk "$awk_script")
	host=$(echo -n "$host" | od -tu1 -An -v | LC_ALL=C awk "$awk_script")
	path=$(echo -n "$path" | od -tu1 -An -v | LC_ALL=C awk "$awk_script")
	alpn=$(echo -n "$alpn" | od -tu1 -An -v | LC_ALL=C awk "$awk_script")
	sni=$(echo -n "$sni" | od -tu1 -An -v | LC_ALL=C awk "$awk_script")
	fp=$(echo -n "$fp" | od -tu1 -An -v | LC_ALL=C awk "$awk_script")
	pbk=$(echo -n "$pbk" | od -tu1 -An -v | LC_ALL=C awk "$awk_script")
	sid=$(echo -n "$sid" | od -tu1 -An -v | LC_ALL=C awk "$awk_script")
	spx=$(echo -n "$spx" | od -tu1 -An -v | LC_ALL=C awk "$awk_script")
	type=$(echo -n "$type" | od -tu1 -An -v | LC_ALL=C awk "$awk_script")
	remarks=$(echo -n "$remarks" | od -tu1 -An -v | LC_ALL=C awk "$awk_script")
	printf "%s" "vless://$id@$address:$port?encryption=$encryption&flow=$flow&security=$security"\
			"&headerType=$headerType&host=$host&path=$path&alpn=$alpn"\
			"&sni=$sni&fp=$fp&pbk=$pbk&sid=$sid&spx=$spx&type=$type#$remarks"$'\n' | sed -e 's/[_A-Za-z0-9]*=&//g'
}

echo "--------------------------------"
remarks="VLESS+Vision+REALITY.blog.$server_domain" # 别名
id=$vless_reality_id # 用户id，需生成
address=blog.$server_domain # 服务器地址
port=443 # 服务器端口
encryption=none # 加密类型
flow=xtls-rprx-vision # 流控
security=reality # 传输层安全
type=tcp # 连接类型
sni=blog.$server_domain # 借用网站域名
fp=chrome # 浏览器类型
pbk=$vless_reality_pbk # 公钥，需生成
sid=$vless_reality_sid1 # 爬虫客户端shortId，需生成
spx=/ # 爬虫起始路径
headerType= # 伪装类型
host= # 伪装域名
path= # 访问路径
alpn= # 应用层协商

vless_link
echo "--------------------------------"
fp=firefox
sid=$vless_reality_sid2
vless_link

echo "--------------------------------"
remarks="VLESS+H2C+REALITY.blog.$server_domain"
id=$vless_h2c_id
flow=
type=h2
vless_link

echo "--------------------------------"
remarks="VLESS+WebSocket+Nginx.www.$server_domain"
id=$vless_websocket_id
address=www.$server_domain # 服务器地址
port=443 # 服务器端口
encryption=none # 加密类型
flow=
security=tls
type=ws
sni=
fp=
pbk=
sid=
spx=
headerType=
host=www.$server_domain
path=$websocket_path
alpn=
vless_link
