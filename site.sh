#!/bin/bash

# Load command prompt params
name=$1
repo=$2
db=$3
archive=$4

# Clone LAMP stack
git clone https://github.com/r8/vagrant-lamp.git

# Rename LAMP stack to project name
mv vagrant-lamp "$name"

# Move into project directory
cd "$name"

# Start Vagrant
vagrant up

# Move into public HTML folder
cd public/local.dev

# Delete default files
rm -rf *
rm .htaccess
rm .gitignore

# Initialize Git
git init

# Download the files archive
curl "$archive" > archive.tar.gz

# Unarchive the file
tar zxf archive.tar.gz

# Move the files into position
mv archive/* ./

# Delete downloaded archive
rm -rf archive
rm archive.tar.gz

# Add site repo as origin
git remote add origin "$repo"

# Pull master branch of repo
git pull origin master

# Move out to public 
cd ../..

# Download database
curl "$db" > database.sql

# Upload database into MySQL
vagrant ssh <<EOF
mysql --user=root --password=vagrant < /vagrant/database.sql
EOF