# AlpacaPi
Astronomy control software using Alpaca protocol on the Raspberry Pi

(C) 2019-2024 by Mark Sproul msproul@skychariot.com

AlpacaPi is an open-source project written in C/C++

This project was intended primarily for use on the Raspberry Pi but will work
on most any Linux platform.  I do my development and testing on desktop Ubuntu

Use of this source code for private or individual use is granted
Use of this source code, in whole or in part for commercial purpose requires
written agreement in advance.

You may use or modify this source code in any way you find useful, provided
that you agree the above terms and that the author(s) have no warranty, obligations or liability.
You must determine the suitability of this source code for your use.

Redistributions of this source code must retain this copyright notice.


More documentation can be found at  https://msproul.github.io/AlpacaPi/

===================================================

## Getting started:

If you haven't already downloaded the git repository,

	connect to the directory you want the installation to be in
	(you can move it later if desired)

	>git clone https://github.com/msproul/AlpacaPi.git
    cd AlpacaPi


## Setup Script

There is a single comprehensive setup script that handles everything:

### Installation

	./setup_complete.sh

This script will:
- Check system requirements and install build tools if needed
- Install required system libraries (libusb, libudev, libi2c, libjpeg, etc.)
- Install FITS library (cfitsio)
- Check for OpenCV and provide installation guidance
- Install USB device rules (for camera/focuser/filter wheel access)
- Install vendor SDKs (optional, based on what you have)
- Download extra data for SkyTravel (optional)
- Verify build environment (platform, OpenCV, SQL detection)
- Build AlpacaPi (optional)

This single script replaces all the old setup scripts:
- `setup.sh` (archived)
- `install_dev_env.sh` (archived)
- `install_everything.sh` (archived)
- `install_fits.sh` (archived)
- `install_rules.sh` (archived)
- `install_libraries.sh` (archived)
- `build_all.sh` (archived)

All functionality is now integrated into `setup_complete.sh` with interactive prompts.

### Important Notes

- **Interactive by default**: The script will prompt you before each major installation step
- **Safe to run multiple times**: The script checks what's already installed and skips if present
- **Requires sudo**: Some steps require administrator privileges (you'll be prompted)
- **Platform detection**: Automatically detects your platform (x64, ARM32, ARM64)
- **OpenCV optional**: OpenCV is only needed for camera/focuser/dome clients, not the basic server
- **OpenCV build time**: Building OpenCV from source takes 4+ hours on Raspberry Pi, 5+ hours on Jetson Nano
- **Build verification**: The script verifies your build environment before building to catch issues early
- **Error handling**: Script exits on error (`set -e`) - if something fails, the script stops immediately
- **Log files**: Creates log files (`opencvinstall-log.txt`, `AlpacaPi_buildlog.txt`) for troubleshooting
- **Reboot may be required**: After installing USB rules, you may need to reboot for them to take effect
- **Cancellable**: You can cancel at any prompt (Ctrl+C) - the script won't leave your system in a broken state

### Uninstallation

To remove AlpacaPi components from your system:

	./setup_complete.sh --uninstall

Or:

	./setup_complete.sh -u

The uninstaller will:
- Remove vendor SDK libraries from `/usr/lib`
- Remove USB device rules from `/lib/udev/rules.d/`
- Remove built binaries (alpacapi, client, camera, etc.)
- Remove build artifacts (object files, logs)
- Optionally remove FITS library (if installed from source)
- Optionally remove OpenCV (if installed via package manager or from source)
- Optionally remove downloaded SDK folders (QHY, PlayerOne, QSI, WiringPi)
- Optionally remove downloaded data folders (OpenNGC, d3-celestial)

**Note**: The uninstaller will stop any running AlpacaPi processes before removing binaries.
Repository SDK folders (ZWO_ASI_SDK, AtikCamerasSDK, ZWO_EFW_SDK, etc.) are NOT removed.


===================================================

## 3rd Party Libraries:

In most cases AlpacaPi relies on libraries supplied by the vendors to talk to the devices.
These libraries are required for the following devices:

	ATIK cameras
	ATIK Filter wheel
	FLIR Cameras
	QHY Cameras
	QSI Cameras
	SONY Cameras
	ToupTek Cameras
	ZWO ASI cameras
	ZWO EFW Filter Wheel

External libraries are NOT required for:

	MoonLite Focusers (built-in support, no SDK needed - optional, enabled by default)
	LX200 Telescope mount (supported - tracking on/off not implemented, optional, disabled by default)
	SkyWatcher Telescope mount (not finished - not implemented, optional, disabled by default)
	Calibration control (Flat panel control - optional, enabled by default)

**Note**: The setup script (`setup_complete.sh`) will prompt you to select which drivers to include in your build. 
By default, MoonLite focusers and calibration control are enabled, but you can disable them if you don't need them.
LX200 telescope mount support is functional (slew, sync, move axis, abort) but tracking on/off is not yet implemented.
SkyWatcher telescope mount is disabled by default since it is not finished.


Vendor SDK installation is handled automatically by `setup_complete.sh`. 

When you run `setup_complete.sh`, it will:
- Detect which vendor SDKs you have downloaded
- Prompt you to install each one
- Install the appropriate libraries for your platform (x64, ARM32, ARM64)
- Install USB rules for each vendor

**Note**: You need to download vendor SDKs separately (they're not included in AlpacaPi). 
Once downloaded and extracted to the AlpacaPi directory, `setup_complete.sh` will detect 
and offer to install them.

Supported vendors:
- ZWO (ASI cameras, EFW filter wheels, EAF focusers)
- ATIK cameras
- QHY cameras
- QSI cameras
- PlayerOne cameras
- ToupTek cameras
- FLIR cameras



===================================================

## Development:

AlpacaPi is written in C and C++ to run on Linux operating systems.
It is built using a conventional Makefile.
The make file has many defines in to enable various features.

Dependencies:
	openCV 3.3.1 or earlier
		OR
	openCV 4.5.1 (mouse wheel not supported after 4.5.1
	cfitsio

Note: these are NOT required for everything, 
only those drivers that deal with cameras and any of the client applications

On the Raspberry Pi, some of the drivers require the wiringPi library.
wiringPi is pre-installed on Raspbian.


There is a lot of documentation that needs to be written and I am working on it
as fast as I can.  If there is a particular part that you need help with or
need better documentation, please let me know and I will try my best to get
more done on that particular part.

There are many different driver modules included in this project, almost every one supported by
Alpaca/ASCOM plus a couple extras I created for my own use.

AlpacaPi has been tested on the following platforms

	Ubuntu 24.04 LTS x86_64
	
	Ubuntu 16.04 LTS x86_64

	Ubuntu 20.04 LTS x86_64

	Raspberry Pi 3 (32 bit)

	Raspberry Pi 4 (32 bit)

	Raspberry Pi 4 (64 bit)

	NVIDIA Jetson Nano (64 bit)

===================================================

## Status:

For those familiar with ASCOM and ASCOM development, I use the CONFORM tool to
verify the workings of my drivers.  Here my current results
(as of Feb 11, 2024)


Apr  1,	2020	<MLS> CONFORM-filterwheel -> PASSED!!!!!!!!!!!!!!!!!!!!!

Apr  2,	2020	<MLS> CONFORM-focuser -> PASSED!!!!!!!!!!!!!!!!!!!!!

Apr  2,	2020	<MLS> CONFORM-rotator -> PASSED!!!!!!!!!!!!!!!!!!!!!

Apr  2,	2020	<MLS> CONFORM-switch -> PASSED!!!!!!!!!!!!!!!!!!!!!

Jan 12,	2021	<MLS> CONFORM-dome/ror -> PASSED!!!!!!!!!!!!!!!!!!!!!

Jan 20,	2021	<MLS> CONFORM-camera/zwo -> PASSED!!!!!!!!!!!!!!!!!!!!!

Mar  1,	2021	<MLS> CONFORM-observingconditions -> PASSED!!!!!!!!!!!!!!!!!!!!!

Apr  6,	2021	<MLS> CONFORM-covercalibrator -> PASSED!!!!!!!!!!!!!!!!!!!!!

Apr 30,	2021	<MLS> CONFORM-filterwheel/atik -> PASSED!!!!!!!!!!!!!!!!!!!!!

Jun 24,	2021	<MLS> CONFORM-switch -> PASSED!!!!!!!!!!!!!!!!!!!!!

Jan  2,	2022	<MLS> CONFORM-switch -> PASSED!!!!!!!!!!!!!!!!!!!!!

Nov 27,	2022	<MLS> CONFORMU-filterwheeldriver_usis -> PASSED!!!!!!!!!!!!!!

Nov 27,	2022	<MLS> CONFORMU-focuserdriver_USIS -> PASSED!!!!!!!!!!!!!!!!!!!!!

Nov 27,	2022	<MLS> CONFORMU-observingconditions -> PASSED!!!!!!!!!!!!!!!!!!!!!

Nov 28,	2022	<MLS> CONFORMU-focuserdriver-Moonlite-HiRes -> PASSED!!!!!!!!!!!!!!!!!!!!!

Nov 28,	2022	<MLS> CONFORMU-focuserdriver-Moonlite-NiteCrawler -> PASSED!!!!!!!!!!!!!!!!!!!!!

Mar  2,	2023	<MLS> CONFORMU-rotatordriver_sim -> PASSED!!!!!!!!!!!!!!!!!!!!!

Mar  3,	2023	<MLS> CONFORMU-filterwheel/simulator -> PASSED!!!!!!!!!!!!!!!!!!!!!

Mar  3,	2023	<MLS> CONFORMU-switch/simulator -> PASSED!!!!!!!!!!!!!!!!!!!!!

Mar  4,	2023	<MLS> CONFORMU-covercalibration/simulator -> PASSED!!!!!!!!!!!!!!!!!!!!!

Mar  4,	2023	<MLS> CONFORMU-camera/simulator -> PASSED!!!!!!!!!!!!!!!!!!!!!

Jun  9,	2023	<MLS> CONFORM-covercalibrarion-Alnitak -> PASSED!!!!!!!!!!!!!!!!!!!!!



===================================================

## Contributing:

We welcome contributions to AlpacaPi! If you'd like to contribute, please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on code formatting, pull requests, and development practices.

The most important rule: **Use TABS (not spaces) for indentation** in all C/C++ source files. See [CONTRIBUTING.md](CONTRIBUTING.md) for complete formatting guidelines.

===================================================

## Documentation:

Documentation is available at https://msproul.github.io/AlpacaPi/

When you download AlpacaPi, you get the full documentation in the "docs" folder

===================================================


## Contact:

msproul@skychariot.com

I program embedded systems for a living, I have been programming for over 40 years.
AlpacaPi is open source, but if you find it useful and care to make a donation to my efforts.
A PayPal donation to the above address would be appreciated.

I have developed this for the purpose of running my own observatory which I put a lot of money
and time into.
I expect to be running this observatory and keeping this software up to date for a long time.


