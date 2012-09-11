#!/bin/bash -e
# install.sh
# This script installs zmbkpose on your server. It also makes sure
# the script's dependencies are present.
#
# You don't need install zmbkpose on a zimbra server. It's not a requirement.
#
# NOTE: This script try to detect if you are on a zimbra host. It will check
# if zimbra user exist and if it is execute capable of  zmlocalconfig command.
# If a zimbra installation is detected, this script will try to configure zmbkpose
#
#--------------------------------------------------------------------------------
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

# Zmbkpose Defaults - Where the script will be placed and look for its settings
OSE_SRC="/usr/local/bin"
OSE_CONF="/etc/zmbkpose"

# Zimbra Defaults - Change these if you compiled zimbra yourself with different 
# settings
ZIMBRA_USER="zimbra"
ZIMBRA_DIR="/opt/zimbra"
ZMBKPOSE_BKDIR=""		# Leave empty to autodetect
ZIMBRA_HOSTNAME=""		# Leave empty to autodetect
ZIMBRA_ADDRESS=""		# Leave empty to autodetect
ZIMBRA_LDAPPASS=""		# Leave empty to autodetect


# Exit codes
ERR_OK="0"			# No error (normal exit)
ERR_NOBKPDIR="1"		# No backup directory could be found
ERR_NOROOT="2"			# Script was run without root privileges
ERR_DEPNOTFOUND="3"		# Missing dependency
ERR_MISSINGFILES="4"		# Missing files

function error(){ echo "ERROR: $@" ; }

function item_check_msg(){ printf '%-40s...' "$@" ; }

function sub_item_check_msg(){ printf '   %-37s...' "$@" ; }

function read_y_n_question(){
	echo -n "$1 [y/n]: "
	while read -s -n 1 r;do
		[ "$r" = y ]  && echo "[YES]" && return 0
		[ "$r" = n ]  && echo "[NO]" && return 1
	done
}


function we_are_on_a_zimbra_host(){
	if 	! test -d $ZIMBRA_DIR  || \
		! grep -q "^$ZIMBRA_USER:" /etc/passwd || \
		! su - $ZIMBRA_USER -c zmlocalconfig >/dev/null 
	then
		echo false 
	else
		echo true
	fi
}


#Parse arguments
while [ -n "$1" ];do
	case "$1" in
		--zmbkdir) 
			[ -z "$2" ] && error "$1 require a argument value." && exit 1
			ZMBKPOSE_BKDIR="$2"
			shift 2
		;;
		--zmbkuser) 
			[ -z "$2" ] && error "$1 require a argument value." && exit 1
			ZMBKPOSE_USER="$2"
			shift 2
		;;
		--help|-h)
			cat<<-EOF
Zmbkpose installer script :
 install.sh [--zmbkdir dir] [--zmbkuser user]
   --zmbkdir  dir   :Configure "dir" as directory for mailbox backups
   --zmbkuser user  :Configure install permissions for run zmbkpose by "user"
	EOF
			exit $ERR_OK
		;;
		*)
			error "\"$1\" : unknown argument"
			exit 1
		;;
	esac
done

# Check if we have root before doing anything
if [ $(id -u) -ne 0 ]; then
	error "You need root privileges to install zmbkpose"
	exit $ERR_NOROOT
fi

#We are on a zimbra host?
IS_A_ZIMBRA_HOST=$(we_are_on_a_zimbra_host)

# Try to guess missing settings as best as we can
item_check_msg 'Checking zimbra installation'
if $IS_A_ZIMBRA_HOST ;then
	echo '[OK]'
	ZMBKPOSE_USER=$ZIMBRA_USER
	test -z $ZIMBRA_HOSTNAME && \
		ZIMBRA_HOSTNAME=`su - $ZMBKPOSE_USER -c zmhostname`
	test -z $ZIMBRA_ADDRESS  && \
		ZIMBRA_ADDRESS=`grep "\b$ZIMBRA_HOSTNAME\b" /etc/hosts|awk '{print $1}'`
	test -z $ZIMBRA_LDAPDN   && \
		ZIMBRA_LDAPDN=`su - $ZMBKPOSE_USER -c "zmlocalconfig zimbra_ldap_userdn"|awk '{print $3}'`
	test -z $ZIMBRA_LDAPPASS && \
		ZIMBRA_LDAPPASS=`su - $ZMBKPOSE_USER -c "zmlocalconfig -s zimbra_ldap_password"|awk '{print $3}'`
	test -z $ZIMBRA_ADMUSER && \
		ZIMBRA_ADMUSERS=`su - zimbra -c 'zmprov getAllAdminAccounts'`
	if [ -z $ZMBKPOSE_BKDIR ]; then
	  test -d $ZIMBRA_DIR/backup && ZMBKPOSE_BKDIR=$ZIMBRA_DIR/backup
	fi
# No a zimbra host
else 
	echo '[NO]'
	if [ -z $ZMBKPOSE_BKDIR ]; then
		test -d /backup && ZMBKPOSE_BKDIR=/backup
		test -d /opt/backup && ZMBKPOSE_BKDIR=/opt/backup
	fi
fi

# Check user for execute zmbkpose
if [ -z "$ZMBKPOSE_USER" ];then
	error "No user defined for zmbkpose execution. Please use --zmbkuser _user_"
	exit $ERR_NOBKPDIR
fi
if ! grep -q "^$ZMBKPOSE_USER:" /etc/passwd ;then
	error "User \"$ZMBKPOSE_USER\" doesn't exists"
	exit $ERR_NOBKPDIR
fi

#Zmbkpose backup dir check
if [ -z $ZMBKPOSE_BKDIR ]; then
	error "No backup directory could be found!. Please use --zmbkdir _dir_"
	exit $ERR_NOBKPDIR
fi
if [ ! -d $ZMBKPOSE_BKDIR ]; then
	error "Backup directory $ZMBKPOSE_BKDIR does not exists."
	exit $ERR_NOBKPDIR
fi

# Check for missing installer files
# TODO: MD5 check of the files
item_check_msg 'Checking installer integrity'
STATUS=0
MYDIR=`dirname $0`
test -f $MYDIR/src/zmbkpose      || STATUS=$ERR_MISSINGFILES
test -f $MYDIR/etc/zmbkpose.conf || STATUS=$ERR_MISSINGFILES
if ! [ $STATUS = 0 ]; then
	echo '[NO]'
	error "Some files are missing. Please re-download the Zmbkpose installer."
	exit $STATUS
else
	echo '[OK]'
fi

# Check for missing dependencies
STATUS=0
item_check_msg 'Checking system for dependencies...'; echo

## Dependencies:No zimbra dependent
DEPS="awk curl date du egrep find grep ldapadd ldapdelete ldapsearch ln printf rm sed sort tar  uniq readlink"
for dep_cmd in $DEPS;do
	sub_item_check_msg "$dep_cmd"
	if su - $ZMBKPOSE_USER -c "which $dep_cmd" >/dev/null 2>&1 ;then 
		printf "[OK]\n" 
	else 
		printf "[NOT FOUND]\n" 
		STATUS=$ERR_DEPNOTFOUND
	fi
done

## Dependencies: zimbra dependent
if $IS_A_ZIMBRA_HOST ;then
	DEPS=""
	for dep_cmd in $DEPS;do
		sub_item_check_msg "$dep_cmd"
		if su - $ZMBKPOSE_USER -c "which $dep_cmd" >/dev/null 2>&1 ;then 
			printf "[OK]\n" 
		else 
			printf "[NOT FOUND]\n" 
			STATUS=$ERR_DEPNOTFOUND
		fi
	done
fi

## Done checking deps
if ! [ $STATUS = 0 ]; then
	echo ""
	echo "You're missing some dependencies OR they are not on $ZMBKPOSE_USER's PATH."
	echo "Please correct the problem and run the installer again."
	exit $STATUS
fi


# Installing
item_check_msg "Installing"
## Create directories if needed
install -o root -g root -m 755 -d $OSE_CONF
install -o root -g root -m 755 -d $OSE_SRC
## Copy files
install -o $ZMBKPOSE_USER -m 700 $MYDIR/src/zmbkpose $OSE_SRC
install --backup=numbered -o $ZMBKPOSE_USER -m 600 $MYDIR/etc/zmbkpose.conf $OSE_CONF

printf "[OK]\n" 


# Configurable parameters
MANUAL_PARAMS="LDAPMASTERSERVER LDAPZIMBRADN LDAPZIMBRAPASS ADMINUSER ADMINPASS"
sed -i "s|^WORKDIR=|WORKDIR=\"$ZMBKPOSE_BKDIR\"|" $OSE_CONF/zmbkpose.conf
	cat<<-EOF

################################################################################
 I configured $OSE_CONF/zmbkpose.conf whith :
    WORKDIR="$ZMBKPOSE_BKDIR"
 Change it if you decide to place the backup files elsewhere.
	EOF

## Host dependent Configurable parameters
if $IS_A_ZIMBRA_HOST ;then
	cat<<-EOF

################################################################################
 If you want, I can try configure $OSE_CONF/zmbkpose.conf
  with the following settings automatically detected:
   * LDAPMASTERSERVER=ldap://$ZIMBRA_ADDRESS:389
   * LDAPZIMBRADN=$ZIMBRA_LDAPDN
   * LDAPZIMBRAPASS=$ZIMBRA_LDAPPASS
	EOF
	if read_y_n_question "Do you like this script make these settings?" ;then
		[ -n "$ZIMBRA_ADDRESS" ] && \
			sed -i "s|^LDAPMASTERSERVER=|LDAPMASTERSERVER=ldap://$ZIMBRA_ADDRESS:389|" $OSE_CONF/zmbkpose.conf && \
			MANUAL_PARAMS=$(echo "$MANUAL_PARAMS"|sed -r 's|\bLDAPMASTERSERVER\b||')
		[ -n "$ZIMBRA_LDAPDN" ] && \
			sed -i "s|^LDAPZIMBRADN=|LDAPZIMBRADN=\"$ZIMBRA_LDAPDN\"|" $OSE_CONF/zmbkpose.conf && \
			MANUAL_PARAMS=$(echo "$MANUAL_PARAMS"|sed -r 's|\bLDAPZIMBRADN\b||')
		[ -n "$ZIMBRA_LDAPPASS" ] && \
			sed -i "s|^LDAPZIMBRAPASS=|LDAPZIMBRAPASS=\"$ZIMBRA_LDAPPASS\"|" $OSE_CONF/zmbkpose.conf && \
			MANUAL_PARAMS=$(echo "$MANUAL_PARAMS"|sed -r 's|\bLDAPZIMBRAPASS\b||')
	fi
fi

# Manual configurations
cat<<-EOF

################################################################################
 You will need to configure the follow values manually  
  in $OSE_CONF/zmbkpose.conf before to use zmbkpose:
$(for p in $MANUAL_PARAMS ;do echo "    * $p";done)
	EOF
if [ -n "$ZIMBRA_ADMUSERS" ]; then
  echo "The following users were found as administrators, and can be configured as ADMINUSER:"
  for u in $ZIMBRA_ADMUSERS;do echo "  * $u";done
fi

# We're done!
cat<<-EOF

################################################################################
	EOF
if read_y_n_question "Install completed. Do you want to display the README file?" ;then
  less $MYDIR/README
fi

exit $ERR_OK
