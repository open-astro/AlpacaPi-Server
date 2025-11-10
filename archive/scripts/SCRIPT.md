# AlpacaPi Scripts Documentation

This document describes all shell scripts in the AlpacaPi project, their purpose, and how they interact with each other.

## Table of Contents

1. [Quick Start - Single Setup Script](#quick-start---single-setup-script)
2. [Main Setup Scripts](#main-setup-scripts)
3. [Installation Scripts](#installation-scripts)
4. [Build Scripts](#build-scripts)
5. [Utility Scripts](#utility-scripts)
6. [Subdirectory Scripts](#subdirectory-scripts)
7. [Script Interaction Flow](#script-interaction-flow)

---

## Quick Start - Single Setup Script

### `setup_complete.sh` ⭐ **RECOMMENDED**
**Purpose**: **Single comprehensive setup script that does everything**  
**Location**: Root directory  
**Status**: ✅ **NEW** - Consolidates all setup functionality into one script  
**Dependencies**: None (entry point)

**What it does** (in order):
1. **Checks system requirements** - Build tools, project files
2. **Detects platform** - x64, ARM32, ARM64
3. **Installs build tools** - gcc, g++, make, cmake, pkg-config, git (if missing)
4. **Installs system libraries** - libusb-1.0-0-dev, libudev-dev, libi2c-dev, libjpeg-dev
5. **Installs FITS library** - Tries package manager first, falls back to source
6. **Checks OpenCV** - Detects if installed, provides installation guidance
7. **Installs USB rules** - Calls `install_rules.sh` for device access
8. **Checks vendor SDKs** - Detects present SDKs, optionally installs them
9. **Provides next steps** - Clear guidance on what to do next

**Usage**: 
```bash
./setup_complete.sh
```

**Features**:
- ✅ **Single script** - No need to run multiple scripts
- ✅ **Interactive prompts** - Asks before installing (can be automated)
- ✅ **Error handling** - Checks before installing, provides clear errors
- ✅ **Platform aware** - Works on x64, ARM32, ARM64
- ✅ **Idempotent** - Safe to run multiple times
- ✅ **Clear output** - Color-coded status messages
- ✅ **Comprehensive** - Handles all setup tasks

**Configuration** (edit script to change):
- `AUTO_INSTALL=false` - Set to `true` to skip prompts
- `INSTALL_VENDOR_SDKS=false` - Set to `true` to auto-install vendor SDKs

**Why use this instead of multiple scripts?**
- Simpler: One command instead of 5+ scripts
- Complete: Handles all setup tasks in correct order
- Safer: Better error checking and validation
- Clearer: Provides guidance and next steps
- Maintainable: Single script to update instead of many

**Note**: This script consolidates functionality from:
- `setup.sh` (system checks)
- `install_dev_env.sh` (build tools)
- `install_everything.sh` (system libraries)
- `install_fits.sh` (FITS library)
- `install_rules.sh` (USB rules)
- `install_libraries.sh` (vendor SDKs - optional)

---

## Main Setup Scripts

### `setup.sh` ⚠️ **ARCHIVED**
**Status**: ⚠️ **ARCHIVED** - Replaced by `setup_complete.sh`  
**Location**: `archive/scripts/` directory  
**Reason Archived**: Incomplete implementation, functionality consolidated into `setup_complete.sh`

**Note**: This script has been moved to `archive/scripts/` and is no longer maintained.  
**Use**: `setup_complete.sh` instead for all setup tasks.  

**What it currently does**:
- Checks for required build tools (gcc, g++, make, cmake) - **only checks, doesn't install**
- Verifies local project files and directories exist
- Checks for system libraries (FITS, OpenCV) - **only checks, doesn't install OpenCV**
- Detects platform (ARMv7 only - **missing ARM64 detection**)
- Creates `Objectfiles` directory
- Checks for FITS library installation
- Can install FITS via `InstallFits()` function
- Checks for FLIR SDK if present (can install)
- Installs libusb-1.0-0-dev (hardcoded at end)
- Provides system status report

**What's Missing** (compared to `install_everything.sh` and requirements):
1. **System package update** - No `apt-get update` before installing packages
2. **Missing system library installations**:
   - `libudev-dev` - Defined but commented out (line 349)
   - `libi2c-dev` - Not installed
   - `libcfitsio-dev` - Not installed (package manager version)
   - `libjpeg-dev` - Function `setupJPEGlib()` exists but **never called**
3. **USB rules installation** - Doesn't call `install_rules.sh`
4. **Platform detection incomplete** - Only checks ARMv7, missing ARM64 (aarch64) detection
5. **OpenCV installation** - Only checks for OpenCV, doesn't offer to install it
6. **Vendor SDK setup** - Doesn't set up ASI, EFW, ATIK, or other vendor SDKs
7. **Error handling** - Shows MISSING_COUNT but doesn't take action on missing items
8. **Completion flow** - Script ends with "not finished" message, no clear next steps

**Usage**: Run this first when setting up AlpacaPi on a new system  
**Interacts with**: `install_fits.sh` (called internally for FITS installation)  
**Testing Needed**: Script needs completion and testing on all supported platforms

**Recommended Completion Steps**:
1. Add `apt-get update` at start
2. Add automatic installation of missing build tools (or prompt user)
3. Add installation of `libudev-dev`, `libi2c-dev`, `libcfitsio-dev`
4. Call `setupJPEGlib()` if JPEG support needed
5. Add ARM64 platform detection
6. Add option to install OpenCV or provide instructions
7. Call `install_rules.sh` for USB device access
8. Add option to set up vendor SDKs or direct user to `install_libraries.sh`
9. Improve error handling and provide actionable next steps
10. Remove "not finished" message when complete

---

### `install_everything.sh` ⚠️ **ARCHIVED**
**Status**: ⚠️ **ARCHIVED** - Replaced by `setup_complete.sh`  
**Location**: `archive/scripts/` directory  
**Reason Archived**: Incomplete implementation, functionality consolidated into `setup_complete.sh`

**Note**: This script has been moved to `archive/scripts/` and is no longer maintained.  
**Use**: `setup_complete.sh` instead for all setup tasks.  
**What it does**:
- Updates system packages (`apt-get update`)
- Installs core development libraries:
  - `libusb-1.0-0-dev`
  - `libudev-dev`
  - `libi2c-dev`
  - `libcfitsio-dev`
- Calls `install_rules.sh` to set up USB device rules
- Checks for required SDK files (ASI, EFW, ATIK, Toupcam, FITS)
- Sets up directories
- Installs cfitsio (via `install_fits.sh`)
- Sets up ASI camera library
- Sets up EFW (ZWO filter wheel) library
- Sets up ATIK camera library
- Sets up Toupcam library
- Installs libUSB

**Usage**: Run after `setup.sh` to install all dependencies  
**Interacts with**: 
- `install_rules.sh` (USB rules)
- `install_fits.sh` (FITS library)
- Downloads and extracts vendor SDKs

---

### `install_dev_env.sh` ⚠️ **ARCHIVED**
**Status**: ⚠️ **ARCHIVED** - Replaced by `setup_complete.sh`  
**Location**: `archive/scripts/` directory  
**Reason Archived**: Functionality consolidated into `setup_complete.sh`

**Note**: This script has been moved to `archive/scripts/` and is no longer maintained.  
**Use**: `setup_complete.sh` instead for all setup tasks.  
**What it does**:
- Installs `build-essential` (gcc, g++, make, etc.)
- Installs `pkg-config`
- Installs `cmake`
- Installs `git`

**Usage**: Run first on a fresh system before other installation scripts  
**Interacts with**: None (standalone)

---

## Installation Scripts

### `install_libraries.sh`
**Purpose**: Installs vendor-specific camera and device driver libraries  
**Location**: Root directory  
**Dependencies**: Vendor SDK directories must exist  
**Status**: ⚠️ **PARTIALLY COMPLETE** - README notes "this script still has more work needed"  
**Known Issues**:
- ToupTek installation only supports 32-bit ARM (armhf) as of 3/19/2021
- Missing support for x64 and ARM64 platforms for ToupTek
- Other vendor libraries may need additional platform support

**What it does**:
- Detects platform (x64, ARM32, ARM64)
- Checks for vendor SDK directories:
  - ASI_lib (ZWO cameras)
  - AtikCamerasSDK
  - EFW_linux_mac_SDK (ZWO filter wheels)
  - FLIR-SDK
  - QHY
  - toupcamsdk
  - ZWO_EAF_SDK (ZWO focusers)
- Installs ATIK camera libraries (platform-specific)
- Installs Touptech camera libraries (⚠️ ARM32 only)
- Installs FLIR Spinnaker SDK (if present)
- Installs ZWO EAF focuser libraries
- Downloads and installs QHY camera SDK
- Copies libraries to `/usr/lib`

**Usage**: Run after vendor SDKs are downloaded/extracted  
**Interacts with**: Vendor SDK directories, platform detection  
**Testing Needed**: 
- Test ToupTek installation on x64 and ARM64 platforms
- Verify all vendor libraries install correctly on all supported platforms
- Test platform detection accuracy

---

### `install_fits.sh`
**Purpose**: Downloads, builds, and installs cfitsio library for FITS file support  
**Location**: Root directory  
**Dependencies**: Requires build tools (gcc, make)  
**What it does**:
- Checks if cfitsio is already installed
- Downloads `cfitsio_latest.tar.gz` if not present
- Detects cfitsio version (3.47, 3.48, 3.49, 3.50, 4.0.0, 4.1.0, 4.4.1, 4.5.0)
- Extracts tar file
- Configures build (`./configure --prefix=/usr/local`)
- Compiles (`make`)
- Installs (`sudo make install`)
- Runs test program to verify installation
- Updates library cache (`ldconfig`)

**Usage**: Called by `setup.sh` or `install_everything.sh`, or run standalone  
**Interacts with**: System package manager, NASA FITS library repository

---

### `install_opencv.sh`
**Purpose**: Downloads, builds, and installs OpenCV version 3.3.1 or 3.2.0  
**Location**: Root directory  
**Dependencies**: Requires cmake, build tools, libgtk2.0-dev, libjpeg-dev  
**What it does**:
- Updates system packages
- Installs libjpeg-dev and libgtk2.0-dev
- Checks for make and cmake
- Creates `opencv` directory
- Downloads OpenCV 3.3.1 or 3.2.0 from GitHub
- Extracts source code
- Runs cmake configuration
- Compiles OpenCV (can take 4+ hours on Raspberry Pi)
- Installs OpenCV system-wide
- Updates library cache

**Warnings**: 
- Build process can take 4+ hours on Raspberry Pi
- Takes 5+ hours on Jetson Nano

**Usage**: Run if OpenCV 3.x is needed (legacy support)  
**Interacts with**: GitHub OpenCV repository

---

### `install_opencv451.sh`
**Purpose**: Downloads, builds, and installs OpenCV version 4.5.1  
**Location**: Root directory  
**Dependencies**: Requires cmake, build tools  
**What it does**:
- Checks for make and cmake
- Creates `opencv` directory
- Downloads OpenCV 4.5.1 from GitHub
- Downloads opencv_contrib repository
- Extracts source code
- Runs cmake configuration
- Compiles OpenCV (can take 4+ hours)
- Installs OpenCV system-wide
- Updates library cache

**Warnings**: 
- Build process can take 4+ hours on Raspberry Pi
- Takes 5+ hours on Jetson Nano

**Usage**: Run if OpenCV 4.x is needed (current version)  
**Interacts with**: GitHub OpenCV and opencv_contrib repositories

---

### `install_playerone.sh`
**Purpose**: Downloads and installs PlayerOne camera and filter wheel SDKs  
**Location**: Root directory  
**Dependencies**: Requires wget, tar  
**What it does**:
- Detects platform (x64, x86, arm32, arm64)
- Creates `PlayerOne` directory
- Downloads PlayerOne Camera SDK (V3.6.2)
- Downloads PlayerOne Filter Wheel SDK (V1.2.0)
- Extracts SDKs
- Copies platform-specific libraries to `/usr/lib`
- Creates symlinks for include directories
- Installs USB udev rules file (`99-player_one_astronomy.rules`)

**Usage**: Run to add PlayerOne camera/filter wheel support  
**Interacts with**: PlayerOne download servers, system `/usr/lib`

---

### `install_qsi.sh`
**Purpose**: Installs QSI (Quantum Scientific Imaging) camera SDK and dependencies  
**Location**: Root directory  
**Dependencies**: Requires libudev-dev, libftd2xx  
**What it does**:
- Detects platform (x64, armv7, armv8)
- Installs libudev-dev
- Downloads and installs libftd2xx (FTDI USB library) for platform
- Downloads QSI API (qsiapi-7.6.0)
- Configures QSI build (`./configure`)
- Compiles QSI library (`make all`)
- Installs QSI library (`sudo make install`)
- Updates library cache

**Usage**: Run to add QSI camera support  
**Interacts with**: QSI and FTDI download servers

---

### `install_wiringpi.sh`
**Purpose**: Installs WiringPi library for Raspberry Pi GPIO access  
**Location**: Root directory  
**Dependencies**: Requires git, ARM platform  
**What it does**:
- Detects if running on ARM platform (Raspberry Pi)
- Clones WiringPi repository from GitHub
- Builds WiringPi library
- Installs WiringPi

**Usage**: Run on Raspberry Pi systems that need GPIO control  
**Interacts with**: GitHub WiringPi repository

---

### `install_rules.sh`
**Purpose**: Installs USB udev rules files for various astronomy devices  
**Location**: Root directory  
**Dependencies**: Requires vendor SDK directories with rules files  
**What it does**:
- Installs rules for ZWO cameras (`asi.rules`)
- Installs rules for ZWO filter wheels (`efw.rules`)
- Installs rules for ATIK cameras (`99-atik.rules`)
- Installs rules for Toupcam cameras (`99-toupcam.rules`)
- Installs rules for FLIR cameras (`40-flir-spinnaker.rules`)
- Installs rules for QHY cameras (`85-qhyccd.rules`)
- Installs rules for ZWO EAF focusers (`eaf.rules`)
- Copies rules to `/lib/udev/rules.d/` or `/etc/udev/rules.d/`

**Usage**: Run after vendor SDKs are installed to enable USB device access  
**Interacts with**: Vendor SDK directories, system udev rules directory

---

### `remove_fits.sh`
**Purpose**: Removes cfitsio library from system (for upgrading)  
**Location**: Root directory  
**Dependencies**: None  
**What it does**:
- Prompts for confirmation
- Removes cfitsio library files from `/usr/local/lib`
- Removes cfitsio header files from `/usr/local/include`
- Removes local cfitsio source directories
- Removes downloaded tar files

**Usage**: Run before installing a new version of cfitsio  
**Interacts with**: System library directories

---

## Build Scripts

### `build_all.sh`
**Purpose**: Comprehensive build script that compiles all AlpacaPi components  
**Location**: Root directory  
**Dependencies**: Requires all libraries installed, Makefile present  
**What it does**:
- Detects platform (x86_64, aarch64, armv7l, armv8)
- Detects OpenCV version (3 or 4)
- Creates build log file (`AlpacaPi_buildlog.txt`)
- Creates `Objectfiles` directory
- Builds components in order:
  1. `client` (basic client)
  2. If OpenCV 3: `camera`, `domectrl`, `focuser`, `rorpi`, `switch`, `skytravel`, `calib`
  3. If OpenCV 4: `cameracv4`, `domectrlcv4`, `focusercv4`, `picv4`, `switchcv4`, `skycv4`, `calibcv4`
  4. Platform-specific server builds:
     - ARM64: `pi64`
     - ARM32: `pi`
     - x86: default `alpacapi`
  5. Additional drivers: `ror` (topens), `alpacapi-expsci` (pmc8)
- Uses parallel compilation (`-j4` or `-j10` depending on platform)
- Logs all build results
- Displays build summary

**Usage**: Run after installation to build all components  
**Interacts with**: Makefile, OpenCV installation, platform detection

---

## Utility Scripts

### `usbquerry.sh`
**Purpose**: Queries USB devices and outputs device-to-port mapping  
**Location**: Root directory  
**Dependencies**: Requires udevadm  
**What it does**:
- Scans `/sys/bus/usb/devices/` for USB devices
- Uses `udevadm` to get device information
- Maps USB serial numbers to device ports (e.g., `/dev/ttyUSB0`)
- Outputs format: `/dev/ttyUSB0 - FTDI_FT230X_Basic_UART_DK0DW206`
- Used by AlpacaPi to identify devices (Moonlite focusers, Alnitak flip-flats, etc.)

**Usage**: Run manually to see USB device mapping, or called by AlpacaPi  
**Interacts with**: System udev, AlpacaPi main program (writes to `usb_id.txt`)

---

### `download_extra_data.sh`
**Purpose**: Downloads additional data files for SkyTravel feature  
**Location**: Root directory  
**Dependencies**: Requires git  
**What it does**:
- Checks for OpenNGC directory and NGC.csv file
- Checks for d3-celestial directory and milkyway.json
- Clones OpenNGC repository (NGC catalog data)
- Clones d3-celestial repository (Milky Way outline data)

**Usage**: Run to download optional data for SkyTravel visualization  
**Interacts with**: GitHub repositories (OpenNGC, d3-celestial)

---

### `make_checkopencv.sh`
**Purpose**: Helper script for Makefile to detect OpenCV version  
**Location**: Root directory  
**Dependencies**: Requires pkg-config  
**What it does**:
- Uses `pkg-config` to check for `opencv4` or `opencv`
- Returns `opencv4` if OpenCV 4 is installed
- Returns `opencv` if OpenCV 3 is installed
- Used by Makefile to set compilation flags

**Usage**: Called by Makefile during build process  
**Interacts with**: Makefile, pkg-config

---

### `make_checkplatform.sh`
**Purpose**: Helper script for Makefile to detect platform architecture  
**Location**: Root directory  
**Dependencies**: None  
**What it does**:
- Uses `uname -m` to detect machine type
- Returns `x64` for x86_64
- Returns `armv7` for armv7l
- Returns `armv8` for aarch64
- Used by Makefile to select platform-specific build options

**Usage**: Called by Makefile during build process  
**Interacts with**: Makefile

---

### `make_checksql.sh`
**Purpose**: Helper script for Makefile to detect SQL database library  
**Location**: Root directory  
**Dependencies**: Requires pkg-config  
**What it does**:
- Uses `pkg-config` to check for `mysqlclient` or `mariadb`
- On ARM platforms: prefers mariadb, falls back to mysqlclient
- On x86 platforms: prefers mysqlclient, falls back to mariadb
- Returns detected SQL library name
- Used by Makefile to link correct SQL library

**Usage**: Called by Makefile during build process  
**Interacts with**: Makefile, pkg-config

---

## Subdirectory Scripts

### `aavso/get.sh`
**Purpose**: Downloads AAVSO Target Tool alert data via API  
**Location**: `aavso/` directory  
**Dependencies**: Requires `aavso_targettool_token.txt`, `replaceCRLF` binary, curl  
**What it does**:
- Reads AAVSO API token from `aavso_targettool_token.txt`
- Creates base64 authentication string
- Compiles `replace.c` to `replaceCRLF` if needed
- Makes API requests to Target Tool:
  - `/nighttime` targets
  - `/telescope` targets
  - `/targets` (default)
  - `/targets?obs_section=all` (all sections)
- Processes JSON responses (removes CR/LF)
- Saves to `alerts_json.txt` and `alerts_json_all.txt`
- Logs retrieval count to `aavso_retrevial_log.txt`
- Retries if request fails

**Usage**: Run to update AAVSO target lists for observation planning  
**Interacts with**: AAVSO Target Tool API, `replace.c` source file

---

### `src_imu/build_test.sh`
**Purpose**: Builds test program for IMU (BNO055) sensor  
**Location**: `src_imu/` directory  
**Dependencies**: Requires gcc, IMU source files  
**What it does**:
- Compiles IMU library test program
- Links with pthread and math libraries
- Includes `src_mlsLib` directory
- Creates `imutest` executable

**Usage**: Run to test IMU sensor functionality  
**Interacts with**: IMU source files, mlsLib

---

### `src_imu/loadcal_bno055.sh`
**Purpose**: Loads calibration data into BNO055 IMU sensor at startup  
**Location**: `src_imu/` directory  
**Dependencies**: Requires `getbno055` binary, calibration file  
**What it does**:
- Verifies `getbno055` program exists
- Verifies calibration file exists (`cal.cfg`)
- Shows sensor information
- Switches sensor to config mode
- Loads calibration data from file
- Switches sensor back to operation mode (NDOF)
- Supports interactive or silent mode
- Can be run from `/etc/rc.local` for automatic calibration on boot

**Usage**: Run at system startup or manually to load IMU calibration  
**Interacts with**: BNO055 sensor hardware, calibration file

---

### `AtikCamerasSDK/install_atik_rules.sh`
**Purpose**: Installs ATIK camera USB rules file  
**Location**: `AtikCamerasSDK/` directory  
**Dependencies**: Requires `99-atik.rules` file  
**What it does**:
- Checks if rules already installed
- Copies `99-atik.rules` to `/lib/udev/rules.d/`
- Prompts for reboot

**Usage**: Run to install ATIK camera USB access rules  
**Interacts with**: System udev rules, ATIK cameras

---

## Script Interaction Flow

### Initial Setup Flow

```
1. install_dev_env.sh
   └─> Installs basic development tools

2. setup.sh
   ├─> Checks system requirements
   ├─> Creates directories
   └─> Calls install_fits.sh (if needed)

3. install_everything.sh
   ├─> Updates system packages
   ├─> Installs core libraries
   ├─> Calls install_rules.sh
   └─> Sets up vendor SDKs

4. install_libraries.sh
   └─> Installs vendor-specific libraries

5. build_all.sh
   ├─> Uses make_checkopencv.sh
   ├─> Uses make_checkplatform.sh
   ├─> Uses make_checksql.sh
   └─> Builds all components
```

### Vendor SDK Installation Flow

```
For each vendor (ASI, ATIK, QHY, PlayerOne, QSI, etc.):

1. Download SDK (manual or via script)
2. Extract SDK to project directory
3. install_libraries.sh detects platform
4. Copies platform-specific libraries to /usr/lib
5. install_rules.sh installs USB rules
6. System ready for that vendor's devices
```

### Build-Time Helper Scripts

```
Makefile calls:
├─> make_checkopencv.sh  (detects OpenCV version)
├─> make_checkplatform.sh (detects architecture)
└─> make_checksql.sh     (detects SQL library)

These set Makefile variables for:
- Include paths
- Library paths
- Compilation flags
- Platform-specific code
```

### Runtime Utility Scripts

```
AlpacaPi program calls:
└─> usbquerry.sh
    └─> Outputs USB device mapping to usb_id.txt
        └─> Used to identify devices on USB ports
```

---

## Script Status and Testing Requirements

### Scripts Requiring Testing/Completion

#### ⚠️ High Priority

1. **`setup.sh`**
   - **Status**: Explicitly marked as "not finished" (last updated 3/23/2022)
   - **Issues**: Incomplete implementation
   - **Testing Needed**: 
     - Test on all supported platforms (Ubuntu 16.04/20.04, RPi 3/4 32/64-bit, Jetson Nano)
     - Verify all dependency checks work correctly
     - Complete missing functionality
     - Test error handling

2. **`install_libraries.sh`**
   - **Status**: Partially complete - "still has more work needed" per README
   - **Known Issues**:
     - ToupTek installation only supports ARM32 (armhf), missing x64 and ARM64 support
     - Last updated note: "ToupTek script is only finished for 32-bit Arm as of 3/19/2021"
   - **Testing Needed**:
     - Test ToupTek installation on x64 platforms
     - Test ToupTek installation on ARM64 platforms
     - Verify all vendor libraries install correctly on all platforms
     - Test platform detection accuracy
     - Add missing platform support for ToupTek

#### ✅ Complete Scripts

The following scripts appear to be complete and functional:
- `install_dev_env.sh` - Simple, complete
- `install_fits.sh` - Well-tested, handles multiple versions
- `install_opencv.sh` - Complete for OpenCV 3.x
- `install_opencv451.sh` - Complete for OpenCV 4.5.1
- `install_playerone.sh` - Complete with platform detection
- `install_qsi.sh` - Complete with platform detection
- `install_wiringpi.sh` - Complete for ARM platforms
- `install_rules.sh` - Complete, handles all vendor rules
- `build_all.sh` - Complete, handles all build scenarios
- `usbquerry.sh` - Complete utility script
- `download_extra_data.sh` - Complete data downloader
- `make_checkopencv.sh` - Complete Makefile helper
- `make_checkplatform.sh` - Complete Makefile helper
- `make_checksql.sh` - Complete Makefile helper
- `remove_fits.sh` - Complete removal script
- `aavso/get.sh` - Complete API client
- `src_imu/build_test.sh` - Complete test builder
- `src_imu/loadcal_bno055.sh` - Complete calibration loader
- `AtikCamerasSDK/install_atik_rules.sh` - Complete rules installer

#### ⚠️ Archived Scripts (No Longer Needed)

These scripts have been archived and replaced by `setup_complete.sh`:
- `setup.sh` - Moved to `archive/scripts/`
- `install_dev_env.sh` - Moved to `archive/scripts/`
- `install_everything.sh` - Moved to `archive/scripts/`

See `archive/scripts/README.md` for details.

---

## Testing Checklist

### Platform Testing Required

For incomplete scripts, test on:
- [ ] Ubuntu 16.04 LTS x86_64
- [ ] Ubuntu 20.04 LTS x86_64
- [ ] Raspberry Pi 3 (32-bit)
- [ ] Raspberry Pi 4 (32-bit)
- [ ] Raspberry Pi 4 (64-bit)
- [ ] NVIDIA Jetson Nano (64-bit)

### Specific Test Cases Needed

#### `setup.sh`
- [ ] All dependency checks work correctly
- [ ] FITS installation detection works
- [ ] OpenCV detection works
- [ ] Platform detection accurate
- [ ] Error handling for missing dependencies
- [ ] FLIR SDK detection (if present)

#### `install_libraries.sh`
- [ ] ToupTek installation on x64 platform
- [ ] ToupTek installation on ARM64 platform
- [ ] All vendor libraries install on all platforms
- [ ] Platform detection selects correct library versions
- [ ] Error handling for missing SDKs
- [ ] Library file permissions correct after installation

---


## Quick Reference

### ⭐ Recommended Workflow

**For new installations:**
```bash
./setup_complete.sh          # Does everything in one script
./build_all.sh               # Build the project
```

**For existing installations:**
```bash
./setup_complete.sh          # Update/verify installation
```

### Individual Scripts (if needed)

| Script | Purpose | Run When |
|--------|---------|----------|
| ⭐ `setup_complete.sh` | **Complete setup (recommended)** | **First time setup** |
| `setup.sh` | Initial system check (incomplete) | Legacy - use setup_complete.sh instead |
| `install_dev_env.sh` | Install dev tools | Legacy - use setup_complete.sh instead |
| `install_everything.sh` | Install dependencies (incomplete) | Legacy - use setup_complete.sh instead |
| `install_libraries.sh` | Install vendor SDKs | After SDKs downloaded (or use setup_complete.sh) |
| `install_rules.sh` | Install USB rules | After libraries (or use setup_complete.sh) |
| `build_all.sh` | Build all components | After installation complete |
| `usbquerry.sh` | Query USB devices | Debugging device issues |
| `download_extra_data.sh` | Download SkyTravel data | Optional, for SkyTravel |

---

**Last Updated**: December 2024  
**Maintained by**: AlpacaPi Development Team

