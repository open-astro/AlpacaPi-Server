# Archived Scripts

This directory contains scripts that have been replaced by `setup_complete.sh`.

## Archived Scripts

### `setup.sh`
**Status**: Replaced by `setup_complete.sh`  
**Reason**: Incomplete implementation, marked as "not finished"  
**Date Archived**: December 2024

### `install_dev_env.sh`
**Status**: Replaced by `setup_complete.sh`  
**Reason**: Functionality consolidated into comprehensive setup script  
**Date Archived**: December 2024

### `install_everything.sh`
**Status**: Replaced by `setup_complete.sh`  
**Reason**: Incomplete implementation, functionality consolidated  
**Date Archived**: December 2024

### `install_fits.sh`
**Status**: Replaced by `setup_complete.sh`  
**Reason**: FITS installation functionality integrated into unified script  
**Date Archived**: December 2024

### `install_libraries.sh`
**Status**: Replaced by `setup_complete.sh`  
**Reason**: Vendor SDK installation functionality integrated into unified script  
**Date Archived**: December 2024

### `install_opencv.sh`
**Status**: Replaced by `setup_complete.sh`  
**Reason**: OpenCV 3.x installation functionality integrated into unified script  
**Date Archived**: December 2024

### `install_opencv451.sh`
**Status**: Replaced by `setup_complete.sh`  
**Reason**: OpenCV 4.5.1 installation functionality integrated into unified script  
**Date Archived**: December 2024

### `install_playerone.sh`
**Status**: Replaced by `setup_complete.sh`  
**Reason**: PlayerOne SDK installation functionality integrated into unified script  
**Date Archived**: December 2024

### `install_qsi.sh`
**Status**: Replaced by `setup_complete.sh`  
**Reason**: QSI SDK installation functionality integrated into unified script  
**Date Archived**: December 2024

### `install_rules.sh`
**Status**: Replaced by `setup_complete.sh`  
**Reason**: USB rules installation functionality integrated into unified script  
**Date Archived**: December 2024

### `install_wiringpi.sh`
**Status**: Replaced by `setup_complete.sh`  
**Reason**: WiringPi installation functionality integrated into unified script  
**Date Archived**: December 2024

### `download_extra_data.sh`
**Status**: Replaced by `setup_complete.sh`  
**Reason**: Extra data download functionality integrated into unified script  
**Date Archived**: December 2024

### `build_all.sh`
**Status**: Replaced by `setup_complete.sh`  
**Reason**: Build functionality integrated as optional step in unified script  
**Date Archived**: December 2024

### `remove_fits.sh`
**Status**: Replaced by `setup_complete.sh`  
**Reason**: FITS removal functionality integrated as optional cleanup step  
**Date Archived**: December 2024

### `SCRIPT.md`
**Status**: Archived - Documentation file  
**Reason**: Most scripts documented are now archived or integrated into `setup_complete.sh`  
**Date Archived**: December 2024  
**Note**: Kept for historical reference and documentation of subdirectory scripts

## Why These Were Archived

The new `setup_complete.sh` script consolidates ALL the functionality from these scripts into a single, comprehensive script that:
- Handles all setup tasks in the correct order
- Provides better error handling and user prompts
- Works on all platforms (x64, ARM32, ARM64)
- Provides clear guidance and next steps
- Is easier to maintain (one script instead of many)
- Allows users to choose what to install via prompts

## If You Need These Scripts

These scripts are kept in the archive for reference. If you need to use them for any reason, you can copy them back to the root directory. However, we **strongly recommend** using `setup_complete.sh` instead, as it provides a better user experience and handles all dependencies correctly.

## Active Scripts (Not Archived)

The following scripts remain in the root directory as they serve different purposes:
- `setup_complete.sh` - The new unified setup script (USE THIS!)
- `make_check*.sh` - Helper scripts used by the Makefile during build (called automatically by make)
- `usbquerry.sh` - Runtime utility for querying USB devices (used by running AlpacaPi)
