#!/bin/bash

WKDIR="/tmp"

function osUpdate {
	echo "Updating system..."
	sudo apt update
	sudo apt upgrade -y
}

function installDependencies {
	echo "Installing dependencies..."
	sudo apt install -y cpp freeglut3-dev g++ gcc gfortran \
    ghostscript m4 make patch pkg-config wget python unzip \
    libopenblas-dev liblapack-dev libhdf5-dev libgsl-dev \
    libscotch-dev libfftw3-dev libarpack2-dev libsuitesparse-dev \
    libmumps-seq-dev libnlopt-dev coinor-libipopt-dev libgmm++-dev libtet1.5-dev \
    gnuplot-qt autoconf automake autotools-dev bison flex gdb valgrind git cmake mpich sudo
}

function checkLastVersionInstalled {
        #check if there is already a ff++ folder
        if [ -d "/usr/local/lib/ff++/" ]; then
                version="$(ls -A /usr/local/lib/ff++/ | sort | tail -n 1)"
        else
                version="0"
        fi
}

function moveOldFreeFem {
	echo "Moving FreeFem++ executables into FreeFem++.old..."
	sudo mv /usr/local/bin/FreeFem++ /usr/local/bin/FreeFem++.old 2>/dev/null
	sudo mv /usr/local/bin/bamg /usr/local/bin/bamg.old 2>/dev/null
	sudo mv /usr/local/bin/ff-mpirun /usr/local/bin/ff-mpirun.old 2>/dev/null
	sudo mv /usr/local/bin/FreeFem++-CoCoa /usr/local/bin/FreeFem++-CoCoa.old 2>/dev/null
	sudo mv /usr/local/bin/cvmsh2 /usr/local/bin/cvmsh2.old 2>/dev/null
	sudo mv /usr/local/bin/ff-pkg-download /usr/local/bin/ff-pkg-download.old 2>/dev/null
	sudo mv /usr/local/bin/FreeFem++-mpi /usr/local/bin/FreeFem++-mpi.old 2>/dev/null
	sudo mv /usr/local/bin/ff-c++ /usr/local/bin/ff-c++.old 2>/dev/null
	sudo mv /usr/local/bin/ffglut /usr/local/bin/ffglut.old 2>/dev/null
	sudo mv /usr/local/bin/FreeFem++-nw /usr/local/bin/FreeFem++-nw.old 2>/dev/null
	sudo mv /usr/local/bin/ff-get-dep /usr/local/bin/ff-get-dep.old 2>/dev/null
	sudo mv /usr/local/bin/ffmedit /usr/local/bin/ffmedit.old 2>/dev/null
}

function configure {
	#generate configure file and run it
	autoreconf -i
	./configure --enable-download --enable-optim
}

checkLastVersionInstalled version
if [ "$version" != "0" ]
then
        echo "FreeFem $version found, we will move executables."
        moveOldFreeFem
else
        echo "No previous FreeFem installation found, let's continue."
fi

#updating system
if ! osUpdate
then
	echo "Error while updating your system, you should stop here." && exit 3
fi

#dependencies
if ! installDependencies
then
	echo "There was a problem while installing dependencies, exiting here." && exit 3
fi

#downloading freefem
echo "Cloning FreeFem git repository..."
git clone https://github.com/FreeFem/FreeFem-sources.git $WKDIR/FreeFem-sources
cd $WKDIR/FreeFem-sources || (echo "Unexpected error while cd to FreeFem folder, exiting." && exit 2)

echo "Generate configure file..."
if ! configure
then
	echo "Error while configuring FreeFem installation, exiting here." && exit 4
fi

#downloading all packages
echo "Downloading FreeFem++ packages..."
if ! ./3rdparty/getall -a
then
	echo "Error while downloading extra packages, exiting here." && exit 5
fi

#Download and compile petsc & slepc
echo "Downloading and compiling petsc-slepc... (it can take few times !)"
cd 3rdparty/ff-petsc || (echo "Unexpected error while cd to download/petsc-slepc folder, exiting." && exit 1)
if ! make petsc-slepc SUDO=sudo
then
	echo "Error while compiling petsc, exiting here." && exit 6
fi
cd $WKDIR/FreeFem-sources || (echo "Unexpected error while cd back to FreeFemm folder, exiting." && exit 1)

#reconfigure after petsc compilation
echo "Reconfigure FreeFem installation now that petsc-slepc is installed..."
if ! ./reconfigure
then
	echo "Error while regenerating configure file. Can't compile FreeFem++." && exit 7
fi

#and start the compilation
echo "Beginning the FreeFem compilation..."

if ! make -j 4
then
	echo "Seems that there is a problem with previous make command. Exiting here, sorry !" && exit 2
fi

if sudo make install
then
	checkLastVersionInstalled version
	/usr/local/bin/FreeFem++ 2>/dev/null
	echo "FreeFem++ $version successfully installed !"
	sudo rm -rf $WKDIR/FreeFem-sources
	exit 0
else
	echo "Something went wrong during the installation, sorry." && exit 2
fi
