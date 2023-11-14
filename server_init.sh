#!/bin/bash

# 通常上，Debian服务器需要的最初配置工作，运行此脚本即可自动完成

# ssh执行远程命令几种方式：
: << "EOF"
1. ssh server command
    在server上执行命令command，不支持交互Shell
2. ssh -t server command
    在server上执行命令command并分配一个伪终端，支持交互Shell
3. cat script.sh | ssh server
    在server上执行script.sh的内容
4. cat script.sh | ssh -T server
    在server上执行script.sh的内容，不需要分配伪终端
5. cat script.sh | ssh -tt server
    在server上执行script.sh的内容，强制分配伪终端，由于stdin被占用，终端无法交互
6. cat filename | ssh server command
    在server上执行命令command，以filename的内容为标准输入
EOF

[ -x "$0" -a "$0" != "bash" ] && {
	scp_dir="$(dirname "$(readlink -f "$0")")"
	[ "$(ls "$scp_dir/shell_common")" ]
} && {
	IFS='' read -r -d '' checkcmd_install < "$scp_dir/shell_common/checkcmd_install.sh"
	IFS='' read -r -d '' awk_conf < "$scp_dir/shell_common/awk_conf.sh"
true;} || {
	checkcmd_install="$(wget -qO- https://github.com/756yang/shell_common/raw/main/checkcmd_install.sh)"
	awk_conf="$(wget -qO- https://github.com/756yang/shell_common/raw/main/awk_conf.sh)"
}

bash -c "$checkcmd_install" @ ssh openssl grep "gawk|awk" sed xargs find sponge tar gzip
[ $? -ne 0 ] && exit 1

read -p "please input you server address:port ? " myserver
read -p "please input you server username (not root)? " username
[[ "$myserver" =~ ":" ]] && mysshport="${myserver##*:}" && myserver="${myserver%:*}"
[ -z "$mysshport" ] && mysshport=22

echo "please input your email:"
my_email=`code_decrypt SZjkY0mA9PPHKlujovTT3OM=`
echo "please input your dns_api_key with format dnsname:apikey"
dns_api_key=`code_decrypt Nsi/NQ3ZqK7OJi+wsruDgL64IZwsdfCGUfepr4F33NgMPg==`
echo "please input your server_domain:"
server_domain=`code_decrypt C8CzPgrRq++AcGs=`

IFS='' read -r -d '' SSH_COMMAND <<EOT
# 更新软件包和系统
apt update && apt upgrade
# 安装必要软件包
apt install sudo vim ufw socat nginx wget
# 配置acme.sh自动申请免费ssl证书
mkdir /etc/nginx/cert
wget -O -  https://get.acme.sh | sh -s email=$my_email
source ~/.bashrc
acme.sh --upgrade --auto-upgrade
acme.sh --set-default-ca --server letsencrypt
dns_api_key=${dns_api_key,,}
dns_api_key=\${dns_api_key^}
export \${dns_api_key%:*}_Key=\${dns_api_key##*:}
dns_api_key=\${dns_api_key,}
read -p "please input a dnssleep time (default is 300): " dnssleep
acme.sh --issue --dns dns_\${dns_api_key%:*} --dnssleep \${dnssleep:-300}\\
		-d $server_domain -d '*.$server_domain' --keylength ec-256 --force
acme.sh --install-cert --ecc -d $server_domain\\
		--cert-file "/etc/nginx/cert/$server_domain.crt"\\
		--key-file "/etc/nginx/cert/$server_domain.key"\\
		--fullchain-file "/etc/nginx/cert/$server_domain.fullchain.crt"\\
		--reloadcmd "systemctl reload nginx"
# 添加普通用户及其家目录
useradd -G sudo -s /bin/bash -d "/home/$username" -m "$username"
passwd "$username"
EOT

ssh root@$myserver -p $mysshport -t "$SSH_COMMAND"

# 复制本地ssh公钥到服务器
ssh-copy-id $username@$myserver -p $mysshport


# 自动检查命令，必要时安装对应软件
IFS='' read -r -d '' SSH_COMMAND <<EOT
function checkcmd_install { $checkcmd_install }
checkcmd_install "gawk|awk" sponge
EOT
$sshcmd $username@$myserver -p $mysshport -t "$SSH_COMMAND"
[ $? -ne 0 ] && exit 1

IFS='' read -r -d '' SSH_COMMAND <<EOT
# 修改sshd配置，禁用密码登录并开启密钥登录
function awk_conf { $awk_conf }
cat /etc/ssh/sshd_config | awk_conf "PermitRootLogin yes"\\
	"PasswordAuthentication no" "RSAAuthentication yes"\\
	"PubkeyAuthentication yes" | sudo sponge /etc/ssh/sshd_config
EOT

ssh $username@$myserver -p $mysshport -t "$SSH_COMMAND"

# 配置防火墙
ssh $username@$myserver -p $mysshport -t "
	sudo ufw allow 80 # 开放HTTP端口
	sudo ufw allow 443 # 开放HTTPS端口
	sudo ufw allow $mysshport # 开放SSH端口
	sudo ufw enable # 开启防火墙
	sudo ufw default deny # 默认关闭端口
	sudo ufw status # 查看防火墙状态
"

