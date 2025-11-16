#!/bin/bash
###############################################################################
#	AlpacaPi System Configuration Script
#	Installs all required dependencies, tools, and applications
###############################################################################
#	Edit History
###############################################################################
#	Jan 2025	<JTS> Initial creation - system configuration and tool installation
###############################################################################

set -e		#*	exit on error

###############################################################################
#	Configuration
###############################################################################
INSTALLED_ANYTHING=false	#*	track if anything was installed

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

CheckCommand()
{
	if command -v "$1" >/dev/null 2>&1
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
	
	#*	Install missing tools automatically
	if [ $MISSING_TOOLS -gt 0 ]
	then
		PrintWarning "$MISSING_TOOLS build tool(s) missing - installing..."
		InstallBuildTools
	fi
	
	#*	Install missing libraries automatically
	if [ $MISSING_LIBS -gt 0 ]
	then
		PrintWarning "$MISSING_LIBS system library/libraries missing - installing..."
		InstallSystemLibraries
	else
		PrintSuccess "All required system libraries are installed"
	fi
}

###############################################################################
#	Check if package is installed
###############################################################################
IsPackageInstalled()
{
	dpkg -l | grep -q "^ii.*$1 " 2>/dev/null
}

###############################################################################
#	Install Build Tools
###############################################################################
InstallBuildTools()
{
	PrintSection "Installing Build Tools"
	
	NEED_INSTALL=false
	
	#*	Check if build-essential is installed
	if IsPackageInstalled "build-essential"
	then
		PrintSuccess "build-essential is already installed"
	else
		NEED_INSTALL=true
	fi
	
	#*	Check if pkg-config is installed
	if IsPackageInstalled "pkg-config"
	then
		PrintSuccess "pkg-config is already installed"
	else
		NEED_INSTALL=true
	fi
	
	if [ "$NEED_INSTALL" = false ]
	then
		PrintSuccess "All build tools are already installed"
		return 0
	fi
	
	INSTALLED_ANYTHING=true
	
	PrintStep "Updating package lists..."
	UPDATE_OUTPUT=$(sudo apt-get update 2>&1)
	if echo "$UPDATE_OUTPUT" | grep -qE "Err:|404"
	then
		PrintWarning "Some repositories failed to update"
	fi
	echo "$UPDATE_OUTPUT" | FilterAptErrors
	
	if ! IsPackageInstalled "build-essential"
	then
		PrintStep "Installing build-essential (gcc, g++, make)..."
		sudo apt-get install -y build-essential
	fi
	
	if ! IsPackageInstalled "pkg-config"
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
	
	LIBRARIES=(
		"libusb-1.0-0-dev"
		"libudev-dev"
		"libi2c-dev"
		"libjpeg-dev"
		"libcfitsio-dev"
		"libgtk2.0-dev"
	)
	
	MISSING_LIBS=()
	INSTALLED_COUNT=0
	
	#*	Check which libraries are already installed
	for LIB in "${LIBRARIES[@]}"
	do
		if IsPackageInstalled "$LIB"
		then
			PrintSuccess "$LIB is already installed"
			INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
		else
			MISSING_LIBS+=("$LIB")
		fi
	done
	
	if [ ${#MISSING_LIBS[@]} -eq 0 ]
	then
		PrintSuccess "All system libraries are already installed"
		return 0
	fi
	
	INSTALLED_ANYTHING=true
	
	PrintStep "Updating package lists..."
	UPDATE_OUTPUT=$(sudo apt-get update 2>&1)
	if echo "$UPDATE_OUTPUT" | grep -qE "Err:|404"
	then
		PrintWarning "Some repositories failed to update"
	fi
	echo "$UPDATE_OUTPUT" | FilterAptErrors
	
	PrintStep "Installing ${#MISSING_LIBS[@]} missing library/libraries..."
	sudo apt-get install -y "${MISSING_LIBS[@]}"
	
	PrintSuccess "System libraries installation complete"
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
		PrintWarning "OpenCV not found - installing..."
		InstallOpenCV
	else
		echo "	Location: $OPENCV_LOCATION"
		PrintSuccess "OpenCV is installed"
	fi
}

InstallOpenCV()
{
	PrintSection "OpenCV Installation"
	
	NEED_INSTALL=false
	OPENCV_PACKAGES=("libopencv-dev" "libopencv-contrib-dev")
	MISSING_PACKAGES=()
	
	#*	Check which OpenCV packages are already installed
	for PKG in "${OPENCV_PACKAGES[@]}"
	do
		if IsPackageInstalled "$PKG"
		then
			PrintSuccess "$PKG is already installed"
		else
			MISSING_PACKAGES+=("$PKG")
			NEED_INSTALL=true
		fi
	done
	
	if [ "$NEED_INSTALL" = false ]
	then
		PrintSuccess "OpenCV packages are already installed"
		sudo ldconfig
		return 0
	fi
	
	INSTALLED_ANYTHING=true
	
	PrintStep "Updating package lists..."
	sudo apt-get update 2>&1 | FilterAptErrors
	
	PrintStep "Installing ${#MISSING_PACKAGES[@]} OpenCV package(s)..."
	if sudo apt-get install -y "${MISSING_PACKAGES[@]}" 2>&1 | FilterAptErrors
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
#	Install Neofetch
###############################################################################
InstallNeofetch()
{
	PrintSection "Installing Neofetch"
	
	if CheckCommand neofetch || IsPackageInstalled "neofetch"
	then
		PrintSuccess "Neofetch is already installed"
	else
		INSTALLED_ANYTHING=true
		PrintStep "Installing Neofetch..."
		sudo apt-get update 2>&1 | FilterAptErrors
		sudo apt-get install -y neofetch
		PrintSuccess "Neofetch installed"
	fi
	
	#*	Add neofetch to .bashrc if not already present
	PrintStep "Configuring Neofetch in .bashrc..."
	BASHRC_FILE="$HOME/.bashrc"
	
	if [ -f "$BASHRC_FILE" ]
	then
		if grep -q "neofetch" "$BASHRC_FILE"
		then
			PrintSuccess "Neofetch already configured in .bashrc"
		else
			echo "" >> "$BASHRC_FILE"
			echo "# Run neofetch on startup" >> "$BASHRC_FILE"
			echo "neofetch" >> "$BASHRC_FILE"
			PrintSuccess "Neofetch added to .bashrc"
		fi
	else
		PrintWarning ".bashrc not found, creating..."
		echo "# Run neofetch on startup" > "$BASHRC_FILE"
		echo "neofetch" >> "$BASHRC_FILE"
		PrintSuccess "Created .bashrc with neofetch"
	fi
}

###############################################################################
#	Check if Go module is installed
###############################################################################
IsGoModuleInstalled()
{
	if ! CheckCommand go
	then
		return 1
	fi
	
	#*	Get Go module cache directory
	GOMODCACHE_DIR=$(go env GOMODCACHE 2>/dev/null)
	if [ -z "$GOMODCACHE_DIR" ]
	then
		#*	Default location if GOMODCACHE not set
		GOMODCACHE_DIR="$HOME/go/pkg/mod"
	fi
	
	#*	Check if module directory exists in cache (Go stores modules with @version suffix)
	#*	We check for any version by looking for the module path prefix
	if [ -d "$GOMODCACHE_DIR" ]
	then
		MODULE_BASE="$GOMODCACHE_DIR/$1@"
		if ls -d "${MODULE_BASE}"* >/dev/null 2>&1
		then
			return 0
		fi
	fi
	
	#*	Fallback: try go list in a temporary module context (more reliable but slower)
	TEMP_CHECK_DIR=$(mktemp -d)
	cd "$TEMP_CHECK_DIR" >/dev/null 2>&1 || return 1
	
	if go mod init temp/check >/dev/null 2>&1
	then
		if go list -m "$1" >/dev/null 2>&1
		then
			cd - >/dev/null 2>&1
			rm -rf "$TEMP_CHECK_DIR"
			return 0
		fi
	fi
	
	cd - >/dev/null 2>&1
	rm -rf "$TEMP_CHECK_DIR"
	return 1
}

###############################################################################
#	Install Charm Tools (gum and bubbles)
###############################################################################
InstallCharmTools()
{
	PrintSection "Installing Charm Tools (gum and bubbles)"
	
	#*	Determine architecture for binary download
	ARCH=""
	if [ "$ISARM64" = true ]
	then
		ARCH="arm64"
	elif [ "$ISARM32" = true ]
	then
		ARCH="armv6"
	elif [ "$ISX64" = true ]
	then
		ARCH="amd64"
	else
		PrintError "Unknown architecture for Charm tools installation"
		return 1
	fi
	
	#*	Install gum
	if CheckCommand gum
	then
		PrintSuccess "gum is already installed"
	else
		PrintStep "Installing gum..."
		GUM_VERSION=$(curl -s https://api.github.com/repos/charmbracelet/gum/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
		if [ -z "$GUM_VERSION" ]
		then
			GUM_VERSION="v0.13.0"	#*	Fallback version
		fi
		
		GUM_URL="https://github.com/charmbracelet/gum/releases/download/${GUM_VERSION}/gum_${GUM_VERSION#v}_linux_${ARCH}.tar.gz"
		
		TEMP_DIR=$(mktemp -d)
		cd "$TEMP_DIR"
		
		curl -L "$GUM_URL" -o gum.tar.gz 2>/dev/null || {
			PrintError "Failed to download gum"
			cd - >/dev/null
			rm -rf "$TEMP_DIR"
			return 1
		}
		
		tar -xzf gum.tar.gz
		
		#*	Find the gum binary (could be in a subdirectory or directly in temp dir)
		if [ -f "gum" ]
		then
			GUM_BINARY="gum"
		elif [ -f "gum_${GUM_VERSION#v}_linux_${ARCH}/gum" ]
		then
			GUM_BINARY="gum_${GUM_VERSION#v}_linux_${ARCH}/gum"
		else
			#*	Search for gum binary in extracted files
			GUM_BINARY=$(find . -name "gum" -type f | head -1)
			if [ -z "$GUM_BINARY" ]
			then
				PrintError "Could not find gum binary in extracted archive"
				cd - >/dev/null
				rm -rf "$TEMP_DIR"
				return 1
			fi
		fi
		
		sudo mv "$GUM_BINARY" /usr/local/bin/gum
		sudo chmod +x /usr/local/bin/gum
		
		cd - >/dev/null
		rm -rf "$TEMP_DIR"
		
		INSTALLED_ANYTHING=true
		
		#*	Verify installation
		if CheckCommand gum
		then
			PrintSuccess "gum installed successfully"
		else
			PrintError "gum installation failed - binary not found in PATH"
			return 1
		fi
	fi
	
	#*	Install Go (required for bubbles)
	PrintStep "Checking for Go (required for bubbles)..."
	if CheckCommand go
	then
		PrintSuccess "Go is already installed"
	else
		if IsPackageInstalled "golang-go"
		then
			PrintSuccess "golang-go package is installed"
		else
			INSTALLED_ANYTHING=true
			PrintStep "Installing Go (golang-go)..."
			sudo apt-get update 2>&1 | FilterAptErrors
			sudo apt-get install -y golang-go
			
			#*	Verify installation
			if CheckCommand go
			then
				PrintSuccess "Go installed successfully"
			else
				PrintWarning "Go package installed but command not found - may need to reload PATH"
			fi
		fi
	fi
	
	#*	Install Charm Go modules
	PrintStep "Installing Charm Go modules..."
	if ! CheckCommand go
	then
		PrintWarning "Go is not installed - skipping Go module installation"
		PrintWarning "Install Go first, then create a Go module and run:"
		PrintWarning "	go get github.com/charmbracelet/bubbletea@latest"
		PrintWarning "	go get github.com/charmbracelet/bubbles@latest"
		PrintWarning "	go get github.com/charmbracelet/lipgloss@latest"
	else
		CHARM_MODULES=(
			"github.com/charmbracelet/bubbletea@latest"
			"github.com/charmbracelet/bubbles@latest"
			"github.com/charmbracelet/lipgloss@latest"
		)
		
		INSTALLED_MODULES=0
		MISSING_MODULES=()
		
		#*	Check which modules are already installed
		PrintStep "Checking for existing Charm Go modules..."
		for MODULE in "${CHARM_MODULES[@]}"
		do
			MODULE_NAME=$(echo "$MODULE" | cut -d'@' -f1)
			if IsGoModuleInstalled "$MODULE_NAME"
			then
				PrintSuccess "$MODULE_NAME is already installed"
				INSTALLED_MODULES=$((INSTALLED_MODULES + 1))
			else
				MISSING_MODULES+=("$MODULE")
			fi
		done
		
		if [ ${#MISSING_MODULES[@]} -gt 0 ]
		then
			echo "	Found ${INSTALLED_MODULES} installed, ${#MISSING_MODULES[@]} to install"
		fi
		
		#*	Install missing modules
		if [ ${#MISSING_MODULES[@]} -eq 0 ]
		then
			PrintSuccess "All Charm Go modules are already installed"
		else
			INSTALLED_ANYTHING=true
			PrintStep "Installing ${#MISSING_MODULES[@]} missing Charm Go module(s)..."
			
			#*	Create temporary Go module to download packages
			#*	This caches them in the global Go module cache
			TEMP_GO_DIR=$(mktemp -d)
			cd "$TEMP_GO_DIR"
			
			#*	Initialize a temporary Go module
			if ! go mod init temp/alpacapi-charm-install >/dev/null 2>&1
			then
				PrintError "Failed to initialize temporary Go module"
				cd - >/dev/null
				rm -rf "$TEMP_GO_DIR"
				return 1
			fi
			
			#*	Install all missing modules in the temporary module
			for MODULE in "${MISSING_MODULES[@]}"
			do
				MODULE_NAME=$(echo "$MODULE" | cut -d'@' -f1)
				PrintStep "Installing $MODULE_NAME..."
				
				#*	Use timeout to prevent hanging (60 seconds should be enough)
				#*	Check if timeout command is available
				if CheckCommand timeout
				then
					ERROR_OUTPUT=$(timeout 60 go get "$MODULE" 2>&1)
					EXIT_CODE=$?
				else
					ERROR_OUTPUT=$(go get "$MODULE" 2>&1)
					EXIT_CODE=$?
				fi
				
				if [ $EXIT_CODE -eq 0 ]
				then
					PrintSuccess "$MODULE_NAME installed successfully"
				else
					if [ $EXIT_CODE -eq 124 ]
					then
						PrintError "Failed to install $MODULE_NAME (timeout after 60 seconds)"
					else
						PrintError "Failed to install $MODULE_NAME"
						echo "$ERROR_OUTPUT" | head -5 | sed 's/^/	/'
					fi
				fi
			done
			
			#*	Clean up temporary directory
			cd - >/dev/null
			rm -rf "$TEMP_GO_DIR"
		fi
	fi
	
	PrintSuccess "Charm tools installation complete"
}

###############################################################################
#	Main Function
###############################################################################
main()
{
	clear
	PrintSection "AlpacaPi System Configuration"
	echo ""
	echo "This script will:"
	echo "	1. Detect platform"
	echo "	2. Check and install system requirements"
	echo "	3. Install OpenCV"
	echo "	4. Install Neofetch and configure .bashrc"
	echo "	5. Install Charm tools (gum and Go modules)"
	echo "	6. Reboot the system"
	echo ""
	
	read -p "Press Enter to continue or Ctrl+C to cancel..."
	
	#*	Determine platform
	DeterminePlatform
	
	#*	Check and install system requirements
	CheckSystemRequirements
	
	#*	Check and install OpenCV
	CheckOpenCV
	
	#*	Install Neofetch
	InstallNeofetch
	
	#*	Install Charm tools
	InstallCharmTools
	
	#*	Final summary
	PrintSection "Configuration Complete!"
	echo ""
	PrintSuccess "All components have been checked and configured"
	echo ""
	echo "Installed components:"
	echo "	✓ Build tools (gcc, g++, make, pkg-config)"
	echo "	✓ System libraries (libusb, libudev, libi2c, libjpeg, libcfitsio, libgtk2.0)"
	echo "	✓ OpenCV"
	echo "	✓ Neofetch (configured in .bashrc)"
	echo "	✓ Charm tools (gum)"
	if CheckCommand go
	then
		echo "	✓ Go (golang-go)"
		if IsGoModuleInstalled "github.com/charmbracelet/bubbletea"
		then
			echo "	✓ Charm Go modules (bubbletea, bubbles, lipgloss)"
		fi
	fi
	echo ""
	
	if [ "$INSTALLED_ANYTHING" = true ]
	then
		PrintWarning "New packages were installed - system will reboot in 10 seconds..."
		PrintWarning "Press Ctrl+C to cancel"
		
		sleep 10
		
		PrintStep "Rebooting system..."
		sudo reboot
	else
		PrintSuccess "All components were already installed - no reboot needed"
		echo ""
		PrintSuccess "Configuration check complete!"
	fi
}

###############################################################################
#	Run main function
###############################################################################
main "$@"

