#!/bin/bash

SCRIPTDIR=/usr/share/freedombox-privoxy
ABP=${SCRIPTDIR}/abp_import.py
HTTPS=${SCRIPTDIR}/https_everywhere_import.py
CONFDIR=/etc/privoxy

test -x ${ABP} || exit 0
test -x ${HTTPS} || exit 0

changes=0

copy_file() {
	if [ ! -e ${CONFDIR}/$1 ]; then
		cp $1 ${CONFDIR}
		changes=`expr ${changes} + 1`
	else
		SHA1_NEW=$(sha1sum $1 | awk '{print $1}')
		SHA1_OLD=$(sha1sum ${CONFDIR}/$1 | awk '{print $1}')
		if [ ${SHA1_OLD} != ${SHA1_NEW} ]; then
			cp $1 ${CONFDIR}
			changes=`expr ${changes} + 1`
		fi
	fi
}

update_abp() {
	wget https://easylist-downloads.adblockplus.org/$1.txt
	${ABP} $1.txt > $1.action
	copy_file $1.action
}

update_https_everywhere() {
	wget https://www.eff.org/files/https-everywhere-2.1.xpi
	unzip https-everywhere-2.1.xpi
	${HTTPS} chrome/content/rules > $1.action
	copy_file $1.action
}

TMPDIR=/tmp/freedombox-privoxy.${RANDOM}
mkdir -p ${TMPDIR}

pushd ${TMPDIR}

## ABP ##
# easyprivacy.action
update_abp easyprivacy
# easylist.action
update_abp easylist

## HTTPS everywhere ##
# https_everywhere
update_https_everywhere	https_everywhere

popd

rm -rf ${TMPDIR}

[ ${changes} -ne 0 ] || exit 1

