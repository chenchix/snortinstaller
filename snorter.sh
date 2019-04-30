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

WORKDIR=$(pwd)/workdir 
RELEASE=$(pwd)/release
HOMEDIR=$(pwd)

function install_dependencies(){
	echo -ne "\n\t${CYAN}[i] INFO:${NOCOLOR} Installing dependencies.\n\n"
	sudo apt install -y --force-yes rsync luajit libluajit-5.1-dev pkg-config build-essential cmake ragel sqlite3 libsqlite3-dev libboost-dev libpcap-dev libpcre3-dev libdumbnet-dev bison flex zlib1g-dev git locate vim libdaq-dev autoconf libtool-bin

}

function hyperscan_install(){
	#Downloading Hyperscan
	echo -ne "\n\t${CYAN}[i] INFO:${NOCOLOR} Downloading ${BOLD}HYPERSCAN${NOCOLOR}.\n\n"
	arch=$(uname -m)
	if [ "$arch" == "aarch64" ]; then
		if [ ! -e $HOMEDIR/$1 ]; then
			echo -ne "\n\t${CYAN}[i]: ERROR: Hyperscan version for ${BOLD}ARM not found. Ask smunoz@marvell.com${NOCOLOR}\n\n"
			RETURN=-1
			return
		else
			tar xf $1 -C ${WORKDIR}/
		fi
	else
		cd $WORKDIR && mkdir -p hyperscan_src && cd hyperscan_src
		wget --no-check-certificate -P $WORKDIR/hyperscan_src https://github.com/intel/hyperscan/archive/v5.0.0.tar.gz
		tar xf v5.0.0.tar.gz && rm v5.0.0.tar.gz && cd hyperscan-5.0.0
		mkdir -p objdir && cd objdir
		cmake .. -DBUILD_STATIC_AND_SHARED=ON #-DBUILD_AVX512=ON
		make && make install 
	fi
	echo -ne "\n\t${GREEN}[+] INFO:${NOCOLOR} ${BOLD}HYPERSCAN${NOCOLOR} installed successfully.\n\n"
	RETURN=0
}


function snort_install() {
	#Downloading SNORT
	cd $WORKDIR && mkdir -p snort_src && cd snort_src
	echo -ne "\n\t${CYAN}[i] INFO:${NOCOLOR} Downloading ${BOLD}SNORT${NOCOLOR}.\n\n"
	wget --no-check-certificate -P $WORKDIR/snort_src https://snort.org/downloads/archive/snort/snort-2.9.11.1.tar.gz

	#Installing SNORT
	cd $WORKDIR/snort_src
	echo -ne "\n\t${CYAN}[i] INFO:${NOCOLOR} Installing ${BOLD}SNORT${NOCOLOR}.\n\n"
	tar xf snort-2.9.11.1.tar.gz
	rm -rf *.tar.gz 

	#Patching snort to use hyperscan
	cd snort-2.9.11.1

	patch_snort
	
	arch=$(uname -m)
	if [ "$arch" == "aarch64" ]; then
	        ./configure --enable-intel-hyperscan \
       		    --with-intel-hyperscan-includes=$WORKDIR/release/src \
	            --with-intel-hyperscan-libraries=$WORKDIR/release/lib \
		    	--prefix=${RELEASE} \
			--enable-gre --enable-mpls --enable-targetbased --enable-ppm --enable-perfprofiling --enable-zlib --enable-active-response --enable-normalizer --enable-reload --enable-react --enable-flexresp3 \
	        && make -j8 && make install
	else
		./configure --enable-sourcefire --enable-intel-hyperscan \
	           --with-intel-hyperscan-includes=$WORKDIR/hyperscan_src/hyperscan-5.0.0/src \
	           --with-intel-hyperscan-libraries=$WORKDIR/hyperscan_src/hyperscan-5.0.0/objdir/lib \
	           --prefix=${RELEASE} \
		&& make && make install
	fi
	echo -ne "\n\t${GREEN}[+] INFO:${NOCOLOR} ${BOLD}$SNORT${NOCOLOR} installed successfully.\n\n"
	cd ..

	sudo ldconfig

}

function patch_snort(){
	
	echo -ne "\n\t${CYAN}[i] INFO:${NOCOLOR} Downloading ${BOLD}SNORT PATCH TO USE HYPERSCAN${NOCOLOR}\n\n"
	cd $WORKDIR/snort_src/snort-2.9.11.1
   	patch -p2 < ${WORKDIR}/../patches/snort-2982-hyperscan-v1.patch 
	autoreconf -fi
}




function setup_snort(){
	mkdir -p ${RELEASE}/lib/snort_dynamicpreprocessor/
	mkdir -p ${RELEASE}/lib/snort_dynamicengine
	mkdir -p ${RELEASE}/lib/snort_dynamicrules
	mkdir -p ${RELEASE}/var/log/snort
	mkdir -p ${RELEASE}/etc

	cd $WORKDIR/snort_src/snort-2.9.11.1
	find -name '*.so' -exec cp {\} ${RELEASE}/lib/snort_dynamicengine/ \; 	
	cd $HOMEDIR
	tar xf config.tar.gz && rsync -av etc ${RELEASE}
	rm -rf etc
	sed -e "s~CHANGEME~$RELEASE~" -i ${RELEASE}/etc/snort.conf
	cd -

}


function setup_hyperscan(){
	
	echo -ne "\n\t${CYAN}[i] INFO:${NOCOLOR} Preparing hyperscan release ${NOCOLOR}\n\n"
	cp -rf ${WORKDIR}/release/bin/hsbench $RELEASE/bin/
	cp -rf ${WORKDIR}/release/bin/pcapscan $RELEASE/bin/
	cp -rf ${WORKDIR}/release/pcre $RELEASE/
	cp -rf ${WORKDIR}/release/corpora $RELEASE/
	cp -rf ${WORKDIR}/release/pcap $RELEASE/
	cp -rf ${WORKDIR}/release/doc	$RELEASE/
	cp -rf ${WORKDIR}/release/tools	$RELEASE/
	cp -rf ${WORKDIR}/release/README.md	$RELEASE/
	cp -rf ${WORKDIR}/release/LICENSE	$RELEASE/
	cp -rf ${WORKDIR}/release/run_bench.sh	$RELEASE/
}

function install_libraries(){
	echo -ne "\n\t${CYAN}[i] INFO:${NOCOLOR} Copying hyperscan libraries.${NOCOLOR}\n\n"
	mkdir -p ${RELEASE}/lib 
	cd ${WORKDIR}/release/lib
	for i in $(find -type f)
	do
		strip $i -o ${RELEASE}/lib/$i
	done
	cd
}

function install_headers(){
	echo -ne "\n\t${CYAN}[i] INFO:${NOCOLOR} Packaging release ${NOCOLOR}\n\n"
	mkdir -p ${RELEASE}/src
	cd ${WORKDIR}/release/src
	cp -t ${RELEASE}/src hs.h hs_common.h hs_compile.h hs_runtime.h

}


function packaging(){
	echo -ne "\n\t${CYAN}[i] INFO:${NOCOLOR} Packaging release ${NOCOLOR}\n\n"
	cd $HOMEDIR
	tar cjf snort_hyperscan_marvell.tar.bz2 release
}

function usage(){
	echo -ne "Usage:\n"
	echo -ne "\t-s on\t\tInstall snort with hyperscan support\n"		
	echo -ne "\t-s off\t\tDo not install snort with hyperscan support\n"		
	echo -ne "\t-l on\t\tInstall hyperscan libraries\n"
	echo -ne "\t-l off\t\tDo not install hyperscan libraries\n"
	echo -ne "\t-a\t\tInstall hyperscan libraries and snort\n"
	echo -ne "\tHYPERSCAN_PACKAGE\n"
	echo -ne "IE: `basename $0` -a hyperscan-5.1.0.tar.bz2\n"
	exit 1

}

while getopts ":s:l:ah:" opt; do
  case $opt in
    s)
      	if [ $OPTARG == "on" ]; 
      	then
	      	echo -ne "\n\t${CYAN}[i]Package with SNORT ${NOCOLOR}.\n\n" >&2
    	   	INSTALL_SNORT=1
    	else
			echo -ne "\n\t${CYAN}[i]Package without SNORT ${NOCOLOR}.\n\n" >&2
		fi
      	;;
    l)
      	if [ $OPTARG == "on" ]; 
      	then
	      	echo -ne "\n\t${CYAN}[i]Package with libraries and headers ${NOCOLOR}.\n\n" >&2
      		INSTALL_LIBRARIES=1
      	else
			echo -ne "\n\t${CYAN}[i]Package without libraries ${NOCOLOR}.\n\n" >&2
		fi
      	;;
    a)
     	echo -ne "\n\t${CYAN}[i]Package with libraries and snort${NOCOLOR}.\n\n" >&2
    	INSTALL_SNORT=1
      	INSTALL_LIBRARIES=1
      	;;
    h)
		usage
		;;
    *)
      	echo -ne "\n\t${CYAN}[i]Invalid option: -$OPTARG ${NOCOLOR}.\n\n" >&2
	usage
      	;;

  esac
done

if [[ $# -eq 0 ]] ; then
    usage
fi

shift $(($OPTIND-1))
if  [ -z $1 ]; then
	usage
fi

read -p "Press any key to continue"


rm -rf $WORKDIR $RELEASE
mkdir -p ${WORKDIR}/release
mkdir -p ${RELEASE}/bin

install_dependencies
hyperscan_install $1
setup_hyperscan

if [ "$INSTALL_SNORT" == "1" ];
then
	snort_install
	setup_snort
fi

if [ "$INSTALL_LIBRARIES" == "1" ];
then
	install_libraries
	install_headers
fi

packaging
#rm -rf $WORKDIR
