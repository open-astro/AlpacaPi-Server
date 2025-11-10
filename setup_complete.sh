#!/bin/bash
###############################################################################
#	AlpacaPi Complete Setup Script
#	This script consolidates ALL setup functionality into a single script
#	Replaces the need for multiple setup/install scripts
###############################################################################
#	Edit History
###############################################################################
#	Dec 2024	<MLS> Created comprehensive setup script consolidating all install scripts
#	Dec 2024	<MLS> Integrated all individual install scripts into one unified script
###############################################################################

set -e		#*	exit on error (can be removed if you want script to continue on errors)

###############################################################################
#	Configuration
###############################################################################
AUTO_INSTALL=false		#*	set to true to skip prompts and install everything automatically
INSTALL_VENDOR_SDKS=false	#*	set to true to automatically install vendor SDKs if present

###############################################################################
#	Colors for output (optional, works on most terminals)
###############################################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

###############################################################################
#	Helper Functions
###############################################################################

#*	Detect number of CPU cores for parallel compilation
DetectCores()
{
	if command -v nproc >/dev/null 2>&1
	then
		NUM_CORES=$(nproc)
	elif [ -f /proc/cpuinfo ]
	then
		NUM_CORES=$(grep -c processor /proc/cpuinfo)
	else
		NUM_CORES=4	#*	Default fallback
	fi
	
	#*	Use all available cores (no cap)
	#*	Modern build systems (make, cmake) handle high core counts well
	echo "$NUM_CORES"
}

#*	Get make parallel flag
GetMakeJobs()
{
	local CORES=$(DetectCores)
	echo "-j$CORES"
}

PrintSection()
{
	echo ""
	echo "================================================================================"
	echo "$1"
	echo "================================================================================"
}

PrintStep()
{
	echo ""
	echo -e "${BLUE}[STEP]${NC} $1"
}

PrintSuccess()
{
	echo -e "${GREEN}[OK]${NC} $1"
}

PrintWarning()
{
	echo -e "${YELLOW}[WARN]${NC} $1"
}

PrintError()
{
	echo -e "${RED}[ERROR]${NC} $1"
}

AskYesNo()
{
	local PROMPT="$1"
	local DEFAULT="${2:-n}"		#*	default to 'n' if not provided
	
	if [ "$AUTO_INSTALL" = true ]
	then
		echo "$PROMPT [Auto: $DEFAULT]"
		YESNO="$DEFAULT"
	else
		echo -n "$PROMPT [y/n] (default: $DEFAULT): "
		read YESNO
		if [ -z "$YESNO" ]
		then
			YESNO="$DEFAULT"
		fi
	fi
	
	if [ "$YESNO" = "y" ] || [ "$YESNO" = "Y" ]
	then
		return 0
	else
		return 1
	fi
}

CheckCommand()
{
	if command -v "$1" >/dev/null 2>&1
	then
		return 0
	else
		return 1
	fi
}

CheckFile()
{
	local MYPATH="$1"
	local FILENAME="$2"
	local FULLPATH="$MYPATH/$FILENAME"
	
	if [ -d "$FULLPATH" ] || [ -f "$FULLPATH" ]
	then
		return 0
	else
		return 1
	fi
}

#*	Filter out harmless apt-get errors (cross-architecture warnings, 404s, etc.)
FilterAptErrors()
{
	grep -vE "(Ign:|404|arm64 Packages|Failed to fetch.*arm64|W:.*arm64|E:.*arm64)" || true
}

###############################################################################
#	Platform Detection
###############################################################################
DeterminePlatform()
{
	MACHINE_TYPE=`uname -m`
	ISX64=false
	ISARM32=false
	ISARM64=false
	PLATFORM="unknown"
	NATIVE_ARCH=`dpkg --print-architecture 2>/dev/null || uname -m`
	
	#*	Detect Linux distribution and version
	if [ -f /etc/os-release ]
	then
		. /etc/os-release
		OS_NAME="$NAME"
		OS_VERSION="$VERSION_ID"
		OS_ID="$ID"
		#*	Handle Raspberry Pi OS (formerly Raspbian)
		if [ "$ID" = "raspbian" ]
		then
			OS_ID="raspberrypi"
			OS_NAME="Raspberry Pi OS"
		elif [ "$ID" = "debian" ] && [ -f /proc/device-tree/model ] && grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null
		then
			OS_ID="raspberrypi"
			OS_NAME="Raspberry Pi OS"
		fi
	else
		OS_NAME="Unknown"
		OS_VERSION="Unknown"
		OS_ID="unknown"
	fi
	
	if [ "$MACHINE_TYPE" = "x86_64" ]
	then
		ISX64=true
		PLATFORM="x64"
		echo "Platform: Intel/AMD 64-bit (x86_64)"
		NATIVE_ARCH="amd64"
	elif [ "$MACHINE_TYPE" = "aarch64" ]
	then
		ISARM64=true
		PLATFORM="arm64"
		echo "Platform: ARM 64-bit (aarch64)"
		NATIVE_ARCH="arm64"
	elif [ "$MACHINE_TYPE" = "armv7l" ]
	then
		ISARM32=true
		PLATFORM="arm32"
		echo "Platform: ARM 32-bit (armv7l)"
		NATIVE_ARCH="armhf"
	else
		echo "Platform: Unknown ($MACHINE_TYPE)"
		NATIVE_ARCH=`uname -m`
	fi
	
	echo "Native architecture: $NATIVE_ARCH"
	echo "OS: $OS_NAME $OS_VERSION"
	
	#*	Check for EOL Ubuntu versions
	if [ "$OS_ID" = "ubuntu" ]
	then
		case "$OS_VERSION" in
			"16.04")
				PrintWarning "Ubuntu 16.04 LTS is End of Life (EOL since April 2021)"
				PrintWarning "Repositories may have moved to old-releases.ubuntu.com"
				PrintWarning "You may need to update /etc/apt/sources.list manually"
				PrintWarning "AlpacaPi was tested on Ubuntu 16.04, but EOL systems may have issues"
				;;
			"18.04")
				PrintWarning "Ubuntu 18.04 LTS reached End of Life (EOL since May 2023)"
				PrintWarning "Repositories may have moved to old-releases.ubuntu.com"
				;;
		esac
	fi
	
	#*	Note: AlpacaPi has been tested on:
	#*	- Ubuntu 16.04 LTS x86_64
	#*	- Ubuntu 20.04 LTS x86_64
	#*	- Raspberry Pi 3/4 (32-bit and 64-bit) - typically running Raspberry Pi OS (Raspbian)
	#*	- NVIDIA Jetson Nano (64-bit)
	#*	The script should work on most Debian-based Linux distributions
}

###############################################################################
#	Check System Requirements
###############################################################################
CheckSystemRequirements()
{
	PrintSection "Checking System Requirements"
	
	MISSING_TOOLS=0
	MISSING_LIBS=0
	
	#*	Check build tools
	PrintStep "Checking build tools..."
	if CheckCommand gcc
	then
		PrintSuccess "gcc found"
	else
		PrintError "gcc not found"
		MISSING_TOOLS=$((MISSING_TOOLS + 1))
	fi
	
	if CheckCommand g++
	then
		PrintSuccess "g++ found"
	else
		PrintError "g++ not found"
		MISSING_TOOLS=$((MISSING_TOOLS + 1))
	fi
	
	if CheckCommand make
	then
		PrintSuccess "make found"
	else
		PrintError "make not found"
		MISSING_TOOLS=$((MISSING_TOOLS + 1))
	fi
	
	if CheckCommand cmake
	then
		PrintSuccess "cmake found"
	else
		PrintWarning "cmake not found (needed for some libraries)"
		MISSING_TOOLS=$((MISSING_TOOLS + 1))
	fi
	
	if CheckCommand pkg-config
	then
		PrintSuccess "pkg-config found"
	else
		PrintWarning "pkg-config not found"
		MISSING_TOOLS=$((MISSING_TOOLS + 1))
	fi
	
	if CheckCommand git
	then
		PrintSuccess "git found"
	else
		PrintWarning "git not found (needed for some downloads)"
		MISSING_TOOLS=$((MISSING_TOOLS + 1))
	fi
	
	#*	Check system libraries
	PrintStep "Checking system libraries..."
	if pkg-config --exists libusb-1.0 2>/dev/null || [ -f "/usr/include/libusb-1.0/libusb.h" ] || [ -f "/usr/local/include/libusb-1.0/libusb.h" ]
	then
		PrintSuccess "libusb-1.0-0-dev found"
	else
		PrintWarning "libusb-1.0-0-dev not found (needed for USB device access)"
		MISSING_LIBS=$((MISSING_LIBS + 1))
	fi
	
	if pkg-config --exists libudev 2>/dev/null || [ -f "/usr/include/libudev.h" ] || [ -f "/usr/local/include/libudev.h" ]
	then
		PrintSuccess "libudev-dev found"
	else
		PrintWarning "libudev-dev not found (needed for USB device management)"
		MISSING_LIBS=$((MISSING_LIBS + 1))
	fi
	
	if [ -f "/usr/include/linux/i2c-dev.h" ] || [ -f "/usr/local/include/linux/i2c-dev.h" ]
	then
		PrintSuccess "libi2c-dev found"
	else
		PrintWarning "libi2c-dev not found (needed for I2C bus support)"
		MISSING_LIBS=$((MISSING_LIBS + 1))
	fi
	
	if pkg-config --exists libjpeg 2>/dev/null || [ -f "/usr/include/jpeglib.h" ] || [ -f "/usr/local/include/jpeglib.h" ]
	then
		PrintSuccess "libjpeg-dev found"
	else
		PrintWarning "libjpeg-dev not found (needed for JPEG image processing)"
		MISSING_LIBS=$((MISSING_LIBS + 1))
	fi
	
	if pkg-config --exists gtk+-2.0 2>/dev/null || [ -f "/usr/include/gtk-2.0/gtk/gtk.h" ] || [ -f "/usr/local/include/gtk-2.0/gtk/gtk.h" ]
	then
		PrintSuccess "libgtk2.0-dev found"
	else
		PrintWarning "libgtk2.0-dev not found (needed for GUI components)"
		MISSING_LIBS=$((MISSING_LIBS + 1))
	fi
	
	#*	Check project files
	PrintStep "Checking project files..."
	if CheckFile "." "Makefile"
	then
		PrintSuccess "Makefile found"
	else
		PrintError "Makefile missing - please re-check download"
		exit 1
	fi
	
	if CheckFile "." "src"
	then
		PrintSuccess "src directory found"
	else
		PrintError "src directory missing - please re-check download"
		exit 1
	fi
	
	#*	Create Objectfiles directory
	mkdir -p Objectfiles
	PrintSuccess "Objectfiles directory ready"
	
	#*	Offer to install missing tools
	if [ $MISSING_TOOLS -gt 0 ]
	then
		PrintWarning "$MISSING_TOOLS build tool(s) missing"
		if AskYesNo "Would you like to install missing build tools?" "y"
		then
			InstallBuildTools
		fi
	fi
	
	#*	Offer to install missing libraries
	if [ $MISSING_LIBS -gt 0 ]
	then
		PrintWarning "$MISSING_LIBS system library/libraries missing"
		if AskYesNo "Would you like to install missing system libraries?" "y"
		then
			InstallSystemLibraries
		fi
	else
		PrintSuccess "All required system libraries are installed"
	fi
}

###############################################################################
#	Install Build Tools
###############################################################################
InstallBuildTools()
{
	PrintSection "Installing Build Tools"
	
	PrintStep "Updating package lists for $NATIVE_ARCH architecture..."
	#*	Update package lists, filtering out cross-architecture errors
	#*	Packages will automatically install for native architecture ($NATIVE_ARCH)
	#*	Note: Ubuntu 16.04/18.04 EOL systems may need repository updates
	UPDATE_OUTPUT=$(sudo apt-get update 2>&1)
	if echo "$UPDATE_OUTPUT" | grep -qE "Err:|404"
	then
		PrintWarning "Some repositories failed to update"
		PrintWarning "This is normal for EOL Ubuntu versions (16.04, 18.04)"
		PrintWarning "The script will continue - packages may still install correctly"
	fi
	echo "$UPDATE_OUTPUT" | grep -vE "(Ign:|404|arm64 Packages|Failed to fetch.*arm64)" || true
	
	PrintStep "Installing build-essential (gcc, g++, make)..."
	sudo apt-get install -y build-essential
	
	if ! CheckCommand pkg-config
	then
		PrintStep "Installing pkg-config..."
		sudo apt-get install -y pkg-config
	fi
	
	if ! CheckCommand cmake
	then
		PrintStep "Installing cmake..."
		sudo apt-get install -y cmake
	fi
	
	if ! CheckCommand git
	then
		PrintStep "Installing git..."
		sudo apt-get install -y git
	fi
	
	PrintSuccess "Build tools installation complete"
}

###############################################################################
#	Install System Libraries
###############################################################################
InstallSystemLibraries()
{
	PrintSection "Installing System Libraries"
	
	PrintStep "Updating package lists for $NATIVE_ARCH architecture..."
	#*	Update package lists, filtering out cross-architecture errors
	#*	Packages will automatically install for native architecture ($NATIVE_ARCH)
	#*	Note: Ubuntu 16.04/18.04 EOL systems may need repository updates
	UPDATE_OUTPUT=$(sudo apt-get update 2>&1)
	if echo "$UPDATE_OUTPUT" | grep -qE "Err:|404"
	then
		PrintWarning "Some repositories failed to update"
		PrintWarning "This is normal for EOL Ubuntu versions (16.04, 18.04)"
		PrintWarning "The script will continue - packages may still install correctly"
	fi
	echo "$UPDATE_OUTPUT" | grep -vE "(Ign:|404|arm64 Packages|Failed to fetch.*arm64)" || true
	
	PrintStep "Installing libusb-1.0-0-dev..."
	sudo apt-get install -y libusb-1.0-0-dev
	
	PrintStep "Installing libudev-dev..."
	sudo apt-get install -y libudev-dev
	
	PrintStep "Installing libi2c-dev..."
	sudo apt-get install -y libi2c-dev
	
	PrintStep "Installing libjpeg-dev..."
	sudo apt-get install -y libjpeg-dev
	
	PrintStep "Installing libgtk2.0-dev..."
	sudo apt-get install -y libgtk2.0-dev
	
	PrintSuccess "System libraries installed"
}

###############################################################################
#	FITS Library Installation (from install_fits.sh)
###############################################################################
CheckForFITSIO()
{
	FITS_INSTALLED=false
	FITS_LOCATION="not-found"
	
	if [ -f "/usr/local/include/fitsio.h" ]
	then
		FITS_INSTALLED=true
		FITS_LOCATION="/usr/local/include"
	elif [ -f "/usr/include/fitsio.h" ]
	then
		FITS_INSTALLED=true
		FITS_LOCATION="/usr/include"
	fi
}

CheckFITSversion()
{
	CFITSIO_PRESENT=false
	FITS_FOLDER=""
	
	#*	Check for various versions
	for version in "3.47" "3.48" "3.49" "3.50" "4.0.0" "4.1.0" "4.4.1" "4.5.0"
	do
		if [ -d "cfitsio-$version" ]
		then
			CFITSIO_PRESENT=true
			FITS_FOLDER="cfitsio-$version"
			break
		fi
	done
}

InstallFITS()
{
	PrintSection "FITS Library (cfitsio)"
	
	CheckForFITSIO
	
	if [ "$FITS_INSTALLED" = true ]
	then
		PrintSuccess "FITS library already installed at $FITS_LOCATION"
		if [ -f "$FITS_LOCATION/fitsio.h" ]
		then
			FITS_VERSION=`grep CFITSIO_VERSION "$FITS_LOCATION/fitsio.h" | head -1`
			echo "	Version: $FITS_VERSION"
		fi
		return 0
	fi
	
	#*	Try package manager first (easier)
	PrintStep "Attempting to install cfitsio via package manager..."
	if sudo apt-get install -y libcfitsio-dev 2>/dev/null
	then
		CheckForFITSIO
		if [ "$FITS_INSTALLED" = true ]
		then
			PrintSuccess "FITS library installed via package manager"
			return 0
		fi
	fi
	
	#*	Fall back to source installation
	PrintWarning "Package manager installation failed or unavailable"
	if ! AskYesNo "Would you like to install FITS from source? (This will take longer)" "y"
	then
		return 1
	fi
	
	CFITSIO_TAR="cfitsio_latest.tar.gz"
	
	#*	Download if needed
	if [ ! -f "$CFITSIO_TAR" ]
	then
		PrintStep "Downloading cfitsio..."
		if ! wget "http://heasarc.gsfc.nasa.gov/FTP/software/fitsio/c/cfitsio_latest.tar.gz"
		then
			PrintError "Failed to download cfitsio"
			return 1
		fi
	fi
	
	#*	Check for existing extracted version
	CheckFITSversion
	
	if [ "$CFITSIO_PRESENT" = false ]
	then
		if [ -f "$CFITSIO_TAR" ]
		then
			PrintStep "Extracting cfitsio..."
			if ! AskYesNo "Extract $CFITSIO_TAR?" "y"
			then
				return 1
			fi
			tar -xvf "$CFITSIO_TAR"
			CheckFITSversion
		fi
	fi
	
	if [ "$CFITSIO_PRESENT" = true ]
	then
		PrintStep "Building and installing cfitsio ($FITS_FOLDER)..."
		if ! AskYesNo "Proceed with build and install? (requires sudo)" "y"
		then
			return 1
		fi
		
		cd "$FITS_FOLDER"
		./configure --prefix=/usr/local
		MAKE_JOBS=$(GetMakeJobs)
		PrintStep "Building FITS library with $MAKE_JOBS (using $(DetectCores) cores)..."
		make $MAKE_JOBS
		sudo make install
		sudo /sbin/ldconfig -v
		
		#*	Run test
		make testprog
		if [ -f testprog ]
		then
			PrintSuccess "testprog Make success"
			./testprog > testprog.lis
			DIFFCNT=`diff testprog.lis testprog.out | wc -l`
			if [ "$DIFFCNT" -eq "0" ]
			then
				PrintSuccess "FITS installation verified"
			else
				PrintWarning "FITS test had differences (may still work)"
			fi
		fi
		cd ..
	else
		PrintError "Could not find or extract cfitsio"
		return 1
	fi
}

###############################################################################
#	OpenCV Installation
###############################################################################
CheckOpenCV()
{
	PrintSection "OpenCV Library Check"
	
	OPENCV_INSTALLED=false
	OPENCV_VERSION=""
	OPENCV_LOCATION=""
	
	#*	Check for OpenCV 4
	if pkg-config --exists opencv4 2>/dev/null
	then
		OPENCV_INSTALLED=true
		OPENCV_VERSION="4"
		OPENCV_LOCATION=`pkg-config --variable=includedir opencv4 2>/dev/null`
		OPENCV_VERSION_STRING=`pkg-config --modversion opencv4 2>/dev/null || echo "4.x"`
		PrintSuccess "OpenCV 4 found (version $OPENCV_VERSION_STRING)"
	elif pkg-config --exists opencv 2>/dev/null
	then
		OPENCV_INSTALLED=true
		OPENCV_VERSION="3"
		OPENCV_LOCATION=`pkg-config --variable=includedir opencv 2>/dev/null`
		OPENCV_VERSION_STRING=`pkg-config --modversion opencv 2>/dev/null || echo "3.x"`
		PrintSuccess "OpenCV 3 found (version $OPENCV_VERSION_STRING)"
	fi
	
	#*	Check common file locations
	if [ "$OPENCV_INSTALLED" = false ]
	then
		if [ -f "/usr/include/opencv2/highgui/highgui_c.h" ] || [ -f "/usr/include/opencv4/opencv2/highgui/highgui.hpp" ]
		then
			OPENCV_INSTALLED=true
			OPENCV_LOCATION="/usr/include"
			PrintSuccess "OpenCV found in /usr/include"
		elif [ -f "/usr/local/include/opencv2/highgui/highgui_c.h" ] || [ -f "/usr/local/include/opencv4/opencv2/highgui/highgui.hpp" ]
		then
			OPENCV_INSTALLED=true
			OPENCV_LOCATION="/usr/local/include"
			PrintSuccess "OpenCV found in /usr/local/include"
		fi
	fi
	
	if [ "$OPENCV_INSTALLED" = false ]
	then
		PrintWarning "OpenCV not found"
		echo ""
		echo "OpenCV is required for:"
		echo "	- Camera image processing"
		echo "	- Client applications (camera, dome, focuser, etc.)"
		echo "	- SkyTravel visualization"
		echo ""
		echo "OpenCV is NOT required for:"
		echo "	- Basic AlpacaPi server (without camera support)"
		echo "	- Roll-off roof control"
		echo ""
		echo "Note: On Raspberry Pi, OpenCV is installed via package manager (fast, ~5 minutes)."
		echo "      Compiling from source takes 4+ hours and is NOT recommended."
		echo ""
		if AskYesNo "Would you like to install OpenCV?" "n"
		then
			InstallOpenCV
		fi
	else
		echo "	Location: $OPENCV_LOCATION"
	fi
}

InstallOpenCV()
{
	PrintSection "OpenCV Installation"
	
	echo ""
	echo "OpenCV will be installed via package manager (recommended for Raspberry Pi)."
	echo "This is fast (~5 minutes) and includes all modules needed by AlpacaPi."
	echo ""
	echo "Note: Compiling OpenCV from source takes 4+ hours on Raspberry Pi and is NOT recommended."
	echo ""
	
	if ! AskYesNo "Install OpenCV via package manager?" "y"
	then
		echo ""
		echo "OpenCV installation skipped."
		echo "You can install it manually later with: sudo apt-get install libopencv-dev"
		echo ""
		echo "Advanced: If you really need to compile from source (not recommended),"
		echo "you can run the old scripts in archive/scripts/install_opencv*.sh"
		return 1
	fi
	
	InstallOpenCVPackageManager
}

InstallOpenCVPackageManager()
{
	PrintSection "Installing OpenCV via Package Manager"
	
	echo ""
	echo "This will install OpenCV using your system's package manager."
	echo "This is much faster than compiling from source (typically 5-10 minutes)."
	echo ""
	
	#*	Detect package manager
	PACKAGE_MANAGER=""
	if command -v apt-get >/dev/null 2>&1
	then
		PACKAGE_MANAGER="apt"
	elif command -v yum >/dev/null 2>&1
	then
		PACKAGE_MANAGER="yum"
	elif command -v dnf >/dev/null 2>&1
	then
		PACKAGE_MANAGER="dnf"
	elif command -v pacman >/dev/null 2>&1
	then
		PACKAGE_MANAGER="pacman"
	else
		PrintError "No supported package manager found (apt-get, yum, dnf, or pacman)"
		echo ""
		echo "OpenCV package manager installation is only supported on:"
		echo "	- Debian/Ubuntu/Raspberry Pi OS (apt-get)"
		echo "	- Red Hat/CentOS/Fedora (yum/dnf)"
		echo "	- Arch Linux (pacman)"
		echo ""
		echo "For other distributions, you may need to:"
		echo "	- Install OpenCV manually using your distribution's package manager"
		echo "	- Or compile from source (see archive/scripts/install_opencv*.sh)"
		return 1
	fi
	
	echo "Detected package manager: $PACKAGE_MANAGER"
	echo ""
	
	if ! AskYesNo "Install OpenCV via package manager? (requires sudo)" "y"
	then
		return 1
	fi
	
	#*	Install based on package manager
	case "$PACKAGE_MANAGER" in
		apt)
			PrintStep "Updating package lists..."
			sudo apt-get update 2>&1 | FilterAptErrors
			
			PrintStep "Detecting available OpenCV packages..."
			
			#*	Check what OpenCV packages are available and their versions
			OPENCV4_PKG_AVAILABLE=false
			OPENCV3_PKG_AVAILABLE=false
			OPENCV_VERSION_DETECTED=""
			
			#*	Check for libopencv4-dev (explicit OpenCV 4 package)
			if apt-cache show libopencv4-dev >/dev/null 2>&1
			then
				OPENCV_VERSION_DETECTED=$(apt-cache show libopencv4-dev 2>/dev/null | grep -i "^Version:" | head -1 | awk '{print $2}' | cut -d. -f1-2 || echo "")
				if [ -n "$OPENCV_VERSION_DETECTED" ] && echo "$OPENCV_VERSION_DETECTED" | grep -qE "^4\."
				then
					OPENCV4_PKG_AVAILABLE=true
					echo "	Found: libopencv4-dev (OpenCV 4.x)"
				fi
			fi
			
			#*	Check for libopencv-dev (could be OpenCV 3 or 4 depending on Ubuntu version)
			if apt-cache show libopencv-dev >/dev/null 2>&1
			then
				OPENCV_VERSION_DETECTED=$(apt-cache show libopencv-dev 2>/dev/null | grep -i "^Version:" | head -1 | awk '{print $2}' | cut -d. -f1-2 || echo "")
				if [ -n "$OPENCV_VERSION_DETECTED" ]
				then
					if echo "$OPENCV_VERSION_DETECTED" | grep -qE "^4\."
					then
						OPENCV4_PKG_AVAILABLE=true
						echo "	Found: libopencv-dev (OpenCV 4.x - version $OPENCV_VERSION_DETECTED)"
					elif echo "$OPENCV_VERSION_DETECTED" | grep -qE "^3\."
					then
						OPENCV3_PKG_AVAILABLE=true
						echo "	Found: libopencv-dev (OpenCV 3.x - version $OPENCV_VERSION_DETECTED)"
					else
						echo "	Found: libopencv-dev (version $OPENCV_VERSION_DETECTED - will detect after installation)"
					fi
				fi
			fi
			
			PrintStep "Installing OpenCV development packages..."
			
			#*	Install based on what's available (prefer OpenCV 4)
			if [ "$OPENCV4_PKG_AVAILABLE" = true ]
			then
				if apt-cache show libopencv4-dev >/dev/null 2>&1
				then
					PrintStep "Installing OpenCV 4 via package manager (libopencv4-dev)..."
					APT_OUTPUT=$(sudo apt-get install -y libopencv4-dev libopencv-contrib-dev 2>&1)
					APT_EXIT_CODE=$?
				else
					PrintStep "Installing OpenCV 4 via package manager (libopencv-dev contains OpenCV 4)..."
					APT_OUTPUT=$(sudo apt-get install -y libopencv-dev libopencv-contrib-dev 2>&1)
					APT_EXIT_CODE=$?
				fi
				echo "$APT_OUTPUT" | FilterAptErrors
				if [ $APT_EXIT_CODE -eq 0 ]
				then
					INSTALL_SUCCESS=true
				else
					INSTALL_SUCCESS=false
				fi
			elif [ "$OPENCV3_PKG_AVAILABLE" = true ]
			then
				PrintStep "Installing OpenCV 3 via package manager (libopencv-dev)..."
				APT_OUTPUT=$(sudo apt-get install -y libopencv-dev libopencv-contrib-dev 2>&1)
				APT_EXIT_CODE=$?
				echo "$APT_OUTPUT" | FilterAptErrors
				if [ $APT_EXIT_CODE -eq 0 ]
				then
					INSTALL_SUCCESS=true
				else
					INSTALL_SUCCESS=false
				fi
			elif apt-cache show libopencv-dev >/dev/null 2>&1
			then
				PrintStep "Installing OpenCV via package manager (libopencv-dev)..."
				echo "	Note: Version will be detected after installation"
				APT_OUTPUT=$(sudo apt-get install -y libopencv-dev libopencv-contrib-dev 2>&1)
				APT_EXIT_CODE=$?
				echo "$APT_OUTPUT" | FilterAptErrors
				if [ $APT_EXIT_CODE -eq 0 ]
				then
					INSTALL_SUCCESS=true
				else
					INSTALL_SUCCESS=false
				fi
			else
				PrintError "OpenCV packages not available in your package repositories"
				echo ""
				echo "This may happen on:"
				echo "	- Very old distributions"
				echo "	- Minimal installations without universe/multiverse repositories enabled"
				echo "	- Some embedded systems"
				echo ""
				
				#*	Offer fallback to compile from source
				if AskYesNo "Would you like to compile OpenCV from source instead? (takes 4+ hours on Raspberry Pi)" "n"
				then
					echo ""
					echo "Which version would you like to compile?"
					echo "	1) OpenCV 4.5.1 (recommended, newer features)"
					echo "	2) OpenCV 3.3.1 (older, more stable)"
					echo "	3) Cancel"
					echo -n "Enter choice [1-3] (default: 1): "
					read OPENCV_CHOICE
					
					if [ -z "$OPENCV_CHOICE" ]
					then
						OPENCV_CHOICE="1"
					fi
					
					case "$OPENCV_CHOICE" in
						1)
							InstallOpenCV451
							;;
						2)
							InstallOpenCV3
							;;
						*)
							PrintWarning "OpenCV compilation cancelled"
							return 1
							;;
					esac
				else
					echo ""
					echo "OpenCV installation skipped."
					echo "You can try installing it manually later, or compile from source using:"
					echo "	archive/scripts/install_opencv451.sh (for OpenCV 4.5.1)"
					echo "	archive/scripts/install_opencv.sh (for OpenCV 3.3.1)"
					return 1
				fi
			fi
			;;
		yum|dnf)
			PrintStep "Installing OpenCV development packages..."
			if sudo $PACKAGE_MANAGER install -y opencv-devel 2>&1
			then
				INSTALL_SUCCESS=true
			else
				INSTALL_SUCCESS=false
			fi
			;;
		pacman)
			PrintStep "Installing OpenCV development packages..."
			if sudo pacman -S --noconfirm opencv 2>&1
			then
				INSTALL_SUCCESS=true
			else
				INSTALL_SUCCESS=false
			fi
			;;
	esac
	
	if [ "$INSTALL_SUCCESS" = true ]
	then
		sudo ldconfig
		
		#*	Determine which version was actually installed
		OPENCV_INSTALLED_VERSION=""
		if pkg-config --exists opencv4 2>/dev/null
		then
			OPENCV_INSTALLED_VERSION="4"
			OPENCV_VERSION_STRING=$(pkg-config --modversion opencv4 2>/dev/null || echo "4.x")
			PrintSuccess "OpenCV installed via package manager (OpenCV $OPENCV_INSTALLED_VERSION - version $OPENCV_VERSION_STRING)"
		elif pkg-config --exists opencv 2>/dev/null
		then
			OPENCV_VERSION_STRING=$(pkg-config --modversion opencv 2>/dev/null || echo "unknown")
			#*	Check if it's actually OpenCV 4 by looking at version string
			if echo "$OPENCV_VERSION_STRING" | grep -qE "^4\."
			then
				OPENCV_INSTALLED_VERSION="4"
				PrintSuccess "OpenCV installed via package manager (OpenCV 4 - version $OPENCV_VERSION_STRING)"
			else
				OPENCV_INSTALLED_VERSION="3"
				PrintSuccess "OpenCV installed via package manager (OpenCV 3 - version $OPENCV_VERSION_STRING)"
			fi
		fi
		
		#*	Verify installation
		if pkg-config --exists opencv4 2>/dev/null || pkg-config --exists opencv 2>/dev/null
		then
			PrintSuccess "OpenCV installation verified"
		else
			PrintWarning "OpenCV installed but pkg-config not detecting it - may need to rebuild"
		fi
	else
		PrintError "OpenCV installation via package manager failed"
		echo ""
		echo "Possible reasons:"
		echo "	- Packages not available in repositories"
		echo "	- Network/connection issues"
		echo "	- Missing dependencies"
		echo ""
		
		#*	Offer fallback to compile from source
		if AskYesNo "Would you like to compile OpenCV from source instead? (takes 4+ hours on Raspberry Pi)" "n"
		then
			echo ""
			echo "Which version would you like to compile?"
			echo "	1) OpenCV 4.5.1 (recommended, newer features)"
			echo "	2) OpenCV 3.3.1 (older, more stable)"
			echo "	3) Cancel"
			echo -n "Enter choice [1-3] (default: 1): "
			read OPENCV_CHOICE
			
			if [ -z "$OPENCV_CHOICE" ]
			then
				OPENCV_CHOICE="1"
			fi
			
			case "$OPENCV_CHOICE" in
				1)
					InstallOpenCV451
					;;
				2)
					InstallOpenCV3
					;;
				*)
					PrintWarning "OpenCV compilation cancelled"
					return 1
					;;
			esac
		else
			echo ""
			echo "OpenCV installation skipped."
			echo "You can try installing it manually later, or compile from source using:"
			echo "	archive/scripts/install_opencv451.sh (for OpenCV 4.5.1)"
			echo "	archive/scripts/install_opencv.sh (for OpenCV 3.3.1)"
			return 1
		fi
	fi
}

InstallOpenCV451()
{
	PrintSection "Installing OpenCV 4.5.1"
	
	BASE_DIR=`pwd`
	LOGFILENAME="$BASE_DIR/opencvinstall-log.txt"
	echo "Log file: $LOGFILENAME"
	echo "*******************************************************" >> "$LOGFILENAME"
	echo -n "Start time=" >> "$LOGFILENAME"
	date >> "$LOGFILENAME"
	
	OPENCV_INSTALL_DIR="opencv"
	mkdir -p "$OPENCV_INSTALL_DIR"
	cd "$OPENCV_INSTALL_DIR"
	
	OPENCV_TARFILE="opencv-4.5.1.tar.gz"
	OPENCV_DIR="opencv-4.5.1"
	OPENCV_REMOTE_FILE="4.5.1.tar.gz"
	OPENCV_WGET_FILE="https://github.com/opencv/opencv/archive/refs/tags/$OPENCV_REMOTE_FILE"
	
	if [ ! -f "$OPENCV_TARFILE" ]
	then
		PrintStep "Downloading OpenCV 4.5.1..."
		if ! AskYesNo "Download $OPENCV_TARFILE? (large file ~100MB)" "y"
		then
			cd ..
			return 1
		fi
		echo "Downloading $OPENCV_WGET_FILE" >> "$LOGFILENAME"
		wget "$OPENCV_WGET_FILE"
		mv "$OPENCV_REMOTE_FILE" "$OPENCV_TARFILE"
	fi
	
	if [ ! -d "$OPENCV_DIR" ]
	then
		if [ -f "$OPENCV_TARFILE" ]
		then
			PrintStep "Extracting OpenCV..."
			tar xvf "$OPENCV_TARFILE"
		else
			PrintError "OpenCV tar file not found"
			cd ..
			return 1
		fi
	fi
	
	#*	Patch OpenCV 4.5.1 for GCC 11+ compatibility (missing cstdint include)
	#*	Apply patch even if OpenCV was already extracted
	#*	This runs AFTER extraction but BEFORE cmake/make, so fresh installs are automatically patched
	ADE_HEADER=""
	if [ -d "$OPENCV_DIR" ]
	then
		#*	Standard structure: opencv-4.5.1/3rdparty/ade/...
		#*	Note: We're in opencv/ directory, so path is relative to that
		ADE_HEADER="$OPENCV_DIR/3rdparty/ade/ade-0.1.1f/sources/ade/include/ade/typed_graph.hpp"
		if [ ! -f "$ADE_HEADER" ]
		then
			#*	Try alternative: maybe extracted directly as opencv/ (without version subdirectory)
			ADE_HEADER="3rdparty/ade/ade-0.1.1f/sources/ade/include/ade/typed_graph.hpp"
		fi
	fi
	
	if [ -n "$ADE_HEADER" ] && [ -f "$ADE_HEADER" ]
	then
		if ! grep -q "#include <cstdint>" "$ADE_HEADER"
		then
			PrintStep "Patching OpenCV 4.5.1 for GCC 11+ compatibility..."
			PrintStep "Adding missing #include <cstdint> to fix GCC 11+ compilation errors"
			#*	Add #include <cstdint> after line 21 (after typed_metadata.hpp include)
			sed -i '21a#include <cstdint>' "$ADE_HEADER"
			PrintSuccess "Applied GCC compatibility patch"
		else
			PrintSuccess "GCC compatibility patch already applied"
		fi
	elif [ -d "$OPENCV_DIR" ]
	then
		PrintWarning "ADE header not found - patch may not be needed or OpenCV structure is different"
	fi
	
	#*	Note: opencv_contrib is NOT needed - the application only uses standard OpenCV modules
	#*	If you need contrib modules in the future, uncomment the section below
	#*	Download opencv_contrib (optional - not used by AlpacaPi)
	#*	if [ ! -d "opencv_contrib" ]
	#*	then
	#*		PrintStep "Downloading opencv_contrib..."
	#*		git clone https://github.com/opencv/opencv_contrib.git
	#*	fi
	
	if [ -d "$OPENCV_DIR" ]
	then
		if [ ! -d "$OPENCV_DIR/CMakeFiles" ]
		then
			PrintStep "Running cmake (this may take a while)..."
			if ! AskYesNo "Run cmake configuration?" "y"
			then
				cd ..
				return 1
			fi
			echo "Running cmake" >> "$LOGFILENAME"
			time cmake -DBUILD_opencv_cudacodec=OFF "$OPENCV_DIR"
		fi
		
		if [ -f Makefile ]
		then
			MAKE_JOBS=$(GetMakeJobs)
			NUM_CORES=$(DetectCores)
			echo ""
			PrintWarning "========================================================================"
			PrintWarning "IMPORTANT: OpenCV compilation will take a LONG time"
			PrintWarning "========================================================================"
			echo ""
			echo "Please be patient - building OpenCV from source is a time-consuming process:"
			echo ""
			echo "	- Estimated time: 4+ hours on Raspberry Pi"
			echo "	- Estimated time: 5+ hours on Jetson Nano"
			echo "	- Estimated time: 30-60 minutes on modern desktop (with $NUM_CORES cores)"
			echo ""
			echo "The build will use $MAKE_JOBS (all $NUM_CORES CPU cores) for faster compilation."
			echo ""
			echo "You can:"
			echo "	- Leave this running in the background"
			echo "	- Check progress periodically"
			echo "	- The build will continue even if you disconnect from SSH"
			echo ""
			if ! AskYesNo "Proceed with OpenCV build? (This will take a very long time)" "n"
			then
				cd ..
				return 1
			fi
			date >> "$LOGFILENAME"
			time make $MAKE_JOBS all
			
			PrintStep "Installing OpenCV..."
			if ! AskYesNo "Install OpenCV? (requires sudo)" "y"
			then
				cd ..
				return 1
			fi
			sudo make install
			sudo ldconfig
			date >> "$LOGFILENAME"
			PrintSuccess "OpenCV 4.5.1 installation complete"
		else
			PrintError "Makefile is missing"
		fi
	fi
	
	cd ..
}

InstallOpenCV3()
{
	PrintSection "Installing OpenCV 3.3.1"
	
	BASE_DIR=`pwd`
	LOGFILENAME="$BASE_DIR/opencvinstall-log.txt"
	echo "Log file: $LOGFILENAME"
	echo "*******************************************************" >> "$LOGFILENAME"
	echo -n "Start time=" >> "$LOGFILENAME"
	date >> "$LOGFILENAME"
	
	OPENCV_INSTALL_DIR="opencv"
	mkdir -p "$OPENCV_INSTALL_DIR"
	cd "$OPENCV_INSTALL_DIR"
	
	#*	Check for existing versions
	if [ -f "opencv-3.3.1.tar.gz" ]
	then
		OPENCV_TARFILE="opencv-3.3.1.tar.gz"
		OPENCV_DIR="opencv-3.3.1"
		OPENCV_WGET_FILE="https://github.com/opencv/opencv/archive/3.3.1.tar.gz"
		OPENCV_REMOTE_FILE="3.3.1.tar.gz"
	elif [ -f "opencv-3.2.0.tar.gz" ]
	then
		OPENCV_TARFILE="opencv-3.2.0.tar.gz"
		OPENCV_DIR="opencv-3.2.0"
		OPENCV_WGET_FILE="https://github.com/opencv/opencv/archive/3.2.0.tar.gz"
		OPENCV_REMOTE_FILE="3.2.0.tar.gz"
	else
		OPENCV_TARFILE="opencv-3.3.1.tar.gz"
		OPENCV_DIR="opencv-3.3.1"
		OPENCV_WGET_FILE="https://github.com/opencv/opencv/archive/3.3.1.tar.gz"
		OPENCV_REMOTE_FILE="3.3.1.tar.gz"
	fi
	
	if [ ! -f "$OPENCV_TARFILE" ]
	then
		PrintStep "Downloading OpenCV..."
		if ! AskYesNo "Download $OPENCV_TARFILE? (large file ~100MB)" "y"
		then
			cd ..
			return 1
		fi
		echo "Downloading $OPENCV_WGET_FILE" >> "$LOGFILENAME"
		wget "$OPENCV_WGET_FILE"
		mv "$OPENCV_REMOTE_FILE" "$OPENCV_TARFILE"
	fi
	
	if [ ! -d "$OPENCV_DIR" ]
	then
		if [ -f "$OPENCV_TARFILE" ]
		then
			PrintStep "Extracting OpenCV..."
			tar xvf "$OPENCV_TARFILE"
		else
			PrintError "OpenCV tar file not found"
			cd ..
			return 1
		fi
	fi
	
	if [ -d "$OPENCV_DIR" ]
	then
		if [ ! -d "$OPENCV_DIR/CMakeFiles" ]
		then
			PrintStep "Running cmake (this may take a while)..."
			if ! AskYesNo "Run cmake configuration?" "y"
			then
				cd ..
				return 1
			fi
			echo "Running cmake" >> "$LOGFILENAME"
			time cmake -DBUILD_opencv_cudacodec=OFF "$OPENCV_DIR"
		fi
		
		if [ -f Makefile ]
		then
			MAKE_JOBS=$(GetMakeJobs)
			NUM_CORES=$(DetectCores)
			echo ""
			PrintWarning "========================================================================"
			PrintWarning "IMPORTANT: OpenCV compilation will take a LONG time"
			PrintWarning "========================================================================"
			echo ""
			echo "Please be patient - building OpenCV from source is a time-consuming process:"
			echo ""
			echo "	- Estimated time: 4+ hours on Raspberry Pi"
			echo "	- Estimated time: 5+ hours on Jetson Nano"
			echo "	- Estimated time: 30-60 minutes on modern desktop (with $NUM_CORES cores)"
			echo ""
			echo "The build will use $MAKE_JOBS (all $NUM_CORES CPU cores) for faster compilation."
			echo ""
			echo "You can:"
			echo "	- Leave this running in the background"
			echo "	- Check progress periodically"
			echo "	- The build will continue even if you disconnect from SSH"
			echo ""
			if ! AskYesNo "Proceed with OpenCV build? (This will take a very long time)" "n"
			then
				cd ..
				return 1
			fi
			date >> "$LOGFILENAME"
			time make $MAKE_JOBS all
			
			PrintStep "Installing OpenCV..."
			if ! AskYesNo "Install OpenCV? (requires sudo)" "y"
			then
				cd ..
				return 1
			fi
			sudo make install
			sudo ldconfig
			date >> "$LOGFILENAME"
			PrintSuccess "OpenCV 3.x installation complete"
		else
			PrintError "Makefile is missing"
		fi
	fi
	
	cd ..
}

###############################################################################
#	USB Rules Installation (from install_rules.sh)
###############################################################################
#*	Helper function to install a single USB rule file
installRules()
{
	local RULE_DIR="$1"
	local RULES_FILE="$2"
	
	if [ -f "/lib/udev/rules.d/$RULES_FILE" ]
	then
		PrintSuccess "Rules file $RULES_FILE already installed in /lib/udev"
		return 0
	elif [ -f "/etc/udev/rules.d/$RULES_FILE" ]
	then
		PrintSuccess "Rules file $RULES_FILE already installed in /etc/udev"
		return 0
	else
		if [ -f "$RULE_DIR/$RULES_FILE" ]
		then
			PrintStep "Installing $RULES_FILE..."
			sudo install "$RULE_DIR/$RULES_FILE" /lib/udev/rules.d
			return 0
		else
			PrintWarning "Can't find $RULE_DIR/$RULES_FILE"
			return 1
		fi
	fi
}

InstallUSBRules()
{
	PrintSection "USB Device Rules"
	
	RULES_INSTALLED=0
	
	#*	Install rules for each vendor SDK if present
	if CheckFile "." "ZWO_ASI_SDK/lib"
	then
		installRules "ZWO_ASI_SDK/lib" "asi.rules" && RULES_INSTALLED=$((RULES_INSTALLED + 1))
	fi
	
	if CheckFile "." "ZWO_EFW_SDK/lib"
	then
		installRules "ZWO_EFW_SDK/lib" "efw.rules" && RULES_INSTALLED=$((RULES_INSTALLED + 1))
	fi
	
	if CheckFile "." "AtikCamerasSDK"
	then
		installRules "AtikCamerasSDK" "99-atik.rules" && RULES_INSTALLED=$((RULES_INSTALLED + 1))
	fi
	
	if CheckFile "." "toupcamsdk/linux/udev"
	then
		installRules "toupcamsdk/linux/udev" "99-toupcam.rules" && RULES_INSTALLED=$((RULES_INSTALLED + 1))
	fi
	
	if CheckFile "." "FLIR-SDK"
	then
		installRules "FLIR-SDK" "40-flir-spinnaker.rules" && RULES_INSTALLED=$((RULES_INSTALLED + 1))
	fi
	
	if CheckFile "." "QHY/etc/udev/rules.d"
	then
		installRules "QHY/etc/udev/rules.d/" "85-qhyccd.rules" && RULES_INSTALLED=$((RULES_INSTALLED + 1))
	fi
	
	if CheckFile "." "ZWO_EAF_SDK/lib"
	then
		installRules "ZWO_EAF_SDK/lib" "eaf.rules" && RULES_INSTALLED=$((RULES_INSTALLED + 1))
	fi
	
	if [ $RULES_INSTALLED -gt 0 ]
	then
		PrintSuccess "Installed $RULES_INSTALLED USB rule file(s)"
		PrintWarning "You may need to reboot for USB rules to take effect"
	else
		PrintWarning "No USB rules found to install"
	fi
}

###############################################################################
#	Vendor SDK Installation (from install_libraries.sh)
###############################################################################
CheckVendorSDKs()
{
	PrintSection "Vendor SDK Check"
	
	echo "Checking for vendor SDK directories..."
	echo ""
	
	VENDOR_COUNT=0
	
	if CheckFile "." "ZWO_ASI_SDK"
	then
		echo "	✓ ZWO_ASI_SDK (ZWO cameras) - Present"
		VENDOR_COUNT=$((VENDOR_COUNT + 1))
	fi
	
	if CheckFile "." "AtikCamerasSDK"
	then
		echo "	✓ AtikCamerasSDK - Present"
		VENDOR_COUNT=$((VENDOR_COUNT + 1))
	fi
	
	if CheckFile "." "ZWO_EFW_SDK"
	then
		echo "	✓ ZWO_EFW_SDK (ZWO filter wheels) - Present"
		VENDOR_COUNT=$((VENDOR_COUNT + 1))
	fi
	
	if CheckFile "." "QHY"
	then
		echo "	✓ QHY - Present"
		VENDOR_COUNT=$((VENDOR_COUNT + 1))
	fi
	
	if CheckFile "." "toupcamsdk"
	then
		echo "	✓ toupcamsdk - Present"
		VENDOR_COUNT=$((VENDOR_COUNT + 1))
	fi
	
	if CheckFile "." "ZWO_EAF_SDK"
	then
		echo "	✓ ZWO_EAF_SDK (ZWO focusers) - Present"
		VENDOR_COUNT=$((VENDOR_COUNT + 1))
	fi
	
	if CheckFile "." "FLIR-SDK"
	then
		echo "	✓ FLIR-SDK - Present"
		VENDOR_COUNT=$((VENDOR_COUNT + 1))
	fi
	
	if CheckFile "." "PlayerOne"
	then
		echo "	✓ PlayerOne - Present"
		VENDOR_COUNT=$((VENDOR_COUNT + 1))
	else
		echo "	○ PlayerOne - Can be downloaded"
	fi
	
	if CheckFile "." "qsiapi-7.6.0"
	then
		echo "	✓ QSI - Present"
		VENDOR_COUNT=$((VENDOR_COUNT + 1))
	else
		echo "	○ QSI - Can be downloaded"
	fi
	
	#*	WiringPi (ARM/Raspberry Pi only)
	if [ "$ISARM32" = true ] || [ "$ISARM64" = true ]
	then
		if CheckFile "." "WiringPi"
		then
			echo "	✓ WiringPi - Present"
			VENDOR_COUNT=$((VENDOR_COUNT + 1))
		else
			echo "	○ WiringPi - Can be downloaded (Raspberry Pi GPIO)"
		fi
	else
		#*	Show WiringPi on x64 with note that it's ARM-only
		echo "	○ WiringPi - ARM/Raspberry Pi only (not available on x64)"
	fi
	
	if [ $VENDOR_COUNT -eq 0 ]
	then
		PrintWarning "No vendor SDKs found in repository"
		echo ""
		echo "Vendor SDKs are optional and only needed if you use specific devices."
		echo "Some SDKs can be downloaded automatically (PlayerOne, QSI, WiringPi)."
		echo ""
		if [ "$INSTALL_VENDOR_SDKS" = true ] || AskYesNo "Would you like to install/download vendor libraries now?" "n"
		then
			InstallVendorSDKs
		fi
	else
		echo ""
		PrintSuccess "Found $VENDOR_COUNT vendor SDK(s)"
		if [ "$INSTALL_VENDOR_SDKS" = true ] || AskYesNo "Would you like to install vendor libraries now?" "n"
		then
			InstallVendorSDKs
		fi
	fi
}

InstallVendorSDKs()
{
	PrintSection "Installing Vendor SDKs"
	
	LIB_DIR="/usr/lib"
	
	#*	ATIK
	if CheckFile "." "AtikCamerasSDK"
	then
		if AskYesNo "Install AtikCamerasSDK support?" "n"
		then
			InstallATIK
		fi
	fi
	
	#*	ToupTek
	if CheckFile "." "toupcamsdk"
	then
		if AskYesNo "Install ToupTek support?" "n"
		then
			InstallToupTec
		fi
	fi
	
	#*	FLIR
	if CheckFile "." "FLIR-SDK"
	then
		if AskYesNo "Install FLIR support?" "n"
		then
			InstallFlir
		fi
	fi
	
	#*	ZWO EAF
	if CheckFile "." "ZWO_EAF_SDK"
	then
		if AskYesNo "Install ZWO EAF (Focuser) support?" "n"
		then
			InstallZWOEAF
		fi
	fi
	
	#*	ZWO EFW
	if CheckFile "." "ZWO_EFW_SDK"
	then
		if AskYesNo "Install ZWO EFW (Filter Wheel) support?" "n"
		then
			InstallZWOEFW
		fi
	fi
	
	#*	QHY
	if CheckFile "." "QHY"
	then
		if AskYesNo "Install QHY support?" "n"
		then
			InstallQHY
		fi
	fi
	
	#*	PlayerOne
	if CheckFile "." "PlayerOne"
	then
		if AskYesNo "Install PlayerOne support?" "n"
		then
			InstallPlayerOne
		fi
	else
		if AskYesNo "Download and install PlayerOne support? (cameras and filter wheels)" "n"
		then
			InstallPlayerOne
		fi
	fi
	
	#*	QSI
	if CheckFile "." "qsiapi-7.6.0"
	then
		if AskYesNo "Install QSI support?" "n"
		then
			InstallQSI
		fi
	else
		if AskYesNo "Download and install QSI support? (cameras)" "n"
		then
			InstallQSI
		fi
	fi
	
	#*	WiringPi (ARM only)
	if [ "$ISARM32" = true ] || [ "$ISARM64" = true ]
	then
		if CheckFile "." "WiringPi"
		then
			if AskYesNo "Install WiringPi? (Raspberry Pi GPIO library)" "n"
			then
				InstallWiringPi
			fi
		else
			if AskYesNo "Download and install WiringPi? (Raspberry Pi GPIO library)" "n"
			then
				InstallWiringPi
			fi
		fi
	fi
}

InstallATIK()
{
	PrintStep "Installing AtikCamerasSDK..."
	
	ATIK_SDK_DIR="AtikCamerasSDK"
	
	if [ "$ISX64" = true ]
	then
		ATIK_SDK_LIB_DIR="$ATIK_SDK_DIR/lib/linux"
		if [ -d "$ATIK_SDK_LIB_DIR/x64" ]
		then
			ATIK_SDK_LIB_DIR="$ATIK_SDK_LIB_DIR/x64"
		elif [ -d "$ATIK_SDK_LIB_DIR/64" ]
		then
			ATIK_SDK_LIB_DIR="$ATIK_SDK_LIB_DIR/64"
		fi
	elif [ "$ISARM64" = true ] || [ "$ISARM32" = true ]
	then
		ATIK_SDK_LIB_DIR="$ATIK_SDK_DIR/lib/ARM"
		if [ "$ISARM64" = true ]
		then
			if [ -d "$ATIK_SDK_LIB_DIR/64" ]
			then
				ATIK_SDK_LIB_DIR="$ATIK_SDK_LIB_DIR/64"
			elif [ -d "$ATIK_SDK_LIB_DIR/x64" ]
			then
				ATIK_SDK_LIB_DIR="$ATIK_SDK_LIB_DIR/x64"
			fi
		else
			if [ -d "$ATIK_SDK_LIB_DIR/32" ]
			then
				ATIK_SDK_LIB_DIR="$ATIK_SDK_LIB_DIR/32"
			elif [ -d "$ATIK_SDK_LIB_DIR/x86" ]
			then
				ATIK_SDK_LIB_DIR="$ATIK_SDK_LIB_DIR/x86"
			fi
		fi
	fi
	
	if [ -d "$ATIK_SDK_LIB_DIR/NoFlyCapture" ]
	then
		sudo cp -v "$ATIK_SDK_LIB_DIR/NoFlyCapture/libatikcameras.so" "$LIB_DIR/"
		sudo ldconfig
		PrintSuccess "AtikCamerasSDK installed"
		
		#*	Automatically install USB rules for ATIK cameras
		if CheckFile "." "AtikCamerasSDK"
		then
			installRules "AtikCamerasSDK" "99-atik.rules" && sudo udevadm control --reload-rules && sudo udevadm trigger
		fi
	else
		PrintError "Could not find AtikCamerasSDK library directory"
	fi
}

InstallToupTec()
{
	PrintStep "Installing ToupTek SDK..."
	
	if [ "$ISARM32" = true ]
	then
		if [ -d "toupcamsdk/linux/armhf" ]
		then
			sudo cp -v toupcamsdk/linux/armhf/libtoupcam.so "$LIB_DIR/"
			sudo ldconfig
			PrintSuccess "ToupTek SDK installed"
			
			#*	Automatically install USB rules for ToupTek cameras
			if CheckFile "." "toupcamsdk/linux/udev"
			then
				installRules "toupcamsdk/linux/udev" "99-toupcam.rules" && sudo udevadm control --reload-rules && sudo udevadm trigger
			fi
		else
			PrintError "Could not find ToupTek SDK for ARM32"
		fi
	else
		PrintWarning "ToupTek installation only supported for ARM32 (Raspberry Pi)"
	fi
}

InstallFlir()
{
	PrintStep "Installing FLIR SDK..."
	
	#*	Check if FLIR-SDK directory exists
	if [ ! -d "FLIR-SDK" ]
	then
		PrintError "FLIR-SDK directory not found"
		echo ""
		echo "The FLIR SDK is not included in the repository."
		echo "You need to download it separately from FLIR and place it in the FLIR-SDK directory."
		echo ""
		return 1
	fi
	
	#*	Check architecture (FLIR Spinnaker SDK supports x64 and ARM)
	if [ "$ISX64" = true ]
	then
		FLIR_ARCH="x64"
		PrintStep "Detected x64 architecture for FLIR SDK"
	elif [ "$ISARM64" = true ]
	then
		FLIR_ARCH="arm64"
		PrintStep "Detected ARM64 architecture for FLIR SDK"
	elif [ "$ISARM32" = true ]
	then
		FLIR_ARCH="arm32"
		PrintStep "Detected ARM32 architecture for FLIR SDK"
	else
		PrintError "Unsupported architecture for FLIR SDK"
		return 1
	fi
	
	#*	Check for installation script
	if [ -f "FLIR-SDK/install_spinnaker_mls.sh" ]
	then
		cd FLIR-SDK
		PrintStep "Running FLIR Spinnaker SDK installation script..."
		if ./install_spinnaker_mls.sh
		then
			cd ..
			PrintSuccess "FLIR SDK installed"
			
			#*	Automatically install USB rules for FLIR cameras
			if CheckFile "." "FLIR-SDK"
			then
				installRules "FLIR-SDK" "40-flir-spinnaker.rules" && sudo udevadm control --reload-rules && sudo udevadm trigger
			fi
		else
			cd ..
			PrintError "FLIR SDK installation script failed"
			return 1
		fi
	else
		PrintError "FLIR install script not found (install_spinnaker_mls.sh)"
		echo ""
		echo "The FLIR SDK directory exists but the installation script is missing."
		echo "Please ensure you have downloaded the complete FLIR Spinnaker SDK."
		echo ""
		return 1
	fi
}

InstallZWOEAF()
{
	PrintStep "Installing ZWO EAF SDK..."
	
	ZWO_EAF_DIR="ZWO_EAF_SDK"
	
	if [ "$ISX64" = true ]
	then
		ZWO_EAF_LIB_DIR="$ZWO_EAF_DIR/lib/x64"
	elif [ "$ISARM64" = true ]
	then
		ZWO_EAF_LIB_DIR="$ZWO_EAF_DIR/lib/armv8"
	elif [ "$ISARM32" = true ]
	then
		ZWO_EAF_LIB_DIR="$ZWO_EAF_DIR/lib/armv7"
	fi
	
	if [ -d "$ZWO_EAF_LIB_DIR" ]
	then
		sudo cp -v "$ZWO_EAF_LIB_DIR/libEAFFocuser."* "$LIB_DIR/"
		sudo ldconfig
		PrintSuccess "ZWO EAF SDK installed"
		
		#*	Automatically install USB rules for EAF
		if CheckFile "." "ZWO_EAF_SDK/lib"
		then
			installRules "ZWO_EAF_SDK/lib" "eaf.rules" && sudo udevadm control --reload-rules && sudo udevadm trigger
		fi
	else
		PrintError "Could not find ZWO EAF SDK library directory"
	fi
}

InstallZWOEFW()
{
	PrintStep "Installing ZWO EFW SDK..."
	
	EFW_DIR="ZWO_EFW_SDK"
	
	if [ "$ISX64" = true ]
	then
		EFW_LIB_DIR="$EFW_DIR/lib/x64"
	elif [ "$ISARM64" = true ]
	then
		EFW_LIB_DIR="$EFW_DIR/lib/armv8"
	elif [ "$ISARM32" = true ]
	then
		EFW_LIB_DIR="$EFW_DIR/lib/armv7"
	fi
	
	if [ -d "$EFW_LIB_DIR" ]
	then
		#*	Install shared library (.so files) for runtime use
		#*	Note: The Makefile currently uses static libraries (.a files) linked at compile time,
		#*	but installing the .so files ensures compatibility if dynamic linking is used later
		sudo cp -v "$EFW_LIB_DIR/libEFWFilter.so"* "$LIB_DIR/" 2>/dev/null || true
		sudo ldconfig
		PrintSuccess "ZWO EFW SDK installed"
		
		#*	Automatically install USB rules for EFW
		if CheckFile "." "ZWO_EFW_SDK/lib"
		then
			installRules "ZWO_EFW_SDK/lib" "efw.rules" && sudo udevadm control --reload-rules && sudo udevadm trigger
		fi
	else
		PrintError "Could not find ZWO EFW SDK library directory"
	fi
}

InstallQHY()
{
	PrintStep "Installing QHY SDK..."
	
	QHY_SDK_DIR="QHY"
	
	if [ ! -d "$QHY_SDK_DIR" ]
	then
		if AskYesNo "QHY directory not found. Download QHY SDK?" "n"
		then
			mkdir -p "$QHY_SDK_DIR"
			cd "$QHY_SDK_DIR"
			
			if [ "$ISX64" = true ]
			then
				QHY_SUBDIR="200626"
				QHY_TAR_FILE="sdk_linux64_20.06.26.tgz"
			elif [ "$ISARM64" = true ]
			then
				QHY_SUBDIR="200626"
				QHY_TAR_FILE="sdk_Arm64_20.06.26.tgz"
			elif [ "$ISARM32" = true ]
			then
				QHY_SUBDIR="200626"
				QHY_TAR_FILE="sdk_arm32_20.06.26.tgz"
			else
				PrintError "Unsupported platform for QHY"
				cd ..
				return 1
			fi
			
			wget "https://www.qhyccd.com/file/repository/publish/SDK/$QHY_SUBDIR/$QHY_TAR_FILE"
			if [ -f "$QHY_TAR_FILE" ]
			then
				tar -xvf "$QHY_TAR_FILE"
				mv -v sdk*/* .
			fi
			cd ..
		else
			return 1
		fi
	fi
	
	if [ -d "$QHY_SDK_DIR" ]
	then
		if [ -d "$QHY_SDK_DIR/include" ]
		then
			PrintSuccess "QHY SDK already installed"
		else
			cd "$QHY_SDK_DIR"
			if [ -f "install.sh" ]
			then
				chmod 755 install.sh
				sudo ./install.sh
				mkdir -p include
				cp -a -v usr/local/include/* include/
				sudo ldconfig
				PrintSuccess "QHY SDK installed"
			else
				PrintError "QHY install.sh not found"
			fi
			cd ..
		fi
		
		#*	Automatically install USB rules for QHY cameras
		if CheckFile "." "QHY/etc/udev/rules.d"
		then
			installRules "QHY/etc/udev/rules.d/" "85-qhyccd.rules" && sudo udevadm control --reload-rules && sudo udevadm trigger
		fi
	fi
}

InstallPlayerOne()
{
	PrintStep "Installing PlayerOne SDK..."
	
	PLAYERONE_DIR="PlayerOne"
	LIB_DIR="/usr/lib"
	
	if [ ! -d "$PLAYERONE_DIR" ]
	then
		mkdir "$PLAYERONE_DIR"
	fi
	
	PLAYERONE_DRIVER_URL="https://player-one-astronomy.com/download/softwares/"
	PLAYERONE_LATESTVER_CAM="PlayerOne_Camera_SDK_Linux_V3.6.2"
	PLAYERONE_LATESTVER_CAM_TAR="PlayerOne_Camera_SDK_Linux_V3.6.2.tar.gz"
	PLAYERONE_LATESTVER_FW="PlayerOne_FilterWheel_SDK_Linux_V1.2.0"
	PLAYERONE_LATESTVER_FW_TAR="PlayerOne_FilterWheel_SDK_Linux_V1.2.0.tar.gz"
	
	#*	Determine platform
	if [ "$ISX64" = true ]
	then
		PLATFORM="x64"
	elif [ "$ISARM32" = true ]
	then
		PLATFORM="arm32"
	elif [ "$ISARM64" = true ]
	then
		PLATFORM="arm64"
	fi
	
	cd "$PLAYERONE_DIR"
	
	#*	Install Camera SDK
	if [ ! -d "$PLAYERONE_LATESTVER_CAM" ]
	then
		if [ ! -f "$PLAYERONE_LATESTVER_CAM_TAR" ]
		then
			PrintStep "Downloading PlayerOne Camera SDK..."
			wget "$PLAYERONE_DRIVER_URL$PLAYERONE_LATESTVER_CAM_TAR"
		fi
		if [ -f "$PLAYERONE_LATESTVER_CAM_TAR" ]
		then
			tar -xvf "$PLAYERONE_LATESTVER_CAM_TAR"
		fi
	fi
	
	if [ -d "$PLAYERONE_LATESTVER_CAM" ]
	then
		CAMERA_LIB_PATH="$PLAYERONE_DIR/$PLAYERONE_LATESTVER_CAM/lib/$PLATFORM"
		if [ -d "$CAMERA_LIB_PATH" ]
		then
			sudo cp -p -v "$CAMERA_LIB_PATH"/* "$LIB_DIR"
			sudo ldconfig
			PrintSuccess "PlayerOne Camera SDK installed"
		fi
		
		#*	Install rules
		PLAYER_RULES_FILE="99-player_one_astronomy.rules"
		RULES_PATH="$PLAYERONE_DIR/$PLAYERONE_LATESTVER_CAM/udev/$PLAYER_RULES_FILE"
		if [ -f "$RULES_PATH" ]
		then
			sudo cp -v -p "$RULES_PATH" /lib/udev/rules.d/
			sudo udevadm control --reload-rules && sudo udevadm trigger
			PrintSuccess "PlayerOne USB rules installed"
		fi
	fi
	
	#*	Install Filter Wheel SDK
	if [ ! -d "$PLAYERONE_LATESTVER_FW" ]
	then
		if [ ! -f "$PLAYERONE_LATESTVER_FW_TAR" ]
		then
			PrintStep "Downloading PlayerOne Filter Wheel SDK..."
			wget "$PLAYERONE_DRIVER_URL$PLAYERONE_LATESTVER_FW_TAR"
		fi
		if [ -f "$PLAYERONE_LATESTVER_FW_TAR" ]
		then
			tar -xvf "$PLAYERONE_LATESTVER_FW_TAR"
		fi
	fi
	
	if [ -d "$PLAYERONE_LATESTVER_FW" ]
	then
		FILTERWHEEL_LIB_PATH="$PLAYERONE_DIR/$PLAYERONE_LATESTVER_FW/lib/$PLATFORM"
		if [ -d "$FILTERWHEEL_LIB_PATH" ]
		then
			sudo cp -p -v "$FILTERWHEEL_LIB_PATH"/* "$LIB_DIR"
			sudo ldconfig
			PrintSuccess "PlayerOne Filter Wheel SDK installed"
		fi
	fi
	
	cd ..
}

InstallQSI()
{
	PrintStep "Installing QSI SDK..."
	
	QSI_FOLDER="qsiapi-7.6.0"
	QSI_TAR_FILE="qsiapi-7.6.0.tar.gz"
	FTDI_FOLDER="libftd2xx"
	
	#*	Determine platform and FTDI file
	if [ "$ISX64" = true ]
	then
		PLATFORM="x64"
		FTDI_TAR_FILE="libftd2xx-x86_64-1.4.24.tgz"
	elif [ "$ISARM32" = true ]
	then
		PLATFORM="armv7"
		FTDI_TAR_FILE="libftd2xx-arm-v7-hf-1.4.24.tgz"
	elif [ "$ISARM64" = true ]
	then
		PLATFORM="armv8"
		FTDI_TAR_FILE="libftd2xx-arm-v8-1.4.24.tgz"
	fi
	
	#*	Install libudev-dev if needed
	if ! CheckCommand pkg-config
	then
		sudo apt-get install -y libudev-dev
	fi
	
	#*	Install FTDI library
	if [ ! -d "$FTDI_FOLDER" ]
	then
		mkdir -p "$FTDI_FOLDER"
	fi
	
	cd "$FTDI_FOLDER"
	if [ ! -f "$FTDI_TAR_FILE" ]
	then
		PrintStep "Downloading FTDI library..."
		wget "https://ftdichip.com/wp-content/uploads/2021/09/$FTDI_TAR_FILE"
	fi
	
	if [ ! -d "release" ]
	then
		if [ -f "$FTDI_TAR_FILE" ]
		then
			tar -xvf "$FTDI_TAR_FILE"
		fi
	fi
	
	if [ -d "release/build" ]
	then
		cd release/build
		sudo cp libftd2xx.* /usr/local/lib
		sudo chmod 0755 /usr/local/lib/libftd2xx.so.1.4.24
		sudo ln -sf /usr/local/lib/libftd2xx.so.1.4.24 /usr/local/lib/libftd2xx.so
		cd ../..
	fi
	cd ..
	
	#*	Install QSI API
	if [ ! -d "$QSI_FOLDER" ]
	then
		if [ ! -f "$QSI_TAR_FILE" ]
		then
			PrintStep "Downloading QSI API..."
			wget "https://qsimaging.com/downloads/qsiapi-7.6.0.tar.gz"
		fi
		if [ -f "$QSI_TAR_FILE" ]
		then
			tar -xvf "$QSI_TAR_FILE"
		fi
	fi
	
	if [ -d "$QSI_FOLDER" ]
	then
		cd "$QSI_FOLDER"
		./configure
		MAKE_JOBS=$(GetMakeJobs)
		PrintStep "Building QSI SDK with $MAKE_JOBS (using $(DetectCores) cores)..."
		make $MAKE_JOBS all
		sudo make install
		sudo ldconfig -v
		cd ..
		PrintSuccess "QSI SDK installed"
	fi
}

InstallWiringPi()
{
	PrintStep "Installing WiringPi..."
	
	if [ ! -d "WiringPi" ]
	then
		PrintStep "Downloading WiringPi..."
		git clone https://github.com/WiringPi/WiringPi
	fi
	
	if [ -d "WiringPi" ]
	then
		cd WiringPi
		./build
		cd ..
		PrintSuccess "WiringPi installed"
	fi
}

###############################################################################
#	Extra Data Download (from download_extra_data.sh)
###############################################################################
DownloadExtraData()
{
	PrintSection "Extra Data for SkyTravel"
	
	if ! AskYesNo "Download extra data for SkyTravel? (OpenNGC, Milky Way outline)" "n"
	then
		return 0
	fi
	
	D3_DIR="d3-celestial"
	OPEN_NGC_DIR="OpenNGC"
	
	#*	Download OpenNGC
	if [ ! -d "$OPEN_NGC_DIR" ]
	then
		PrintStep "Downloading OpenNGC..."
		git clone https://github.com/mattiaverga/OpenNGC
		PrintSuccess "OpenNGC downloaded"
	else
		PrintSuccess "OpenNGC already present"
	fi
	
	#*	Download d3-celestial (Milky Way outline)
	if [ ! -d "$D3_DIR" ]
	then
		PrintStep "Downloading d3-celestial (Milky Way outline)..."
		git clone https://github.com/ofrohn/d3-celestial.git
		PrintSuccess "d3-celestial downloaded"
	else
		PrintSuccess "d3-celestial already present"
	fi
}

###############################################################################
#	Select Drivers to Build
###############################################################################
SelectDrivers()
{
	PrintSection "Driver Selection"
	
	echo "Select which drivers to include in the AlpacaPi build:"
	echo ""
	
	#*	Camera drivers
	BUILD_ZWO_CAMERA=false
	if CheckFile "." "ZWO_ASI_SDK"
	then
		if AskYesNo "Include ZWO ASI camera support?" "y"
		then
			BUILD_ZWO_CAMERA=true
		fi
	else
		echo "	○ ZWO ASI cameras - SDK not found (skipped)"
	fi
	
	#*	Filter wheel drivers
	BUILD_ZWO_FILTERWHEEL=false
	if CheckFile "." "ZWO_EFW_SDK"
	then
		if AskYesNo "Include ZWO EFW filter wheel support?" "y"
		then
			BUILD_ZWO_FILTERWHEEL=true
		fi
	else
		echo "	○ ZWO EFW filter wheel - SDK not found (skipped)"
	fi
	
	#*	Focuser drivers
	BUILD_ZWO_FOCUSER=false
	if CheckFile "." "ZWO_EAF_SDK"
	then
		if AskYesNo "Include ZWO EAF focuser support?" "y"
		then
			BUILD_ZWO_FOCUSER=true
		fi
	else
		echo "	○ ZWO EAF focuser - SDK not found (skipped)"
	fi
	
	BUILD_MOONLITE_FOCUSER=false
	if AskYesNo "Include MoonLite focuser support? (No external SDK required)" "y"
	then
		BUILD_MOONLITE_FOCUSER=true
	fi
	
	#*	Rotator drivers
	BUILD_ROTATOR=false
	if AskYesNo "Include rotator support? (NiteCrawler)" "y"
	then
		BUILD_ROTATOR=true
	fi
	
	#*	Calibration control
	BUILD_CALIBRATION=false
	if AskYesNo "Include calibration control? (Flat panel control)" "y"
	then
		BUILD_CALIBRATION=true
	fi
	
	#*	Telescope mount drivers
	BUILD_LX200_TELESCOPE=false
	if AskYesNo "Include LX200 telescope mount support? (Supported - tracking on/off not implemented)" "n"
	then
		BUILD_LX200_TELESCOPE=true
	fi
	
	BUILD_SKYWATCHER_TELESCOPE=false
	if AskYesNo "Include SkyWatcher telescope mount support? (Not finished - not implemented)" "n"
	then
		BUILD_SKYWATCHER_TELESCOPE=true
	fi
	
	#*	Export for use in BuildAlpacaPi
	export BUILD_ZWO_CAMERA
	export BUILD_ZWO_FILTERWHEEL
	export BUILD_ZWO_FOCUSER
	export BUILD_MOONLITE_FOCUSER
	export BUILD_ROTATOR
	export BUILD_CALIBRATION
	export BUILD_LX200_TELESCOPE
	export BUILD_SKYWATCHER_TELESCOPE
	
	#*	Display summary
	echo ""
	echo "Selected drivers:"
	[ "$BUILD_ZWO_CAMERA" = true ] && echo "	✓ ZWO ASI cameras"
	[ "$BUILD_ZWO_FILTERWHEEL" = true ] && echo "	✓ ZWO EFW filter wheel"
	[ "$BUILD_ZWO_FOCUSER" = true ] && echo "	✓ ZWO EAF focuser"
	[ "$BUILD_MOONLITE_FOCUSER" = true ] && echo "	✓ MoonLite focuser"
	[ "$BUILD_ROTATOR" = true ] && echo "	✓ Rotator (NiteCrawler)"
	[ "$BUILD_CALIBRATION" = true ] && echo "	✓ Calibration control"
	[ "$BUILD_LX200_TELESCOPE" = true ] && echo "	✓ LX200 telescope mount"
	[ "$BUILD_SKYWATCHER_TELESCOPE" = true ] && echo "	✓ SkyWatcher telescope mount"
	echo ""
}

###############################################################################
#	Build AlpacaPi (from build_all.sh)
###############################################################################
BuildAlpacaPi()
{
	PrintSection "Building AlpacaPi"
	
	#*	Prompt for driver selection
	SelectDrivers
	
	if ! AskYesNo "Build AlpacaPi now? (This will compile all components)" "n"
	then
		return 0
	fi
	
	LOGFILENAME="AlpacaPi_buildlog.txt"
	mkdir -p Objectfiles
	
	rm -f "$LOGFILENAME"
	echo "*******************************************" >> "$LOGFILENAME"
	echo -n "Start time = " >> "$LOGFILENAME"
	date >> "$LOGFILENAME"
	
	#*	Determine cores to use (detect automatically)
	CORES=$(GetMakeJobs)
	NUM_CORES=$(DetectCores)
	PrintStep "Using $CORES (detected $NUM_CORES CPU cores) for parallel compilation"
	
	#*	Check for OpenCV
	OPENCV_V3_OK=false
	OPENCV_V4_OK=false
	
	if [ -d "/usr/include/opencv" ] || [ -d "/usr/local/include/opencv" ] || [ -d "/usr/include/opencv2" ]
	then
		OPENCV_V3_OK=true
		PrintSuccess "OpenCV 3 detected"
	fi
	
	if [ -d "/usr/include/opencv4" ] || [ -d "/usr/local/include/opencv4" ]
	then
		OPENCV_V4_OK=true
		PrintSuccess "OpenCV 4 detected"
	fi
	
	if [ "$OPENCV_V3_OK" = false ] && [ "$OPENCV_V4_OK" = false ]
	then
		PrintWarning "OpenCV not found - some components may not build"
	fi
	
	#*	Build client (no OpenCV required)
	PrintStep "Building client..."
	make clean >/dev/null 2>&1
	if make $CORES client >/dev/null 2>&1
	then
		PrintSuccess "Client built successfully"
	else
		PrintWarning "Client build had issues (check log)"
	fi
	
	#*	Build OpenCV 3 components
	if [ "$OPENCV_V3_OK" = true ]
	then
		PrintStep "Building OpenCV 3 components..."
		
		for target in camera domectrl focuser rorpi switch sky
		do
			PrintStep "Building $target..."
			make clean >/dev/null 2>&1
			make $CORES "$target" >/dev/null 2>&1
		done
		
		if [ "$ISARM32" = true ] || [ "$ISARM64" = true ]
		then
			make clean >/dev/null 2>&1
			make $CORES calib >/dev/null 2>&1
		fi
	fi
	
	#*	Build OpenCV 4 components
	if [ "$OPENCV_V4_OK" = true ]
	then
		PrintStep "Building OpenCV 4 components..."
		
		for target in cameracv4 domectrlcv4 focusercv4 picv4 switchcv4 skycv4
		do
			PrintStep "Building $target..."
			make clean >/dev/null 2>&1
			make $CORES "$target" >/dev/null 2>&1
		done
		
		if [ "$ISARM32" = true ] || [ "$ISARM64" = true ]
		then
			make clean >/dev/null 2>&1
			make $CORES calibcv4 >/dev/null 2>&1
		fi
		
		#*	Build server
		if [ ! -f "alpacapi" ]
		then
			if [ "$ISARM64" = true ]
			then
				make clean >/dev/null 2>&1
				make $CORES pi64 >/dev/null 2>&1
			fi
		fi
	fi
	
	#*	Build server based on platform with selective drivers
	#*	Create a custom Makefile that conditionally includes drivers based on user selections
	PrintStep "Building AlpacaPi server with selected drivers..."
	
	#*	Install USB rules for ZWO cameras if ZWO camera support is selected
	if [ "$BUILD_ZWO_CAMERA" = true ]
	then
		if CheckFile "." "ZWO_ASI_SDK/lib"
		then
			PrintStep "Installing USB rules for ZWO ASI cameras..."
			installRules "ZWO_ASI_SDK/lib" "asi.rules" && sudo udevadm control --reload-rules && sudo udevadm trigger
			
			#*	Install ASI shared library for runtime use
			#*	Note: The Makefile uses static libraries (.a files) linked at compile time,
			#*	but installing the .so files ensures the SDK can access USB devices at runtime
			if [ "$ISX64" = true ]
			then
				ASI_LIB_DIR="ZWO_ASI_SDK/lib/x64"
			elif [ "$ISARM64" = true ]
			then
				ASI_LIB_DIR="ZWO_ASI_SDK/lib/armv8"
			elif [ "$ISARM32" = true ]
			then
				ASI_LIB_DIR="ZWO_ASI_SDK/lib/armv7"
			fi
			
			if [ -d "$ASI_LIB_DIR" ]
			then
				PrintStep "Installing ZWO ASI SDK shared library..."
				sudo cp -v "$ASI_LIB_DIR/libASICamera2.so"* /usr/lib/ 2>/dev/null || true
				sudo ldconfig
				PrintSuccess "ZWO ASI SDK shared library installed"
			fi
		fi
	fi
	
	#*	Create temporary Makefile snippet for selective builds
	CUSTOM_MAKEFILE=".Makefile.custom"
	
	#*	Build the custom Makefile with conditional logic
	cat > "$CUSTOM_MAKEFILE" << EOF
#*	Temporary Makefile for selective driver builds
#*	Auto-generated by setup_complete.sh
#*	Includes the original Makefile and creates a custom target

include Makefile

#*	Custom target with selective drivers
alpacapi_selective:	DEFINEFLAGS		+=	-D_ALPACA_PI_
alpacapi_selective:	DEFINEFLAGS		+=	-D_INCLUDE_ALPACA_EXTENSIONS_
alpacapi_selective:	DEFINEFLAGS		+=	-D_INCLUDE_HTTP_HEADER_
alpacapi_selective:	DEFINEFLAGS		+=	-D_USE_CAMERA_READ_THREAD_
alpacapi_selective:	DEFINEFLAGS		+=	-D_INCLUDE_MILLIS_
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_DISCOVERY_QUERRY_
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_FITS_
alpacapi_selective:	DEFINEFLAGS		+=	-D_USE_OPENCV_
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_CTRL_IMAGE_
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_LIVE_CONTROLLER_

EOF
	
	#*	Add conditional driver flags
	if [ "$BUILD_ZWO_CAMERA" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_CAMERA_
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_ASI_
EOF
	fi
	
	if [ "$BUILD_ZWO_FILTERWHEEL" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_FILTERWHEEL_
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_FILTERWHEEL_ZWO_
EOF
	fi
	
	if [ "$BUILD_ZWO_FOCUSER" = true ] || [ "$BUILD_MOONLITE_FOCUSER" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_FOCUSER_
EOF
		if [ "$BUILD_ZWO_FOCUSER" = true ]
		then
			cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_FOCUSER_ZWO_
EOF
		fi
		if [ "$BUILD_MOONLITE_FOCUSER" = true ]
		then
			cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_FOCUSER_MOONLITE_
EOF
		fi
	fi
	
	if [ "$BUILD_ROTATOR" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_ROTATOR_
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_ROTATOR_NITECRAWLER_
EOF
	fi
	
	if [ "$BUILD_CALIBRATION" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_CALIBRATION_
EOF
	fi
	
	if [ "$BUILD_LX200_TELESCOPE" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_TELESCOPE_
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_TELESCOPE_LX200_
EOF
	fi
	
	if [ "$BUILD_SKYWATCHER_TELESCOPE" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_TELESCOPE_
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_TELESCOPE_SKYWATCH_
EOF
	fi
	
	#*	Add object dependencies (always include base objects)
	cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	$(DRIVER_OBJECTS)				\
			$(HELPER_OBJECTS)				\
			$(SERIAL_OBJECTS)				\
			$(SOCKET_OBJECTS)				\
			$(LIVE_WINDOW_OBJECTS)

EOF
	
	#*	Add conditional object dependencies
	if [ "$BUILD_ZWO_CAMERA" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	$(CAMERA_DRIVER_OBJECTS)		\
			$(ASI_CAMERA_OBJECTS)
EOF
	fi
	
	if [ "$BUILD_CALIBRATION" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	$(CALIBRATION_DRIVER_OBJECTS)
EOF
	fi
	
	if [ "$BUILD_ZWO_FILTERWHEEL" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	$(FILTERWHEEL_DRIVER_OBJECTS)	\
			$(ZWO_EFW_OBJECTS)
EOF
	fi
	
	if [ "$BUILD_ZWO_FOCUSER" = true ] || [ "$BUILD_MOONLITE_FOCUSER" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	$(FOCUSER_DRIVER_OBJECTS)
EOF
		if [ "$BUILD_ZWO_FOCUSER" = true ]
		then
			cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	$(ZWO_EAF_LIB_DIR)libEAFFocuser.a
EOF
		fi
	fi
	
	#*	Build link command with conditional objects
	#*	Start with base objects (always included)
	LINK_OBJECTS="\$(DRIVER_OBJECTS) \$(HELPER_OBJECTS) \$(SERIAL_OBJECTS) \$(SOCKET_OBJECTS) \$(LIVE_WINDOW_OBJECTS)"
	LINK_LIBS="\$(OPENCV_LINK) -ludev -lusb-1.0 -lpthread -lcfitsio"
	
	#*	Add conditional objects and libraries
	if [ "$BUILD_ZWO_CAMERA" = true ]
	then
		LINK_OBJECTS="$LINK_OBJECTS \$(CAMERA_DRIVER_OBJECTS) \$(ASI_CAMERA_OBJECTS)"
	fi
	
	if [ "$BUILD_CALIBRATION" = true ]
	then
		LINK_OBJECTS="$LINK_OBJECTS \$(CALIBRATION_DRIVER_OBJECTS)"
	fi
	
	if [ "$BUILD_ZWO_FILTERWHEEL" = true ]
	then
		LINK_OBJECTS="$LINK_OBJECTS \$(FILTERWHEEL_DRIVER_OBJECTS) \$(ZWO_EFW_OBJECTS)"
	fi
	
	if [ "$BUILD_ZWO_FOCUSER" = true ] || [ "$BUILD_MOONLITE_FOCUSER" = true ]
	then
		LINK_OBJECTS="$LINK_OBJECTS \$(FOCUSER_DRIVER_OBJECTS)"
		if [ "$BUILD_ZWO_FOCUSER" = true ]
		then
			LINK_OBJECTS="$LINK_OBJECTS \$(ZWO_EAF_LIB_DIR)libEAFFocuser.a"
		fi
	fi
	
	#*	Add link command (single command with all objects)
	cat >> "$CUSTOM_MAKEFILE" << EOF
	\$(LINK)  									\\
		$LINK_OBJECTS				\\
		$LINK_LIBS					\\
		-o alpacapi

EOF
	
	#*	Try building with custom Makefile, fall back to standard if it fails
	BUILD_SUCCESS=false
	if [ "$ISARM64" = true ] || [ "$ISARM32" = true ] || [ "$ISX64" = true ]
	then
		make clean >/dev/null 2>&1
		if make -f "$CUSTOM_MAKEFILE" $CORES alpacapi_selective >/dev/null 2>&1
		then
			BUILD_SUCCESS=true
			PrintSuccess "Built with selective drivers"
		else
			PrintWarning "Selective build failed, falling back to default build"
		fi
	fi
	
	#*	Fall back to standard build if custom build failed
	if [ "$BUILD_SUCCESS" = false ]
	then
		if [ "$ISARM64" = true ]
		then
			make clean >/dev/null 2>&1
			make $CORES pi64 >/dev/null 2>&1
		elif [ "$ISARM32" = true ]
		then
			make clean >/dev/null 2>&1
			make $CORES pi >/dev/null 2>&1
		else
			make clean >/dev/null 2>&1
			make $CORES alpacapi >/dev/null 2>&1
		fi
	fi
	
	#*	Clean up temporary Makefile
	rm -f "$CUSTOM_MAKEFILE"
	
	#*	Build additional components
	if [ "$ISARM32" = true ] || [ "$ISARM64" = true ]
	then
		PrintStep "Building Raspberry Pi specific components..."
		make clean >/dev/null 2>&1
		make $CORES topens >/dev/null 2>&1
		make clean >/dev/null 2>&1
		make $CORES pmc8 >/dev/null 2>&1
	fi
	
	#*	Check results
	echo -n "End time = " >> "$LOGFILENAME"
	date >> "$LOGFILENAME"
	
	if [ -f "alpacapi" ]
	then
		PrintSuccess "AlpacaPi server built successfully!"
		echo "	Log saved as $LOGFILENAME"
		
		#*	Check what features were built into alpacapi
		echo ""
		echo "Features built into alpacapi server:"
		if nm alpacapi 2>/dev/null | grep -q "FilterwheelZWO\|CreateFilterWheelObjects_ZWO"
		then
			echo "	✓ Filter Wheel support (ZWO EFW)"
		fi
		if nm alpacapi 2>/dev/null | grep -q "FocuserZWO\|CreateFocuserObjects_ZWO"
		then
			echo "	✓ Focuser support (ZWO EAF)"
		fi
		if nm alpacapi 2>/dev/null | grep -q "CameraZWO\|CreateCameraObjects_ZWO"
		then
			echo "	✓ Camera support (ZWO ASI)"
		fi
	else
		PrintWarning "AlpacaPi server build may have failed (check $LOGFILENAME)"
	fi
	
	#*	Show what was built
	echo ""
	echo "Built components:"
	ls -lt | grep -E "^-" | head -10
	
	#*	Show client apps that were built
	echo ""
	echo "Client applications built:"
	CLIENT_APPS_BUILT=0
	if [ -f "client" ]
	then
		echo "	✓ client (command-line Alpaca client)"
		CLIENT_APPS_BUILT=$((CLIENT_APPS_BUILT + 1))
	fi
	if [ -f "camera" ] || [ -f "cameracv4" ]
	then
		if [ -f "camera" ]
		then
			echo "	✓ camera (Camera GUI - includes filter wheel support)"
		fi
		if [ -f "cameracv4" ]
		then
			echo "	✓ cameracv4 (Camera GUI - OpenCV 4 - includes filter wheel support)"
		fi
		CLIENT_APPS_BUILT=$((CLIENT_APPS_BUILT + 1))
	fi
	if [ -f "domectrl" ] || [ -f "domectrlcv4" ]
	then
		if [ -f "domectrl" ]
		then
			echo "	✓ domectrl (Dome control GUI)"
		fi
		if [ -f "domectrlcv4" ]
		then
			echo "	✓ domectrlcv4 (Dome control GUI - OpenCV 4)"
		fi
		CLIENT_APPS_BUILT=$((CLIENT_APPS_BUILT + 1))
	fi
	if [ -f "focuser" ] || [ -f "focusercv4" ]
	then
		if [ -f "focuser" ]
		then
			echo "	✓ focuser (Focuser GUI)"
		fi
		if [ -f "focusercv4" ]
		then
			echo "	✓ focusercv4 (Focuser GUI - OpenCV 4)"
		fi
		CLIENT_APPS_BUILT=$((CLIENT_APPS_BUILT + 1))
	fi
	if [ -f "switch" ] || [ -f "switchcv4" ]
	then
		if [ -f "switch" ]
		then
			echo "	✓ switch (Switch control GUI)"
		fi
		if [ -f "switchcv4" ]
		then
			echo "	✓ switchcv4 (Switch control GUI - OpenCV 4)"
		fi
		CLIENT_APPS_BUILT=$((CLIENT_APPS_BUILT + 1))
	fi
	if [ -f "sky" ] || [ -f "skycv4" ]
	then
		if [ -f "sky" ]
		then
			echo "	✓ sky (SkyTravel star chart)"
		fi
		if [ -f "skycv4" ]
		then
			echo "	✓ skycv4 (SkyTravel star chart - OpenCV 4)"
		fi
		CLIENT_APPS_BUILT=$((CLIENT_APPS_BUILT + 1))
	fi
	if [ $CLIENT_APPS_BUILT -eq 0 ]
	then
		PrintWarning "No client applications were built (OpenCV may be missing)"
		echo "	Note: Client apps require OpenCV to be installed"
		echo "	Run the setup script again to install OpenCV if needed"
	fi
}

###############################################################################
#	Remove FITS Library (from remove_fits.sh)
###############################################################################
RemoveFITS()
{
	PrintSection "Remove FITS Library (cfitsio)"
	
	PrintWarning "This will remove cfitsio from your system"
	echo "The purpose of this is to prepare for installing a new version."
	echo ""
	
	if ! AskYesNo "Are you sure you want to remove cfitsio library?" "n"
	then
		return 0
	fi
	
	PrintStep "Removing FITS library files..."
	
	if [ -f "/usr/local/include/fitsio.h" ]
	then
		sudo rm -v /usr/local/lib/libcfitsio*
		sudo rm -v /usr/local/include/fitsio*.h
		sudo rm -v /usr/local/include/drvrsmem.h
		sudo rm -v /usr/local/include/longnam.h
		PrintSuccess "FITS library files removed from /usr/local"
	fi
	
	PrintStep "Removing local FITS directories and files..."
	rm -R -v cfitsio-*/ 2>/dev/null || true
	rm -v cfitsio_latest.tar.gz 2>/dev/null || true
	
	PrintSuccess "FITS library removal complete"
}

###############################################################################
#	Uninstall AlpacaPi Components
###############################################################################
UninstallAlpacaPi()
{
	PrintSection "AlpacaPi Uninstall"
	
	PrintWarning "This will remove AlpacaPi components from your system"
	echo ""
	echo "What will be removed:"
	echo "	- Vendor SDK libraries (from /usr/lib)"
	echo "	- USB device rules (from /lib/udev/rules.d/)"
	echo "	- FITS library (cfitsio) - if installed from source"
	echo "	- Built binaries (alpacapi and other executables)"
	echo "	- Downloaded SDK folders (QHY, PlayerOne, QSI, WiringPi - optional)"
	echo ""
	echo "What will NOT be removed:"
	echo "	- Repository SDK folders (ZWO_ASI_SDK, AtikCamerasSDK, ZWO_EFW_SDK, ZWO_EAF_SDK, FLIR-SDK, toupcamsdk)"
	echo "	- System libraries (libusb, libudev, etc.) - may be used by other software"
	echo "	- Build tools (gcc, g++, make, etc.) - may be used by other software"
	echo ""
	echo "OpenCV removal (optional):"
	echo "	- OpenCV installed via package manager - can be removed (optional)"
	echo "	- OpenCV compiled from source - can be removed (optional)"
	echo ""
	
	if ! AskYesNo "Are you sure you want to uninstall AlpacaPi components?" "n"
	then
		echo "Uninstall cancelled."
		return 0
	fi
	
	REMOVED_COUNT=0
	
	#*	Remove vendor SDK libraries from /usr/lib
	PrintStep "Removing vendor SDK libraries..."
	VENDOR_LIBS=(
		"libASICamera2.so"
		"libEFWFilter.so"
		"libatikcameras.so"
		"libtoupcam.so"
		"libEAFFocuser.so"
		"libftd2xx.so"
		"libftd2xx.so.1.4.24"
	)
	
	#*	PlayerOne libraries (pattern matching)
	for lib in /usr/lib/libPlayerOne*.so*; do
		if [ -f "$lib" ]
		then
			VENDOR_LIBS+=("$(basename "$lib")")
		fi
	done
	
	#*	QHY libraries (pattern matching)
	for lib in /usr/lib/libqhy*.so*; do
		if [ -f "$lib" ]
		then
			VENDOR_LIBS+=("$(basename "$lib")")
		fi
	done
	
	#*	QSI libraries (pattern matching)
	for lib in /usr/lib/libqsi*.so*; do
		if [ -f "$lib" ]
		then
			VENDOR_LIBS+=("$(basename "$lib")")
		fi
	done
	
	for lib in "${VENDOR_LIBS[@]}"
	do
		if [ -f "/usr/lib/$lib" ]
		then
			sudo rm -v "/usr/lib/$lib" && REMOVED_COUNT=$((REMOVED_COUNT + 1))
		fi
	done
	
	#*	Remove QSI/QHY libraries from /usr/local/lib (if installed there)
	for lib in /usr/local/lib/libqsi*.so* /usr/local/lib/libqhy*.so* /usr/local/lib/libftd2xx*.so*; do
		if [ -f "$lib" ]
		then
			sudo rm -v "$lib" && REMOVED_COUNT=$((REMOVED_COUNT + 1))
		fi
	done
	
	#*	Remove QSI headers from /usr/local/include (if installed via make install)
	if [ -d "/usr/local/include/qsiapi" ]
	then
		sudo rm -rf /usr/local/include/qsiapi
		PrintSuccess "Removed QSI headers from /usr/local/include"
	fi
	
	#*	Remove WiringPi libraries and headers (if installed)
	if [ -f "/usr/local/lib/libwiringPi.so" ] || [ -f "/usr/lib/libwiringPi.so" ]
	then
		sudo rm -f /usr/local/lib/libwiringPi* /usr/lib/libwiringPi* 2>/dev/null || true
		sudo rm -rf /usr/local/include/wiringPi* /usr/include/wiringPi* 2>/dev/null || true
		sudo ldconfig
		PrintSuccess "Removed WiringPi libraries and headers"
	fi
	
	if [ $REMOVED_COUNT -gt 0 ]
	then
		sudo ldconfig
		PrintSuccess "Removed $REMOVED_COUNT vendor SDK library files"
	else
		PrintWarning "No vendor SDK libraries found to remove"
	fi
	
	#*	Remove USB device rules
	PrintStep "Removing USB device rules..."
	RULES_FILES=(
		"asi.rules"
		"efw.rules"
		"99-atik.rules"
		"99-toupcam.rules"
		"40-flir-spinnaker.rules"
		"85-qhyccd.rules"
		"eaf.rules"
		"99-player_one_astronomy.rules"
	)
	
	REMOVED_RULES=0
	for rule in "${RULES_FILES[@]}"
	do
		if [ -f "/lib/udev/rules.d/$rule" ]
		then
			sudo rm -v "/lib/udev/rules.d/$rule" && REMOVED_RULES=$((REMOVED_RULES + 1))
		elif [ -f "/etc/udev/rules.d/$rule" ]
		then
			sudo rm -v "/etc/udev/rules.d/$rule" && REMOVED_RULES=$((REMOVED_RULES + 1))
		fi
	done
	
	if [ $REMOVED_RULES -gt 0 ]
	then
		PrintSuccess "Removed $REMOVED_RULES USB device rule files"
		PrintWarning "You may need to reboot for USB rules changes to take effect"
	else
		PrintWarning "No USB device rules found to remove"
	fi
	
	#*	Remove FITS library (if installed from source)
	PrintStep "Checking for FITS library (cfitsio)..."
	if [ -f "/usr/local/include/fitsio.h" ]
	then
		if AskYesNo "Remove FITS library (cfitsio) from /usr/local?" "n"
		then
			sudo rm -v /usr/local/lib/libcfitsio* 2>/dev/null || true
			sudo rm -v /usr/local/include/fitsio*.h 2>/dev/null || true
			sudo rm -v /usr/local/include/drvrsmem.h 2>/dev/null || true
			sudo rm -v /usr/local/include/longnam.h 2>/dev/null || true
			sudo ldconfig
			PrintSuccess "FITS library removed"
		fi
	else
		PrintWarning "FITS library not found in /usr/local (may be installed via package manager)"
	fi
	
	#*	Remove built binaries
	PrintStep "Removing built binaries..."
	
	#*	First, check for and stop any running AlpacaPi processes (server and clients)
	ALPACAPI_PROCESSES=(
		"alpacapi"
		"client"
		"camera"
		"cameracv4"
		"domectrl"
		"domectrlcv4"
		"focuser"
		"focusercv4"
		"switch"
		"switchcv4"
		"sky"
		"skycv4"
		"calib"
		"calibcv4"
		"topens"
		"pmc8"
		"skytravel"
		"rorpi"
	)
	
	RUNNING_PROCESSES=()
	#*	Get the current directory (AlpacaPi repository root) - normalize path
	ALPACAPI_DIR=$(cd . && pwd)
	
	for proc in "${ALPACAPI_PROCESSES[@]}"
	do
		#*	Use pgrep -x for exact process name match (executable name only)
		#*	This avoids matching processes with these strings in their command line
		PIDS=$(pgrep -x "$proc" 2>/dev/null || true)
		if [ -n "$PIDS" ]
		then
			for pid in $PIDS
			do
				#*	Skip this script's PID
				if [ "$pid" = "$$" ]
				then
					continue
				fi
				
				#*	Get the executable path (most reliable method)
				EXE_PATH=$(readlink -f "/proc/$pid/exe" 2>/dev/null || echo "")
				
				#*	Only match processes whose executable is in the AlpacaPi directory
				#*	This ensures we only detect actual AlpacaPi binaries, not system-wide matches
				if [ -n "$EXE_PATH" ]
				then
					#*	Check if executable is in the current AlpacaPi directory
					if echo "$EXE_PATH" | grep -q "^${ALPACAPI_DIR}/"
					then
						RUNNING_PROCESSES+=("$pid:$proc")
					fi
				fi
			done
		fi
	done
	
	if [ ${#RUNNING_PROCESSES[@]} -gt 0 ]
	then
		PrintWarning "Found running AlpacaPi processes:"
		for proc_info in "${RUNNING_PROCESSES[@]}"
		do
			PID=$(echo "$proc_info" | cut -d: -f1)
			NAME=$(echo "$proc_info" | cut -d: -f2)
			echo "	- PID $PID: $NAME"
		done
		
		if AskYesNo "Stop running AlpacaPi processes before removing binaries?" "y"
		then
			for proc_info in "${RUNNING_PROCESSES[@]}"
			do
				PID=$(echo "$proc_info" | cut -d: -f1)
				NAME=$(echo "$proc_info" | cut -d: -f2)
				PrintStep "Stopping $NAME (PID: $PID)..."
				kill "$PID" 2>/dev/null || true
				#*	Wait a moment for graceful shutdown
				sleep 1
				#*	Force kill if still running
				if kill -0 "$PID" 2>/dev/null
				then
					PrintWarning "Process $PID ($NAME) still running, forcing termination..."
					kill -9 "$PID" 2>/dev/null || true
				fi
			done
			sleep 1
			#*	Verify all processes are stopped
			REMAINING_COUNT=0
			for proc_info in "${RUNNING_PROCESSES[@]}"
			do
				PID=$(echo "$proc_info" | cut -d: -f1)
				if kill -0 "$PID" 2>/dev/null
				then
					REMAINING_COUNT=$((REMAINING_COUNT + 1))
				fi
			done
			if [ $REMAINING_COUNT -gt 0 ]
			then
				PrintWarning "Some AlpacaPi processes may still be running"
			else
				PrintSuccess "All AlpacaPi processes stopped"
			fi
		else
			PrintWarning "Skipping process termination - binaries may not be removable while running"
		fi
	fi
	
	BINARIES=(
		"alpacapi"
		"client"
		"camera"
		"domectrl"
		"focuser"
		"rorpi"
		"switch"
		"sky"
		"cameracv4"
		"domectrlcv4"
		"focusercv4"
		"picv4"
		"switchcv4"
		"skycv4"
		"calib"
		"calibcv4"
		"topens"
		"pmc8"
		"skytravel"
	)
	
	REMOVED_BINS=0
	for bin in "${BINARIES[@]}"
	do
		if [ -f "$bin" ]
		then
			rm -v "$bin" && REMOVED_BINS=$((REMOVED_BINS + 1))
		fi
	done
	
	if [ $REMOVED_BINS -gt 0 ]
	then
		PrintSuccess "Removed $REMOVED_BINS built binaries"
	else
		PrintWarning "No built binaries found to remove"
	fi
	
	#*	Remove build artifacts (but preserve Objectfiles folder - it's part of repository)
	PrintStep "Removing build artifacts..."
	
	#*	Call make clean to remove all object files properly
	if [ -f "Makefile" ]
	then
		PrintStep "Running 'make clean' to remove object files..."
		make clean >/dev/null 2>&1 || true
		PrintSuccess "make clean completed"
	fi
	
	#*	Also clean skytravel-specific object files if they exist
	if [ -d "obj/skytravel/src" ]
	then
		rm -vf obj/skytravel/src/*.o 2>/dev/null || true
	fi
	
	#*	Also clean sss-specific object files if they exist
	if [ -d "obj/sss/src" ]
	then
		rm -vf obj/sss/src/*.o 2>/dev/null || true
	fi
	
	#*	Ensure Objectfiles directory is clean (but preserve folder and placeholder.txt)
	if [ -d "Objectfiles" ]
	then
		#*	Remove any remaining object files (make clean should have done this, but double-check)
		find Objectfiles -mindepth 1 ! -name "placeholder.txt" -delete 2>/dev/null || true
		PrintSuccess "Cleaned Objectfiles directory (preserved repository folder)"
	fi
	
	#*	Remove build log
	if [ -f "AlpacaPi_buildlog.txt" ]
	then
		rm -v AlpacaPi_buildlog.txt
		PrintSuccess "Removed build log"
	fi
	
	#*	Remove any other common build artifacts
	if [ -f "opencvinstall-log.txt" ]
	then
		rm -v opencvinstall-log.txt
		PrintSuccess "Removed OpenCV install log"
	fi
	
	#*	Optional: Remove OpenCV (if installed by this script)
	PrintStep "Checking for OpenCV installation..."
	OPENCV_PACKAGE_MANAGER=false
	OPENCV_SOURCE_COMPILED=false
	OPENCV_VERSION_DETECTED=""
	
	#*	Check if OpenCV was installed via package manager
	if dpkg -l | grep -q "^ii.*libopencv" 2>/dev/null
	then
		OPENCV_PACKAGE_MANAGER=true
		#*	Detect which version is installed
		if pkg-config --exists opencv4 2>/dev/null
		then
			OPENCV_VERSION_DETECTED=$(pkg-config --modversion opencv4 2>/dev/null || echo "4.x")
			PrintWarning "OpenCV found (installed via package manager - OpenCV 4, version $OPENCV_VERSION_DETECTED)"
		elif pkg-config --exists opencv 2>/dev/null
		then
			OPENCV_VERSION_DETECTED=$(pkg-config --modversion opencv 2>/dev/null || echo "unknown")
			if echo "$OPENCV_VERSION_DETECTED" | grep -qE "^4\."
			then
				PrintWarning "OpenCV found (installed via package manager - OpenCV 4, version $OPENCV_VERSION_DETECTED)"
			else
				PrintWarning "OpenCV found (installed via package manager - OpenCV 3, version $OPENCV_VERSION_DETECTED)"
			fi
		else
			PrintWarning "OpenCV found (installed via package manager - version detection failed)"
		fi
	fi
	
	#*	Check if OpenCV was compiled from source (in /usr/local)
	#*	Check for various OpenCV versions (3.x, 4.x, etc.)
	if [ -f "/usr/local/lib/libopencv_core.so" ] || \
	   [ -f "/usr/local/lib/libopencv_core.so.4" ] || \
	   [ -f "/usr/local/lib/libopencv_core.so.3" ] || \
	   ls /usr/local/lib/libopencv_core.so.* 2>/dev/null | grep -q "libopencv_core.so"
	then
		OPENCV_SOURCE_COMPILED=true
		#*	Try to detect version from library files
		if ls /usr/local/lib/libopencv_core.so.* 2>/dev/null | grep -qE "\.so\.4\."
		then
			OPENCV_VERSION_DETECTED=$(ls /usr/local/lib/libopencv_core.so.* 2>/dev/null | head -1 | sed 's/.*\.so\.\([0-9]\+\.[0-9]\+\).*/\1/' || echo "4.x")
			PrintWarning "OpenCV found (compiled from source in /usr/local - OpenCV 4, version $OPENCV_VERSION_DETECTED)"
		elif ls /usr/local/lib/libopencv_core.so.* 2>/dev/null | grep -qE "\.so\.3\."
		then
			OPENCV_VERSION_DETECTED=$(ls /usr/local/lib/libopencv_core.so.* 2>/dev/null | head -1 | sed 's/.*\.so\.\([0-9]\+\.[0-9]\+\).*/\1/' || echo "3.x")
			PrintWarning "OpenCV found (compiled from source in /usr/local - OpenCV 3, version $OPENCV_VERSION_DETECTED)"
		else
			PrintWarning "OpenCV found (compiled from source in /usr/local - version unknown)"
		fi
	fi
	
	if [ "$OPENCV_PACKAGE_MANAGER" = true ] || [ "$OPENCV_SOURCE_COMPILED" = true ]
	then
		if AskYesNo "Remove OpenCV?" "n"
		then
			#*	Remove package manager installation
			if [ "$OPENCV_PACKAGE_MANAGER" = true ]
			then
				PrintStep "Removing OpenCV packages..."
				#*	Find all installed OpenCV packages dynamically
				OPENCV_PACKAGES=$(dpkg -l | grep "^ii.*libopencv" | awk '{print $2}' | tr '\n' ' ')
				if [ -n "$OPENCV_PACKAGES" ]
				then
					echo "Found OpenCV packages: $OPENCV_PACKAGES"
					sudo apt-get remove -y $OPENCV_PACKAGES 2>&1 | FilterAptErrors || true
					PrintSuccess "OpenCV packages removed"
					
					#*	Warn about autoremove and let user decide
					echo ""
					PrintWarning "OpenCV dependencies may still be installed"
					echo "These were automatically installed when OpenCV was installed."
					echo "Some may be used by other software on your system."
					echo ""
					if AskYesNo "Remove unused OpenCV dependencies? (apt-get autoremove - may remove packages used by other software)" "n"
					then
						sudo apt-get autoremove -y 2>&1 | FilterAptErrors || true
						PrintSuccess "Unused dependencies removed"
					else
						PrintWarning "Skipped autoremove - dependencies left intact"
					fi
				else
					PrintWarning "Could not find OpenCV package names to remove"
				fi
			fi
			
			#*	Remove source-compiled installation
			if [ "$OPENCV_SOURCE_COMPILED" = true ]
			then
				PrintStep "Removing source-compiled OpenCV from /usr/local..."
				sudo rm -rf /usr/local/lib/libopencv* 2>/dev/null || true
				sudo rm -rf /usr/local/include/opencv* 2>/dev/null || true
				sudo rm -rf /usr/local/include/opencv2 2>/dev/null || true
				sudo rm -rf /usr/local/share/opencv* 2>/dev/null || true
				sudo ldconfig
				PrintSuccess "Source-compiled OpenCV removed"
			fi
			
			#*	Optional: Remove OpenCV source/build directory
			if [ -d "opencv" ]
			then
				if AskYesNo "Remove OpenCV source/build directory (opencv/)? (large, ~500MB-2GB)" "n"
				then
					rm -rf opencv
					PrintSuccess "Removed OpenCV source directory"
				fi
			fi
		fi
	else
		PrintWarning "OpenCV not found (or not installed by this script)"
	fi
	
	#*	Optional: Remove downloaded SDK folders (NOT repository SDKs)
	#*	Only remove SDKs that were downloaded by the script, not ones included in the repo
	#*	Check if any downloaded SDK folders exist before asking
	DOWNLOADED_SDK_FOLDERS=(
		"QHY"
		"PlayerOne"
		"qsiapi-7.6.0"
		"libftd2xx"
		"WiringPi"
	)
	
	DOWNLOADED_SDKS_FOUND=0
	for sdk in "${DOWNLOADED_SDK_FOLDERS[@]}"
	do
		if [ -d "$sdk" ]
		then
			DOWNLOADED_SDKS_FOUND=$((DOWNLOADED_SDKS_FOUND + 1))
		fi
	done
	
	if [ $DOWNLOADED_SDKS_FOUND -gt 0 ]
	then
		if AskYesNo "Remove downloaded SDK folders? (QHY, PlayerOne, QSI, WiringPi - NOT repo SDKs)" "n"
		then
			PrintStep "Removing downloaded SDK folders..."
			PrintWarning "Repository SDKs (ZWO_ASI_SDK, AtikCamerasSDK, ZWO_EFW_SDK, ZWO_EAF_SDK, FLIR-SDK, toupcamsdk) will NOT be removed"
			echo ""
			
			REMOVED_SDKS=0
			for sdk in "${DOWNLOADED_SDK_FOLDERS[@]}"
			do
				if [ -d "$sdk" ]
				then
					rm -rf "$sdk" && REMOVED_SDKS=$((REMOVED_SDKS + 1))
					PrintSuccess "Removed $sdk"
				fi
			done
			
			if [ $REMOVED_SDKS -eq 0 ]
			then
				PrintWarning "No downloaded SDK folders found to remove"
			fi
		fi
	else
		PrintWarning "No downloaded SDK folders found (QHY, PlayerOne, QSI, WiringPi)"
		echo "These SDKs are not part of the repository and would only exist if downloaded by the setup script."
	fi
	
	#*	Optional: Remove downloaded data folders
	if AskYesNo "Remove downloaded data folders? (OpenNGC, d3-celestial)" "n"
	then
		PrintStep "Removing data folders..."
		if [ -d "OpenNGC" ]
		then
			rm -rf OpenNGC
			PrintSuccess "Removed OpenNGC"
		fi
		if [ -d "d3-celestial" ]
		then
			rm -rf d3-celestial
			PrintSuccess "Removed d3-celestial"
		fi
	fi
	
	#*	Summary
	PrintSection "Uninstall Complete"
	echo ""
	echo "Removed components:"
	echo "	- Vendor SDK libraries: $REMOVED_COUNT files"
	echo "	- USB device rules: $REMOVED_RULES files"
	echo "	- Built binaries: $REMOVED_BINS files"
	echo ""
	echo "Note: System libraries (libusb, libudev, etc.) and build tools were NOT removed"
	echo "      as they may be used by other software on your system."
	echo ""
	echo "If you removed USB rules, you may need to reboot for changes to take effect."
}

###############################################################################
#	Verify Build Environment (using Makefile helper scripts)
###############################################################################
VerifyBuildEnvironment()
{
	PrintSection "Verifying Build Environment"
	
	#*	Check platform detection
	PrintStep "Checking platform detection..."
	if [ -f "./make_checkplatform.sh" ]
	then
		PLATFORM_DETECTED=`./make_checkplatform.sh`
		if [ -n "$PLATFORM_DETECTED" ] && [ "$PLATFORM_DETECTED" != "unknown" ]
		then
			PrintSuccess "Platform detected: $PLATFORM_DETECTED"
			if [ "$PLATFORM" != "$PLATFORM_DETECTED" ]
			then
				PrintWarning "Platform mismatch: script detected '$PLATFORM', Makefile will use '$PLATFORM_DETECTED'"
			fi
		else
			PrintError "Platform detection failed"
		fi
	else
		PrintError "make_checkplatform.sh not found - Makefile may fail"
	fi
	
	#*	Check OpenCV detection
	PrintStep "Checking OpenCV detection..."
	if [ -f "./make_checkopencv.sh" ]
	then
		OPENCV_DETECTED=`./make_checkopencv.sh`
		if [ -n "$OPENCV_DETECTED" ]
		then
			if [ "$OPENCV_DETECTED" = "opencv4" ]
			then
				PrintSuccess "OpenCV 4 detected (Makefile will use: $OPENCV_DETECTED)"
			elif [ "$OPENCV_DETECTED" = "opencv" ]
			then
				PrintSuccess "OpenCV 3 detected (Makefile will use: $OPENCV_DETECTED)"
			else
				PrintWarning "OpenCV detection returned: $OPENCV_DETECTED"
			fi
		else
			PrintWarning "OpenCV not detected - camera/focuser/dome clients may not build"
		fi
	else
		PrintError "make_checkopencv.sh not found - Makefile may fail"
	fi
	
	#*	Check SQL detection
	PrintStep "Checking SQL library detection..."
	if [ -f "./make_checksql.sh" ]
	then
		SQL_DETECTED=`./make_checksql.sh`
		if [ -n "$SQL_DETECTED" ] && [ "$SQL_DETECTED" != "sql_not_installed" ]
		then
			PrintSuccess "SQL library detected: $SQL_DETECTED"
			echo "	Note: SQL is used for optional remote Gaia database queries in SkyTravel"
		else
			echo "	SQL library not detected"
			echo "	Note: SQL is OPTIONAL and only needed for remote Gaia database queries in SkyTravel"
			echo "	SkyTravel works fine without SQL using local star catalogs (OpenNGC)"
			echo "	If you need SQL support, install: libmariadb-dev (Raspberry Pi) or libmysqlclient-dev (Ubuntu)"
		fi
	else
		PrintError "make_checksql.sh not found - Makefile may fail"
	fi
	
	#*	Summary
	echo ""
	echo "Build environment summary:"
	echo "	Platform: $PLATFORM_DETECTED"
	echo "	OpenCV: $OPENCV_DETECTED"
	echo "	SQL: $SQL_DETECTED"
	echo ""
	
	if [ -z "$OPENCV_DETECTED" ] || ([ "$OPENCV_DETECTED" != "opencv" ] && [ "$OPENCV_DETECTED" != "opencv4" ])
	then
		PrintWarning "OpenCV not detected - you may need to install it before building camera/focuser/dome clients"
	fi
}
main()
{
	#*	Check for uninstall mode FIRST (before printing anything)
	if [ "$1" = "--uninstall" ] || [ "$1" = "-u" ] || [ "$1" = "uninstall" ]
	then
		clear
		DeterminePlatform
		UninstallAlpacaPi
		exit 0
	fi
	
	clear
	PrintSection "AlpacaPi Complete Setup"
	echo ""
	echo "This script will guide you through the setup process with interactive prompts."
	echo ""
	echo "Setup steps:"
	echo "	1. Check system requirements (build tools and system libraries)"
	echo "	2. Install FITS library"
	echo "	3. Check/Install OpenCV"
	echo "	4. Install USB device rules"
	echo "	5. Install vendor SDKs (optional)"
	echo "	6. Download extra data for SkyTravel (optional)"
	echo "	7. Verify build environment (platform, OpenCV, SQL detection)"
	echo "	8. Build AlpacaPi (optional)"
	echo ""
	echo "You will be prompted before each step. You can run this script multiple times safely."
	echo ""
	echo "Usage:"
	echo "	./setup_complete.sh          - Run setup/install"
	echo "	./setup_complete.sh --uninstall  - Run uninstall mode"
	echo ""
	
	if [ "$AUTO_INSTALL" != true ]
	then
		if ! AskYesNo "Ready to begin setup?" "y"
		then
			echo "Setup cancelled."
			exit 0
		fi
	fi
	
	#*	Determine platform
	DeterminePlatform
	
	#*	Check system requirements (includes checking and installing system libraries)
	CheckSystemRequirements
	
	#*	Install FITS
	if AskYesNo "Install FITS library (cfitsio)?" "y"
	then
		InstallFITS
	fi
	
	#*	Check/Install OpenCV
	CheckOpenCV
	
	#*	Install USB rules
	if AskYesNo "Install USB device rules? (Required for USB device access)" "y"
	then
		InstallUSBRules
	fi
	
	#*	Check vendor SDKs
	CheckVendorSDKs
	
	#*	Download extra data
	DownloadExtraData
	
	#*	Verify build environment
	VerifyBuildEnvironment
	
	#*	Build AlpacaPi (optional)
	if AskYesNo "Build AlpacaPi now? (Compile all components)" "n"
	then
		BuildAlpacaPi
	fi
	
	#*	Final summary
	PrintSection "Setup Complete!"
	echo ""
	echo "Next steps:"
	OPENCV_FOUND=false
	if pkg-config --exists opencv4 2>/dev/null || pkg-config --exists opencv 2>/dev/null || [ -f "/usr/include/opencv2/highgui/highgui_c.h" ] || [ -f "/usr/local/include/opencv2/highgui/highgui_c.h" ] || [ -f "/usr/include/opencv4/opencv2/highgui/highgui.hpp" ] || [ -f "/usr/local/include/opencv4/opencv2/highgui/highgui.hpp" ]
	then
		OPENCV_FOUND=true
	fi
	
	if [ "$OPENCV_FOUND" = false ]
	then
		echo "	1. Install OpenCV if needed for camera/focuser/dome clients"
		echo ""
	fi
	echo "	1. If USB rules were installed, you may need to reboot:"
	echo "		sudo reboot"
	echo ""
	if [ ! -f "alpacapi" ]
	then
		echo "	2. Build AlpacaPi (if not already built):"
		echo "		./build_all.sh"
		echo "		OR"
		echo "		make"
		echo ""
	fi
	echo "	3. Run AlpacaPi server:"
	echo "		./alpacapi"
	echo ""
	
	PrintSuccess "Setup script completed successfully!"
}

###############################################################################
#	Run main function
###############################################################################
main "$@"
