#!/bin/bash

[ -x "$0" -a "$0" != "bash" ] && {
	scp_dir="$(dirname "$(readlink -f "$0")")"
	[ "$(ls "$scp_dir/shell_common")" ] && [ "$(ls "$scp_dir/script")" ]
} && {
	IFS='' read -r -d '' checkcmd_install < "$scp_dir/shell_common/checkcmd_install.sh"
	IFS='' read -r -d '' awk_conf < "$scp_dir/shell_common/awk_conf.sh"
	IFS='' read -r -d '' mailu_setup_mailu < "$scp_dir/script/mailu/setup_mailu.py"
	IFS='' read -r -d '' nginx_http_mailu_acme < "$scp_dir/script/nginx/http_mailu_acme.conf"
true;} || {
	checkcmd_install="$(wget -qO- https://github.com/756yang/shell_common/raw/main/checkcmd_install.sh)"
	awk_conf="$(wget -qO- https://github.com/756yang/shell_common/raw/main/awk_conf.sh)"
	mailu_setup_mailu="$(wget -qO- https://github.com/756yang/my_debian_server_config/raw/main/script/mailu/setup_mailu.py)"
	nginx_http_mailu_acme="$(wget -qO- https://github.com/756yang/my_debian_server_config/raw/main/script/nginx/http_mailu_acme.conf)"
}

bash -c "$checkcmd_install" @ ssh sshpass openssl grep "gawk|awk" sed xargs find sponge tar gzip python3 pip3
[ $? -ne 0 ] && exit 1

# Selenium环境安装
{ python3 -m pip list | grep selenium &>/dev/null;} || {
	if { cat /proc/version | grep -E "MINGW|MSYS" &>/dev/null;}; then
		python3 -m pip install selenium
	elif { cat /proc/version | grep "Debian 12" &>/dev/null;}; then
		sudo apt install python3-selenium
	else
		echo "No support Selenium installed, please manual install it."
		exit 1
	fi
}

read -p "please input you server address:port ? " myserver
read -p "please input you server username:password ? " username
[[ "$myserver" =~ ":" ]] && mysshport="${myserver##*:}" && myserver="${myserver%:*}"
[ -z "$mysshport" ] && mysshport=22
[[ "$username" =~ ":" ]] && mypassword="${username#*:}" && username="${username%%:*}"
[ -n "$mypassword" ] && sshcmd='sshpass -p "'"$mypassword"'" ssh' || sshcmd=ssh

IFS='' read -r -d '' SSH_COMMAND <<EOT
function checkcmd_install { $checkcmd_install }
# which.debianutils 检查是否Debian系统，仅支持Debian
checkcmd_install which.debianutils curl sed grep "gawk|awk" sponge
EOT
eval "$sshcmd" $username@$myserver -p $mysshport -t '"$SSH_COMMAND"'
[ $? -ne 0 ] && exit 1


echo "please input your server_domain:"
server_domain=`code_decrypt C8CzPgrRq++AcGs=`
echo "please input your mail_site_name:"
mail_site_name=`code_decrypt Nci7PF7Wq7PUTHKzva7R3A==`
echo "please input your mail_admin_pass:"
mail_admin_pass=`code_decrypt Fci7PCHpjJihVUI=`
mail_public_ip=$($sshcmd $username@$myserver -p $mysshport "curl ifconfig.me 2>/dev/null")
mailu_setup_mailu="$(echo -n "$mailu_setup_mailu" | sed 's/\$server_domain/'$server_domain'/g'\
		| sed 's/\$mail_site_name/'$mail_site_name'/g'\
		| sed 's/\$mail_public_ip/'$mail_public_ip'/g'\
		| sed 's/\$username/'$username'/g')"
mailu_config_cmd="$(python3 -c "$mailu_setup_mailu")"

IFS='' read -r -d '' SSH_COMMANDS <<"EOT"
# 检查 docker compose 并尝试安装
docker compose version &>/dev/null || {
	# Uninstall all conflicting packages:
	for pkg in docker.io docker-doc docker-compose podman-docker containerd runc
	do
		{ dpkg -l | grep $pkg &>/dev/null;} && sudo apt-get remove $pkg
	done

	# Add Docker's official GPG key:
	sudo apt-get update
	sudo apt-get install ca-certificates curl gnupg
	sudo install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	sudo chmod a+r /etc/apt/keyrings/docker.gpg

	# Add the repository to Apt sources:
	echo \
	  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
	  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
	  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update

	# Install the latest version:
	sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

EOT

IFS='' read -r -d '' SSH_COMMAND <<EOT
# 下载 mailu 配置文件
sudo mkdir /mailu
sudo bash -c "$mailu_config_cmd"

EOT
SSH_COMMANDS="$SSH_COMMANDS""$SSH_COMMAND"

IFS='' read -r -d '' SSH_COMMAND <<EOT
# 自动编辑 mailu 配置文件
sudo sed -i 's/$mail_public_ip:80:80/127.0.0.1:8080:80/' /mailu/docker-compose.yml
sudo sed -i 's/$mail_public_ip:443:443/127.0.0.1:8443:443/' /mailu/docker-compose.yml
subnet_ip="\$(cat /mailu/mailu.env | grep 'SUBNET=')"
subnet_ip=\${subnet_ip#*=}
subnet_ip=\${subnet_ip%.*}.1
function awk_conf { $awk_conf }
cat /mailu/mailu.env | awk_conf "REAL_IP_HEADER="\\
		"PROXY_PROTOCOL=http"\\
		"REAL_IP_FROM=$mail_public_ip,""\$subnet_ip" | sudo sponge /mailu/mailu.env

# 自动编辑 nginx_sni 分流配置
cat /etc/nginx/modules-enabled/stream_sni_proxy.conf | awk 'BEGIN{sni_stream=0} {
	print \$0;
	if(sni_stream==0)
		if(match(\$0,"[ \t]?stream {"))sni_stream=1;
	else if(sni_stream==1){
		if(match(\$0,"[ \t]?map \$ssl_preread_server_name \$backend_name {")){
			sni_stream=2;
			printf("\t\tmail.$server_domain mailu;\n");
		}
	}
	else if(sni_stream==2){
		if(match(\$0,"^[ \t]*}")){
			sni_stream=3;
			printf("\tupstream mailu {\n\t\tserver 127.0.0.1:8443;\n\t}\n");
		}
	}
}' | sudo sponge /etc/nginx/modules-enabled/stream_sni_proxy.conf

EOT
SSH_COMMANDS="$SSH_COMMANDS""$SSH_COMMAND"

# 配置mailu申请证书通路
eval "$nginx_http_mailu_acme"

IFS='' read -r -d '' SSH_COMMAND <<EOT
# 安装 mailu 并设置密码
cd /mailu
sudo docker compose -p mailu up -d
sudo docker compose -p mailu exec admin flask mailu admin $username $server_domain $mail_admin_pass

EOT
SSH_COMMANDS="$SSH_COMMANDS""$SSH_COMMAND"

eval "$sshcmd" $username@$myserver -p $mysshport -t '"$SSH_COMMANDS"'


