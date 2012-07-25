#!/bin/bash
# install.sh
# This script installs zmbkpose on a ZCS server. It also makes sure
# the script's dependencies are present.
#
# LIMITATIONS: For now this script does NOT customize the zmbkpose config file.
# As such you MUST configure it manually after the install finishes. 
# It also assumes you're doing a local install and requires the user zimbra to exist
# on your server. While not strictly necessary this is enforced due to the way
# the current zmbkpose script works.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# v: 0.1a

# Zmbkpose Defaults - Where the script will be placed and look for its settings
OSE_SRC="/usr/local/bin"
OSE_CONF="/etc/zmbkpose"

# Zimbra Defaults - Change these if you compiled zimbra yourself with different 
# settings
ZIMBRA_USER="zimbra"
ZIMBRA_DIR="/opt/zimbra"

# Exit codes
ERR_OK="0"			# No error (normal exit)
ERR_NOROOT="2"			# Script was run without root privileges
ERR_DEPNOTFOUND="3"		# Missing dependency

clear
echo "This will install zmbkpose, a script aimed at creating backups for ZCS Community Edition."
echo ""
echo "The installer will assume the following conditions are true:"
echo "Zimbra User: $ZIMBRA_USER"
echo "Zimbra Install Directory: $ZIMBRA_DIR"
echo "Zmbkpose Install Directory: $OSE_SRC"
echo "Zmbkpose Settings Directory: $OSE_CONF"
echo ""
echo "Press ENTER to continue or CTRL+C to cancel."
read tmp

# Check if we have root before doing anything
if [ $(id -u) -ne 0 ]; then
	echo "You need root privileges to install zmbkpose"
	exit $ERR_NOROOT
fi

# Check for missing installer files
# TODO: MD5 check of the files
printf "Checking installer integrity...	"
STATUS=0
MYDIR=`dirname $0`
test -f $MYDIR/src/zmbkpose      || STATUS=$ERR_MISSINGFILES
test -f $MYDIR/etc/zmbkpose.conf || STATUS=$ERR_MISSINGFILES
if ! [ $STATUS = 0 ]; then
	printf '[ERROR]\n'
	echo "Some files are missing. Please re-download the Zmbkpose installer."
	exit $STATUS
else
	printf '[OK]\n'
fi

# Check for missing dependencies
STATUS=0
echo "Checking system for dependencies..."

## Zimbra Mailbox
printf "	ZCS Mailbox Control...	"
su - $ZIMBRA_USER -c "which zmmailboxdctl" > /dev/null 2>&1
if [ $? = 0 ]; then
        printf "[OK]\n"
else
        printf "[NOT FOUND]\n"
        STATUS=$ERR_DEPNOTFOUND
fi

## LDAP utils
printf "	ldapsearch...	"
su - $ZIMBRA_USER -c "which ldapsearch" > /dev/null 2>&1
if [ $? = 0 ]; then
	printf "[OK]\n"
else
	printf "[NOT FOUND]\n"
	STATUS=$ERR_DEPNOTFOUND
fi

## Curl
printf "	curl...		"
su - $ZIMBRA_USER -c "which curl" > /dev/null 2>&1
if [ $? = 0 ]; then
        printf "[OK]\n"
else
        printf "[NOT FOUND]\n"
        STATUS=$ERR_DEPNOTFOUND
fi

## mktemp
printf "	mktemp...	"
su - $ZIMBRA_USER -c "which mktemp" > /dev/null 2>&1
if [ $? = 0 ]; then
        printf "[OK]\n"
else
        printf "[NOT FOUND]\n"
        STATUS=$ERR_DEPNOTFOUND
fi

## date
printf "	date...		"
su - $ZIMBRA_USER -c "which date" > /dev/null 2>&1
if [ $? = 0 ]; then
        printf "[OK]\n"
else
        printf "[NOT FOUND]\n"
        STATUS=$ERR_DEPNOTFOUND
fi

## egrep
printf "	egrep...	"
su - $ZIMBRA_USER -c "which egrep" > /dev/null 2>&1
if [ $? = 0 ]; then
        printf "[OK]\n"
else
        printf "[NOT FOUND]\n"
        STATUS=$ERR_DEPNOTFOUND
fi

if ! [ $STATUS = 0 ]; then
	echo ""
	echo "You're missing some dependencies OR they are not on $ZIMBRA_USER's PATH."
	echo "Please correct the problem and run the installer again."
	exit $STATUS
fi
# Done checking deps

echo "Installing..."

# Create directories if needed
test -d $OSE_CONF || mkdir -p $OSE_CONF
test -d $OSE_SRC  || mkdir -p $OSE_SRC

# Copy files
install -o $ZIMBRA_USER -m 755 $MYDIR/src/zmbkpose $OSE_SRC
install --backup=numbered -o $ZIMBRA_USER -m 644 $MYDIR/etc/zmbkpose.conf $OSE_CONF

read -p "Install completed. Do you want to display the README file? (Y/n)" tmp
case "$tmp" in
	y|Y|Yes|"") less $MYDIR/README
	*) echo "Done!"
esac

exit $ERR_OK
