#!/bin/bash
 
# TODO
# 1. Add Drush support on staging side export

# Load command prompt params
name=$1
site_type=$2
repo=$3
staging_user=$4
staging_host=$5
staging_path=$6
staging_mysql_user=$7
staging_mysql_db=$8
staging_mysql_pw=$9
staging_mysql_host=${10}

echo "Building vagrant site:

      /|\     \\\\     //=\\
     // \\\\      \\\\  //
    //___\|    _||__||__  __   _  _  __
   //----||  // ||--||-  -_/   ||/  /  \\
  //     ||  \\\\_// ||    \__/ |/    \__/
                  ||
                 ||
                _/

================================================================================
Name:			${name}
Type:			${site_type}
Stating User:		${staging_user}
Staging Host:		${staging_host}
Staging Path:		${staging_path}
Staging MySQL User: 	${staging_mysql_user}
Staging MySQL DB:	${staging_mysql_db}
Staging MySQL PW:	${staging_mysql_pw}
Staging MySQL Host: 	${staging_mysql_host}
================================================================================
"

echo -n "Starting in ...  "
i=3
while [ $i -gt 0 ]; do
	echo -n -e "\b$i"
	sleep 1
	i=$((i-1))
done

echo

#if false; then

echo "Cloning Vagrant LAMP stack"
git clone https://github.com/r8/vagrant-lamp.git #> /dev/null

# Renaming LAMP stack to project name
mv vagrant-lamp "$name"

# Move into project directory
cd "$name"



echo "Setting up Vagrant"
vagrant up #> /dev/null

# Move into public HTML folder
cd public/local.dev

# Delete default files
rm -rf *
rm .htaccess
rm .gitignore



echo "Cloning the site into Vagrant"

# Initialize Git
git init

# Add site repo as origin
git remote add origin "$repo"

# Pull master branch of repo
git pull origin master



echo "Downloading the staging DB"

# Move out to public 
cd ../..

# Export database on staging
ssh "${staging_user}"@"${staging_host}" <<EOF
	mysqldump --user="${staging_mysql_user}" --password="${staging_mysql_pw}" --host="${staging_mysql_host}" ${staging_mysql_db} > /tmp/database.sql
	exit
EOF

# Download database from staging
sftp "${staging_user}"@"${staging_host}" <<EOF
	get /tmp/database.sql
	rm /tmp/database.sql
	quit
EOF



echo "Importing the staging DB"

# Replace the staging hostname with the local hostname
php <<EOF
	<?php
	\$path = 'public/database.sql';
	\$sql = file_get_contents(\$path);
	\$sql = str_replace(${staging_host},'local.dev',\$sql);
	file_put_contents(\$path,\$sql);
EOF

# Upload database into MySQL
vagrant ssh <<EOF
	mysql --user=root --password=vagrant <<EOG 
	drop schema if exists dev;
	create schema dev;
EOG
	mysql --user=root --password=vagrant dev < /vagrant/database.sql
	exit
EOF



echo "Setting up the configuration files"

cd public/local.dev

if [ "$site_type" == "drupal" ]; then
	rm sites/default/settings.php
	cp sites/default/default.settings.php sites/default/settings.php
	echo "\$databases = array('default' => array ('default' => array ('database' => 'dev', 'username' => 'root', 'password' => 'vagrant', 'host' => 'localhost', 'port' => '', 'driver' => 'mysql', 'prefix' => '', ), ), );" >> sites/default/settings.php
elif [ "$site_type" == "wordpress" ]; then
	rm wp-config.php
	cp wp-config-sample.php wp-config.php
	cat wp-config.php | sed -e "s/database_name_here/dev/g" > wp-config.php
	cat wp-config.php | sed -e "s/username_here/root/g" > wp-config.php
	cat wp-config.php | sed -e "s/password_here/vagrant/g" > wp-config.php
fi



#echo "Setting up the drush aliases file"

#exit

# cat <<EOF > /usr/share/php/drush/aliases.drushrc.php
# <?php
# \$aliases["staging"] = array (
# 	'uri' => '$staging_host',
# 	'root' => '$staging_path',
# 	'remote-host' => '$staging_host',
# 	'remote-user' => '$staging_user',
# 	'path-aliases' => array (
# 		'%drush' => '/usr/share/php/drush/',
# 		'%site' => '/vagrant/public/local.dev/'
# 	),
# 	'databases' => array (
# 		'default' => array (
# 			'default' => array (
# 				'driver' => 'mysql',
# 				'username' => '$staging_mysql_user',
# 				'password' => '$staging_mysql_pw',
# 				'port' => '',
# 				'host' => '$staging_mysql_host',
# 				'database' => '$staging_mysql_db'
# 			)
# 		)
# 	)
# );
# \$aliases["dev"] = array (
# 	'uri' => 'local.dev',
# 	'root' => '/vagrant/public/local.dev/'
# 	'#name' => 'local',
# );
# ?>
# EOF
