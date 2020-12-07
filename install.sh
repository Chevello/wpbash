#!/bin/bash
# Credit: 
# Lee Wayward @ https://gitlab.com/thecloudorguk/server_install/ 
# Jeffrey B. Murphy @ https://www.jbmurphy.com/2015/10/29/bash-script-to-change-the-security-keys-and-salts-in-a-wp-config-php-file/
# https://gulshankumar.net/install-wordpress-with-lemp-on-ubuntu-18-04/
#
# Instruction
# Run the following commands 
# sudo chmod +x install.sh
# sudo ./install.sh
#
clear
echo "Please provide your 
name without the www. (e.g. mydomain.com)"
read -p "Type your domain name, then press [ENTER] : " MY_DOMAIN
echo "Please provide a name for the DATABASE"
read -p "Type your database name, then press [ENTER] : " dbname
echo "Please provide a DATABASE username"
read -p "Type your database username, then press [ENTER] : " dbuser


#echo $MY_DOMAIN
#echo $dbname
#echo $dbuser
read -t 30 -p "Thank you. Please press [ENTER] continue or [Control]+[C] to cancel"


#Add repositories
sudo apt-get update
sudo apt-get install -y software-properties-common
sudo add-apt-repository universe
#Add MariaDB Repository with the latest MariaDB version
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash

DEBIAN_FRONTEND=noninteractive sudo apt-get update && sudo apt upgrade -y && sudo apt dist-upgrade && sudo apt autoclean && sudo apt autoremove -y 

#Install nginx and php7.4 on Ubuntu 20.04 LTS
apt install -y nginx nginx-extras 
apt install -y php-fpm php-mysql php-intl php-xml php-xmlrpc libphp-phpmailer php-mbstring php-common php-curl php-pear php-gd php-zip php-dev php-soap php-mbstring libpcre2-dev zlib1g-dev php libapache2-mod-php

SERVERIP=$(curl https://ipinfo.io/ip)

#----------------------------------------------------------------

service nginx restart && systemctl restart php7.4-fpm.service 

echo "Installing MariaDB"
sudo apt-get install mariadb-server galera-4 mariadb-client libmariadb3 mariadb-backup mariadb-common expect -y
CURRENT_MYSQL_PASSWORD='PASS'
NEW_MYSQL_PASSWORD=$(openssl rand -base64 29 | tr -d "=+/" | cut -c1-25)

#Secure MariaDB with mysql_secure_installation
SECURE_MYSQL=$(sudo expect -c "
set timeout 3
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"\r\"
expect \"Switch to unix_socket authentication \"
send \"n\r\"
expect \"Change the root password?\"
send \"y\r\"
expect \"New password:\"
send \"$NEW_MYSQL_PASSWORD\r\"
expect \"Re-enter new password:\"
send \"$NEW_MYSQL_PASSWORD\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")
echo "${SECURE_MYSQL}"

#Install PHPMyAdmin
sudo apt-get install phpmyadmin -y

# Create WordPress MySQL database
userpass=$(openssl rand -base64 29 | tr -d "=+/" | cut -c1-25) #creates random pass
echo "CREATE DATABASE $dbname;" | sudo mysql -u root -p$NEW_MYSQL_PASSWORD
echo "CREATE USER '$dbuser'@'localhost' IDENTIFIED BY '$userpass';" | sudo mysql -u root -p$NEW_MYSQL_PASSWORD
echo "GRANT ALL PRIVILEGES ON $dbname.* TO '$dbuser'@'localhost';" | sudo mysql -u root -p$NEW_MYSQL_PASSWORD
echo "FLUSH PRIVILEGES;" | sudo mysql -u root -p$NEW_MYSQL_PASSWORD
echo "delete from mysql.user where user='mysql';" | sudo mysql -u root -p$NEW_MYSQL_PASSWORD


#Install WordPress
apt purge expect -y
apt autoremove -y
apt autoclean -y
wget https://wordpress.org/latest.tar.gz
tar xzvf latest.tar.gz
cp ./wordpress/wp-config-sample.php ./wordpress/wp-config.php
mkdir ./wordpress/wp-content/upgrade
mkdir /var/www/html/$MY_DOMAIN
cp -a ./wordpress/. /var/www/html/$MY_DOMAIN
chown -R www-data /var/www/html/$MY_DOMAIN

#Write Permission to group
find /var/www/html/$MY_DOMAIN -type d -exec chmod g+s {} \;
chmod g+w /var/www/html/$MY_DOMAIN/wp-content
chmod -R g+w /var/www/html/$MY_DOMAIN/wp-content/themes
chmod -R g+w /var/www/html/$MY_DOMAIN/wp-content/plugins
clear

#Change wp-config.php data / changes some problems, not needed in this build.
#sed -i '20i//Define Memory Limit' /var/www/html/$MY_DOMAIN/wp-config.php
#sed -i '21idefine('\'WP_MEMORY_LIMIT\'', '\'256M\'');' /var/www/html/$MY_DOMAIN/wp-config.php
#sed -i '22idefine('\'WP_MAX_MEMORY_LIMIT\'', '\'320M\'');' /var/www/html/$MY_DOMAIN/wp-config.php
#sed -i '23i//Disable Theme Editor' /var/www/html/$MY_DOMAIN/wp-config.php
#sed -i '24idefine('\'DISALLOW_FILE_EDIT\'', '\'true\'');' /var/www/html/$MY_DOMAIN/wp-config.php
#sed -i '23i//Disable Theme Editor' /var/www/html/$MY_DOMAIN/wp-config.php
#sed -i '24idefine('\'WP_POST_REVISIONS\'', '\'5\'');' /var/www/html/$MY_DOMAIN/wp-config.php
# -------------------------------------------------------------

# Create temp file for server block for W3TC
echo '' > /var/www/html/$MY_DOMAIN/nginx.conf
service nginx restart
service php7.4-fpm restart
service mysql restart

# Securing System & wp-config
# Reset UFW and enable UFW
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable


#Disable Password SSH login
perl -pi -e "s/PasswordAuthentication yes/PasswordAuthentication no/g" /etc/ssh/sshd_config

# Clean UP Unnecessary WordPress Files
sudo rm -rf /root/wordpress
sudo rm -f latest.tar.gz
sudo rm -f /etc/nginx/sites-available/default
clear

echo "WordPress Installed. Please visit your website to continue setup"
echo
echo
echo "Here are your WordPress MySQL database details!"
echo
echo "Database Name: $dbname"
echo "Database Username: $dbuser"
echo "Database User Password: $userpass"
echo "Your MySQL ROOT Password is: $NEW_MYSQL_PASSWORD"
echo
echo
