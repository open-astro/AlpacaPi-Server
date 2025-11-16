# AlpacaPi Driver Support

This document lists all supported hardware vendors and device types in AlpacaPi Server.

## Camera Drivers

| Vendor | Models | Connection | Status |
|--------|--------|------------|--------|
| **ATIK** | All ATIK cameras | USB | ✅ Supported |
| **FLIR** | All FLIR cameras (via Spinnaker SDK) | USB | ✅ Supported |
| **OGMA** | All OGMA cameras | USB | ✅ Supported |
| **PlayerOne** | All PlayerOne cameras | USB | ✅ Supported |
| **QHY** | All QHY cameras | USB | ✅ Supported |
| **QSI** | All QSI cameras | USB | ✅ Supported |
| **SONY** | All SONY cameras | USB | ✅ Supported |
| **ToupTek** | All ToupTek cameras | USB | ✅ Supported |
| **ZWO** | All ZWO ASI cameras | USB | ✅ Supported |
| **Simulator** | Software simulator for testing | N/A | ✅ Supported |

## Telescope/Mount Drivers

| Vendor | Models | Connection | Status |
|--------|--------|------------|--------|
| **Explore Scientific** | PMC-8 mounts | USB/Serial | ✅ Supported |
| **iOptron** | CEM120, CEM70, GEM45, CEM40, GEM28, CEM26 series | USB/Serial, Ethernet | ✅ Supported |
| **LX200** | Meade LX200 compatible mounts | TCP/IP | ✅ Supported |
| **Rigel** | Rigel mounts | USB/Serial | ✅ Supported |
| **Servo** | Servo-based mounts | Custom | ✅ Supported |
| **SkyWatcher** | SkyWatcher mounts | USB/Serial | ✅ Supported |
| **Simulator** | Software simulator for testing | N/A | ✅ Supported |

## Filter Wheel Drivers

| Vendor | Models | Connection | Status |
|--------|--------|------------|--------|
| **ATIK** | All ATIK filter wheels | USB | ✅ Supported |
| **PlayerOne** | All PlayerOne filter wheels | USB | ✅ Supported |
| **QHY** | All QHY filter wheels | USB | ✅ Supported |
| **ZWO** | All ZWO EFW filter wheels | USB | ✅ Supported |
| **Simulator** | Software simulator for testing | N/A | ✅ Supported |

## Focuser Drivers

| Vendor | Models | Connection | Status | Requires wiringPi | Requires 32-bit RPi OS |
|--------|--------|------------|--------|-------------------|----------------------|
| **MoonLite** | All MoonLite focusers | USB/Serial | ✅ Supported | ✅ Yes | ⚠️ Recommended |
| **ZWO** | All ZWO EAF focusers | USB | ✅ Supported | ❌ No | ❌ No |
| **Simulator** | Software simulator for testing | N/A | ✅ Supported | ❌ No | ❌ No |

## Rotator Drivers

| Vendor | Models | Connection | Status | Requires wiringPi | Requires 32-bit RPi OS |
|--------|--------|------------|--------|-------------------|----------------------|
| **MoonLite** | All MoonLite rotators (NiteCrawler) | USB/Serial | ✅ Supported | ✅ Yes | ⚠️ Recommended |
| **Simulator** | Software simulator for testing | N/A | ✅ Supported | ❌ No | ❌ No |

## Dome Drivers

| Vendor | Models | Connection | Status | Requires wiringPi | Requires 32-bit RPi OS |
|--------|--------|------------|--------|-------------------|----------------------|
| **RaspberryPi** | Roll-off roof (ROR) domes | GPIO | ✅ Supported | ✅ Yes | ⚠️ Recommended |
| **RaspberryPi** | Custom dome controllers | GPIO | ✅ Supported | ✅ Yes | ⚠️ Recommended |
| **Simulator** | Software simulator for testing | N/A | ✅ Supported | ❌ No | ❌ No |

## Switch Drivers

| Vendor | Models | Connection | Status | Requires wiringPi | Requires 32-bit RPi OS |
|--------|--------|------------|--------|-------------------|----------------------|
| **RaspberryPi** | GPIO-based switches | GPIO | ✅ Supported | ✅ Yes | ⚠️ Recommended |

## Observing Conditions Drivers

| Vendor | Models | Connection | Status | Requires wiringPi | Requires 32-bit RPi OS |
|--------|--------|------------|--------|-------------------|----------------------|
| **RaspberryPi** | Custom weather sensors | GPIO/I2C | ✅ Supported | ❌ No* | ❌ No |

## Cover Calibrator Drivers

| Vendor | Models | Connection | Status | Requires wiringPi | Requires 32-bit RPi OS |
|--------|--------|------------|--------|-------------------|----------------------|
| **Alnitak** | Flip-Flat, Flat-Man | USB/Serial | ✅ Supported | ❌ No | ❌ No |
| **RaspberryPi** | Custom calibration devices | GPIO | ✅ Supported | ✅ Yes | ⚠️ Recommended |

## Shutter Drivers

| Vendor | Models | Connection | Status | Requires wiringPi | Requires 32-bit RPi OS |
|--------|--------|------------|--------|-------------------|----------------------|
| **Arduino** | Custom Arduino-based shutters | USB/Serial | ✅ Supported | ✅ Yes** | ⚠️ Recommended |

## Notes

- **Simulator Drivers**: Software simulators are available for all device types to facilitate testing and development without physical hardware.

- **Connection Types**:
  - **USB**: Direct USB connection using vendor SDKs
  - **USB/Serial**: USB-to-serial adapter or direct serial connection
  - **Ethernet**: Network-based connection (TCP/IP)
  - **GPIO**: Raspberry Pi GPIO pins
  - **I2C**: I2C bus communication

- **wiringPi Requirements**: 
  - Drivers marked with ✅ **Yes** require the wiringPi library for GPIO control on Raspberry Pi
  - wiringPi can be installed via: `wget https://project-downloads.drogon.net/wiringpi-latest.deb && sudo dpkg -i wiringpi-latest.deb`
  - Note: wiringPi version 2.6.0+ supports 64-bit Raspberry Pi OS, but 32-bit is still recommended for maximum compatibility
  - *Observing Conditions driver uses RTIMULib instead of wiringPi for sensor access

- **32-bit Raspberry Pi OS Requirements**:
  - Drivers marked with ⚠️ **Recommended** work best on 32-bit Raspberry Pi OS (armv7/armhf)
  - While wiringPi 2.6.0+ supports 64-bit, some drivers may have better compatibility on 32-bit systems
  - **Recommended** means 32-bit is recommended but not strictly required for newer wiringPi versions
  - **Arduino Shutter driver**: Uses wiringPi conditionally when running on ARM architecture (`__arm__`)

- **Driver Status**: All listed drivers are actively maintained and tested. If you encounter issues with a specific driver, please report them via [GitHub issues](https://github.com/open-astro/AlpacaPi-Server/issues).

- **Adding New Drivers**: New driver support can be added by implementing the appropriate driver interface. See the existing driver implementations and SDKs for reference.
