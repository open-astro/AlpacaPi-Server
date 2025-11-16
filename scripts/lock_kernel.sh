#!/bin/bash
#*****************************************************************************
# lock_kernel.sh
# 
# Script to lock Raspberry Pi kernel and firmware packages to prevent
# kernel updates while allowing other system packages to update.
#
# This prevents kernel upgrades that break ZWO EAF/EFW hardware support
# which requires kernel 6.1.x for /dev/hidraw* support.
#*****************************************************************************

set -e

METHOD="${1:-1}"

echo "Raspberry Pi Kernel Lock Script"
echo "================================"
echo ""
echo "This script will prevent kernel and firmware updates to maintain"
echo "compatibility with ZWO EAF/EFW hardware (requires kernel 6.1.x)."
echo ""

if [ "$METHOD" = "1" ] || [ "$METHOD" = "apt-mark" ]; then
	echo "Method 1: Remove post-install scripts + apt-mark hold (Recommended)"
	echo "-------------------------------------------------------------------"
	echo ""
	echo "This method combines script removal with package holds for maximum protection."
	echo ""
	
	#*	Remove the post-install scripts that automatically update kernel
	echo "Step 1: Removing kernel post-install scripts..."
	if [ -f "/etc/kernel/postinst.d/z50-raspi-firmware" ]; then
		sudo rm /etc/kernel/postinst.d/z50-raspi-firmware
		echo "  Removed: /etc/kernel/postinst.d/z50-raspi-firmware"
	else
		echo "  Already removed: /etc/kernel/postinst.d/z50-raspi-firmware"
	fi
	
	if [ -f "/etc/initramfs/post-update.d/z50-raspi-firmware" ]; then
		sudo rm /etc/initramfs/post-update.d/z50-raspi-firmware
		echo "  Removed: /etc/initramfs/post-update.d/z50-raspi-firmware"
	else
		echo "  Already removed: /etc/initramfs/post-update.d/z50-raspi-firmware"
	fi
	
	echo ""
	echo "Step 2: Getting current package versions..."
	KERNEL_VER=$(dpkg -l | grep '^ii.*raspberrypi-kernel' | awk '{print $3}' | head -1)
	FIRMWARE_VER=$(dpkg -l | grep '^ii.*raspi-firmware' | awk '{print $3}' | head -1)
	
	if [ -z "$KERNEL_VER" ]; then
		echo "  WARNING: Could not determine raspberrypi-kernel version"
		KERNEL_VER="*"
	fi
	if [ -z "$FIRMWARE_VER" ]; then
		echo "  WARNING: Could not determine raspi-firmware version"
		FIRMWARE_VER="*"
	fi
	
	echo "  Kernel version: $KERNEL_VER"
	echo "  Firmware version: $FIRMWARE_VER"
	echo ""
	
	echo "Step 3: Holding kernel and firmware packages..."
	
	sudo apt-mark hold raspi-firmware \
		libraspberrypi0 \
		libraspberrypi-bin \
		libraspberrypi-dev \
		libraspberrypi-doc \
		raspberrypi-kernel \
		raspberrypi-bootloader \
		rpi-eeprom 2>/dev/null || true
	
	echo ""
	echo "Step 4: Creating apt preferences with version pinning..."
	echo "        (This prevents broken dependency states)"
	
	PREFERENCES_FILE="/etc/apt/preferences.d/99-hold-kernel"
	
	sudo tee "$PREFERENCES_FILE" > /dev/null << EOF
Package: raspberrypi-kernel
Pin: version $KERNEL_VER
Pin-Priority: 1001

Package: raspi-firmware
Pin: version $FIRMWARE_VER
Pin-Priority: 1001

Package: libraspberrypi0
Pin: version *
Pin-Priority: -1

Package: libraspberrypi-bin
Pin: version *
Pin-Priority: -1

Package: libraspberrypi-dev
Pin: version *
Pin-Priority: -1

Package: libraspberrypi-doc
Pin: version *
Pin-Priority: -1

Package: raspberrypi-bootloader
Pin: version *
Pin-Priority: -1

Package: rpi-eeprom
Pin: version *
Pin-Priority: -1
EOF
	
	echo ""
	echo "Lock applied successfully!"
	echo ""
	echo "Current kernel version: $(uname -r)"
	echo ""
	echo "IMPORTANT: Use 'sudo apt upgrade' instead of 'sudo apt full-upgrade'"
	echo "           to avoid dependency resolution that might require --fix-broken"
	echo ""
	echo "To verify holds, run: apt-mark showhold"
	echo "To remove locks, run: $0 unlock"
	echo ""
	
elif [ "$METHOD" = "2" ] || [ "$METHOD" = "preferences" ]; then
	echo "Method 2: Using apt preferences file (More permanent)"
	echo "------------------------------------------------------"
	echo ""
	
	PREFERENCES_FILE="/etc/apt/preferences.d/99-hold-kernel"
	
	if [ -f "$PREFERENCES_FILE" ]; then
		echo "Preferences file already exists: $PREFERENCES_FILE"
		read -p "Overwrite? (y/N): " -n 1 -r
		echo
		if [[ ! $REPLY =~ ^[Yy]$ ]]; then
			echo "Aborted."
			exit 0
		fi
	fi
	
	echo "Getting current package versions for pinning..."
	KERNEL_VER=$(dpkg -l | grep '^ii.*raspberrypi-kernel' | awk '{print $3}' | head -1)
	FIRMWARE_VER=$(dpkg -l | grep '^ii.*raspi-firmware' | awk '{print $3}' | head -1)
	
	if [ -z "$KERNEL_VER" ]; then
		echo "  WARNING: Could not determine raspberrypi-kernel version, using wildcard"
		KERNEL_VER="*"
	fi
	if [ -z "$FIRMWARE_VER" ]; then
		echo "  WARNING: Could not determine raspi-firmware version, using wildcard"
		FIRMWARE_VER="*"
	fi
	
	echo "  Kernel version: $KERNEL_VER"
	echo "  Firmware version: $FIRMWARE_VER"
	echo ""
	echo "Creating apt preferences file with version pinning..."
	
	sudo tee "$PREFERENCES_FILE" > /dev/null << EOF
Package: raspberrypi-kernel
Pin: version $KERNEL_VER
Pin-Priority: 1001

Package: raspi-firmware
Pin: version $FIRMWARE_VER
Pin-Priority: 1001

Package: libraspberrypi0
Pin: version *
Pin-Priority: -1

Package: libraspberrypi-bin
Pin: version *
Pin-Priority: -1

Package: libraspberrypi-dev
Pin: version *
Pin-Priority: -1

Package: libraspberrypi-doc
Pin: version *
Pin-Priority: -1

Package: raspberrypi-bootloader
Pin: version *
Pin-Priority: -1

Package: rpi-eeprom
Pin: version *
Pin-Priority: -1
EOF
	
	echo ""
	echo "Preferences file created: $PREFERENCES_FILE"
	echo ""
	echo "IMPORTANT: Use 'sudo apt upgrade' instead of 'sudo apt full-upgrade'"
	echo "           to avoid dependency resolution that might require --fix-broken"
	echo ""
	echo "To remove, run: sudo rm $PREFERENCES_FILE"
	echo ""
	
elif [ "$METHOD" = "unlock" ] || [ "$METHOD" = "remove" ]; then
	echo "Removing kernel locks"
	echo "---------------------"
	echo ""
	
	echo "Removing apt-mark holds..."
	sudo apt-mark unhold raspi-firmware \
		libraspberrypi0 \
		libraspberrypi-bin \
		libraspberrypi-dev \
		libraspberrypi-doc \
		raspberrypi-kernel \
		raspberrypi-bootloader \
		rpi-eeprom 2>/dev/null || true
	
	echo "Note: Post-install scripts were removed. They will not be restored."
	echo "      If you need kernel updates, you may need to reinstall raspi-firmware."
	
	if [ -f "/etc/apt/preferences.d/99-hold-kernel" ]; then
		echo "Removing apt preferences file..."
		sudo rm /etc/apt/preferences.d/99-hold-kernel
		echo "Preferences file removed."
	fi
	
	echo ""
	echo "Kernel locks removed. Kernel updates will now be allowed."
	echo ""
	
elif [ "$METHOD" = "status" ] || [ "$METHOD" = "check" ]; then
	echo "Kernel Lock Status"
	echo "------------------"
	echo ""
	
	echo "Held packages (apt-mark):"
	apt-mark showhold | grep -E "(raspi|raspberrypi|libraspberrypi|rpi-eeprom)" || echo "  (none)"
	echo ""
	
	if [ -f "/etc/apt/preferences.d/99-hold-kernel" ]; then
		echo "Apt preferences file exists: /etc/apt/preferences.d/99-hold-kernel"
	else
		echo "No apt preferences file found."
	fi
	echo ""
	
	if [ -f "/etc/kernel/postinst.d/z50-raspi-firmware" ]; then
		echo "WARNING: Kernel post-install script exists: /etc/kernel/postinst.d/z50-raspi-firmware"
		echo "         This script should be removed for kernel lock to work properly."
	else
		echo "Kernel post-install script removed: /etc/kernel/postinst.d/z50-raspi-firmware"
	fi
	
	if [ -f "/etc/initramfs/post-update.d/z50-raspi-firmware" ]; then
		echo "WARNING: Initramfs post-update script exists: /etc/initramfs/post-update.d/z50-raspi-firmware"
		echo "         This script should be removed for kernel lock to work properly."
	else
		echo "Initramfs post-update script removed: /etc/initramfs/post-update.d/z50-raspi-firmware"
	fi
	echo ""
	
	echo "Current kernel version:"
	uname -r
	echo ""
	
	echo "Checking for broken packages..."
	if dpkg -l | grep -q "^..r"; then
		echo "  WARNING: Broken packages detected. Run: sudo apt --fix-broken install"
		echo "           (But check what it will upgrade first!)"
	else
		echo "  No broken packages detected."
	fi
	echo ""
	
else
	echo "Usage: $0 [method]"
	echo ""
	echo "Methods:"
	echo "  1 or apt-mark    - Use apt-mark hold (recommended, default)"
	echo "  2 or preferences - Use apt preferences file (more permanent)"
	echo "  unlock or remove - Remove all kernel locks"
	echo "  status or check  - Show current lock status"
	echo ""
	echo "Examples:"
	echo "  $0                # Use method 1 (apt-mark)"
	echo "  $0 2              # Use method 2 (preferences)"
	echo "  $0 unlock         # Remove all locks"
	echo "  $0 status         # Check current status"
	exit 1
fi

