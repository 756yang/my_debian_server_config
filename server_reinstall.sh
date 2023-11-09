#!/bin/bash

[ -x "$0" -a "$0" != "bash" ] && {
	IFS='' read -r -d '' checkcmd_install < "$(dirname "$(readlink -f "$0")")/shell_common/checkcmd_install.sh"
} || {
	checkcmd_install="$(wget -qO- https://github.com/756yang/shell_common/raw/main/checkcmd_install.sh)"
}

bash -c "$checkcmd_install" @ ssh sshpass grep "gawk|awk"
[ $? -ne 0 ] && exit 1

read -p "please input you server address:port ? " myserver
read -p "please input you server username:password ? " username
mysshport=${myserver##*:}
myserver=${myserver%:*}
[[ "$username" =~ ":" ]] && mypassword="${username#*:}" && username="${username%%:*}"
[ -n "mypassword" ] && sshcmd='sshpass -p "'$mypassword'" ssh' || sshcmd=ssh

IFS='' read -r -d '' SSH_COMMAND <<EOT
function checkcmd_install {$checkcmd_install}
checkcmd_install tar gzip hostname openssl sudo wget sed cpio
EOT
$sshcmd $username@$myserver -p $mysshport -t "$SSH_COMMAND"
[ $? -ne 0 ] && exit 1

$sshcmd $username@$myserver -p $mysshport "
	cd / && tar -cvzf - /etc/hosts\
			/etc/host.conf\
			/etc/resolv.conf\
			/etc/sysctl.conf
" | cat > $myserver.conf.tar.gz

IFS='' read -r -d '' SSH_COMMAND <<"EOT"
hostname $HOSTNAME # 临时修改主机名
domainname $(hostname -d) # 临时修改主机域
password=$(openssl rand -base64 9)
sudo bash -c "$(wget -qO- https://github.com/756yang/debian_vps_reinstall/raw/master/debi.sh)" @ --network-console --version 12 --filesystem btrfs --esp 500 --swap 100% --bbr --user root --password $password --ethx
echo "root password is: "$password
sudo reboot
EOT
$sshcmd $username@$myserver -p $mysshport -t "$SSH_COMMAND" | tee $myserver.pass
mypassword=$(cat $myserver.pass | grep "root password is:" | awk '{print $4}')

sleep 300
sshpass -p "$mypassword" scp -P $mysshport $myserver.conf.tar.gz root@$myserver:~/
sshpass -p "$mypassword" ssh root@$myserver -p $mysshport "tar -xvzf $myserver.conf.tar.gz -C / && reboot"
