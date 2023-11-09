#!/bin/bash

[ -x "$0" -a "$0" != "bash" ] && {
	IFS='' read -r -d '' checkcmd_install < "$(dirname "$(readlink -f "$0")")/shell_common/checkcmd_install.sh"
} || {
	checkcmd_install="$(wget -qO- https://github.com/756yang/shell_common/raw/main/checkcmd_install.sh)"
}

bash -c "$checkcmd_install" @ ssh sshpass openssl grep "gawk|awk" sed xargs find sponge tar gzip
[ $? -ne 0 ] && exit 1

read -p "please input you server address:port ? " myserver
read -p "please input you server username:password ? " username
mysshport=${myserver##*:}
myserver=${myserver%:*}
[[ "$username" =~ ":" ]] && mypassword="${username#*:}" && username="${username%%:*}"
[ -n "mypassword" ] && sshcmd='sshpass -p "'$mypassword'" ssh' || sshcmd=ssh

IFS='' read -r -d '' SSH_COMMAND <<EOT
function checkcmd_install {$checkcmd_install}
checkcmd_install wget grep git
EOT
$sshcmd $username@$myserver -p $mysshport -t "$SSH_COMMAND"
[ $? -ne 0 ] && exit 1


IFS='' read -r -d '' SSH_COMMAND <<"EOT"
# 安装xray-core
sudo bash -c "$(wget -O - https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# 配置tcp_bbr加速网络
if ! { lsmod | grep tcp_bbr >/dev/null; }; then
	if ! { grep '^[^#]*net\.ipv4\.tcp_congestion_control' /etc/sysctl.conf >/dev/null; }; then
		awk '{print}END{print "net.ipv4.tcp_congestion_control=bbr"}' /etc/sysctl.conf | sponge /etc/sysctl.conf
		if ! { grep '^[^#]*net\.core\.default_qdisc' /etc/sysctl.conf >/dev/null; }; then
			awk '{print}END{print "net.core.default_qdisc=fq"}' /etc/sysctl.conf | sponge /etc/sysctl.conf
		fi
		sudo sysctl -p
	fi
fi
EOT

$sshcmd $username@$myserver -p $mysshport -t "$SSH_COMMAND"


echo "please input your server_domain:"
server_domain=`code_decrypt C8CzPgrRq++AcGs=`

echo "please input your websocket_path:"
websocket_path=`code_decrypt V8WAaCvam5ec`

echo "please input your vless_reality_id:"
vless_reality_id=`code_decrypt SZjlaUmF/afZKS+z5feEgba+PcB/cvzKA6T4q9p+3dkAPiiy` # REALITY配置的用户id，需生成
echo "please input your vless_reality_prk:"
vless_reality_prk=`code_decrypt LeizGi6dhY2NXG6lt7zli8aJR54nY7GmY6X6opQopMhfIS7yEO9vx/ygRg==` # REALITY配置的私钥，需生成
echo "please input your vless_reality_pbk:"
vless_reality_pbk=`code_decrypt Itq1JDTDhouXLFO957vI8r+sdI4hX5W2H/SghfgruNFpRyn9M5RazvX6fA==` # REALITY配置的公钥，需生成
echo "please input your vless_reality_sid1:"
vless_reality_sid1=`code_decrypt HJm2Yx2G8PSWfH/kt+2Jgw==` # REALITY配置的爬虫客户端shortId(长)，需生成
echo "please input your vless_reality_sid2:"
vless_reality_sid2=`code_decrypt QJHjaEnW9/g=` # REALITY配置的爬虫客户端shortId(短)，需生成
echo "please input your vless_websocket_id:"
vless_websocket_id=`code_decrypt TJizMU6E9qDZLi3ksPeE0OjpPcB+JfbKC6P2+YAui4gJai2z` # WebSocket配置的用户id，需生成


IFS='' read -r -d '' SSH_COMMAND <<EOT
# 配置http跳转https
echo 'server {
	listen 80 default_server;
	return 301 https://\$http_host\$request_uri;
}' | sudo tee /etc/nginx/conf.d/http_redirect.conf


# 配置https服务
echo "server {
	listen 127.0.0.1:7443 ssl http2 proxy_protocol default_server;
	set_real_ip_from 127.0.0.1;
	real_ip_header proxy_protocol;
	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_reject_handshake on;
}

server {
	listen 127.0.0.1:7443 ssl http2 proxy_protocol;
	set_real_ip_from 127.0.0.1;
	real_ip_header X-Forwarded-For;
	server_name blog.$server_domain www.$server_domain;
	ssl_certificate /etc/nginx/cert/$server_domain.fullchain.crt;
	ssl_certificate_key /etc/nginx/cert/$server_domain.key;
	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_prefer_server_ciphers on;
	ssl_ciphers ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305;
	ssl_ecdh_curve secp521r1:secp384r1:secp256r1:x25519;

	location $websocket_path {
		if (\\\$http_upgrade != "websocket") {
			return 404;
		}
		proxy_redirect off;
		proxy_pass http://127.0.0.1:2001;
		proxy_http_version 1.1;
		proxy_set_header Upgrade \\\$http_upgrade;
		proxy_set_header Connection "upgrade";
		proxy_set_header Host \\\$host;
		proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
	}

	location / {
		add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
		root /home/$username/www/hexoblog;
		index index.html;
	}
}" | sudo tee /etc/nginx/conf.d/https_from_xray.conf


# 配置xray服务
echo '{
  "log": {
    "loglevel": "warning",
    "error": "/var/log/xray/error.log",
    "access": "/var/log/xray/access.log"
  },
  "inbounds": [
    {
      "port": 443, //VLESS+Vision+REALITY 监听端口
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$vless_reality_id", //修改为自己的 UUID
            "flow": "xtls-rprx-vision", //启用 XTLS Vision
            "email": "443@gmail.com"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false, //选填，若为 true 输出调试信息。
          "dest": 7443, //转发给自己的网站监听端口
          "xver": 2, //开启 PROXY protocol 发送，发送真实来源 IP 和端口给自己的网站。 1 或 2 表示 PROXY protocol 版本。
          "serverNames": [ //必填，客户端可用的 serverName 列表，暂不支持 * 通配符。
            "blog.$server_domain" //修改为自己的网站域名
          ],
          "privateKey": "$vless_reality_prk", //修改为自己执行 ./xray x25519 后生成的一对密钥中私钥
          "shortIds": [ //必填，客户端可用的 shortId 列表，可用于区分不同的客户端。
            "$vless_reality_sid1",
            "$vless_reality_sid2" //若有此项，客户端 shortId 可为空。若不为空，可 0 到 f（0123456789abcdef），长度为 2 的倍数，长度上限为 16 。
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    },
    {
      "listen": "127.0.0.1", //只监听本机，避免本机外的机器探测到下面端口。
      "port": 2001, //VLESS+WebSocket 监听端口
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$vless_websocket_id", //修改为自己的 UUID
            "email": "2001@gmail.com"
          }
        ],
    "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "$websocket_path" //修改为自己的路径
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "blocked"
      }
    ]
  },
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "tag": "blocked",
      "protocol": "blackhole",
      "settings": {}
    }
  ]
}' | sudo tee /usr/local/etc/xray/config.json

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
git --work-tree=\$HOME/www/hexoblog --git-dir=\$HOME/git/repo/hexoblog.git checkout -f' > ~/git/repo/hexoblog.git/hooks/post-receive
chmod +x ~/git/repo/hexoblog.git/hooks/post-receive

EOT

$sshcmd $username@$myserver -p $mysshport -t "$SSH_COMMAND"


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
