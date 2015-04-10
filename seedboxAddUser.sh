#!/bin/bash

PORT=5000
PORTR=55000
RPC=1
REALM="Authorized users only"

if [ "$#" -ne 2 ]; then
	echo "Usage: $0 username drive"
	exit 1
fi

if [ ! -b "$2" ]; then
	echo "Requires drive name!"
	exit 1
fi

if [ -d "/home/$1" ]; then
	echo "User $1 already exists"
	exit 1
fi

echo -n "Creating Partition..."
echo -e "o\nn\np\n1\n\n\nw" | sudo fdisk $2
mke2fs -t ext4 $2"1"
echo $2"1 /home/$1 ext4 defaults 0 0" >> /etc/fstab
mkdir /home/$1
mount -a
echo "Done"

echo -n "Creating local user..."
password=`tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -1`
useradd -d /home/$1 -s /bin/bash -p $(openssl passwd -1 $password) $1
echo "Done"

echo -n "Creating user directories..."
rmdir "/home/$1/lost+found"
mkdir /home/$1/{downloads,.session,watch}
RANGE="$PORTR-$(expr $PORTR + 4)"
sed -e "s/<user>/$1/" -e "s/<port_range>/$RANGE/" -e "s/<scgi_port>/$PORT/" rtorrent.rc.template > /home/$1/.rtorrent.rc
chown -R $1:$1 /home/$1
echo "Done"

echo -n "Creating web user..."
(echo -n "$1:$REALM:" && echo -n "$1:$REALM:$password" | md5sum - | cut -d' ' -f1) >> /etc/lighttpd/.passwd
echo "Done"

echo -n "Doing web config for user..."
mkdir /var/www/rutorrent/conf/users/$1
cp /var/www/rutorrent/conf/access.ini /var/www/rutorrent/conf/users/$1/access.ini
cp /var/www/rutorrent/conf/plugins.ini /var/www/rutorrent/conf/users/$1/plugins.ini
n=$(printf %03d $RPC)
sed -e "s/<user>/$1/" -e "s/<port>/$PORT/" -e "s/<rpc>/$n/" config.php.template > /var/www/rutorrent/conf/users/$1/config.php
echo "Done"

echo -n "Saving user to txt..."
echo "$1:$password" >> /root/users.txt
echo "Done"

clear
echo -e "User Details:\nusername: $1\npassword: $password"
