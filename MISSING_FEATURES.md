# Missing Features in AlpacaPi

This document lists features available in vendor SDKs that are not yet implemented in AlpacaPi.

## Camera

### ZWO ASI Camera SDK v1.39 Features Not Implemented

#### 1. GPS Support (New in SDK v1.39)
- **Functions:**
  - `ASIGPSGetData()` - Get GPS data from camera
  - `ASIGetDataAfterExpGPS()` - Get exposure data with GPS timestamps
  - `ASIGetVideoDataGPS()` - Get video frames with GPS data
- **Control Types:**
  - `ASI_GPS_SUPPORT` - GPS feature detection
  - `ASI_GPS_START_LINE` - GPS start line for rolling shutter
  - `ASI_GPS_END_LINE` - GPS end line for rolling shutter
- **Use Case:** Timestamp exposures with GPS coordinates for precise astrophotography

#### 2. Pulse Guiding (SDK Available, Not Fully Implemented)
- **Functions:**
  - `ASIPulseGuideOn()` - Start pulse guide in direction
  - `ASIPulseGuideOff()` - Stop pulse guide
- **Current Status:** AlpacaPi checks for ST4 port but doesn't use SDK functions
- **Use Case:** Precise autoguiding via ST4 port using SDK functions

#### 3. Dark Frame Subtraction
- **Functions:**
  - `ASIEnableDarkSubtract()` - Enable hardware dark frame subtraction
  - `ASIDisableDarkSubtract()` - Disable dark frame subtraction
- **Use Case:** Real-time dark frame correction without post-processing

#### 4. Trigger Output Configuration
- **Functions:**
  - `ASISetTriggerOutputIOConf()` - Configure trigger output pins
  - `ASIGetTriggerOutputIOConf()` - Get trigger output configuration
- **Use Case:** Synchronize camera with external equipment (mounts, filter wheels, etc.)

#### 5. Soft Trigger
- **Functions:**
  - `ASISendSoftTrigger()` - Send software trigger for synchronized exposures
- **Use Case:** Multi-camera synchronization without hardware triggers

#### 6. Dropped Frames Detection
- **Functions:**
  - `ASIGetDroppedFrames()` - Monitor USB transfer issues
- **Use Case:** Diagnose USB bandwidth problems and frame loss

#### 7. Gain/Offset Optimization
- **Functions:**
  - `ASIGetGainOffset()` - Get optimal gain/offset values for best dynamic range
  - `ASIGetLMHGainOffset()` - Get Low/Medium/High gain offsets
- **Use Case:** Optimize camera settings for best signal-to-noise ratio

#### 8. Start Position Control
- **Functions:**
  - `ASISetStartPos()` - Set ROI start position
  - `ASIGetStartPos()` - Get ROI start position
- **Use Case:** Fine-tune subframe positioning independently from ROI size

#### 9. Camera ID Management
- **Functions:**
  - `ASISetID()` - Set camera ID
  - `ASIGetID()` - Get camera ID
  - `ASIGetCameraPropertyByID()` - Get camera info by ID instead of index
- **Use Case:** Manage multiple cameras with consistent IDs

#### 10. Camera Check Utilities
- **Functions:**
  - `ASICameraCheck()` - Check if specific VID/PID camera is connected
  - `ASIGetProductIDs()` - Get list of connected camera product IDs
- **Use Case:** Camera enumeration and detection without opening cameras

#### 11. New Control Types (SDK v1.39)
- `ASI_FAN_ADJUST` - Fan speed control (new in v1.39)
- `ASI_PWRLED_BRIGNT` - Power LED brightness control (new in v1.39)
- `ASI_USBHUB_RESET` - USB hub reset functionality (new in v1.39)
- `ASI_ROLLING_INTERVAL` - Rolling shutter interval control (new in v1.39)

### Currently Implemented Features

The following ZWO ASI SDK features **are** implemented in AlpacaPi:

- Basic camera operations (open, close, exposure, video capture)
- Control value get/set (gain, offset, temperature, cooler, etc.)
- ROI format configuration
- Camera mode support (normal, trigger, soft trigger modes)
- Serial number reading
- SDK version detection
- Camera property enumeration
- Image format support (RAW8, RAW16, RGB24, Y8)
- Video capture with frame retrieval
- Exposure status monitoring

### Priority Recommendations

1. **Pulse Guiding** - Use SDK functions instead of ST4 port check (high priority for autoguiding)
2. **GPS Support** - Useful for timestamped astrophotography (medium priority)
3. **Dropped Frames Detection** - Helpful for USB diagnostics (medium priority)
4. **Dark Frame Subtraction** - Hardware-accelerated correction (low priority, can be done in software)

---

## Filter Wheel

### ZWO EFW Filter Wheel SDK v1.7 Features Not Implemented

#### 1. Filter Wheel Calibration
- **Functions:**
  - `EFWCalibrate()` - Calibrate filter wheel position
- **Use Case:** Recalibrate filter wheel after mechanical issues or filter changes

#### 2. Direction Control (Unidirectional Mode)
- **Functions:**
  - `EFWSetDirection()` - Set unidirectional rotation mode
  - `EFWGetDirection()` - Get current direction setting
- **Use Case:** Prevent backlash by always rotating in one direction

#### 3. Firmware Version Detection
- **Functions:**
  - `EFWGetFirmwareVersion()` - Get firmware version (major, minor, build)
- **Use Case:** Check firmware compatibility and version-specific features

#### 4. Hardware Error Code Detection
- **Functions:**
  - `EFWGetHWErrorCode()` - Get hardware error code from filter wheel
- **Use Case:** Diagnose hardware issues and error states

#### 5. Serial Number Reading
- **Functions:**
  - `EFWGetSerialNumber()` - Get serial number from filter wheel
- **Use Case:** Identify specific filter wheels and track hardware

#### 6. Filter Wheel ID Management
- **Functions:**
  - `EFWSetID()` - Set alias/ID for filter wheel
- **Use Case:** Assign custom names/IDs to filter wheels for easier identification

#### 7. Product ID Enumeration
- **Functions:**
  - `EFWGetProductIDs()` - Get list of connected filter wheel product IDs
- **Use Case:** Enumerate filter wheels without opening them

### Currently Implemented Features

The following ZWO EFW SDK features **are** implemented in AlpacaPi:

- Basic filter wheel operations (open, close, get/set position)
- Filter wheel enumeration (`EFWGetNum`, `EFWGetID`)
- Property reading (`EFWGetProperty`)
- SDK version detection (`EFWGetSDKVersion`)

### Priority Recommendations

1. **Hardware Error Code Detection** - Useful for troubleshooting (high priority)
2. **Firmware Version Detection** - Helpful for compatibility checks (medium priority)
3. **Direction Control** - Prevents backlash issues (medium priority)
4. **Calibration** - Useful for maintenance (low priority)

---

## Focuser

### ZWO EAF Focuser SDK v1.6 Features Not Implemented

#### 1. Focuser Close Function
- **Functions:**
  - `EAFClose()` - Close focuser connection
- **Use Case:** Properly close focuser connections when not in use

#### 2. Backlash Compensation
- **Functions:**
  - `EAFGetBacklash()` - Get backlash compensation value
  - `EAFSetBacklash()` - Set backlash compensation value
- **Use Case:** Compensate for mechanical backlash in focuser mechanism

#### 3. Beep Control
- **Functions:**
  - `EAFGetBeep()` - Get beep setting
  - `EAFSetBeep()` - Enable/disable beep sound
- **Use Case:** Control audible feedback from focuser

#### 4. Reverse Direction Control
- **Functions:**
  - `EAFGetReverse()` - Get reverse direction setting
  - `EAFSetReverse()` - Set reverse direction
- **Use Case:** Reverse focuser movement direction if needed

#### 5. Maximum Step Limit
- **Functions:**
  - `EAFGetMaxStep()` - Get maximum step value
  - `EAFSetMaxStep()` - Set maximum step limit
- **Use Case:** Set limits to prevent focuser from moving beyond safe range

#### 6. Step Range Query
- **Functions:**
  - `EAFStepRange()` - Get valid step range
- **Use Case:** Query valid movement range for focuser

#### 7. Stop Movement
- **Functions:**
  - `EAFStop()` - Stop focuser movement immediately
- **Use Case:** Emergency stop or abort focuser movement

#### 8. Reset Position
- **Functions:**
  - `EAFResetPostion()` - Reset focuser position to zero
- **Use Case:** Reset focuser position reference point

#### 9. Firmware Version Detection
- **Functions:**
  - `EAFGetFirmwareVersion()` - Get firmware version
- **Use Case:** Check firmware compatibility and version-specific features

#### 10. Serial Number Reading
- **Functions:**
  - `EAFGetSerialNumber()` - Get serial number from focuser
- **Use Case:** Identify specific focusers and track hardware

#### 11. Focuser ID Management
- **Functions:**
  - `EAFSetID()` - Set alias/ID for focuser
- **Use Case:** Assign custom names/IDs to focusers for easier identification

#### 12. Product ID Enumeration
- **Functions:**
  - `EAFGetProductIDs()` - Get list of connected focuser product IDs
  - `EAFCheck()` - Check if device is EAF by VID/PID
- **Use Case:** Enumerate focusers without opening them

### Currently Implemented Features

The following ZWO EAF SDK features **are** implemented in AlpacaPi:

- Basic focuser operations (open, move, get position)
- Focuser enumeration (`EAFGetNum`, `EAFGetID`)
- Property reading (`EAFGetProperty`)
- Temperature reading (`EAFGetTemp`)
- Movement status (`EAFIsMoving`)
- SDK version detection (`EAFGetSDKVersion`)

### Priority Recommendations

1. **Stop Movement** - Essential for safety (high priority)
2. **Backlash Compensation** - Important for accurate focusing (high priority)
3. **Maximum Step Limit** - Prevents damage (high priority)
4. **Reverse Direction** - Useful for different setups (medium priority)
5. **Firmware Version Detection** - Helpful for compatibility (medium priority)
6. **Reset Position** - Useful for calibration (low priority)

---

## Notes

- **Camera SDK:** Updated to v1.39 (was v1.14.1227) - Directory: `ZWO_ASI_SDK`
- **Filter Wheel SDK:** Updated to v1.7 (was v0.4.1022) - Directory: `ZWO_EFW_SDK`
- **Focuser SDK:** Directory: `ZWO_EAF_SDK`
- Last updated: 2024-11-09
- SDK sources:
  - Camera: `/home/dev/Downloads/ASI_linux_mac_SDK_V1.39/`
  - Filter Wheel: `/home/dev/Downloads/EFW_linux_mac_SDK_V1.7/`

