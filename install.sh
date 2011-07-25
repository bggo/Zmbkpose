#!/bin/bash

# Simple install script

CONF=/etc/zmbkpose/
SRC=/usr/local/bin/


check_root() {
if [ $(id -u) -ne 0 ];then
	echo "To install zmbkpose you need to have root privileges"
	exit 2
fi
}


check_exist() {

if [ -d $DIR ];then
	echo "$DIR - Ok"
else
	echo "$DIR not found, creating"
	mkdir -p $DIR
fi

}


copy_files() {

echo "cp $DIR/* $DEST"
cp $DIR/* $DEST

}

exec_perm() {

echo "chmod +x $FILE"
chmod +x $FILE

}
### Main

check_root

DIR=$SRC
check_exist

DIR=$CONF
check_exist 

####### Coping sourcecode

DIR=src
DEST=$SRC
copy_files

DIR=etc
DEST=$CONF
copy_files

######## Perm

FILE=${SRC}zmbkpose
exec_perm




