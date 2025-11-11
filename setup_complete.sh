#!/bin/bash
###############################################################################
#	AlpacaPi Setup Script
#	Verifies system requirements and builds alpacapi with selected drivers
###############################################################################
#	Edit History
###############################################################################
#	Dec 2024	<MLS> Streamlined setup script - verification and driver selection only
###############################################################################

set -e		#*	exit on error

###############################################################################
#	Configuration
###############################################################################
AUTO_INSTALL=false		#*	set to true to skip prompts and install everything automatically
UNINSTALL_MODE=false	#*	set to true when -u flag is used

###############################################################################
#	Colors for output
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

#*	Filter out harmless apt-get errors
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
	
	if CheckCommand pkg-config
	then
		PrintSuccess "pkg-config found"
	else
		PrintWarning "pkg-config not found"
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
	
	if [ -f "/usr/include/fitsio.h" ] || [ -f "/usr/local/include/fitsio.h" ]
	then
		PrintSuccess "libcfitsio-dev found"
	else
		PrintWarning "libcfitsio-dev not found (needed for FITS file support)"
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
	
	PrintStep "Updating package lists..."
	UPDATE_OUTPUT=$(sudo apt-get update 2>&1)
	if echo "$UPDATE_OUTPUT" | grep -qE "Err:|404"
	then
		PrintWarning "Some repositories failed to update"
	fi
	echo "$UPDATE_OUTPUT" | FilterAptErrors
	
	PrintStep "Installing build-essential (gcc, g++, make)..."
	sudo apt-get install -y build-essential
	
	if ! CheckCommand pkg-config
	then
		PrintStep "Installing pkg-config..."
		sudo apt-get install -y pkg-config
	fi
	
	PrintSuccess "Build tools installation complete"
}

###############################################################################
#	Install System Libraries
###############################################################################
InstallSystemLibraries()
{
	PrintSection "Installing System Libraries"
	
	PrintStep "Updating package lists..."
	UPDATE_OUTPUT=$(sudo apt-get update 2>&1)
	if echo "$UPDATE_OUTPUT" | grep -qE "Err:|404"
	then
		PrintWarning "Some repositories failed to update"
	fi
	echo "$UPDATE_OUTPUT" | FilterAptErrors
	
	PrintStep "Installing required libraries..."
	sudo apt-get install -y libusb-1.0-0-dev libudev-dev libi2c-dev libjpeg-dev libcfitsio-dev libgtk2.0-dev
	
	PrintSuccess "System libraries installed"
}

###############################################################################
#	OpenCV Verification and Installation
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
		echo "	- Camera image processing and live view"
		echo "	- Video recording with cameras"
		echo ""
		echo "OpenCV is NOT required for:"
		echo "	- Basic AlpacaPi server (camera control, exposure settings)"
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
	echo "OpenCV will be installed via package manager (recommended)."
	echo ""
	
	if ! AskYesNo "Install OpenCV via package manager?" "y"
	then
		echo ""
		echo "OpenCV installation skipped."
		echo "You can install it manually later with: sudo apt-get install libopencv-dev"
		return 1
	fi
	
			PrintStep "Updating package lists..."
			sudo apt-get update 2>&1 | FilterAptErrors
			
			PrintStep "Installing OpenCV development packages..."
	if sudo apt-get install -y libopencv-dev libopencv-contrib-dev 2>&1 | FilterAptErrors
	then
		sudo ldconfig
		PrintSuccess "OpenCV installed via package manager"
		
		#*	Verify installation
		if pkg-config --exists opencv4 2>/dev/null || pkg-config --exists opencv 2>/dev/null
		then
			PrintSuccess "OpenCV installation verified"
		else
			PrintWarning "OpenCV installed but pkg-config not detecting it - may need to rebuild"
		fi
	else
		PrintError "OpenCV installation via package manager failed"
			return 1
		fi
}

###############################################################################
#	Uninstall AlpacaPi
###############################################################################
UninstallAlpacaPi()
{
	PrintSection "Uninstalling AlpacaPi"
	
	#*	Stop any running AlpacaPi processes (always do this)
	PrintStep "Stopping running AlpacaPi processes..."
	if pgrep -f "alpacapi" >/dev/null 2>&1
	then
		PrintWarning "Found running AlpacaPi processes, stopping them..."
		sudo pkill -f "alpacapi" || true
		sleep 2
		if pgrep -f "alpacapi" >/dev/null 2>&1
		then
			PrintWarning "Some processes still running, force killing..."
			sudo pkill -9 -f "alpacapi" || true
		fi
		PrintSuccess "AlpacaPi processes stopped"
	else
		PrintSuccess "No running AlpacaPi processes found"
	fi
	
	echo ""
	echo "What would you like to remove?"
	echo ""
	
	#*	Option 1: Remove alpacapi application binary
	REMOVE_APP=false
	if [ -f "alpacapi" ]
	then
		if AskYesNo "Remove alpacapi application binary?" "y"
		then
			REMOVE_APP=true
		fi
	else
		PrintWarning "alpacapi binary not found"
	fi
	
	#*	Option 2: Remove USB driver rules
	REMOVE_DRIVERS=false
	RULES_FOUND=0
	
	#*	List of rules files that might have been installed
	RULES_FILES=(
		"/lib/udev/rules.d/asi.rules"
		"/etc/udev/rules.d/asi.rules"
		"/lib/udev/rules.d/efw.rules"
		"/etc/udev/rules.d/efw.rules"
		"/lib/udev/rules.d/eaf.rules"
		"/etc/udev/rules.d/eaf.rules"
		"/lib/udev/rules.d/99-atik.rules"
		"/etc/udev/rules.d/99-atik.rules"
		"/lib/udev/rules.d/99-toupcam.rules"
		"/etc/udev/rules.d/99-toupcam.rules"
		"/lib/udev/rules.d/40-flir-spinnaker.rules"
		"/etc/udev/rules.d/40-flir-spinnaker.rules"
		"/lib/udev/rules.d/85-qhyccd.rules"
		"/etc/udev/rules.d/85-qhyccd.rules"
	)
	
	#*	Check which rules exist
	for RULE_FILE in "${RULES_FILES[@]}"
	do
		if [ -f "$RULE_FILE" ]
		then
			RULES_FOUND=$((RULES_FOUND + 1))
		fi
	done
	
	if [ $RULES_FOUND -gt 0 ]
	then
		echo ""
		echo "Found $RULES_FOUND USB driver rule file(s):"
		for RULE_FILE in "${RULES_FILES[@]}"
		do
			if [ -f "$RULE_FILE" ]
			then
				echo "	- $RULE_FILE"
			fi
		done
		echo ""
		if AskYesNo "Remove USB driver rules? (Required for USB device access)" "y"
		then
			REMOVE_DRIVERS=true
		fi
	else
		PrintWarning "No USB driver rules found"
	fi
	
	#*	Option 3: Remove build artifacts
	REMOVE_BUILD_ARTIFACTS=false
	BUILD_ARTIFACTS_FOUND=false
	
	if [ -d "Objectfiles" ] || [ -f "AlpacaPi_buildlog.txt" ] || [ -f ".Makefile.custom" ] || [ -f ".selective_build.log" ]
	then
		BUILD_ARTIFACTS_FOUND=true
	fi
	
	if [ "$BUILD_ARTIFACTS_FOUND" = true ]
	then
		echo ""
		if AskYesNo "Remove build artifacts? (Objectfiles, build logs, etc.)" "y"
		then
			REMOVE_BUILD_ARTIFACTS=true
		fi
	fi
	
	#*	Perform removals based on user choices
	echo ""
	PrintSection "Removing Selected Components"
	
	#*	Remove application binary
	if [ "$REMOVE_APP" = true ]
	then
		PrintStep "Removing alpacapi application binary..."
		if [ -f "alpacapi" ]
		then
			rm -f "alpacapi"
			PrintSuccess "Removed alpacapi binary"
		fi
	fi
	
	#*	Remove USB driver rules
	if [ "$REMOVE_DRIVERS" = true ]
	then
		PrintStep "Removing USB driver rules..."
		RULES_REMOVED=0
		
		for RULE_FILE in "${RULES_FILES[@]}"
		do
			if [ -f "$RULE_FILE" ]
			then
				sudo rm -f "$RULE_FILE"
				RULES_REMOVED=$((RULES_REMOVED + 1))
				PrintSuccess "Removed $RULE_FILE"
			fi
		done
		
		if [ $RULES_REMOVED -gt 0 ]
		then
			PrintSuccess "Removed $RULES_REMOVED USB rule file(s)"
			PrintWarning "You may need to reboot for USB rule changes to take effect"
		fi
	fi
	
	#*	Remove build artifacts
	if [ "$REMOVE_BUILD_ARTIFACTS" = true ]
	then
		PrintStep "Removing build artifacts..."
		
		if [ -d "Objectfiles" ]
		then
			rm -rf Objectfiles
			PrintSuccess "Removed Objectfiles directory"
		fi
		
		if [ -f "AlpacaPi_buildlog.txt" ]
		then
			rm -f AlpacaPi_buildlog.txt
			PrintSuccess "Removed build log"
		fi
		
		if [ -f ".Makefile.custom" ]
		then
			rm -f .Makefile.custom
			PrintSuccess "Removed temporary Makefile"
		fi
		
		if [ -f ".selective_build.log" ]
		then
			rm -f .selective_build.log
			PrintSuccess "Removed build log"
		fi
	fi
	
	#*	Summary
	echo ""
	PrintSection "Uninstallation Summary"
	
	if [ "$REMOVE_APP" = true ] || [ "$REMOVE_DRIVERS" = true ] || [ "$REMOVE_BUILD_ARTIFACTS" = true ]
	then
		PrintSuccess "Selected components have been removed"
	else
		PrintWarning "No components were selected for removal"
	fi
	
	#*	Note about SDK folders and system libraries
	echo ""
	PrintWarning "Repository SDK folders (ZWO_ASI_SDK, AtikCamerasSDK, ZWO_EFW_SDK, etc.) were NOT removed"
	PrintWarning "System libraries (libusb, libudev, OpenCV, etc.) were NOT removed"
	
	PrintSection "Uninstallation Complete!"
}

###############################################################################
#	USB Rules Installation
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
	if CheckFile "." "sdk/ZWO_ASI_SDK/lib"
	then
		installRules "sdk/ZWO_ASI_SDK/lib" "asi.rules" && RULES_INSTALLED=$((RULES_INSTALLED + 1))
	fi
	
	if CheckFile "." "sdk/ZWO_EFW_SDK/lib"
	then
		installRules "sdk/ZWO_EFW_SDK/lib" "efw.rules" && RULES_INSTALLED=$((RULES_INSTALLED + 1))
	fi
	
	if CheckFile "." "sdk/AtikCamerasSDK"
	then
		installRules "sdk/AtikCamerasSDK" "99-atik.rules" && RULES_INSTALLED=$((RULES_INSTALLED + 1))
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
	
	if CheckFile "." "sdk/ZWO_EAF_SDK/lib"
	then
		installRules "sdk/ZWO_EAF_SDK/lib" "eaf.rules" && RULES_INSTALLED=$((RULES_INSTALLED + 1))
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
#	Vendor SDK Installation
###############################################################################
CheckVendorSDKs()
{
	PrintSection "Vendor SDK Check"
	
	echo "Checking for vendor SDK directories..."
	echo ""
	
	VENDOR_COUNT=0
	
	if CheckFile "." "sdk/ZWO_ASI_SDK"
	then
		echo "	✓ ZWO_ASI_SDK (ZWO cameras) - Present"
		VENDOR_COUNT=$((VENDOR_COUNT + 1))
	fi
	
	if CheckFile "." "sdk/AtikCamerasSDK"
	then
		echo "	✓ AtikCamerasSDK - Present"
		VENDOR_COUNT=$((VENDOR_COUNT + 1))
	fi
	
	if CheckFile "." "sdk/ZWO_EFW_SDK"
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
	
	if CheckFile "." "sdk/ZWO_EAF_SDK"
	then
		echo "	✓ ZWO_EAF_SDK (ZWO focusers) - Present"
		VENDOR_COUNT=$((VENDOR_COUNT + 1))
	fi
	
	if CheckFile "." "FLIR-SDK"
	then
		echo "	✓ FLIR-SDK - Present"
		VENDOR_COUNT=$((VENDOR_COUNT + 1))
	fi
	
	if [ $VENDOR_COUNT -eq 0 ]
	then
		PrintWarning "No vendor SDKs found in repository"
		echo ""
		echo "Vendor SDKs are optional and only needed if you use specific devices."
	else
		echo ""
		PrintSuccess "Found $VENDOR_COUNT vendor SDK(s)"
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
	
	#*	Initialize all driver flags to false
	BUILD_CAMERA=false
	BUILD_CAMERA_ASI=false
	BUILD_CAMERA_ATIK=false
	BUILD_CAMERA_FLIR=false
	BUILD_CAMERA_QHY=false
	BUILD_CAMERA_TOUP=false
	
	BUILD_FILTERWHEEL=false
	BUILD_FILTERWHEEL_ZWO=false
	BUILD_FILTERWHEEL_ATIK=false
	
	BUILD_FOCUSER=false
	BUILD_FOCUSER_ZWO=false
	BUILD_FOCUSER_MOONLITE=false
	
	BUILD_ROTATOR=false
	BUILD_ROTATOR_NITECRAWLER=false
	
	BUILD_TELESCOPE=false
	BUILD_TELESCOPE_LX200=false
	BUILD_TELESCOPE_SKYWATCHER=false
	BUILD_TELESCOPE_SERVO=false
	
	BUILD_DOME=false
	
	BUILD_SWITCH=false
	
	BUILD_CALIBRATION=false
	
	BUILD_OBSERVINGCONDITIONS=false
	
	#*	Camera drivers
	if AskYesNo "Include camera support?" "y"
	then
		BUILD_CAMERA=true
		
		if CheckFile "." "sdk/ZWO_ASI_SDK"
			then
			if AskYesNo "  Include ZWO ASI camera support?" "y"
			then
				BUILD_CAMERA_ASI=true
			fi
		fi
		
		if CheckFile "." "sdk/AtikCamerasSDK"
		then
			if AskYesNo "  Include ATIK camera support?" "n"
			then
				BUILD_CAMERA_ATIK=true
			fi
		fi
		
			if CheckFile "." "FLIR-SDK"
			then
			if AskYesNo "  Include FLIR camera support?" "n"
			then
				BUILD_CAMERA_FLIR=true
			fi
		fi
		
		if CheckFile "." "QHY"
		then
			if AskYesNo "  Include QHY camera support?" "n"
			then
				BUILD_CAMERA_QHY=true
			fi
	fi
	
		if CheckFile "." "toupcamsdk"
		then
			if AskYesNo "  Include ToupTek camera support?" "n"
		then
				BUILD_CAMERA_TOUP=true
			fi
		fi
	fi
	
	#*	Filter wheel drivers
	if AskYesNo "Include filter wheel support?" "y"
	then
		BUILD_FILTERWHEEL=true
		
		if CheckFile "." "sdk/ZWO_EFW_SDK"
		then
			if AskYesNo "  Include ZWO EFW filter wheel support?" "y"
			then
				BUILD_FILTERWHEEL_ZWO=true
			fi
		fi
		
		if CheckFile "." "sdk/AtikCamerasSDK"
	then
			if AskYesNo "  Include ATIK filter wheel support?" "n"
			then
				BUILD_FILTERWHEEL_ATIK=true
			fi
		fi
		fi
		
	#*	Focuser drivers
	if AskYesNo "Include focuser support?" "y"
	then
		BUILD_FOCUSER=true
		
		if CheckFile "." "sdk/ZWO_EAF_SDK"
		then
			if AskYesNo "  Include ZWO EAF focuser support?" "y"
			then
				BUILD_FOCUSER_ZWO=true
			fi
		fi
		
		if AskYesNo "  Include MoonLite focuser support? (No external SDK required)" "y"
		then
			BUILD_FOCUSER_MOONLITE=true
		fi
	fi
	
	#*	Rotator drivers
	if AskYesNo "Include rotator support? (NiteCrawler)" "y"
	then
		BUILD_ROTATOR=true
		BUILD_ROTATOR_NITECRAWLER=true
	fi
	
	#*	Telescope mount drivers
	if AskYesNo "Include telescope mount support?" "n"
	then
		BUILD_TELESCOPE=true
		
		if AskYesNo "  Include LX200 telescope mount support?" "n"
		then
			BUILD_TELESCOPE_LX200=true
		fi
		
		if AskYesNo "  Include SkyWatcher telescope mount support? (Not finished)" "n"
		then
			BUILD_TELESCOPE_SKYWATCHER=true
		fi
		
		if CheckFile "." "libs/src_servo"
	then
			if AskYesNo "  Include Servo telescope mount support?" "n"
		then
				BUILD_TELESCOPE_SERVO=true
		fi
		fi
	fi
	
	#*	Dome drivers
	if AskYesNo "Include dome support?" "n"
	then
		BUILD_DOME=true
	fi
	
	#*	Switch drivers
	if AskYesNo "Include switch support?" "n"
	then
		BUILD_SWITCH=true
	fi
	
	#*	Calibration control
	if AskYesNo "Include calibration control? (Flat panel control)" "y"
	then
		BUILD_CALIBRATION=true
	fi
	
	#*	Observing conditions
	if AskYesNo "Include observing conditions support?" "n"
	then
		BUILD_OBSERVINGCONDITIONS=true
	fi
	
	#*	Display summary
	echo ""
	echo "Selected drivers:"
	[ "$BUILD_CAMERA" = true ] && echo "	✓ Camera support"
	[ "$BUILD_CAMERA_ASI" = true ] && echo "	  - ZWO ASI cameras"
	[ "$BUILD_CAMERA_ATIK" = true ] && echo "	  - ATIK cameras"
	[ "$BUILD_CAMERA_FLIR" = true ] && echo "	  - FLIR cameras"
	[ "$BUILD_CAMERA_QHY" = true ] && echo "	  - QHY cameras"
	[ "$BUILD_CAMERA_TOUP" = true ] && echo "	  - ToupTek cameras"
	[ "$BUILD_FILTERWHEEL" = true ] && echo "	✓ Filter wheel support"
	[ "$BUILD_FILTERWHEEL_ZWO" = true ] && echo "	  - ZWO EFW filter wheel"
	[ "$BUILD_FILTERWHEEL_ATIK" = true ] && echo "	  - ATIK filter wheel"
	[ "$BUILD_FOCUSER" = true ] && echo "	✓ Focuser support"
	[ "$BUILD_FOCUSER_ZWO" = true ] && echo "	  - ZWO EAF focuser"
	[ "$BUILD_FOCUSER_MOONLITE" = true ] && echo "	  - MoonLite focuser"
	[ "$BUILD_ROTATOR" = true ] && echo "	✓ Rotator support (NiteCrawler)"
	[ "$BUILD_TELESCOPE" = true ] && echo "	✓ Telescope mount support"
	[ "$BUILD_TELESCOPE_LX200" = true ] && echo "	  - LX200 telescope mount"
	[ "$BUILD_TELESCOPE_SKYWATCHER" = true ] && echo "	  - SkyWatcher telescope mount"
	[ "$BUILD_TELESCOPE_SERVO" = true ] && echo "	  - Servo telescope mount"
	[ "$BUILD_DOME" = true ] && echo "	✓ Dome support"
	[ "$BUILD_SWITCH" = true ] && echo "	✓ Switch support"
	[ "$BUILD_CALIBRATION" = true ] && echo "	✓ Calibration control"
	[ "$BUILD_OBSERVINGCONDITIONS" = true ] && echo "	✓ Observing conditions"
	echo ""
}

###############################################################################
#	Build AlpacaPi
###############################################################################
BuildAlpacaPi()
{
	PrintSection "Building AlpacaPi"
	
	#*	Prompt for driver selection
	SelectDrivers
	
	if ! AskYesNo "Build AlpacaPi now? (This will compile alpacapi)" "n"
	then
		return 0
	fi
	
	LOGFILENAME="AlpacaPi_buildlog.txt"
	mkdir -p Objectfiles
	
	rm -f "$LOGFILENAME"
	echo "*******************************************" >> "$LOGFILENAME"
	echo -n "Start time = " >> "$LOGFILENAME"
	date >> "$LOGFILENAME"
	
	#*	Determine cores to use
	CORES=$(GetMakeJobs)
	NUM_CORES=$(DetectCores)
	PrintStep "Using $CORES (detected $NUM_CORES CPU cores) for parallel compilation"
	
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
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_CTRL_IMAGE_
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_LIVE_CONTROLLER_

EOF
	
	#*	Add OpenCV flags if OpenCV is detected
	if pkg-config --exists opencv4 2>/dev/null || pkg-config --exists opencv 2>/dev/null || \
	   [ -f "/usr/include/opencv2/highgui/highgui_c.h" ] || [ -f "/usr/local/include/opencv2/highgui/highgui_c.h" ] || \
	   [ -f "/usr/include/opencv4/opencv2/highgui/highgui.hpp" ] || [ -f "/usr/local/include/opencv4/opencv2/highgui/highgui.hpp" ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_USE_OPENCV_
EOF
	fi
	
	#*	Add conditional driver flags
	if [ "$BUILD_CAMERA" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_CAMERA_
EOF
		if [ "$BUILD_CAMERA_ASI" = true ]
		then
			cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_ASI_
EOF
	fi
		if [ "$BUILD_CAMERA_ATIK" = true ]
		then
			cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_ATIK_
EOF
		fi
		if [ "$BUILD_CAMERA_FLIR" = true ]
		then
			cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_FLIR_
EOF
		fi
		if [ "$BUILD_CAMERA_QHY" = true ]
		then
			cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_QHY_
EOF
		fi
		if [ "$BUILD_CAMERA_TOUP" = true ]
		then
			cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_TOUP_
EOF
		fi
	fi
	
	if [ "$BUILD_FILTERWHEEL" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_FILTERWHEEL_
EOF
		if [ "$BUILD_FILTERWHEEL_ZWO" = true ]
		then
			cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_FILTERWHEEL_ZWO_
EOF
	fi
		if [ "$BUILD_FILTERWHEEL_ATIK" = true ]
		then
			cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_FILTERWHEEL_ATIK_
EOF
		fi
	fi
	
	if [ "$BUILD_FOCUSER" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_FOCUSER_
EOF
		if [ "$BUILD_FOCUSER_ZWO" = true ]
		then
			cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_FOCUSER_ZWO_
EOF
		fi
		if [ "$BUILD_FOCUSER_MOONLITE" = true ]
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
	
	if [ "$BUILD_TELESCOPE" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_TELESCOPE_
EOF
		if [ "$BUILD_TELESCOPE_LX200" = true ]
		then
			cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_TELESCOPE_LX200_
EOF
		fi
		if [ "$BUILD_TELESCOPE_SKYWATCHER" = true ]
		then
			cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_TELESCOPE_SKYWATCH_
EOF
	fi
		if [ "$BUILD_TELESCOPE_SERVO" = true ]
		then
			cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_TELESCOPE_SERVO_
EOF
		fi
	fi
	
	if [ "$BUILD_DOME" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_DOME_
EOF
	fi
	
	if [ "$BUILD_SWITCH" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_SWITCH_
EOF
	fi
	
	if [ "$BUILD_CALIBRATION" = true ]
	then
	cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_CALIBRATION_
EOF
	fi
	
	if [ "$BUILD_OBSERVINGCONDITIONS" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_OBSERVINGCONDITIONS_
EOF
	fi
	
	#*	Add object dependencies
	cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	$(DRIVER_OBJECTS)				\
			$(HELPER_OBJECTS)				\
			$(SERIAL_OBJECTS)				\
			$(SOCKET_OBJECTS)

EOF
	
	#*	Add conditional object dependencies
	if [ "$BUILD_CAMERA" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	$(CAMERA_DRIVER_OBJECTS)
EOF
		if [ "$BUILD_CAMERA_ASI" = true ]
		then
			cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	$(ASI_CAMERA_OBJECTS)
EOF
		fi
	fi
	
	if [ "$BUILD_CALIBRATION" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	$(CALIBRATION_DRIVER_OBJECTS)
EOF
	fi
	
	if [ "$BUILD_FILTERWHEEL" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	$(FILTERWHEEL_DRIVER_OBJECTS)
EOF
		if [ "$BUILD_FILTERWHEEL_ZWO" = true ]
		then
			cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	$(ZWO_EFW_OBJECTS)
EOF
		fi
	fi
	
	if [ "$BUILD_FOCUSER" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	$(FOCUSER_DRIVER_OBJECTS)
EOF
		if [ "$BUILD_FOCUSER_ZWO" = true ]
		then
			cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	$(ZWO_EAF_LIB_DIR)libEAFFocuser.a
EOF
		fi
	fi
	
	#*	Add OpenCV-dependent objects if OpenCV is detected
	if pkg-config --exists opencv4 2>/dev/null || pkg-config --exists opencv 2>/dev/null || \
	   [ -f "/usr/include/opencv2/highgui/highgui_c.h" ] || [ -f "/usr/local/include/opencv2/highgui/highgui_c.h" ] || \
	   [ -f "/usr/include/opencv4/opencv2/highgui/highgui.hpp" ] || [ -f "/usr/local/include/opencv4/opencv2/highgui/highgui.hpp" ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
alpacapi_selective:	$(LIVE_WINDOW_OBJECTS)
EOF
	fi
	
	#*	Add link command - use Make variables directly for proper expansion
	cat >> "$CUSTOM_MAKEFILE" << 'EOF'
	$(LINK)  									\
EOF
	#*	Add objects using Make variables
	if [ "$BUILD_CAMERA" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
		$(CAMERA_DRIVER_OBJECTS)				\
EOF
		if [ "$BUILD_CAMERA_ASI" = true ]
		then
			cat >> "$CUSTOM_MAKEFILE" << 'EOF'
		$(ASI_CAMERA_OBJECTS)					\
EOF
		fi
	fi
	
	if [ "$BUILD_CALIBRATION" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
		$(CALIBRATION_DRIVER_OBJECTS)			\
EOF
	fi
	
	if [ "$BUILD_FILTERWHEEL" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
		$(FILTERWHEEL_DRIVER_OBJECTS)			\
EOF
		if [ "$BUILD_FILTERWHEEL_ZWO" = true ]
		then
			cat >> "$CUSTOM_MAKEFILE" << 'EOF'
		$(ZWO_EFW_OBJECTS)						\
EOF
		fi
	fi
	
	if [ "$BUILD_FOCUSER" = true ]
	then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
		$(FOCUSER_DRIVER_OBJECTS)				\
EOF
	fi
	
	#*	Add base objects and libraries
	cat >> "$CUSTOM_MAKEFILE" << 'EOF'
		$(DRIVER_OBJECTS)						\
		$(HELPER_OBJECTS)						\
		$(SERIAL_OBJECTS)						\
		$(SOCKET_OBJECTS)						\
EOF
	
	#*	Add OpenCV objects if detected
	if pkg-config --exists opencv4 2>/dev/null || pkg-config --exists opencv 2>/dev/null || \
	   [ -f "/usr/include/opencv2/highgui/highgui_c.h" ] || [ -f "/usr/local/include/opencv2/highgui/highgui_c.h" ] || \
	   [ -f "/usr/include/opencv4/opencv2/highgui/highgui.hpp" ] || [ -f "/usr/local/include/opencv4/opencv2/highgui/highgui.hpp" ]
		then
		cat >> "$CUSTOM_MAKEFILE" << 'EOF'
		$(LIVE_WINDOW_OBJECTS)					\
		$(OPENCV_LINK)							\
EOF
	fi
	
	#*	Add vendor libraries
	if [ "$BUILD_FOCUSER_ZWO" = true ]
	then
	cat >> "$CUSTOM_MAKEFILE" << EOF
		\$(ZWO_EAF_LIB_DIR)libEAFFocuser.a		\\
EOF
	fi
	
	#*	Add standard libraries
	cat >> "$CUSTOM_MAKEFILE" << 'EOF'
		-ludev									\
		-lusb-1.0								\
		-lpthread								\
		-lcfitsio								\
		-o alpacapi

EOF
	
	#*	Try building with custom Makefile
	BUILD_SUCCESS=false
	if [ "$ISARM64" = true ] || [ "$ISARM32" = true ] || [ "$ISX64" = true ]
	then
		make clean >/dev/null 2>&1
		BUILD_LOG=".selective_build.log"
		if make -f "$CUSTOM_MAKEFILE" $CORES alpacapi_selective >"$BUILD_LOG" 2>&1
		then
			BUILD_SUCCESS=true
			PrintSuccess "Built alpacapi with selected drivers"
			rm -f "$BUILD_LOG"
		else
			PrintWarning "Selective build failed, falling back to default build"
			if [ -f "$BUILD_LOG" ]
			then
				echo "Build error details (last 20 lines):"
				tail -20 "$BUILD_LOG"
				echo ""
				echo "Full build log saved to: $BUILD_LOG"
			fi
		fi
	fi
	
	#*	Fall back to standard build if custom build failed
	if [ "$BUILD_SUCCESS" = false ]
	then
		PrintStep "Falling back to standard build..."
		make clean >/dev/null 2>&1
		if [ "$ISARM64" = true ]
		then
			make $CORES pi64 >"$BUILD_LOG" 2>&1 || true
		elif [ "$ISARM32" = true ]
		then
			make $CORES pi >"$BUILD_LOG" 2>&1 || true
		else
			make $CORES alpacapi >"$BUILD_LOG" 2>&1 || true
		fi
	fi
	
	#*	Clean up temporary Makefile
	rm -f "$CUSTOM_MAKEFILE"
	
	#*	Check results
	echo -n "End time = " >> "$LOGFILENAME"
	date >> "$LOGFILENAME"
	
	if [ -f "alpacapi" ]
	then
		PrintSuccess "AlpacaPi server built successfully!"
		echo "	Log saved as $LOGFILENAME"
	else
		PrintWarning "AlpacaPi server build may have failed (check $LOGFILENAME)"
	fi
}

###############################################################################
#	Parse Command Line Arguments
###############################################################################
ParseArguments()
{
	while [ $# -gt 0 ]
	do
		case "$1" in
			-u|--uninstall)
				UNINSTALL_MODE=true
				shift
				;;
			-h|--help)
				echo "AlpacaPi Setup Script"
				echo ""
				echo "Usage: $0 [OPTIONS]"
				echo ""
				echo "Options:"
				echo "  -u, --uninstall    Uninstall AlpacaPi (remove binaries and USB rules)"
				echo "  -h, --help         Show this help message"
				echo ""
				exit 0
				;;
			*)
				PrintError "Unknown option: $1"
				echo "Use -h or --help for usage information"
				exit 1
				;;
		esac
	done
}

###############################################################################
#	Main Function
###############################################################################
main()
{
	#*	Parse command line arguments
	ParseArguments "$@"
	
	#*	If uninstall mode, run uninstall and exit
	if [ "$UNINSTALL_MODE" = true ]
	then
		clear
		UninstallAlpacaPi
		exit 0
	fi
	
	clear
	PrintSection "AlpacaPi Setup"
	echo ""
	echo "This script will verify system requirements and help you build alpacapi."
	echo ""
	echo "Setup steps:"
	echo "	1. Check system requirements (build tools and system libraries)"
	echo "	2. Check/Install OpenCV"
	echo "	3. Install USB device rules"
	echo "	4. Check vendor SDKs"
	echo "	5. Select drivers to build"
	echo "	6. Build alpacapi"
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
	
	#*	Check system requirements
	CheckSystemRequirements
	
	#*	Check/Install OpenCV
	CheckOpenCV
	
	#*	Install USB rules
	if AskYesNo "Install USB device rules? (Required for USB device access)" "y"
	then
		InstallUSBRules
	fi
	
	#*	Check vendor SDKs
	CheckVendorSDKs
	
	#*	Build AlpacaPi
	if AskYesNo "Build AlpacaPi now? (Compile alpacapi)" "n"
	then
		BuildAlpacaPi
	fi
	
	#*	Final summary
	PrintSection "Setup Complete!"
	echo ""
	if [ -f "alpacapi" ]
	then
		echo "AlpacaPi server (alpacapi) has been built successfully!"
		echo ""
		echo "To run AlpacaPi server:"
		echo "	./alpacapi"
	else
		echo "To build AlpacaPi server:"
		echo "	./setup_complete.sh"
		echo "	OR"
		echo "	make alpacapi"
	fi
	echo ""
	
	PrintSuccess "Setup script completed!"
}

###############################################################################
#	Run main function
###############################################################################
main "$@"
