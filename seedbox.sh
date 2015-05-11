#!/bin/bash

### Only for Ubuntu 14.04 amd64 ###

if [ "$(whoami)" != "root" ]; then
	echo "Sorry, you are not root. Cannot run it!"
	exit 1
fi

work_dir="/tmp"
libtorrent_deb="https://raw.githubusercontent.com/yash069/rtorrent-cookbook/master/files/default/libtorrent_0.13.4-1_amd64.deb"
rtorrent_deb="https://raw.githubusercontent.com/yash069/rtorrent-cookbook/master/files/default/rtorrent_0.9.4-1_amd64.deb"
xmlrpc_deb="https://raw.githubusercontent.com/yash069/rtorrent-cookbook/master/files/default/xmlrpc-c_1.33.14-1_amd64.deb"
winrar_tar="http://www.rarlab.com/rar/rarlinux-x64-5.2.1.tar.gz"
rutorrent="https://bintray.com/artifact/download/novik65/generic/rutorrent-3.6.tar.gz"
rutorrent_plugins="https://bintray.com/artifact/download/novik65/generic/plugins-3.6.tar.gz"

spinner(){
    local pid=$1
    local delay=0.25
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

update_apt(){
	apt-get update &>> /dev/null
}

install_php(){
	apt-get -y install php5-cli php5-fpm php5-curl &>> /dev/null
	sed -i "s/;cgi.fix_pathinfo=0/cgi.fix_pathinfo=1/g" /etc/php5/fpm/php.ini
	sed -i "s/expose_php = On/expose_php = Off/g" /etc/php5/fpm/php.ini
}

install_lighttpd(){
	apt-get -y install lighttpd &>> /dev/null
	cp /etc/lighttpd/conf-available/15-fastcgi-php.conf /etc/lighttpd/conf-available/15-fastcgi-php-spawnfcgi.conf
	sed -i '/"bin-path" => "\/usr\/bin\/php-cgi",/d' /etc/lighttpd/conf-available/15-fastcgi-php.conf
	sed -i 's/lighttpd\/php.socket/php5-fpm.sock/g' /etc/lighttpd/conf-available/15-fastcgi-php.conf

	cat >> /etc/lighttpd/lighttpd.conf <<END
auth.backend = "htdigest"
auth.backend.htdigest.userfile = "/etc/lighttpd/.passwd"
auth.debug = 2
auth.require = ( "/rutorrent" =>
(
	"method" => "digest",
	"realm" => "Authorized users only",
	"require" => "valid-user"
)
)
END

	cat >> /var/www/index.html <<END
<!-- YaSH069 ruTorrent Script -->
<html>
 <head>
  <title>IndeX</title>
 </head>
 <body>
  <h2>Go do something productive!</h2>
 </body>
</html>
END
	lighttpd-enable-mod auth > /dev/null
	lighttpd-enable-mod fastcgi > /dev/null
	lighttpd-enable-mod fastcgi-php > /dev/null
}

download_package(){
	apt-get -y install curl > /dev/null
	cd $work_dir
	curl -ss -O $libtorrent_deb
	curl -ss -O $rtorrent_deb
	curl -ss -O $xmlrpc_deb
	curl -ss -O $winrar_tar
	wget --quiet $rutorrent
	wget --quiet $rutorrent_plugins
}

install_depends(){
	apt-get -y install zip libav-tools mediainfo subversion &>> /dev/null
	ln -s /usr/bin/avconv /usr/bin/ffmpeg
	tar -xf $work_dir/rarlinux-x64-5.2.1.tar.gz -C /usr/local/bin --overwrite --strip-components 1 rar/rar rar/unrar
}

install_rtorrent(){
	dpkg -i $work_dir/xmlrpc-c_1.33.14-1_amd64.deb > /dev/null
	dpkg -i $work_dir/libtorrent_0.13.4-1_amd64.deb > /dev/null
	dpkg -i $work_dir/rtorrent_0.9.4-1_amd64.deb > /dev/null
	ldconfig
}

install_rutorrent(){
	tar -xf $work_dir/rutorrent-3.6.tar.gz -C /var/www/
	tar -xf $work_dir/plugins-3.6.tar.gz -C /var/www/rutorrent
	svn -q co http://svn.rutorrent.org/svn/filemanager/trunk/filemanager/ /var/www/rutorrent/plugins/filemanager/
	cat > /var/www/rutorrent/plugins/filemanager/conf.php <<END
<?php
$fm['tempdir'] = '/tmp'; // path were to store temporary data ; must be writable
$fm['mkdperm'] = 755; // default permission to set to new created directories
// set with fullpath to binary or leave empty
$pathToExternals['rar'] = '/usr/local/bin/rar';
$pathToExternals['zip'] = '/usr/bin/zip';
$pathToExternals['unzip'] = '/usr/bin/unzip';
$pathToExternals['tar'] = '/bin/tar';
$pathToExternals['gzip'] = '/bin/gzip';
$pathToExternals['bzip2'] = '/bin/bzip2';
// archive mangling, see archiver man page before editing
$fm['archive']['types'] = array('rar', 'zip', 'tar', 'gzip', 'bzip2');
$fm['archive']['compress'][0] = range(0, 5);
$fm['archive']['compress'][1] = array('-0', '-1', '-9');
$fm['archive']['compress'][2] = $fm['archive']['compress'][3] = $fm['archive']['compress'][4] = array(0);
?>
END
}

install_vsftpd(){
	apt-get -y install vsftpd &>> /dev/null
	cat > /etc/vsftpd.conf <<END
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
xferlog_file=/var/log/vsftpd.log
connect_from_port_20=YES
idle_session_timeout=300
ftpd_banner=FTP
chroot_local_user=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=ftp
hide_file={.*}
allow_writeable_chroot=YES
pasv_enable=YES
pasv_max_port=27600
pasv_min_port=27200
END
}

restart_services(){
	service php5-fpm restart
	service lighttpd restart
	service vsftpd restart
}

echo -n "Updating Repo..."
update_apt & spinner $!
echo "Done"

echo -n "Installing PHP..."
install_php & spinner $!
echo "Done"

echo -n "Installing lighttpd..."
install_lighttpd & spinner $!
echo "Done"

echo -n "Downloading necessary packages..."
download_package & spinner $!
echo "Done"

echo -n "Downloading necessary dependencies..."
install_depends & spinner $!
echo "Done"

echo -n "Installing rtorrent..."
install_rtorrent & spinner $!
echo "Done"

echo -n "Installing ruTorrent..."
install_rutorrent & spinner $!
echo "Done"

echo -n "Installing vsftpd..."
install_vsftpd & spinner $!
echo "Done"

echo -n "Restarting services..."
(restart_services > /dev/null) & spinner $!
echo "Done"

