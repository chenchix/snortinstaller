#!/bin/bash
# Title: Snorter.sh
# Description: Install automatically Snort + patch + Hyperscan

RED='\033[0;31m'
ORANGE='\033[0;205m'
YELLOW='\033[0;93m'
GREEN='\033[0;32m'
CYAN='\033[0;96m'
BLUE='\033[0;34m'
VIOLET='\033[0;35m'
NOCOLOR='\033[0m'
BOLD='\033[1m'

WORKDIR=~/benchmark
HOMEDIR=$(pwd)

function install_dependencies(){
	echo -ne "\n\t${CYAN}[i] INFO:${NOCOLOR} Installing dependencies.\n\n"
	sudo apt install -y --force-yes build-essential cmake ragel sqlite3 libsqlite3-dev libboost-dev libpcap-dev libpcre3-dev libdumbnet-dev bison flex zlib1g-dev git locate vim libdaq-dev autoconf libtool-bin

}
function snort_install() {
	#Downloading SNORT
	cd $WORKDIR && mkdir -p snort_src && cd snort_src
	echo -ne "\n\t${CYAN}[i] INFO:${NOCOLOR} Downloading ${BOLD}SNORT${NOCOLOR}.\n\n"
	wget --no-check-certificate -P $WORKDIR/snort_src https://snort.org/downloads/archive/snort/snort-2.9.8.2.tar.gz

	#Installing SNORT
	cd $WORKDIR/snort_src
	echo -ne "\n\t${CYAN}[i] INFO:${NOCOLOR} Installing ${BOLD}SNORT${NOCOLOR}.\n\n"
	tar xf snort-2.9.8.2.tar.gz
	rm -rf *.tar.gz 

	#Patching snort to use hyperscan
	patch_snort
	cd snort-2.9.8.2
	
	arch=$(uname -m)
	if [ "$arch" == "aarch64" ]; then
	        ./configure --enable-sourcefire --enable-intel-hyperscan \
        	    --with-intel-hyperscan-includes=$WORKDIR/hyperscan_src/hyperscan_4.7.0_arm/src \
	            --with-intel-hyperscan-libraries=$WORKDIR/hyperscan_src/hyperscan_4.7.0_arm/objdir/lib \
	        && make && make install
	else
		/configure --enable-sourcefire --enable-intel-hyperscan \
	           --with-intel-hyperscan-includes=$WORKDIR/hyperscan_src/hyperscan-5.0.0/src \
	           --with-intel-hyperscan-libraries=$WORKDIR/hyperscan_src/hyperscan-5.0.0/objdir/lib \
		& make && make install
	fi
	echo -ne "\n\t${GREEN}[+] INFO:${NOCOLOR} ${BOLD}$SNORT${NOCOLOR} installed successfully.\n\n"
	cd ..

	sudo ldconfig

}

function patch_snort(){
	
	echo -ne "\n\t${CYAN}[i] INFO:${NOCOLOR} Downloading ${BOLD}SNORT PATCH TO USE HYPERSCAN${NOCOLOR}.\n\n"
	wget --no-check-certificate -P $WORKDIR/snort_src https://01.org/sites/default/files/downloads//snort-2982-hyperscan-v1.tar.gz
	cd $WORKDIR/snort_src/snort-2.9.8.2
	tar xf $WORKDIR/snort_src/snort-2982-hyperscan-v1.tar.gz && rm $WORKDIR/snort_src/snort-2982-hyperscan-v1.tar.gz
    	zcat snort-2982-hyperscan-v1/snort-2982-hyperscan-v1.patch.gz | patch -p2
	autoreconf -fi
}



function hyperscan_install(){
	#Downloading Hyperscan
	cd $WORKDIR && mkdir -p hyperscan_src && cd hyperscan_src

	echo -ne "\n\t${CYAN}[i] INFO:${NOCOLOR} Downloading ${BOLD}HYPERSCAN${NOCOLOR}.\n\n"
	arch=$(uname -m)
	if [ "$arch" == "aarch64" ]; then
		if [ ! -e $HOMEDIR/hyperscan_4.7.0_arm.tar.bz2 ]; then
			echo -ne "\n\t${CYAN}[i]: ERROR: Hyperscan version for ${BOLD}ARM not found. Ask smunoz@marvell.com${NOCOLOR}\n\n"
			RETURN=-1
			return
		fi
		tar xf $HOMEDIR/hyperscan_4.7.0_arm.tar.bz2 && cd hyperscan_4.7.0_arm
	else
		wget --no-check-certificate -P $WORKDIR/hyperscan_src https://github.com/intel/hyperscan/archive/v5.0.0.tar.gz
		tar xf v5.0.0.tar.gz && rm v5.0.0.tar.gz && cd hyperscan-5.0.0
	fi
	
	mkdir -p objdir && cd objdir
	cmake .. -DBUILD_STATIC_AND_SHARED=ON #-DBUILD_AVX512=ON
	make && sudo make install 
	echo -ne "\n\t${GREEN}[+] INFO:${NOCOLOR} ${BOLD}HYPERSCAN${NOCOLOR} installed successfully.\n\n"
	RETURN=0
}

function setup_snort(){
	sudo mkdir -p /usr/local/lib/snort_dynamicpreprocessor/
	sudo mkdir -p /usr/local/lib/snort_dynamicengine
	sudo mkdir -p /usr/local/lib/snort_dynamicrules
	sudo mkdir -p /var/log/snort

	cd $WORKDIR/snort_src/snort-2.9.8.2
	find -name '*.so' -exec sudo cp {\} /usr/local/lib/snort_dynamicengine/ \; 	
	cd $HOMEDIR
	tar xf config.tar.gz && mv etc/* $WORKDIR/snort_src/snort-2.9.8.2/etc
	cd -

}

mkdir -p $WORKDIR
install_dependencies
hyperscan_install
if [ $RETURN == -1 ]; then
	cd $HOMEDIR
	return 0
else
	snort_install
	setup_snort
	echo -ne "\n\t${CYAN}[i] INFO:${NOCOLOR} Run snort using this line ${NOCOLOR}.\n\n"
	echo -ne "\n\t${BOLD} sudo LD_LIBRARY_PATH=$WORKDIR/hyperscan_src/hyperscan-5.0.0/objdir/lib src/snort -c etc/snort.conf ${NOCOLOR}\n"
fi
