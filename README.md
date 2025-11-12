## AlpacaPi Server

AlpacaPi Server is a lightweight Alpaca server implementation that provides device drivers allowing your astrophotography equipment such as cameras, filter wheels, focusers, and mounts to be controlled over the network.

Alpaca is an open, device-agnostic protocol developed by the ASCOM Initiative that communicates using standard HTTP/REST calls and JSON. This means any Alpaca-compatible application can control your gear without platform or driver-installation headaches.

With AlpacaPi Server running, your devices can be managed through popular astrophotography software including N.I.N.A. (Nighttime Imaging ’N’ Astronomy), Sequence Generator Pro (SGPro), SkySafari 7, Voyager, and many other applications that support the Alpaca standard without installing ASCOM or hardware-specific drivers on your computer.

Once installed and running you can access the web sever and make changes to your gear where acceptable. The ports to access the portal http://ip:6800/ based on the IP of your RPi

<img src="./logos/alpcapi_web.png" alt="Alpaca Web Portal" width="600">

This code is based on work from https://msproul.github.io/AlpacaPi/

## Hardware Support for ASIAIR Pro RPi

The software is designed to work on the ASIAR Pro RasperryPi model from ZWO. These units will allow you to easily run eveyrhing on the small RPi and not have to lug around a Laptop or Mini PC to be connected to your equipment. In turn this device has 4 USB ports and 4x12v Power converters to controll all your equipment and run power for them as needed.

- ZWO ASIAIR Pro RPi 4 (Tested November 2025)

- RPi5 w/ ASIAIR Pro Power ports (Tested November 2025) [more details](https://joeytroy.com/asiair-pro-pi-5/) 

## Raspberry Pi OS Download

The recommend Raspberry Pi OS is [Bookworm (64bit) from 2023-10-10](https://downloads.raspberrypi.com/raspios_arm64/images/raspios_arm64-2023-10-10/) this is the full Desktop OS. It's also recommend to setup [VNC](https://www.google.com/search?q=setup+vnc+on+raspberry+pi&ie=UTF-8). You can also download the [RealVNC Viewer](https://www.realvnc.com/en/connect/download/viewer/) (free) for Windows, macOS, Linux, Android, or IOS to control the RPi from the GUI.

## Important: Kernel Information

If you plan to use ZWO EAF/EFW hardware with AlpacaPi Server, you must use a kernel that supports /dev/hidraw*. The ZWO SDK depends on this legacy HID interface and currently only works reliably on Raspberry Pi kernels in the 6.1.x family.

Newer kernels (6.6.x and above) remove or break this HID binding, causing AlpacaPi to lose access to ZWO devices and produce errors When running the following command:

```bash
dev@raspberrypi:~ $ ls -l /dev/hidraw* 
ls: cannot access '/dev/hidraw*': No such file or directory
```

## Updating the OS properly

To keep the system up to date and stop the kernel from upgrading run the following command

```bash
sudo rm /etc/kernel/postinst.d/z50-raspi-firmware
sudo rm /etc/initramfs/post-update.d/z50-raspi-firmware
sudo apt-mark hold raspi-firmware
```
Then update the system with

```bash
sudo apt update && sudo apt full-upgrade -y
```
Note: The system will throw errors this is normal so the kernel doesn't update but the applications will

```
Errors were encountered while processing:
 raspi-firmware
 libraspberrypi0:arm64
 sense-hat
 libraspberrypi-bin
 libraspberrypi-dev
 libraspberrypi-doc
E: Sub-process /usr/bin/dpkg returned an error code (1)
```

## AlpacaPi Server Installation

To install AlpacaPi Server simply run the following command and follow the guided prompts

```bash
git clone https://github.com/open-astro/AlpacaPi.git
cd AlpacaPi
./setup_complete.sh
```

This script will:
- Check system requirements and install build tools if needed
- Install required system libraries (libusb, libudev, libi2c, libjpeg, etc.)
- Check for OpenCV and provide installation guidance
- Install USB device rules (for camera/focuser/filter wheel access)
- Install vendor SDKs (optional, based on what you have)
- Install drivers
- Build AlpacaPi-Server

## Uninstallation

To remove AlpacaPi-Server components from your system:

```bash
cd AlpacaPi
./setup_complete.sh -u
```

**Note**: The uninstaller will stop any running AlpacaPi processes before removing binaries.
Repository SDK folders (ZWO_ASI_SDK, AtikCamerasSDK, ZWO_EFW_SDK, etc.) are NOT removed.

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
	ZWO ASI Cameras
	ZWO EAF Focuser
	ZWO EFW Filter Wheel

External libraries are NOT required for:

- Calibration control (Flat panel control)
- MoonLite Focusers (built-in support)
- iOptron Telescope Mounts (Work in progress)
- LX200 Telescope Mounts (supported - tracking on/off not implemented, optional, disabled by default)
- SkyWatcher Telescope Mount (not finished - not implemented, optional, disabled by default)

Vendor SDK installation is handled automatically by `setup_complete.sh`. 

When you run `setup_complete.sh`, it will:
- Detect which vendor SDKs you have downloaded
- Prompt you to install each one
- Install the appropriate libraries for your platform (x64, ARM32, ARM64)
- Install USB rules for each vendor

**Note**: You need to download vendor SDKs separately (they're not included in AlpacaPi). Once downloaded and extracted to the AlpacaPi directory, `setup_complete.sh` will detect and offer to install them.

Supported vendors:
- ZWO (ASI cameras, EFW filter wheels, EAF focusers)
- ATIK cameras
- QHY cameras
- QSI cameras
- PlayerOne cameras
- ToupTek cameras
- FLIR cameras

## Contributing:

We welcome contributions to AlpacaPi! If you'd like to contribute, please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on code formatting, pull requests, and development practices.

The most important rule: **Use TABS (not spaces) for indentation** in all C/C++ source files. See [CONTRIBUTING.md](CONTRIBUTING.md) for complete formatting guidelines.


## Copyright Notice
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
