#!/bin/bash

[ -x "$0" -a "$0" != "bash" ] && {
	scp_dir="$(dirname "$(readlink -f "$0")")"
	[ "$(ls "$scp_dir/shell_common")" ]
} && {
	IFS='' read -r -d '' checkcmd_install < "$scp_dir/shell_common/checkcmd_install.sh"
	true # read命令读取文件退出状态是1，表示遇到了EOF
} || {
	checkcmd_install="$(wget -qO- https://github.com/756yang/shell_common/raw/main/checkcmd_install.sh)"
}

bash -c "$checkcmd_install" @ ssh sshpass grep "gawk|awk"
[ $? -ne 0 ] && exit 1

:<<"EOT"
{ cat /proc/version | grep -E "MINGW|MSYS" &>/dev/null;} && {
	# 安装nmap程序
	wget https://nmap.org/dist/nmap-7.92-win32.zip &&\
	unzip nmap-7.92-win32.zip -d / &&\
	rm nmap-7.92-win32.zip &&\
	printf '#/bin/bash\n/nmap-7.92/nmap.exe "$@"\n' > /usr/bin/nmap
} || bash -c "$checkcmd_install" @ nmap
[ $? -ne 0 ] && exit 1
EOT

# sshcmd='sshpass -p "xxx" ssh'
# 直接用 $sshcmd 调用命令会出现异常，会传入带引号的参数导致密码输入不正确
# 应该使用 eval $sshcmd 调用命令，或者不要带引号的参数

# 不使用 eval $sshcmd 避免 "$SSH_COMMAND" 参数会被eval解析
# 或者 "$SSH_COMMAND" 参数修改为 '"$SSH_COMMAND"' 就能正确被eval解析
read -p "please input you server address:port ? " myserver
read -p "please input you server username:password ? " username
[[ "$myserver" =~ ":" ]] && mysshport="${myserver##*:}" && myserver="${myserver%:*}"
[ -z "$mysshport" ] && mysshport=22
[[ "$username" =~ ":" ]] && mypassword="${username#*:}" && username="${username%%:*}"
[ -n "$mypassword" ] && sshcmd='sshpass -p "'"$mypassword"'" ssh' || sshcmd=ssh

IFS='' read -r -d '' SSH_COMMAND <<EOT
function checkcmd_install { $checkcmd_install }
checkcmd_install tar gzip hostname openssl sudo wget sed cpio
EOT
eval "$sshcmd" -p $mysshport $username@$myserver -t '"$SSH_COMMAND"'
[ $? -ne 0 ] && exit 1

# 若tar命令将文件打包输出到终端，会报错：
# tar: Refusing to write archive contents to terminal (missing -f option?)
# 解决此问题的方式是通过管道重定向
IFS='' read -r -d '' SSH_COMMAND <<EOT
tar -cvzf - /etc/hosts\
		/etc/hostname\
		/etc/host.conf\
		/etc/resolv.conf\
		/etc/sysctl.conf
EOT
eval "$sshcmd" -p $mysshport $username@$myserver '"$SSH_COMMAND"' > $myserver.conf.tar.gz

echo "please input install-script extra options (--china to use apt mirrors)? "
read install_options

IFS='' read -r -d '' SSH_COMMAND <<EOT
sudo hostname \$HOSTNAME # 临时修改主机名
sudo domainname \$(hostname -d) # 临时修改主机域
password=\$(openssl rand -base64 9)
sudo bash -c "\$(wget -qO- https://github.com/756yang/debian_vps_reinstall/raw/master/debi.sh)" @ --network-console --version 12 --filesystem btrfs --esp 500 --swap 100% --bbr --user root --password \$password --ethx --ssh-port $mysshport $install_options
echo "root password is: "\$password
sudo reboot
EOT
eval "$sshcmd" -p $mysshport $username@$myserver -t '"$SSH_COMMAND"' | tee $myserver.pass
mypassword=$(cat $myserver.pass | grep "root password is:" | awk '{print $4}')

sleep 120
old_myserver=$myserver
[ -z "$(timeout 5 ssh-keyscan $myserver 2>/dev/null)" ] && {
	read -p "scan ip address or not (N|y)? " addr_ins
	[ "$addr_ins" = y -o "$addr_ins" = Y ] && addr_ins=32 || addr_ins=0
	# 扫描ssh服务器，防止本地虚拟机IP变动而无法连接
	temp_file=$(mktemp)
	myserver_subnet=${myserver%.*}
	myserver_netsub=${myserver##*.}
	while true; do
		(timeout 5 sshpass -p "$mypassword" ssh -o GlobalKnownHostsFile=/dev/null\
			-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no\
			installer@$myserver_subnet.$myserver_netsub exit &>/dev/null &&\
			echo $myserver_subnet.$myserver_netsub
		) &>> "$temp_file" &
		for ((i=1;i<addr_ins;i++)); do
			(timeout 5 sshpass -p "$mypassword" ssh -o GlobalKnownHostsFile=/dev/null\
				-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no\
				installer@$myserver_subnet.$[(myserver_netsub+i)%256] exit &>/dev/null &&\
				echo $myserver_subnet.$[(myserver_netsub+i)%256]
			) &>> "$temp_file" &
		done
		wait
		[ $(stat -c "%s" "$temp_file") -ne 0 ] && break
		myserver_netsub=$[(myserver_netsub+addr_ins)%256]
	done
	myserver=$(head -n 1 "$temp_file")
	rm "$temp_file"
}
echo "login installer, press 'Ctrl+A' and then press '4' to monitor installation logs."
sshpass -p "$mypassword" ssh -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null\
		-o StrictHostKeyChecking=no installer@$myserver
sleep 20
[ -z "$(timeout 5 ssh-keyscan -p $mysshport $myserver 2>/dev/null)" ] && {
	read -p "scan ip address or not (N|y)? " addr_ins
	[ "$addr_ins" = y -o "$addr_ins" = Y ] && addr_ins=32 || addr_ins=0
	# 扫描ssh服务器，防止本地虚拟机IP变动而无法连接
	temp_file=$(mktemp)
	myserver_subnet=${myserver%.*}
	myserver_netsub=${myserver##*.}
	while true; do
		(timeout 5 sshpass -p "$mypassword" ssh -o GlobalKnownHostsFile=/dev/null\
			-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no\
			-p $mysshport root@$myserver_subnet.$myserver_netsub exit &>/dev/null &&\
			echo $myserver_subnet.$myserver_netsub
		) &>> "$temp_file" &
		for ((i=1;i<addr_ins;i++)); do
			(timeout 5 sshpass -p "$mypassword" ssh -o GlobalKnownHostsFile=/dev/null\
				-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no\
				-p $mysshport root@$myserver_subnet.$[(myserver_netsub+i)%256] exit &>/dev/null &&\
				echo $myserver_subnet.$[(myserver_netsub+i)%256]
			) &>> "$temp_file" &
		done
		wait
		[ $(stat -c "%s" "$temp_file") -ne 0 ] && break
		myserver_netsub=$[(myserver_netsub+addr_ins)%256]
	done
	myserver=$(head -n 1 "$temp_file")
	rm "$temp_file"
}
[ $mysshport -eq 22 ] && ssh-keygen -R $myserver || ssh-keygen -R "[$myserver]:$mysshport"
ssh-keyscan -p $mysshport $myserver 2>/dev/null | head -n 1 >> ~/.ssh/known_hosts
sshpass -p "$mypassword" scp -P $mysshport $old_myserver.conf.tar.gz root@$myserver:~/

IFS='' read -r -d '' SSH_COMMANDS <<EOT
tar -cvzf $myserver.conf.tgz /etc/hosts\
		/etc/hostname\
		/etc/host.conf\
		/etc/resolv.conf\
		/etc/sysctl.conf
tar -xvzf $old_myserver.conf.tar.gz -C /
rm $old_myserver.conf.tar.gz

EOT

echo "please input mount option for root filesystem (y to set compress=zstd:1)? "
read mount_options
[ -n "$mount_options" ] && {
	[ "$mount_options" = y -o "$mount_options" = Y ] && mount_options="compress=zstd:1"
	IFS='' read -r -d '' SSH_COMMAND <<EOT
sed -i 's!\\(/[ \\t][ \\t]*btrfs[ \\t][ \\t]*\\)defaults!\\1$mount_options!' /etc/fstab

EOT
	SSH_COMMANDS="$SSH_COMMANDS""$SSH_COMMAND"
}

IFS='' read -r -d '' SSH_COMMAND <<EOT
reboot
EOT
SSH_COMMANDS="$SSH_COMMANDS""$SSH_COMMAND"

sshpass -p "$mypassword" ssh root@$myserver -p $mysshport "$SSH_COMMANDS"

sleep 10
while true; do
	[ -n "$(timeout 5 ssh-keyscan -p $mysshport $myserver 2>/dev/null)" ] && break
done
if { echo "$mount_options" | grep compress &>/dev/null;}; then
	compress_options="${mount_options#*compress=}"
	compress_options="${compress_options%%[:,]*}"
	# 重新压缩根文件系统
	sshpass -p "$mypassword" ssh root@$myserver -p $mysshport -t\
		"btrfs filesystem defragment -r -c$compress_options /"
fi

[ "$old_myserver" != "$myserver" ] && {
	printf "You server address ip was changed! %s to %s\n" $old_myserver $myserver
	echo "If you want to keep the old IP address, edit"\
		"/var/lib/dhcp/dhclient.eth0.leases and reset the dhcp service address pool."
}

echo "Server Reinstall Completed!"
