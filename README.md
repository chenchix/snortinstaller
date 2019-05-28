OVERVIEW
========
Script to install automatically snort 2.9.11.1, patch it and use hyperscan 5.0 as engine

USAGE
=====

$ git clone https://github.com/chenchix/snortinstaller.git

$ chmod u+x snorter.sh

$ ./snorter.sh
Usage: [parameters] HYPERSCAN_PACKAGE
	-s on		Install snort with hyperscan support
	-s off		Install snort without hyperscan support
	-l on		Install hyperscan libraries
	-l off		Do not install hyperscan libraries
	-a		Install hyperscan libraries and snort
IE: ./snorter.sh -a hyperscan-5.1.0.tar.bz2


Credits
=======
This script is based in the awesome work made by Joan Bono with his snorter. 
https://github.com/joanbono/Snorter
