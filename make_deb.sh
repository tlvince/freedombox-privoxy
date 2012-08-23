#!/bin/bash

# Get version of deb we want to make
version=`cat VERSION`

patchcount=90
prepend() {
    echo -e "$1"|cat - $2 > /tmp/out && mv /tmp/out $2
}
dir_setup() {
    ## Copy privoxy dir, set dir aliases and apply upstream dpatch patches
    fakeversion=${version%-*}
    origversion=${fakeversion%-*}
    PRIVDIR=$PWD/privoxy-${origversion}
    FBOXDIR=freedombox-privoxy-${fakeversion}
    echo PRIVDIR = ${PRIVDIR}
    echo FBOXDIR = ${FBOXDIR}

    if [ -z ${PRIVDIR} ]; then
	pwd
	echo PRIVDIR is blank!  Do you have a valid deb-src line in /etc/apt/sources?
	exit
    fi

    if [ -z ${FBOXDIR} ]; then
	pwd
	echo FBOXDIR is blank!
	exit
    fi

    rm -rf ${FBOXDIR}
    cp -r ${PRIVDIR} ${FBOXDIR}
    ORIG=privoxy_${origversion}.orig.tar.gz
    FBOXORIG=freedombox-privoxy_${fakeversion}.orig.tar.gz
    cp ${ORIG} ${FBOXORIG}
    cd ${FBOXDIR}
    QUILT_PATCHES=debian/patches quilt pop -a
    sed -i -e '/^9/d' debian/patches/series
    QUILT_PATCHES=debian/patches quilt push -a
    cd ../..
    DEBDIR=$PWD/Debian/freedombox-privoxy-${fakeversion}
    echo DEBDIR = ${DEBDIR}
}

add_patch() {
    echo Adding patch $1
    mkdir -p privoxy
    DEST=${DEBDIR}/debian/patches/${patchcount}_$1.patch
    echo "${patchcount}_$1.patch" >> ${DEBDIR}/debian/patches/series
    diff -urNad ${DEBDIR}/$1 privoxy/$1 > ${DEST}
    patchcount=`expr ${patchcount} + 1` 
}

update_control() {
    echo Updating control
    ## update control file
    cp privoxy/debian/control ${DEBDIR}/debian/control
}

update_changelog() {
    echo Updating changelog
    cp changelog changelog.debian
    cat ${DEBDIR}/debian/changelog >> changelog.debian
    mv changelog.debian ${DEBDIR}/debian/changelog
}

update_rules() {
    echo Updating rules
    ## Update rules file
    pushd ${DEBDIR}/debian
    sed -i -e"s/^\(DEBDIR.*\)privoxy/\1freedombox-privoxy/" rules 
    sed -i -e"s/\(cd.*DEBDIR.*\)privoxy/\1freedombox-privoxy/" rules
    sed -i -e"s/dh_installinit/dh_installinit --name=privoxy/" rules
    mv init.d freedombox-privoxy.privoxy.init
    sed -i '/install -m.*trust/i \\tinstall -m 0644 https_everywhere.action $(DEBDIR)/etc/privoxy/https_everywhere.action' rules
    sed -i '/install -m.*trust/i \\tinstall -m 0644 easyprivacy.action $(DEBDIR)/etc/privoxy/easyprivacy.action' rules
    sed -i '/install -m.*trust/i \\tinstall -m 0644 easylist.action $(DEBDIR)/etc/privoxy/easylist.action' rules
    popd
    #sed -i -e"s/\(cd.*DEBDIR.*\)privoxy/\1; ln -s freedombox-privoxy privoxy)\n\t(\1freedombox-privoxy/" rules
}

update_doc_base() {
    echo Updating doc_base
    ## update dirs in doc-base
    pushd ${DEBDIR}/debian
    sed -i -e"s/\/privoxy/\/freedombox-privoxy/" doc-base.*
    popd
}

## Make working dir
mkdir -p Debian
cd Debian

## Install source package
apt-get source privoxy
echo You might need to \"apt-get build-dep privoxy\" as root
dir_setup
add_patch config
add_patch match-all.action
add_patch default.action
add_patch default.filter
add_patch easyprivacy.action
add_patch easylist.action
add_patch https_everywhere.action
add_patch filters.c

update_changelog
update_control
update_rules
update_doc_base

cd Debian/${FBOXDIR}; 
QUILT_PATCHES=debian/patches quilt push -a

cp ${PRIVDIR}/debian/init.d debian/init.d
