######################################################################################
#	Make file for alpaca driver
#	written by hand by Mark Sproul
#	(C) 2019 by Mark Sproul
#
#		sudo apt-get install build-essential
#		sudo apt-get install pkg-config
#		sudo apt-get install libusb-1.0-0-dev
#		sudo apt-get install libudev-dev
#		sudo apt-get install libopencv-dev
#		sudo apt-get install libi2c-dev
#		sudo apt-get install libjpeg-dev
#		sudo apt-get install libcfitsio-dev
#
#		sudo apt-get install wiringpi
#
#		sudo apt-get install libnova-dev		<<<< required for TSC
#
#		sudo apt-get install git-gui
#
#	https://www.gnu.org/software/make/manual/make.html
#
######################################################################################
#	WiringPi
#		https://github.com/WiringPi/WiringPi
#		https://github.com/TheNextLVL/wiringPi
#	Version 2.7 and later
#		git clone https://github.com/WiringPi/WiringPi.git
######################################################################################
#	Edit History
######################################################################################
#++	Apr  9,	2019	<MLS> Started on alpaca driver
#++	Apr 29,	2019	<MLS> Added openCV support
#++	May  7,	2019	<MLS> Added smate build option
#++	May 24,	2019	<MLS> Added wx build option
#++	Jun 25,	2019	<MLS> Added jetson build option
#++	Aug 20,	2019	<MLS> Added ATIK support
#++	Jan  9,	2020	<MLS> Added ToupTek support
#++	Jan 24,	2020	<MLS> Moved _ENABLE_FITS_ to Makefile
#++	Feb 11,	2020	<MLS> Added shutter
#++	Apr  3,	2020	<MLS> Added _ENABLE_FLIR_
#++	Apr 16,	2020	<MLS> Added _ENABLE_PWM_SWITCH_
#++	Apr 22,	2020	<MLS> Added flir to build flir camera on ubuntu
#++	Jun  8,	2020	<MLS> Added video controller
#++	Jun 23,	2020	<MLS> Added preview controller
#++	Jul 16,	2020	<MLS> Added pi64 for 64 bit Raspberry Pi OS
#++	Dec 12,	2020	<MLS> Moved _ENABLE_REMOTE_SHUTTER_ into Makefile
#++	Jan 13,	2021	<MLS> Added build commands for touptech cameras
#++	Mar 18,	2021	<MLS> Updating Makefile to use AtikCamerasSDK_2020_10_19
#++	Mar 18,	2021	<MLS> Updating QHY camera support
#++	Apr 20,	2021	<MLS> Added _ENABLE_TELESCOPE_RIGEL_
#++	Apr 26,	2021	<MLS> Added _ENABLE_FILTERWHEEL_ZWO_
#++	Apr 26,	2021	<MLS> Added _ENABLE_FILTERWHEEL_ATIK_
#++	Jan  6,	2022	<MLS> Added _ENABLE_REMOTE_SQL_  & _ENABLE_REMOTE_GAIA_
#++	Jan 13,	2022	<MLS> Added _ENABLE_ASTEROIDS_
#++	Jan 18,	2022	<MLS> Added fitsview to makefile
#++	Mar 24,	2022	<MLS> Added -fPIE to compile options
#++	Mar 25,	2022	<MLS> Added _ENABLE_TELESCOPE_SERVO_
#++	Mar 26,	2022	<MLS> Added make_checkplatform.sh
#++	Mar 26,	2022	<MLS> Added make_checkopencv.sh
#++	Mar 26,	2022	<MLS> Added make_checksql.sh
#++	May  2,	2022	<MLS> Added IMU source directory (src_imu)
#++	May  2,	2022	<MLS> Added _ENABLE_IMU_
#++	May  2,	2022	<MLS> Added make moonlite for stand alone moonlite focuser driver
#++	May  4,	2022	<MLS> Added camera simulator (make camerasim)
#++	May 19,	2022	<MLS> Updated Makefile to reflect RNS filename changes
#++	Jun 30,	2022	<MLS> Added dumpfits to makefile
#++	Oct 17,	2022	<MLS> Added _ENABLE_FOCUSER_MOONLITE_
#++	Oct 17,	2022	<MLS> Added _ENABLE_FILTERWHEEL_USIS_
#++	Mar  5,	2023	<MLS> Re-organizing object lists
#++	Dec  2,	2023	<MLS> Added piswitch3
#++	Apr 22,	2024	<MLS> Added _INCLUDE_MULTI_LANGUAGE_SUPPORT_
#++	Jun 16,	2024	<MLS> Updated QSI Makefile entry
#++	Aug 17,	2024	<MLS> Added _ENABLE_EXPLORADOME_
#++	Nov 28,	2024	<MLS> Added support for ZWO EAF focuser
######################################################################################
#	Cr_Core is for the Sony camera
######################################################################################

#PLATFORM			=	x86
#PLATFORM			=	x64
#PLATFORM			=	armv7

###########################################
#	lets try to determine platform
MACHINE_TYPE		=	$(shell uname -m)
PLATFORM			=	$(shell ./scripts/make_checkplatform.sh)
OPENCV_VERSION		=	$(shell ./scripts/make_checkopencv.sh)
SQL_VERSION			=	$(shell ./scripts/make_checksql.sh)

###########################################
# default settings for Desktop Linux build
USR_HOME			=	$(HOME)/
GCC_DIR				=	/usr/bin/
#INCLUDE_BASE		=	/usr/include/
#LIB_BASE			=	/usr/lib/

#	OpenCV detection via pkg-config (works with both package manager and source-compiled)
#	pkg-config will automatically provide correct include and library paths
OPENCV_COMPILE		=	$(shell pkg-config --cflags $(OPENCV_VERSION))
OPENCV_LINK			=	$(shell pkg-config --libs $(OPENCV_VERSION))
#*	Note: pkg-config already includes library paths, but we add /usr/local/lib/
#*	for source-compiled OpenCV installations (optional, won't hurt package manager installs)
OPENCV_LIB			=	/usr/local/lib/
OPENCV_LINK			+=	-L$(OPENCV_LIB)

PHASEONE_INC		=	/usr/local/include/phaseone/include/
PHASEONE_LIB		=	/usr/local/lib/

PLAYERONE_LIB		=	/usr/local/lib/

SRC_DIR				=	./src/
DRIVERS_DIR			=	./drivers/
SRC_IMGPROC			=	./src_imageproc/
SRC_IMU				=	./libs/src_imu/
SRC_DISCOVERY		=	./src_discovery/
SRC_MOONRISE		=	./libs/src_MoonRise/
SRC_SERVO			=	./libs/src_servo/
SRC_PDS				=	./src_pds/
SRC_SKYIMAGE		=	./src_skyimage/
SRC_SPECTROGRAPH	=	./src_spectrograph/

MLS_LIB_DIR			=	./libs/src_mlsLib/
OBJECT_DIR			=	./Objectfiles/


GD_DIR				=	../gd/
############################################
# ZWO libraires
ASI_LIB_DIR		=	./sdk/ZWO_ASI_SDK
ASI_INCLUDE_DIR	=	./sdk/ZWO_ASI_SDK/include
EFW_LIB_DIR		=	./sdk/ZWO_EFW_SDK
ZWO_EAF_DIR			=	./sdk/ZWO_EAF_SDK/include
ZWO_EAF_LIB_DIR		=	./sdk/ZWO_EAF_SDK/lib/$(PLATFORM)/

############################################
#	as of Mar 18, 2021, supporting the AtikCamerasSDK_2020_10_19 version of ATIK
ATIK_DIR			=	./sdk/AtikCamerasSDK
ATIK_LIB_MASTER_DIR	=	$(ATIK_DIR)/lib
ATIK_INCLUDE_DIR	=	$(ATIK_DIR)/include
ATIK_INCLUDE_DIR2	=	$(ATIK_DIR)/inc
#ATIK_LIB_DIR		=	$(ATIK_LIB_MASTER_DIR)/linux/x64/NoFlyCapture
ATIK_LIB_DIR		=	$(ATIK_LIB_MASTER_DIR)/linux/64/NoFlyCapture
#ATIK_LIB_DIR_V129	=	$(ATIK_LIB_MASTER_DIR)/ARM/pi/pi3/x86/NoFlyCapture
ATIK_LIB_DIR_ARM32	=	$(ATIK_LIB_MASTER_DIR)/ARM/32/NoFlyCapture
ATIK_LIB_DIR_ARM64	=	$(ATIK_LIB_MASTER_DIR)/ARM/64/NoFlyCapture

ATIK_PLATFORM		=	unknown

ifeq ($(PLATFORM),  x64)
	ATIK_PLATFORM	=	linux/64
endif
ifeq ($(PLATFORM),  armv7)
	ATIK_PLATFORM	=	ARM/32
endif
ifeq ($(PLATFORM),  armv8)
	ATIK_PLATFORM	=	ARM/64
endif
ATIK_LIB_DIR	=	$(ATIK_LIB_MASTER_DIR)/$(ATIK_PLATFORM)/NoFlyCapture

############################################
TOUP_DIR			=	./toupcamsdk
TOUP_INCLUDE_DIR	=	$(TOUP_DIR)/inc
TOUP_LIB_DIR		=	$(TOUP_DIR)/linux/x64

############################################
OGMA_DIR			=	./OGMAcamSDK
OGMA_INCLUDE_DIR	=	$(OGMA_DIR)/inc
OGMA_LIB_DIR		=	$(OGMA_DIR)/linux/arm64


############################################
FLIR_INCLUDE_DIR	=	/usr/include/spinnaker


############################################
SONY_INCLUDE_DIR	=	./SONY_SDK/CRSDK
SONY_LIB_DIR		=	./SONY_SDK/lib

############################################
#	QHY support
QHY_INCLUDE_DIR		=	./QHY/include

############################################
#	QSI support
QSI_INCLUDE_DIR		=	./qsiapi-7.6.0/lib

DEFINEFLAGS		+=	-D_ALPACA_PI_
DEFINEFLAGS		+=	-D_INCLUDE_ALPACA_EXTENSIONS_
DEFINEFLAGS		+=	-D_INCLUDE_HTTP_HEADER_
DEFINEFLAGS		+=	-D_USE_CAMERA_READ_THREAD_
#DEFINEFLAGS		+=	-D_INCLUDE_MULTI_LANGUAGE_SUPPORT_

CFLAGS			=	-Wall -Wno-multichar -Wno-unknown-pragmas -Wstrict-prototypes
CFLAGS			+=	-Wextra
#CFLAGS			+=	-Werror
CFLAGS			+=	-Wmissing-prototypes
#CFLAGS			+=	-trigraphs
CFLAGS			+=	-g
#CFLAGS			+=	-Wno-unused-but-set-variable
#CFLAGS			+=	-Wstrict-prototypes
#CFLAGS			+=	-mx32
CFLAGS			+=	-fPIE
CFLAGS			+=	-Wno-implicit-fallthrough

CPLUSFLAGS		=	-Wall -Wno-multichar -Wno-unknown-pragmas
CPLUSFLAGS		+=	-Wextra
CPLUSFLAGS		+=	-Wuninitialized
CPLUSFLAGS		+=	-Wmaybe-uninitialized
CPLUSFLAGS		+=	-Wno-unused-parameter
#CPLUSFLAGS		+=	-Wno-class-memaccess
#CPLUSFLAGS		+=	-O2
#CPLUSFLAGS		+=	-trigraphs
CPLUSFLAGS		+=	-g
#CPLUSFLAGS		+=	-Wno-unused-but-set-variable
CPLUSFLAGS		+=	-fPIE
CPLUSFLAGS		+=	-Wno-format-overflow
CPLUSFLAGS		+=	-Wno-implicit-fallthrough


COMPILE			=	gcc -c $(CFLAGS) $(DEFINEFLAGS) $(OPENCV_COMPILE)
COMPILEPLUS		=	g++ -c $(CPLUSFLAGS) $(DEFINEFLAGS) $(OPENCV_COMPILE)
LINK			=	g++


INCLUDES		=	-I/usr/include					\
					-I/usr/local/include			\
					-I$(SRC_DIR)					\
					-I$(DRIVERS_DIR)				\
					-I$(DRIVERS_DIR)ZWO/Camera		\
					-I$(DRIVERS_DIR)ZWO/FilterWheel	\
					-I$(DRIVERS_DIR)ZWO/Focuser		\
					-I$(DRIVERS_DIR)ATIK/Camera		\
					-I$(DRIVERS_DIR)ATIK/FilterWheel	\
					-I$(DRIVERS_DIR)QHY/Camera		\
					-I$(DRIVERS_DIR)QHY/FilterWheel	\
					-I$(DRIVERS_DIR)QSI/Camera		\
					-I$(DRIVERS_DIR)PlayerOne/Camera	\
					-I$(DRIVERS_DIR)PlayerOne/FilterWheel	\
					-I$(DRIVERS_DIR)ToupTek/Camera	\
					-I$(DRIVERS_DIR)FLIR/Camera		\
					-I$(DRIVERS_DIR)OGMA/Camera		\
					-I$(DRIVERS_DIR)SONY/Camera		\
					-I$(DRIVERS_DIR)MoonLite/Focuser	\
					-I$(DRIVERS_DIR)MoonLite/Rotator	\
					-I$(DRIVERS_DIR)LX200/Telescope	\
					-I$(DRIVERS_DIR)ExpSci/Telescope	\
					-I$(DRIVERS_DIR)Rigel/Telescope	\
					-I$(DRIVERS_DIR)SkyWatcher/Telescope	\
					-I$(DRIVERS_DIR)Servo/Telescope	\
					-I$(DRIVERS_DIR)iOptron/Telescope	\
					-I$(DRIVERS_DIR)Simulator/Camera	\
					-I$(DRIVERS_DIR)Simulator/FilterWheel	\
					-I$(DRIVERS_DIR)Simulator/Focuser	\
					-I$(DRIVERS_DIR)Simulator/Rotator	\
					-I$(DRIVERS_DIR)Simulator/Telescope	\
					-I$(DRIVERS_DIR)Simulator/Dome	\
					-I$(DRIVERS_DIR)RaspberryPi/Dome	\
					-I$(DRIVERS_DIR)RaspberryPi/Switch	\
					-I$(DRIVERS_DIR)RaspberryPi/ObservingConditions	\
					-I$(DRIVERS_DIR)RaspberryPi/Calibration	\
					-I$(DRIVERS_DIR)Arduino/Shutter	\
					-I$(SRC_SKYIMAGE)				\
					-I$(SRC_IMGPROC)				\
					-I$(SRC_PDS)					\
					-I$(SRC_SPECTROGRAPH)			\
					-I$(ASI_INCLUDE_DIR)			\
					-I$(ATIK_INCLUDE_DIR)			\
					-I$(ATIK_INCLUDE_DIR2)			\
					-I$(EFW_LIB_DIR)/include		\
					-I$(FLIR_INCLUDE_DIR)			\
					-I$(MLS_LIB_DIR)				\
					-I$(QHY_INCLUDE_DIR)			\
					-I$(TOUP_INCLUDE_DIR)			\
					-I$(SONY_INCLUDE_DIR)			\
					-I$(ZWO_EAF_DIR)				\


#					-I/usr/include/opencv2			\
#					-I/usr/local/include/opencv2	\
#					-I/usr/include/opencv4			\
#					-I/usr/local/include/opencv4	\


######################################################################################
ASI_CAMERA_OBJECTS=												\
				$(ASI_LIB_DIR)/lib/$(PLATFORM)/libASICamera2.a	\


######################################################################################
ZWO_EFW_OBJECTS=												\
				$(EFW_LIB_DIR)/lib/$(PLATFORM)/libEFWFilter.a	\



######################################################################################
SOCKET_OBJECTS=												\
				$(OBJECT_DIR)socket_listen.o				\
				$(OBJECT_DIR)json_parse.o					\
				$(OBJECT_DIR)sendrequest_lib.o				\


######################################################################################
DISCOVERY_LIB_OBJECTS=										\
				$(OBJECT_DIR)discovery_lib.o				\



######################################################################################
# CPP objects
CPP_OBJECTS=												\
				$(OBJECT_DIR)cpu_stats.o					\
				$(OBJECT_DIR)discoverythread.o				\
				$(OBJECT_DIR)eventlogging.o					\
				$(OBJECT_DIR)HostNames.o					\
				$(OBJECT_DIR)JsonResponse.o					\
				$(OBJECT_DIR)linuxerrors.o					\
				$(OBJECT_DIR)lx200_com.o					\
				$(OBJECT_DIR)managementdriver.o				\
				$(OBJECT_DIR)observatory_settings.o			\
				$(OBJECT_DIR)readconfigfile.o				\
				$(OBJECT_DIR)sidereal.o						\
				$(OBJECT_DIR)serialport.o					\
				$(OBJECT_DIR)telescopedriver.o				\
				$(OBJECT_DIR)telescopedriver_comm.o			\
				$(OBJECT_DIR)telescopedriver_lx200.o		\
				$(OBJECT_DIR)telescopedriver_Rigel.o		\
				$(OBJECT_DIR)telescopedriver_servo.o		\
				$(OBJECT_DIR)telescopedriver_sim.o			\
				$(OBJECT_DIR)telescopedriver_skywatch.o		\
				$(OBJECT_DIR)telescopedriver_iOptron.o		\


######################################################################################
LIVE_WINDOW_OBJECTS=										\
				$(OBJECT_DIR)controller.o					\
				$(OBJECT_DIR)controller_image.o				\
				$(OBJECT_DIR)opencv_utils.o					\
				$(OBJECT_DIR)windowtab.o					\
				$(OBJECT_DIR)windowtab_about.o				\
				$(OBJECT_DIR)windowtab_fitsheader.o			\
				$(OBJECT_DIR)windowtab_image.o				\
				$(OBJECT_DIR)windowtab_imageinfo.o			\
				$(OBJECT_DIR)fits_opencv.o					\


#				$(OBJECT_DIR)controllerAlpaca.o				\

######################################################################################
#	Driver Objects
DRIVER_OBJECTS=												\
				$(OBJECT_DIR)alpacadriver.o					\
				$(OBJECT_DIR)alpacadriver_gps.o				\
				$(OBJECT_DIR)alpacadriverConnect.o			\
				$(OBJECT_DIR)alpacadriverSetup.o			\
				$(OBJECT_DIR)alpacadriverThread.o			\
				$(OBJECT_DIR)alpacadriver_templog.o			\
				$(OBJECT_DIR)alpacadriver_helper.o			\
				$(OBJECT_DIR)alpaca_discovery.o				\
				$(OBJECT_DIR)alpacadriverLogging.o			\
				$(OBJECT_DIR)commoncolor.o					\
				$(OBJECT_DIR)julianTime.o					\
				$(OBJECT_DIR)moonphase.o					\
				$(OBJECT_DIR)MoonRise.o						\
				$(OBJECT_DIR)cpu_stats.o					\
				$(OBJECT_DIR)discoverythread.o				\
				$(OBJECT_DIR)eventlogging.o					\
				$(OBJECT_DIR)HostNames.o					\
				$(OBJECT_DIR)JsonResponse.o					\
				$(OBJECT_DIR)linuxerrors.o					\
				$(OBJECT_DIR)managementdriver.o				\
				$(OBJECT_DIR)observatory_settings.o			\
				$(OBJECT_DIR)readconfigfile.o				\
				$(OBJECT_DIR)sidereal.o						\

######################################################################################
# Camera objects
CAMERA_DRIVER_OBJECTS=										\
				$(OBJECT_DIR)cameradriver.o					\
				$(OBJECT_DIR)cameradriverAnalysis.o			\
				$(OBJECT_DIR)cameradriver_ASI.o				\
				$(OBJECT_DIR)cameradriver_ATIK.o			\
				$(OBJECT_DIR)cameradriver_auxinfo.o			\
				$(OBJECT_DIR)cameradriver_fits.o			\
				$(OBJECT_DIR)cameradriver_gps.o				\
				$(OBJECT_DIR)cameradriver_FLIR.o			\
				$(OBJECT_DIR)cameradriver_jpeg.o			\
				$(OBJECT_DIR)cameradriver_livewindow.o		\
				$(OBJECT_DIR)cameradriver_OGMA.o			\
				$(OBJECT_DIR)cameradriver_opencv.o			\
				$(OBJECT_DIR)cameradriver_overlay.o			\
				$(OBJECT_DIR)cameradriver_png.o				\
				$(OBJECT_DIR)cameradriver_QHY.o				\
				$(OBJECT_DIR)cameradriver_QSI.o				\
				$(OBJECT_DIR)cameradriver_readthread.o		\
				$(OBJECT_DIR)cameradriver_PlayerOne.o		\
				$(OBJECT_DIR)cameradriver_SONY.o			\
				$(OBJECT_DIR)cameradriver_save.o			\
				$(OBJECT_DIR)cameradriver_sim.o				\
				$(OBJECT_DIR)cameradriver_TOUP.o			\
				$(OBJECT_DIR)NASA_moonphase.o				\
				$(OBJECT_DIR)multicam.o						\


######################################################################################
CALIBRATION_DRIVER_OBJECTS=									\
				$(OBJECT_DIR)calibrationdriver.o			\
				$(OBJECT_DIR)calibrationdriver_rpi.o		\
				$(OBJECT_DIR)calibration_Alnitak.o		\
				$(OBJECT_DIR)calibration_sim.o				\

######################################################################################
DOME_DRIVER_OBJECTS=										\
				$(OBJECT_DIR)domedriver.o					\
				$(OBJECT_DIR)domedriver_sim.o				\
				$(OBJECT_DIR)domeshutter.o					\
				$(OBJECT_DIR)domedriver_rpi.o				\
				$(OBJECT_DIR)domedriver_ror_rpi.o			\
				$(OBJECT_DIR)raspberrypi_relaylib.o			\

######################################################################################
SHUTTER_DRIVER_OBJECTS=										\
				$(OBJECT_DIR)shutterdriver.o				\
				$(OBJECT_DIR)shutterdriver_arduino.o		\



######################################################################################
# Filterwheel objects
FILTERWHEEL_DRIVER_OBJECTS=									\
				$(OBJECT_DIR)filterwheeldriver.o			\
				$(OBJECT_DIR)filterwheeldriver_ATIK.o		\
				$(OBJECT_DIR)filterwheeldriver_Play1.o		\
				$(OBJECT_DIR)filterwheeldriver_QHY.o		\
				$(OBJECT_DIR)filterwheeldriver_ZWO.o		\
				$(OBJECT_DIR)filterwheeldriver_sim.o		\

######################################################################################
FOCUSER_DRIVER_OBJECTS=										\
				$(OBJECT_DIR)focuserdriver.o				\
				$(OBJECT_DIR)focuserdriver_nc.o				\
				$(OBJECT_DIR)focuserdriver_sim.o			\
				$(OBJECT_DIR)focuserdriver_ZWO.o			\
				$(OBJECT_DIR)moonlite_com.o					\
				$(OBJECT_DIR)rotatordriver.o				\
				$(OBJECT_DIR)rotatordriver_nc.o				\
				$(OBJECT_DIR)rotatordriver_sim.o			\

######################################################################################
SLITTRACKER_DRIVER_OBJECTS=									\
				$(OBJECT_DIR)slittracker.o					\

######################################################################################
OBSCOND_DRIVER_OBJECTS=										\
				$(OBJECT_DIR)obsconditionsdriver.o			\
				$(OBJECT_DIR)obsconditionsdriver_rpi.o		\
				$(OBJECT_DIR)obsconditionsdriver_sim.o		\


######################################################################################
SWITCH_DRIVER_OBJECTS=										\
				$(OBJECT_DIR)switchdriver.o					\
				$(OBJECT_DIR)switchdriver_rpi.o				\
				$(OBJECT_DIR)switchdriver_sim.o				\
				$(OBJECT_DIR)switchdriver_stepper.o			\

######################################################################################
TELESCOPE_DRIVER_OBJECTS=									\
				$(OBJECT_DIR)telescopedriver.o				\
				$(OBJECT_DIR)telescopedriver_comm.o			\
				$(OBJECT_DIR)telescopedriver_lx200.o		\
				$(OBJECT_DIR)telescopedriver_Rigel.o		\
				$(OBJECT_DIR)telescopedriver_servo.o		\
				$(OBJECT_DIR)telescopedriver_sim.o			\
				$(OBJECT_DIR)telescopedriver_iOptron.o		\
				$(OBJECT_DIR)lx200_com.o					\

EXPSCI_OBJECTS=												\
				$(OBJECT_DIR)telescopedriver_ExpSci.o		\


######################################################################################
SERIAL_OBJECTS=												\
				$(OBJECT_DIR)serialport.o					\
				$(OBJECT_DIR)usbmanager.o					\

######################################################################################
TEST_OBJECTS=												\
				$(OBJECT_DIR)cameradriver_PhaseOne.o		\

######################################################################################
#	Camera Objects
IMAGEPROC_OBJECTS=											\
				$(OBJECT_DIR)imageprocess_orb.o				\


######################################################################################
CLIENT_OBJECTS=												\
				$(OBJECT_DIR)json_parse.o					\
				$(OBJECT_DIR)discoveryclient.o				\

######################################################################################
HELPER_OBJECTS=												\
				$(OBJECT_DIR)helper_functions.o				\


######################################################################################
#	Roll Off Roof Objects
ROR_OBJECTS=												\
				$(OBJECT_DIR)alpacadriver.o					\
				$(OBJECT_DIR)alpacadriverConnect.o			\
				$(OBJECT_DIR)alpacadriverSetup.o			\
				$(OBJECT_DIR)alpacadriverThread.o			\
				$(OBJECT_DIR)alpacadriver_helper.o			\
				$(OBJECT_DIR)alpacadriverLogging.o			\
				$(OBJECT_DIR)alpaca_discovery.o				\
				$(OBJECT_DIR)cpu_stats.o					\
				$(OBJECT_DIR)discoverythread.o				\
				$(OBJECT_DIR)domedriver.o					\
				$(OBJECT_DIR)domedriver_ror_rpi.o			\
				$(OBJECT_DIR)eventlogging.o					\
				$(OBJECT_DIR)HostNames.o					\
				$(OBJECT_DIR)JsonResponse.o					\
				$(OBJECT_DIR)linuxerrors.o					\
				$(OBJECT_DIR)managementdriver.o				\
				$(OBJECT_DIR)observatory_settings.o			\
				$(OBJECT_DIR)raspberrypi_relaylib.o			\

######################################################################################
# IMU objects
IMU_OBJECTS=												\
				$(OBJECT_DIR)imu_lib.o						\
				$(OBJECT_DIR)imu_lib_bno055.o				\
				$(OBJECT_DIR)imu_lib_LIS2DH12.o				\
				$(OBJECT_DIR)i2c_bno055.o					\


######################################################################################
# GPS objects
GPS_OBJECTS=												\
				$(OBJECT_DIR)gps_data.o						\
				$(OBJECT_DIR)ParseNMEA.o					\
				$(OBJECT_DIR)NMEA_helper.o					\
				$(OBJECT_DIR)GPS_graph.o					\
				$(OBJECT_DIR)web_graphics_opencv.o			\

#				$(OBJECT_DIR)serialport.o					\

######################################################################################
# GPS objects
NMEA_OBJECTS=												\
				$(OBJECT_DIR)ParseNMEA.o					\
				$(OBJECT_DIR)NMEA_helper.o					\


######################################################################################
help:
	#################################################################################
	# The AlpacaPi project consists of two main parts, drivers and clients,
	#	There are 2 major variants that to be dealt with opencv4 and opencv
	#	The newer opencv4 variant only supports the C++ interface
	#	AlpacaPi was originally written with the C interface
	#   Once everything is converted to opencv4, the opencv options will go away
	#
	#	Driver make options
	#        make dome          Raspberry pi version to control dome using DC motor controller
	#
	#     opencv4 only options
	#        make alpacapicv4   Driver for x86 linux
	#        make camerasim     Camera simulator
	#        make simulator     Several different simulators
	#        make picv4         Version for Raspberry Pi using OpenCV 4 or later

	#     opencv only options
	#        make alpacapi       Driver for x86 linux
	#        make jetson         Version to run on nvidia jetson board, this is an armv8
	#        make moonlite       Driver for moonlite focusers ONLY
	#        make nocamera       Build without the camera support
	#        make noopencv       Camera driver for ZWO WITHOUT opencv
	#        make pi             Version for Raspberry Pi
	#        make qhypi          Camera driver for QHY cameras only for Raspberry-Pi
	#        make qsi            Camera driver for QSI cameras
	#        make wx             Version that uses the R-Pi sensor board
	#
	#
	# Telescope drivers,
	# As of May 2022, the telescope driver is still in development,
	# There are several options that are in progress
	#        make tele      Makes a version which speaks LX200 over a TCP/IP connection
	#        make rigel     Makes a special version for a user that uses a rigel controller
	#        make eq6       A version to control eq6 style mounts
	#        make servo     A telescope controller based on servo motors using LM628/629
	#
	# Miscellaneous
	#        make clean      removes all binaries
	#        make help       this message
	#
	#    Client make options
	#       SkyTravel is an all in one client program, it has all of the controllers built in
	#       with full Alpaca Discovery support and generates a list of available devices
	#
	#       make sky         makes SkyTravel with openCV 3.3.1 or earlier
	#       make skysql      same as sky but with SQL database support
	#>      make skycv4      makes SkyTravel with newer Versions after 3.3.1
	#>      make skycv4sql   same as skycv4 with SQL database support
	#
	#   Some of the clients can also be built separately
	#       make camera
	#       make domectrl
	#       make focuser
	#       make switch
	#
	# MACHINE_TYPE  =$(MACHINE_TYPE)
	# PLATFORM      =$(PLATFORM)
	# OPENCV_VERSION=$(OPENCV_VERSION)
	# SQL_VERSION   =$(SQL_VERSION)
	# ATIK_PLATFORM =$(ATIK_PLATFORM)
	#################################################################################



#	Debug                     Makefile
#        smate      Build a version to run on a Stellarmate running smate OS



######################################################################################
alpacapi		:		DEFINEFLAGS		+=	-D_INCLUDE_MILLIS_
alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_CAMERA_
alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_ASI_
#alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_ATIK_
alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_CALIBRATION_
alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_DISCOVERY_QUERRY_
#alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_DOME_
alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_FITS_
alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_FILTERWHEEL_
alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_FILTERWHEEL_ZWO_
#alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_FLIR_
alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_FOCUSER_
alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_FOCUSER_MOONLITE_
alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_FOCUSER_ZWO_
#alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_MULTICAM_
#alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_OBSERVINGCONDITIONS_
#alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_QHY_
alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_ROTATOR_
alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_ROTATOR_NITECRAWLER_
#alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_SAFETYMONITOR_
#alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_SWITCH_
#alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_SLIT_TRACKER_
#alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_TOUP_
alpacapi		:		DEFINEFLAGS		+=	-D_USE_OPENCV_
#alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_TELESCOPE_
#alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_TELESCOPE_LX200_
alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_CTRL_IMAGE_
alpacapi		:		DEFINEFLAGS		+=	-D_ENABLE_LIVE_CONTROLLER_
alpacapi		:									\
					$(DRIVER_OBJECTS)				\
					$(CAMERA_DRIVER_OBJECTS)		\
					$(CALIBRATION_DRIVER_OBJECTS)	\
					$(FILTERWHEEL_DRIVER_OBJECTS)	\
					$(FOCUSER_DRIVER_OBJECTS)		\
					$(HELPER_OBJECTS)				\
					$(SERIAL_OBJECTS)				\
					$(SOCKET_OBJECTS)				\
					$(LIVE_WINDOW_OBJECTS)			\

		$(LINK)  									\
					$(DRIVER_OBJECTS)				\
					$(CAMERA_DRIVER_OBJECTS)		\
					$(CALIBRATION_DRIVER_OBJECTS)	\
					$(FILTERWHEEL_DRIVER_OBJECTS)	\
					$(FOCUSER_DRIVER_OBJECTS)		\
					$(HELPER_OBJECTS)				\
					$(SERIAL_OBJECTS)				\
					$(SOCKET_OBJECTS)				\
					$(LIVE_WINDOW_OBJECTS)			\
					$(ASI_CAMERA_OBJECTS)			\
					$(OPENCV_LINK)					\
					-L$(ZWO_EAF_LIB_DIR)			\
					-Wl,-rpath,$(ZWO_EAF_LIB_DIR)	\
					$(ZWO_EFW_OBJECTS)				\
					-lEAFFocuser					\
					-ludev							\
					-lusb-1.0						\
					-lpthread						\
					-lcfitsio						\
					-o alpacapi


#					-L$(ATIK_LIB_DIR)/			\
#					-latikcameras				\
#					-lqhyccd					\


######################################################################################
clean:
	rm -vf $(OBJECT_DIR)*.o

######################################################################################
cleanskytravel:
	rm -vf $(OBJECT_DIR)*.o
	rm -vf obj/skytravel/src/*.o

cleansss:
	rm -vf $(OBJECT_DIR)*.o
	rm -vf obj/sss/src/*.o

######################################################################################
$(OBJECT_DIR)socket_listen.o : $(SRC_DIR)socket_listen.c $(SRC_DIR)socket_listen.h
	$(COMPILE) $(INCLUDES) $(SRC_DIR)socket_listen.c -o$(OBJECT_DIR)socket_listen.o

$(OBJECT_DIR)JsonResponse.o : $(SRC_DIR)JsonResponse.c $(SRC_DIR)JsonResponse.h
	$(COMPILE) $(INCLUDES) $(SRC_DIR)JsonResponse.c -o$(OBJECT_DIR)JsonResponse.o


$(OBJECT_DIR)eventlogging.o : $(SRC_DIR)eventlogging.c $(SRC_DIR)eventlogging.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)eventlogging.c -o$(OBJECT_DIR)eventlogging.o

######################################################################################
$(OBJECT_DIR)readconfigfile.o : $(SRC_DIR)readconfigfile.c $(SRC_DIR)readconfigfile.h
	$(COMPILE) $(INCLUDES) $(SRC_DIR)readconfigfile.c -o$(OBJECT_DIR)readconfigfile.o


######################################################################################
# CPP objects
#-------------------------------------------------------------------------------------
$(OBJECT_DIR)alpacadriver.o :			$(SRC_DIR)alpacadriver.cpp				\
										$(SRC_DIR)alpacadriver.h				\
										$(SRC_DIR)alpaca_defs.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)alpacadriver.cpp -o$(OBJECT_DIR)alpacadriver.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)alpacadriver_gps.o :		$(SRC_DIR)alpacadriver_gps.cpp			\
										$(SRC_DIR)alpacadriver_gps.h			\
										$(MLS_LIB_DIR)ParseNMEA.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)alpacadriver_gps.cpp -o$(OBJECT_DIR)alpacadriver_gps.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)alpacadriverConnect.o :	$(SRC_DIR)alpacadriverConnect.cpp		\
										$(SRC_DIR)alpaca_defs.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)alpacadriverConnect.cpp -o$(OBJECT_DIR)alpacadriverConnect.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)alpacadriverThread.o :		$(SRC_DIR)alpacadriverThread.cpp		\
										$(SRC_DIR)alpacadriver.h				\
										$(SRC_DIR)alpaca_defs.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)alpacadriverThread.cpp -o$(OBJECT_DIR)alpacadriverThread.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)alpacadriverSetup.o :		$(SRC_DIR)alpacadriverSetup.cpp			\
										$(SRC_DIR)alpacadriver.h				\
										$(SRC_DIR)alpaca_defs.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)alpacadriverSetup.cpp -o$(OBJECT_DIR)alpacadriverSetup.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)alpacadriver_helper.o :	$(SRC_DIR)alpacadriver_helper.c			\
										$(SRC_DIR)alpacadriver_helper.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)alpacadriver_helper.c -o$(OBJECT_DIR)alpacadriver_helper.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)alpaca_discovery.o :		$(SRC_DIR)alpaca_discovery.cpp			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)alpaca_discovery.cpp -o$(OBJECT_DIR)alpaca_discovery.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)alpacadriver_templog.o :	$(SRC_DIR)alpacadriver_templog.cpp		\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)alpacadriver_templog.cpp -o$(OBJECT_DIR)alpacadriver_templog.o



#-------------------------------------------------------------------------------------
$(OBJECT_DIR)alpacadriverLogging.o :	$(SRC_DIR)alpacadriverLogging.cpp	\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)alpacadriverLogging.cpp -o$(OBJECT_DIR)alpacadriverLogging.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver.o :			$(SRC_DIR)cameradriver.cpp			\
										$(SRC_DIR)cameradriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)cameradriver.cpp -o$(OBJECT_DIR)cameradriver.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver_readthread.o :$(SRC_DIR)cameradriver_readthread.cpp	\
										$(SRC_DIR)cameradriver.h				\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)cameradriver_readthread.cpp -o$(OBJECT_DIR)cameradriver_readthread.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriverAnalysis.o :	$(SRC_DIR)cameradriverAnalysis.cpp	\
										$(SRC_DIR)cameradriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)cameradriverAnalysis.cpp -o$(OBJECT_DIR)cameradriverAnalysis.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver_fits.o :		$(SRC_DIR)cameradriver_fits.cpp		\
										$(SRC_DIR)cameradriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)cameradriver_fits.cpp -I$(SRC_MOONRISE) -o$(OBJECT_DIR)cameradriver_fits.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver_gps.o :		$(SRC_DIR)cameradriver_gps.cpp		\
										$(SRC_DIR)cameradriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)cameradriver_gps.cpp -o$(OBJECT_DIR)cameradriver_gps.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver_ASI.o :		$(DRIVERS_DIR)ZWO/Camera/cameradriver_ASI.cpp		\
										$(DRIVERS_DIR)ZWO/Camera/cameradriver_ASI.h		\
										$(SRC_DIR)cameradriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)ZWO/Camera/cameradriver_ASI.cpp -o$(OBJECT_DIR)cameradriver_ASI.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver_ATIK.o :		$(DRIVERS_DIR)ATIK/Camera/cameradriver_ATIK.cpp		\
										$(DRIVERS_DIR)ATIK/Camera/cameradriver_ATIK.h		\
										$(SRC_DIR)cameradriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)ATIK/Camera/cameradriver_ATIK.cpp -o$(OBJECT_DIR)cameradriver_ATIK.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver_auxinfo.o :	$(SRC_DIR)cameradriver_auxinfo.cpp		\
										$(SRC_DIR)cameradriver_auxinfo.h		\
										$(SRC_DIR)cameradriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)cameradriver_auxinfo.cpp -o$(OBJECT_DIR)cameradriver_auxinfo.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver_overlay.o :	$(SRC_DIR)cameradriver_overlay.cpp	\
										$(SRC_DIR)cameradriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)cameradriver_overlay.cpp -o$(OBJECT_DIR)cameradriver_overlay.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)filterwheeldriver_ATIK.o :	$(DRIVERS_DIR)ATIK/FilterWheel/filterwheeldriver_ATIK.cpp	\
										$(DRIVERS_DIR)ATIK/FilterWheel/filterwheeldriver_ATIK.h		\
										$(SRC_DIR)filterwheeldriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)ATIK/FilterWheel/filterwheeldriver_ATIK.cpp -o$(OBJECT_DIR)filterwheeldriver_ATIK.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)filterwheeldriver_Play1.o :	$(DRIVERS_DIR)PlayerOne/FilterWheel/filterwheeldriver_Play1.cpp	\
											$(DRIVERS_DIR)PlayerOne/FilterWheel/filterwheeldriver_Play1.h		\
											$(SRC_DIR)filterwheeldriver.h				\
											$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)PlayerOne/FilterWheel/filterwheeldriver_Play1.cpp -o$(OBJECT_DIR)filterwheeldriver_Play1.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver_PlayerOne.o :			$(DRIVERS_DIR)PlayerOne/Camera/cameradriver_PlayerOne.cpp	\
												$(DRIVERS_DIR)PlayerOne/Camera/cameradriver_PlayerOne.h		\
												$(SRC_DIR)cameradriver.h				\
												$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)PlayerOne/Camera/cameradriver_PlayerOne.cpp -o$(OBJECT_DIR)cameradriver_PlayerOne.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver_OGMA.o :				$(DRIVERS_DIR)OGMA/Camera/cameradriver_OGMA.cpp	\
												$(DRIVERS_DIR)OGMA/Camera/cameradriver_OGMA.h	\
												$(SRC_DIR)cameradriver.h		\
												$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)OGMA/Camera/cameradriver_OGMA.cpp -o$(OBJECT_DIR)cameradriver_OGMA.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)filterwheeldriver_QHY.o :	$(DRIVERS_DIR)QHY/FilterWheel/filterwheeldriver_QHY.cpp		\
										$(DRIVERS_DIR)QHY/FilterWheel/filterwheeldriver_QHY.h		\
										$(SRC_DIR)filterwheeldriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)QHY/FilterWheel/filterwheeldriver_QHY.cpp -o$(OBJECT_DIR)filterwheeldriver_QHY.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)filterwheeldriver_sim.o :	$(DRIVERS_DIR)Simulator/FilterWheel/filterwheeldriver_sim.cpp		\
										$(DRIVERS_DIR)Simulator/FilterWheel/filterwheeldriver_sim.h		\
										$(SRC_DIR)filterwheeldriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)Simulator/FilterWheel/filterwheeldriver_sim.cpp -o$(OBJECT_DIR)filterwheeldriver_sim.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver_QHY.o :		$(DRIVERS_DIR)QHY/Camera/cameradriver_QHY.cpp		\
										$(DRIVERS_DIR)QHY/Camera/cameradriver_QHY.h		\
										$(SRC_DIR)cameradriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)QHY/Camera/cameradriver_QHY.cpp -o$(OBJECT_DIR)cameradriver_QHY.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)ParseNMEA.o :				$(MLS_LIB_DIR)ParseNMEA.c 	\
										$(MLS_LIB_DIR)ParseNMEA.h
	$(COMPILEPLUS) $(INCLUDES)			$(MLS_LIB_DIR)ParseNMEA.c -o$(OBJECT_DIR)ParseNMEA.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)web_graphics_opencv.o :	$(MLS_LIB_DIR)web_graphics_opencv.cpp 	\
										$(MLS_LIB_DIR)web_graphics_opencv.h
	$(COMPILEPLUS) $(INCLUDES)			$(MLS_LIB_DIR)web_graphics_opencv.cpp -o$(OBJECT_DIR)web_graphics_opencv.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)gps_data.o :				$(SRC_DIR)gps_data.cpp 		\
										$(SRC_DIR)gps_data.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)gps_data.cpp -o$(OBJECT_DIR)gps_data.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)GPS_graph.o :				$(MLS_LIB_DIR)GPS_graph.c 		\
										$(MLS_LIB_DIR)GPS_graph.h
	$(COMPILEPLUS) $(INCLUDES)			$(MLS_LIB_DIR)GPS_graph.c -o$(OBJECT_DIR)GPS_graph.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)NMEA_helper.o :			$(MLS_LIB_DIR)NMEA_helper.c 	\
										$(MLS_LIB_DIR)NMEA_helper.h
	$(COMPILEPLUS) $(INCLUDES)			$(MLS_LIB_DIR)NMEA_helper.c -o$(OBJECT_DIR)NMEA_helper.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver_QSI.o :		$(DRIVERS_DIR)QSI/Camera/cameradriver_QSI.cpp		\
										$(DRIVERS_DIR)QSI/Camera/cameradriver_QSI.h		\
										$(SRC_DIR)cameradriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)QSI/Camera/cameradriver_QSI.cpp -o$(OBJECT_DIR)cameradriver_QSI.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver_FLIR.o :		$(DRIVERS_DIR)FLIR/Camera/cameradriver_FLIR.cpp		\
										$(DRIVERS_DIR)FLIR/Camera/cameradriver_FLIR.h		\
										$(SRC_DIR)cameradriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)FLIR/Camera/cameradriver_FLIR.cpp -o$(OBJECT_DIR)cameradriver_FLIR.o



#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver_livewindow.o :$(SRC_DIR)cameradriver_livewindow.cpp	\
									 	$(SRC_DIR)cameradriver.h				\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)cameradriver_livewindow.cpp -o$(OBJECT_DIR)cameradriver_livewindow.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver_PhaseOne.o 	:$(SRC_DIR)cameradriver_PhaseOne.cpp	\
									 	$(SRC_DIR)cameradriver_PhaseOne.h		\
									 	$(SRC_DIR)cameradriver.h				\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)cameradriver_PhaseOne.cpp -o$(OBJECT_DIR)cameradriver_PhaseOne.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver_save.o :		$(SRC_DIR)cameradriver_save.cpp		\
									 	$(SRC_DIR)cameradriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)cameradriver_save.cpp -o$(OBJECT_DIR)cameradriver_save.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver_sim.o :		$(DRIVERS_DIR)Simulator/Camera/cameradriver_sim.cpp		\
									 	$(DRIVERS_DIR)Simulator/Camera/cameradriver_sim.h		\
										$(SRC_DIR)cameradriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)Simulator/Camera/cameradriver_sim.cpp -o$(OBJECT_DIR)cameradriver_sim.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver_opencv.o :	$(SRC_DIR)cameradriver_opencv.cpp	\
									 	$(SRC_DIR)cameradriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)cameradriver_opencv.cpp -o$(OBJECT_DIR)cameradriver_opencv.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver_TOUP.o :		$(DRIVERS_DIR)ToupTek/Camera/cameradriver_TOUP.cpp		\
									 	$(DRIVERS_DIR)ToupTek/Camera/cameradriver_TOUP.h		\
										$(SRC_DIR)cameradriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)ToupTek/Camera/cameradriver_TOUP.cpp -o$(OBJECT_DIR)cameradriver_TOUP.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver_jpeg.o :		$(SRC_DIR)cameradriver_jpeg.cpp 	\
										$(SRC_DIR)cameradriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)cameradriver_jpeg.cpp -o$(OBJECT_DIR)cameradriver_jpeg.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver_png.o :		$(SRC_DIR)cameradriver_png.cpp 		\
										$(SRC_DIR)cameradriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)cameradriver_png.cpp -o$(OBJECT_DIR)cameradriver_png.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cameradriver_SONY.o :		$(DRIVERS_DIR)SONY/Camera/cameradriver_SONY.cpp 	\
										$(DRIVERS_DIR)SONY/Camera/cameradriver_SONY.h		\
										$(SRC_DIR)cameradriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)SONY/Camera/cameradriver_SONY.cpp -o$(OBJECT_DIR)cameradriver_SONY.o



#-------------------------------------------------------------------------------------
$(OBJECT_DIR)multicam.o :				$(SRC_DIR)multicam.cpp				\
										$(SRC_DIR)multicam.h				\
										$(SRC_DIR)cameradriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)multicam.cpp -o$(OBJECT_DIR)multicam.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)domedriver.o :				$(SRC_DIR)domedriver.cpp			\
										$(SRC_DIR)domedriver.h				\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)domedriver.cpp -o$(OBJECT_DIR)domedriver.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)domedriver_sim.o :			$(DRIVERS_DIR)Simulator/Dome/domedriver_sim.cpp		\
										$(DRIVERS_DIR)Simulator/Dome/domedriver_sim.h			\
										$(SRC_DIR)domedriver.h				\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)Simulator/Dome/domedriver_sim.cpp -o$(OBJECT_DIR)domedriver_sim.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)domeshutter.o :			$(DRIVERS_DIR)RaspberryPi/Dome/domeshutter.cpp			\
										$(SRC_DIR)domedriver.h				\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)RaspberryPi/Dome/domeshutter.cpp -o$(OBJECT_DIR)domeshutter.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)domedriver_rpi.o :			$(DRIVERS_DIR)RaspberryPi/Dome/domedriver_rpi.cpp		\
										$(SRC_DIR)domedriver.h				\
										$(DRIVERS_DIR)RaspberryPi/Dome/domedriver_rpi.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)RaspberryPi/Dome/domedriver_rpi.cpp -o$(OBJECT_DIR)domedriver_rpi.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)domedriver_ror_rpi.o :		$(DRIVERS_DIR)RaspberryPi/Dome/domedriver_ror_rpi.cpp	\
										$(DRIVERS_DIR)RaspberryPi/Dome/domedriver_ror_rpi.h		\
										$(SRC_DIR)domedriver.h				\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)RaspberryPi/Dome/domedriver_ror_rpi.cpp -o$(OBJECT_DIR)domedriver_ror_rpi.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)shutterdriver.o :			$(SRC_DIR)shutterdriver.cpp			\
										$(SRC_DIR)shutterdriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)shutterdriver.cpp -o$(OBJECT_DIR)shutterdriver.o
#-------------------------------------------------------------------------------------
$(OBJECT_DIR)shutterdriver_arduino.o :	$(DRIVERS_DIR)Arduino/Shutter/shutterdriver_arduino.cpp	\
										$(DRIVERS_DIR)Arduino/Shutter/shutterdriver_arduino.h	\
										$(SRC_DIR)shutterdriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)Arduino/Shutter/shutterdriver_arduino.cpp -o$(OBJECT_DIR)shutterdriver_arduino.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)filterwheeldriver.o :		$(SRC_DIR)filterwheeldriver.cpp		\
										$(SRC_DIR)filterwheeldriver.h		\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)filterwheeldriver.cpp -o$(OBJECT_DIR)filterwheeldriver.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)filterwheeldriver_ZWO.o :	$(DRIVERS_DIR)ZWO/FilterWheel/filterwheeldriver_ZWO.cpp	\
										$(DRIVERS_DIR)ZWO/FilterWheel/filterwheeldriver_ZWO.h 	\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)ZWO/FilterWheel/filterwheeldriver_ZWO.cpp -o$(OBJECT_DIR)filterwheeldriver_ZWO.o
#-------------------------------------------------------------------------------------
$(OBJECT_DIR)focuserdriver.o :			$(SRC_DIR)focuserdriver.cpp			\
										$(SRC_DIR)focuserdriver.h	 		\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)focuserdriver.cpp -o$(OBJECT_DIR)focuserdriver.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)focuserdriver_nc.o :		$(DRIVERS_DIR)MoonLite/Focuser/focuserdriver_nc.cpp		\
										$(DRIVERS_DIR)MoonLite/Focuser/focuserdriver_nc.h 		\
										$(SRC_DIR)focuserdriver.h	 		\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)MoonLite/Focuser/focuserdriver_nc.cpp -o$(OBJECT_DIR)focuserdriver_nc.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)focuserdriver_sim.o :		$(DRIVERS_DIR)Simulator/Focuser/focuserdriver_sim.cpp		\
										$(DRIVERS_DIR)Simulator/Focuser/focuserdriver_sim.h 		\
										$(SRC_DIR)focuserdriver.h	 		\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)Simulator/Focuser/focuserdriver_sim.cpp -o$(OBJECT_DIR)focuserdriver_sim.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)focuserdriver_ZWO.o :		$(DRIVERS_DIR)ZWO/Focuser/focuserdriver_ZWO.cpp		\
										$(DRIVERS_DIR)ZWO/Focuser/focuserdriver_ZWO.h 		\
										$(SRC_DIR)focuserdriver.h	 		\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)ZWO/Focuser/focuserdriver_ZWO.cpp -o$(OBJECT_DIR)focuserdriver_ZWO.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)rotatordriver.o :			$(SRC_DIR)rotatordriver.cpp			\
										$(SRC_DIR)rotatordriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)rotatordriver.cpp -o$(OBJECT_DIR)rotatordriver.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)rotatordriver_nc.o :		$(DRIVERS_DIR)MoonLite/Rotator/rotatordriver_nc.cpp		\
										$(DRIVERS_DIR)MoonLite/Rotator/rotatordriver_nc.h	 	\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)MoonLite/Rotator/rotatordriver_nc.cpp -o$(OBJECT_DIR)rotatordriver_nc.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)rotatordriver_sim.o :		$(DRIVERS_DIR)Simulator/Rotator/rotatordriver_sim.cpp		\
										$(DRIVERS_DIR)Simulator/Rotator/rotatordriver_sim.h	 	\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)Simulator/Rotator/rotatordriver_sim.cpp -o$(OBJECT_DIR)rotatordriver_sim.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)slittracker.o :		$(SRC_DIR)slittracker.cpp				\
										$(SRC_DIR)slittracker.h	 			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)slittracker.cpp -o$(OBJECT_DIR)slittracker.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)telescopedriver.o :		$(SRC_DIR)telescopedriver.cpp		\
										$(SRC_DIR)telescopedriver.h			\
										$(SRC_DIR)domedriver.h				\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)telescopedriver.cpp -o$(OBJECT_DIR)telescopedriver.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)telescopedriver_comm.o :	$(SRC_DIR)telescopedriver_comm.cpp	\
										$(SRC_DIR)telescopedriver_comm.h	\
										$(SRC_DIR)telescopedriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)telescopedriver_comm.cpp -o$(OBJECT_DIR)telescopedriver_comm.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)telescopedriver_ExpSci.o :	$(DRIVERS_DIR)ExpSci/Telescope/telescopedriver_ExpSci.cpp	\
										$(DRIVERS_DIR)ExpSci/Telescope/telescopedriver_ExpSci.h		\
										$(SRC_DIR)telescopedriver.h				\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)ExpSci/Telescope/telescopedriver_ExpSci.cpp -o$(OBJECT_DIR)telescopedriver_ExpSci.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)telescopedriver_lx200.o :	$(DRIVERS_DIR)LX200/Telescope/telescopedriver_lx200.cpp	\
										$(DRIVERS_DIR)LX200/Telescope/telescopedriver_lx200.h	\
										$(SRC_DIR)telescopedriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)LX200/Telescope/telescopedriver_lx200.cpp -o$(OBJECT_DIR)telescopedriver_lx200.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)telescopedriver_Rigel.o :	$(DRIVERS_DIR)Rigel/Telescope/telescopedriver_Rigel.cpp	\
										$(DRIVERS_DIR)Rigel/Telescope/telescopedriver_Rigel.h	\
										$(SRC_DIR)telescopedriver_comm.h	\
										$(SRC_DIR)telescopedriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)Rigel/Telescope/telescopedriver_Rigel.cpp -o$(OBJECT_DIR)telescopedriver_Rigel.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)telescopedriver_servo.o :	$(DRIVERS_DIR)Servo/Telescope/telescopedriver_servo.cpp	\
										$(DRIVERS_DIR)Servo/Telescope/telescopedriver_servo.h	\
										$(SRC_DIR)telescopedriver_comm.h	\
										$(SRC_DIR)telescopedriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)Servo/Telescope/telescopedriver_servo.cpp -o$(OBJECT_DIR)telescopedriver_servo.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)telescopedriver_sim.o :	$(DRIVERS_DIR)Simulator/Telescope/telescopedriver_sim.cpp	\
										$(DRIVERS_DIR)Simulator/Telescope/telescopedriver_sim.h	\
										$(SRC_DIR)telescopedriver.h			\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(DRIVERS_DIR)Simulator/Telescope/telescopedriver_sim.cpp -o$(OBJECT_DIR)telescopedriver_sim.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)telescopedriver_skywatch.o :	$(DRIVERS_DIR)SkyWatcher/Telescope/telescopedriver_skywatch.cpp	\
											$(DRIVERS_DIR)SkyWatcher/Telescope/telescopedriver_skywatch.h	\
											$(SRC_DIR)telescopedriver.h				\
											$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)				$(DRIVERS_DIR)SkyWatcher/Telescope/telescopedriver_skywatch.cpp -o$(OBJECT_DIR)telescopedriver_skywatch.o

$(OBJECT_DIR)telescopedriver_iOptron.o :	$(DRIVERS_DIR)iOptron/Telescope/telescopedriver_iOptron.cpp	\
											$(DRIVERS_DIR)iOptron/Telescope/telescopedriver_iOptron.h	\
											$(SRC_DIR)telescopedriver.h				\
											$(SRC_DIR)telescopedriver_comm.h		\
											$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)				$(DRIVERS_DIR)iOptron/Telescope/telescopedriver_iOptron.cpp -o$(OBJECT_DIR)telescopedriver_iOptron.o



#-------------------------------------------------------------------------------------
$(OBJECT_DIR)managementdriver.o :		$(SRC_DIR)managementdriver.cpp		\
										$(SRC_DIR)managementdriver.h 		\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)managementdriver.cpp -o$(OBJECT_DIR)managementdriver.o
#-------------------------------------------------------------------------------------
$(OBJECT_DIR)switchdriver.o :			$(SRC_DIR)switchdriver.cpp			\
										$(SRC_DIR)switchdriver.h		 	\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)switchdriver.cpp -o$(OBJECT_DIR)switchdriver.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)switchdriver_rpi.o :		$(DRIVERS_DIR)RaspberryPi/Switch/switchdriver_rpi.cpp		\
										$(DRIVERS_DIR)RaspberryPi/Dome/raspberrypi_relaylib.h	\
										$(DRIVERS_DIR)RaspberryPi/Switch/switchdriver_rpi.h		\
										$(SRC_DIR)switchdriver.h		 	\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES) $(DRIVERS_DIR)RaspberryPi/Switch/switchdriver_rpi.cpp -o$(OBJECT_DIR)switchdriver_rpi.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)switchdriver_sim.o :		$(SRC_DIR)switchdriver_sim.cpp		\
										$(SRC_DIR)switchdriver_sim.h		\
										$(SRC_DIR)switchdriver.h		 	\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)switchdriver_sim.cpp -o$(OBJECT_DIR)switchdriver_sim.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)switchdriver_stepper.o :	$(SRC_DIR)switchdriver_stepper.cpp	\
										$(SRC_DIR)switchdriver_stepper.h	\
										$(SRC_DIR)switchdriver.h		 	\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)switchdriver_stepper.cpp -o$(OBJECT_DIR)switchdriver_stepper.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)obsconditionsdriver.o :	$(SRC_DIR)obsconditionsdriver.cpp	\
										$(SRC_DIR)obsconditionsdriver.h	 	\
										$(SRC_DIR)alpacadriver.h			\
										$(SRC_DIR)alpaca_defs.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)obsconditionsdriver.cpp -o$(OBJECT_DIR)obsconditionsdriver.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)obsconditionsdriver_rpi.o :	$(DRIVERS_DIR)RaspberryPi/ObservingConditions/obsconditionsdriver_rpi.cpp 	\
											$(SRC_DIR)obsconditionsdriver.h			\
											$(SRC_DIR)alpacadriver.h				\
											$(SRC_DIR)alpaca_defs.h
	$(COMPILEPLUS) $(INCLUDES) $(DRIVERS_DIR)RaspberryPi/ObservingConditions/obsconditionsdriver_rpi.cpp -o$(OBJECT_DIR)obsconditionsdriver_rpi.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)obsconditionsdriver_sim.o :	$(SRC_DIR)obsconditionsdriver_sim.cpp 	\
											$(SRC_DIR)obsconditionsdriver_sim.h		\
											$(SRC_DIR)obsconditionsdriver.h			\
											$(SRC_DIR)alpacadriver.h				\
											$(SRC_DIR)alpaca_defs.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)obsconditionsdriver_sim.cpp -o$(OBJECT_DIR)obsconditionsdriver_sim.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)calibrationdriver.o :			$(SRC_DIR)calibrationdriver.cpp 	\
											$(SRC_DIR)calibrationdriver.h		\
											$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)calibrationdriver.cpp -o$(OBJECT_DIR)calibrationdriver.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)calibrationdriver_rpi.o :		$(DRIVERS_DIR)RaspberryPi/Calibration/calibrationdriver_rpi.cpp \
											$(DRIVERS_DIR)RaspberryPi/Calibration/calibrationdriver_rpi.h	\
											$(SRC_DIR)calibrationdriver.h		\
											$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES) $(DRIVERS_DIR)RaspberryPi/Calibration/calibrationdriver_rpi.cpp -o$(OBJECT_DIR)calibrationdriver_rpi.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)calibration_sim.o :			$(SRC_DIR)calibration_sim.cpp	\
											$(SRC_DIR)calibration_sim.h		\
											$(SRC_DIR)calibrationdriver.h	\
											$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)calibration_sim.cpp -o$(OBJECT_DIR)calibration_sim.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)calibration_Alnitak.o :		$(DRIVERS_DIR)RaspberryPi/Calibration/calibration_Alnitak.cpp 	\
											$(DRIVERS_DIR)RaspberryPi/Calibration/calibration_Alnitak.h		\
											$(SRC_DIR)calibrationdriver.h		\
											$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES) $(DRIVERS_DIR)RaspberryPi/Calibration/calibration_Alnitak.cpp -o$(OBJECT_DIR)calibration_Alnitak.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)usbmanager.o :					$(SRC_DIR)usbmanager.cpp 			\
											$(SRC_DIR)usbmanager.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)usbmanager.cpp -o$(OBJECT_DIR)usbmanager.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)discoverythread.o :		$(SRC_DIR)discoverythread.c 		\
										$(SRC_DIR)discoverythread.h 		\
										$(SRC_DIR)alpacadriver.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)discoverythread.c -o$(OBJECT_DIR)discoverythread.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)HostNames.o :				$(SRC_DIR)HostNames.c 	\
										$(SRC_DIR)HostNames.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)HostNames.c -o$(OBJECT_DIR)HostNames.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)sendrequest_lib.o :		$(SRC_DIR)sendrequest_lib.c 	\
										$(SRC_DIR)sendrequest_lib.h 	\
										$(MLS_LIB_DIR)json_parse.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)sendrequest_lib.c -o$(OBJECT_DIR)sendrequest_lib.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)observatory_settings.o :	$(SRC_DIR)observatory_settings.c 	\
										$(SRC_DIR)observatory_settings.h
	$(COMPILEPLUS) $(INCLUDES)			$(SRC_DIR)observatory_settings.c -o$(OBJECT_DIR)observatory_settings.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)serialport.o :				$(SRC_DIR)serialport.c 	\
										$(SRC_DIR)serialport.h
	$(COMPILE) $(INCLUDES)				$(SRC_DIR)serialport.c -o$(OBJECT_DIR)serialport.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)sidereal.o :				$(SRC_DIR)sidereal.c 			\
										$(SRC_DIR)sidereal.h
	$(COMPILE) $(INCLUDES) $(SRC_DIR)sidereal.c -o$(OBJECT_DIR)sidereal.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)cpu_stats.o :				$(SRC_DIR)cpu_stats.c 			\
										$(SRC_DIR)cpu_stats.h
	$(COMPILE) $(INCLUDES) $(SRC_DIR)cpu_stats.c -o$(OBJECT_DIR)cpu_stats.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)helper_functions.o :		$(SRC_DIR)helper_functions.c 			\
										$(SRC_DIR)helper_functions.h
	$(COMPILE) $(INCLUDES) $(SRC_DIR)helper_functions.c -o$(OBJECT_DIR)helper_functions.o



######################################################################################
# ATIK objects
$(OBJECT_DIR)camera_atik.o : $(SRC_DIR)camera_atik.c $(SRC_DIR)camera_atik.h
	$(COMPILE) $(INCLUDES) $(SRC_DIR)camera_atik.c -o$(OBJECT_DIR)camera_atik.o



######################################################################################
#	CLIENT_OBJECTS
$(OBJECT_DIR)json_parse.o : $(MLS_LIB_DIR)json_parse.c $(MLS_LIB_DIR)json_parse.h
	$(COMPILE) $(INCLUDES) $(MLS_LIB_DIR)json_parse.c -o$(OBJECT_DIR)json_parse.o

$(OBJECT_DIR)discoveryclient.o : $(SRC_DISCOVERY)discoveryclient.c $(SRC_DISCOVERY)discoveryclient.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DISCOVERY)discoveryclient.c -o$(OBJECT_DIR)discoveryclient.o




######################################################################################
$(OBJECT_DIR)mandelbrot.o : $(SRC_DIR)mandelbrot.c
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)mandelbrot.c -o$(OBJECT_DIR)mandelbrot.o



######################################################################################
$(OBJECT_DIR)controller.o : $(SRC_DIR)controller.cpp $(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller.cpp -o$(OBJECT_DIR)controller.o



#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controllerClient.o : 		$(SRC_DIR)controllerClient.cpp		\
										$(SRC_DIR)controllerClient.h		\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controllerClient.cpp -o$(OBJECT_DIR)controllerClient.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controllerServer.o : 		$(SRC_DIR)controllerServer.cpp		\
										$(SRC_DIR)controllerServer.h		\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controllerServer.cpp -o$(OBJECT_DIR)controllerServer.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controllerAlpaca.o : 		$(SRC_DIR)controllerAlpaca.cpp		\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controllerAlpaca.cpp -o$(OBJECT_DIR)controllerAlpaca.o



#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_filterwheel.o : $(SRC_DIR)controller_filterwheel.cpp	\
										$(SRC_DIR)controller_fw_common.cpp		\
										$(SRC_DIR)controller_filterwheel.h		\
										$(SRC_DIR)controller.h					\
										$(SRC_DIR)windowtab_about.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_filterwheel.cpp -o$(OBJECT_DIR)controller_filterwheel.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_focus.o : 		$(SRC_DIR)controller_focus.cpp		\
										$(SRC_DIR)controller_focus.h		\
										$(SRC_DIR)controller.h				\
										$(SRC_DIR)focuser_AlpacaCmds.cpp	\
										$(SRC_DIR)windowtab_auxmotor.h		\
										$(SRC_DIR)windowtab_config.h		\
										$(SRC_DIR)windowtab_ml_single.h		\
										$(SRC_DIR)windowtab_graphs.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_focus.cpp -o$(OBJECT_DIR)controller_focus.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_focus_generic.o : 	$(SRC_DIR)controller_focus_generic.cpp	\
											$(SRC_DIR)controller_focus_generic.h	\
											$(SRC_DIR)controller_focus.h			\
											$(SRC_DIR)controller.h					\
											$(SRC_DIR)windowtab_ml_single.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_focus_generic.cpp -o$(OBJECT_DIR)controller_focus_generic.o



#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_focus_ml_nc.o : $(SRC_DIR)controller_focus_ml_nc.cpp	\
										$(SRC_DIR)controller_focus_ml_nc.h		\
										$(SRC_DIR)controller_focus.h			\
										$(SRC_DIR)windowtab_about.h				\
										$(SRC_DIR)windowtab_nitecrawler.h		\
										$(SRC_DIR)windowtab_graphs.h			\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_focus_ml_nc.cpp -o$(OBJECT_DIR)controller_focus_ml_nc.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_focus_ml_hr.o : $(SRC_DIR)controller_focus_ml_hr.cpp	\
										$(SRC_DIR)controller_focus_ml_hr.h		\
										$(SRC_DIR)controller_focus.h			\
										$(SRC_DIR)windowtab_about.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_focus_ml_hr.cpp -o$(OBJECT_DIR)controller_focus_ml_hr.o



#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_obsconditions.o : 	$(SRC_DIR)controller_obsconditions.cpp		\
											$(SRC_DIR)controller_obsconditions.h		\
											$(SRC_DIR)controller.h						\
											$(SRC_DIR)alpaca_defs.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_obsconditions.cpp -o$(OBJECT_DIR)controller_obsconditions.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_rotator.o : 		$(SRC_DIR)controller_rotator.cpp		\
											$(SRC_DIR)controller_rotator.h			\
											$(SRC_DIR)controller.h					\
											$(SRC_DIR)alpaca_defs.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_rotator.cpp -o$(OBJECT_DIR)controller_rotator.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_rotator.o : 			$(SRC_DIR)windowtab_rotator.cpp			\
											$(SRC_DIR)windowtab_rotator.h			\
											$(SRC_DIR)windowtab.h					\
											$(SRC_DIR)alpaca_defs.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_rotator.cpp -o$(OBJECT_DIR)windowtab_rotator.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_switch.o : 		$(SRC_DIR)controller_switch.cpp		\
										$(SRC_DIR)controller_switch.h		\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_switch.cpp -o$(OBJECT_DIR)controller_switch.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_camera.o : 		$(SRC_DIR)controller_camera.cpp		\
										$(SRC_DIR)controller_camera.h		\
										$(SRC_DIR)controller_fw_common.cpp	\
										$(SRC_DIR)windowtab_camera.h		\
										$(SRC_DIR)windowtab_about.h			\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_camera.cpp -o$(OBJECT_DIR)controller_camera.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_cam_normal.o : 	$(SRC_DIR)controller_cam_normal.cpp	\
										$(SRC_DIR)controller_cam_normal.h	\
										$(SRC_DIR)controller_fw_common.cpp	\
										$(SRC_DIR)windowtab_camera.h		\
										$(SRC_DIR)windowtab_about.h			\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_cam_normal.cpp -o$(OBJECT_DIR)controller_cam_normal.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controllerImageArray.o : 	$(SRC_DIR)controllerImageArray.cpp	\
										$(SRC_DIR)controller_fw_common.cpp	\
										$(SRC_DIR)controller_camera.h		\
										$(SRC_DIR)windowtab_camera.h		\
										$(SRC_DIR)windowtab_about.h			\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controllerImageArray.cpp -o$(OBJECT_DIR)controllerImageArray.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_covercalib.o : 	$(SRC_DIR)controller_covercalib.cpp	\
										$(SRC_DIR)controller_covercalib.h	\
										$(SRC_DIR)windowtab_covercalib.h	\
										$(SRC_DIR)windowtab_about.h			\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_covercalib.cpp -o$(OBJECT_DIR)controller_covercalib.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_dome.o : 		$(SRC_DIR)controller_dome.cpp		\
										$(SRC_DIR)controller_dome.h			\
										$(SRC_DIR)windowtab_dome.h			\
										$(SRC_DIR)windowtab_about.h			\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_dome.cpp -o$(OBJECT_DIR)controller_dome.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_multicam.o : 	$(SRC_DIR)controller_multicam.cpp	\
										$(SRC_DIR)controller_multicam.h		\
										$(SRC_DIR)windowtab_about.h			\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_multicam.cpp -o$(OBJECT_DIR)controller_multicam.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_startup.o : 	$(SRC_DIR)controller_startup.cpp	\
										$(SRC_DIR)controller_startup.h		\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_startup.cpp -o$(OBJECT_DIR)controller_startup.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_startup.o : 		$(SRC_DIR)windowtab_startup.cpp		\
										$(SRC_DIR)windowtab_startup.h		\
										$(SRC_DIR)windowtab.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_startup.cpp -o$(OBJECT_DIR)windowtab_startup.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_fitsheader.o : 	$(SRC_DIR)windowtab_fitsheader.cpp		\
										$(SRC_DIR)windowtab_fitsheader.h		\
										$(SRC_DIR)windowtab.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_fitsheader.cpp -o$(OBJECT_DIR)windowtab_fitsheader.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_slit.o : 		$(SRC_DIR)controller_slit.cpp		\
										$(SRC_DIR)controller_slit.h			\
										$(SRC_DIR)windowtab_slit.h			\
										$(SRC_DIR)windowtab_about.h			\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_slit.cpp -o$(OBJECT_DIR)controller_slit.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_dome_common.o : $(SRC_DIR)controller_dome_common.cpp	\
										$(SRC_DIR)controller_dome.h				\
										$(SRC_DIR)windowtab_dome.h				\
										$(SRC_DIR)windowtab_about.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_dome_common.cpp -o$(OBJECT_DIR)controller_dome_common.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_telescope.o :	$(SRC_DIR)controller_telescope.cpp		\
										$(SRC_DIR)controller_tscope_common.cpp	\
										$(SRC_DIR)controller_telescope.h		\
										$(SRC_DIR)windowtab_telescope.h			\
										$(SRC_DIR)windowtab_about.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_telescope.cpp -o$(OBJECT_DIR)controller_telescope.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_alpacalist.o :	$(SRC_DIR)windowtab_alpacalist.cpp		\
										$(SRC_DIR)windowtab_alpacalist.h		\
										$(SRC_DIR)windowtab.h					\
										$(SRC_DIR)discoverythread.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_alpacalist.cpp -o$(OBJECT_DIR)windowtab_alpacalist.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_iplist.o : 		$(SRC_DIR)windowtab_iplist.cpp		\
										$(SRC_DIR)windowtab_iplist.h		\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)discoverythread.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_iplist.cpp -o$(OBJECT_DIR)windowtab_iplist.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_sw_versions.o : 	$(SRC_DIR)windowtab_sw_versions.cpp		\
										$(SRC_DIR)windowtab_sw_versions.h		\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)discoverythread.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_sw_versions.cpp -o$(OBJECT_DIR)windowtab_sw_versions.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_deviceselect.o : $(SRC_DIR)windowtab_deviceselect.cpp	\
										$(SRC_DIR)windowtab_deviceselect.h		\
										$(SRC_DIR)windowtab.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_deviceselect.cpp -o$(OBJECT_DIR)windowtab_deviceselect.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_image.o : 		$(SRC_DIR)controller_image.cpp		\
										$(SRC_DIR)controller_image.h		\
										$(SRC_DIR)windowtab_image.h			\
										$(SRC_DIR)windowtab_about.h			\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_image.cpp -o$(OBJECT_DIR)controller_image.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_image.o : 		$(SRC_DIR)windowtab_image.cpp		\
										$(SRC_DIR)windowtab_image.h			\
										$(SRC_DIR)controller_image.h		\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_image.cpp -o$(OBJECT_DIR)windowtab_image.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_imageinfo.o : 	$(SRC_DIR)windowtab_imageinfo.cpp	\
										$(SRC_DIR)windowtab_imageinfo.h		\
										$(SRC_DIR)controller_image.h		\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_imageinfo.cpp -o$(OBJECT_DIR)windowtab_imageinfo.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_usb.o : 		$(SRC_DIR)controller_usb.cpp		\
										$(SRC_DIR)controller_usb.h			\
										$(SRC_DIR)windowtab_usb.h			\
										$(SRC_DIR)windowtab_about.h			\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_usb.cpp -o$(OBJECT_DIR)controller_usb.o




#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_preview.o : 	$(SRC_DIR)controller_preview.cpp	\
										$(SRC_DIR)controller_preview.h		\
										$(SRC_DIR)windowtab_about.h			\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_preview.cpp -o$(OBJECT_DIR)controller_preview.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)NASA_moonphase.o : 	$(SRC_DIR)NASA_moonphase.cpp		\
										$(SRC_DIR)NASA_moonphase.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)NASA_moonphase.cpp -o$(OBJECT_DIR)NASA_moonphase.o




#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab.o : 				$(SRC_DIR)windowtab.cpp				\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab.cpp -o$(OBJECT_DIR)windowtab.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_camsettings.o : 	$(SRC_DIR)windowtab_camsettings.cpp	\
										$(SRC_DIR)windowtab_camsettings.h	\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller_camera.h		\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_camsettings.cpp -o$(OBJECT_DIR)windowtab_camsettings.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_camcooler.o : 	$(SRC_DIR)windowtab_camcooler.cpp	\
										$(SRC_DIR)windowtab_camcooler.h		\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller_camera.h		\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_camcooler.cpp -o$(OBJECT_DIR)windowtab_camcooler.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_camvideo.o : 	$(SRC_DIR)windowtab_camvideo.cpp	\
										$(SRC_DIR)windowtab_camvideo.h		\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_camvideo.cpp -o$(OBJECT_DIR)windowtab_camvideo.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_filelist.o : 	$(SRC_DIR)windowtab_filelist.cpp	\
										$(SRC_DIR)controller_camera.h		\
										$(SRC_DIR)windowtab_filelist.h		\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_filelist.cpp -o$(OBJECT_DIR)windowtab_filelist.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_filterwheel.o : 	$(SRC_DIR)windowtab_filterwheel.cpp	\
										$(SRC_DIR)windowtab_filterwheel.h	\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_filterwheel.cpp -o$(OBJECT_DIR)windowtab_filterwheel.o



#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_ml_single.o : 	$(SRC_DIR)windowtab_ml_single.cpp	\
										$(SRC_DIR)windowtab_ml_single.h		\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_ml_single.cpp -o$(OBJECT_DIR)windowtab_ml_single.o

$(OBJECT_DIR)windowtab_nitecrawler.o : 	$(SRC_DIR)windowtab_nitecrawler.cpp	\
										$(SRC_DIR)windowtab_nitecrawler.h	\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_nitecrawler.cpp -o$(OBJECT_DIR)windowtab_nitecrawler.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_about.o : 		$(SRC_DIR)windowtab_about.cpp		\
										$(SRC_DIR)windowtab_about.h			\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_about.cpp -o$(OBJECT_DIR)windowtab_about.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_drvrInfo.o : 	$(SRC_DIR)windowtab_drvrInfo.cpp		\
										$(SRC_DIR)windowtab_drvrInfo.h			\
										$(SRC_DIR)windowtab.h					\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_drvrInfo.cpp -o$(OBJECT_DIR)windowtab_drvrInfo.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_capabilities.o : $(SRC_DIR)windowtab_capabilities.cpp	\
										$(SRC_DIR)windowtab_capabilities.h		\
										$(SRC_DIR)windowtab.h					\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_capabilities.cpp -o$(OBJECT_DIR)windowtab_capabilities.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_DeviceState.o :	$(SRC_DIR)windowtab_DeviceState.cpp		\
										$(SRC_DIR)windowtab_DeviceState.h		\
										$(SRC_DIR)windowtab.h					\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_DeviceState.cpp -o$(OBJECT_DIR)windowtab_DeviceState.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_moon.o : 		$(SRC_DIR)windowtab_moon.cpp		\
										$(SRC_DIR)windowtab_moon.h			\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_moon.cpp -o$(OBJECT_DIR)windowtab_moon.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_MoonPhase.o : 	$(SRC_DIR)windowtab_MoonPhase.cpp	\
										$(SRC_DIR)windowtab_MoonPhase.h		\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_MoonPhase.cpp -o$(OBJECT_DIR)windowtab_MoonPhase.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_obscond.o : 		$(SRC_DIR)windowtab_obscond.cpp		\
										$(SRC_DIR)windowtab_obscond.h		\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)alpaca_defs.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_obscond.cpp -o$(OBJECT_DIR)windowtab_obscond.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_multicam.o : 	$(SRC_DIR)windowtab_multicam.cpp	\
										$(SRC_DIR)windowtab_multicam.h		\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)alpaca_defs.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_multicam.cpp -o$(OBJECT_DIR)windowtab_multicam.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)opencv_utils.o : 			$(SRC_DIR)opencv_utils.cpp		\
										$(SRC_DIR)opencv_utils.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)opencv_utils.cpp -o$(OBJECT_DIR)opencv_utils.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_preview.o : 		$(SRC_DIR)windowtab_preview.cpp		\
										$(SRC_DIR)windowtab_preview.h		\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_preview.cpp -o$(OBJECT_DIR)windowtab_preview.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_auxmotor.o : 	$(SRC_DIR)windowtab_auxmotor.cpp	\
										$(SRC_DIR)windowtab_auxmotor.h		\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_auxmotor.cpp -o$(OBJECT_DIR)windowtab_auxmotor.o



#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_camera.o : 		$(SRC_DIR)windowtab_camera.cpp		\
										$(SRC_DIR)windowtab_camera.h		\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_camera.cpp -o$(OBJECT_DIR)windowtab_camera.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_config.o : 		$(SRC_DIR)windowtab_config.cpp		\
										$(SRC_DIR)windowtab_config.h		\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_config.cpp -o$(OBJECT_DIR)windowtab_config.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_covercalib.o : 	$(SRC_DIR)windowtab_covercalib.cpp	\
										$(SRC_DIR)windowtab_covercalib.h	\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_covercalib.cpp -o$(OBJECT_DIR)windowtab_covercalib.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_dome.o : 		$(SRC_DIR)windowtab_dome.cpp		\
										$(SRC_DIR)windowtab_dome.h			\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_dome.cpp -o$(OBJECT_DIR)windowtab_dome.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_mount.o : 		$(SRC_DIR)windowtab_mount.cpp		\
										$(SRC_DIR)windowtab_mount.h			\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_mount.cpp -o$(OBJECT_DIR)windowtab_mount.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_graphs.o : 		$(SRC_DIR)windowtab_graphs.cpp		\
										$(SRC_DIR)windowtab_graphs.h		\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_graphs.cpp -o$(OBJECT_DIR)windowtab_graphs.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_slit.o : 		$(SRC_DIR)windowtab_slit.cpp		\
										$(SRC_DIR)windowtab_slit.h			\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_slit.cpp -o$(OBJECT_DIR)windowtab_slit.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_slitdome.o : 	$(SRC_DIR)windowtab_slitdome.cpp		\
										$(SRC_DIR)windowtab_slitdome.h			\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_slitdome.cpp -o$(OBJECT_DIR)windowtab_slitdome.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_slitgraph.o : 	$(SRC_DIR)windowtab_slitgraph.cpp	\
										$(SRC_DIR)windowtab_slitgraph.h		\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_slitgraph.cpp -o$(OBJECT_DIR)windowtab_slitgraph.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_switch.o : 		$(SRC_DIR)windowtab_switch.cpp		\
										$(SRC_DIR)windowtab_switch.h		\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_switch.cpp -o$(OBJECT_DIR)windowtab_switch.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_usb.o : 			$(SRC_DIR)windowtab_usb.cpp			\
										$(SRC_DIR)windowtab_usb.h			\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_usb.cpp -o$(OBJECT_DIR)windowtab_usb.o





#-------------------------------------------------------------------------------------
$(OBJECT_DIR)nitecrawler_image.o : 		$(SRC_DIR)nitecrawler_image.c		\
										$(SRC_DIR)nitecrawler_image.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)nitecrawler_image.c -o$(OBJECT_DIR)nitecrawler_image.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)moonlite_com.o : 			$(SRC_DIR)moonlite_com.c			\
										$(SRC_DIR)moonlite_com.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)moonlite_com.c -o$(OBJECT_DIR)moonlite_com.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_main.o : 		$(SRC_DIR)controller_main.cpp		\
										$(SRC_DIR)controller_focus.h		\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_main.cpp -o$(OBJECT_DIR)controller_main.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)fits_opencv.o :			$(SRC_DIR)fits_opencv.c			\
										$(SRC_DIR)fits_opencv.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)fits_opencv.c -o$(OBJECT_DIR)fits_opencv.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)fitsview.o :				$(SRC_DIR)fitsview.c
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)fitsview.c -o$(OBJECT_DIR)fitsview.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)dumpfits.o :				$(SRC_DIR)dumpfits.c
	$(COMPILE) $(INCLUDES) $(SRC_DIR)dumpfits.c -o$(OBJECT_DIR)dumpfits.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)PDS_ReadNASAfiles.o :		$(SRC_PDS)PDS_ReadNASAfiles.c			\
										$(SRC_PDS)PDS_ReadNASAfiles.h
	$(COMPILE) $(INCLUDES) $(SRC_PDS)PDS_ReadNASAfiles.c -o$(OBJECT_DIR)PDS_ReadNASAfiles.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)PDS_decompress.o :			$(SRC_PDS)PDS_decompress.c			\
										$(SRC_PDS)PDS_decompress.h
	$(COMPILE) $(INCLUDES) $(SRC_PDS)PDS_decompress.c -o$(OBJECT_DIR)PDS_decompress.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)discovery_lib.o :			$(SRC_DIR)discovery_lib.c			\
										$(SRC_DIR)discovery_lib.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)discovery_lib.c -o$(OBJECT_DIR)discovery_lib.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)commoncolor.o :			$(SRC_DIR)commoncolor.c				\
										$(SRC_DIR)commoncolor.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)commoncolor.c -o$(OBJECT_DIR)commoncolor.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)imageprocess_orb.o :		$(SRC_IMGPROC)imageprocess_orb.cpp	\
										$(SRC_IMGPROC)imageprocess_orb.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_IMGPROC)imageprocess_orb.cpp -o$(OBJECT_DIR)imageprocess_orb.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)moonphase.o :				$(SRC_DIR)moonphase.c	\
										$(SRC_DIR)moonphase.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)moonphase.c -o$(OBJECT_DIR)moonphase.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)MoonRise.o :				$(SRC_MOONRISE)MoonRise.cpp	\
										$(SRC_MOONRISE)MoonRise.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_MOONRISE)MoonRise.cpp -I$(SRC_MOONRISE) -o$(OBJECT_DIR)MoonRise.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)julianTime.o :				$(SRC_DIR)julianTime.c	\
										$(SRC_DIR)julianTime.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)julianTime.c -o$(OBJECT_DIR)julianTime.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)raspberrypi_relaylib.o :	$(DRIVERS_DIR)RaspberryPi/Dome/raspberrypi_relaylib.c	\
										$(DRIVERS_DIR)RaspberryPi/Dome/raspberrypi_relaylib.h
	$(COMPILEPLUS) $(INCLUDES) $(DRIVERS_DIR)RaspberryPi/Dome/raspberrypi_relaylib.c -o$(OBJECT_DIR)raspberrypi_relaylib.o




######################################################################################
#-------------------------------------------------------------------------------------
$(OBJECT_DIR)skytravel_main.o :			$(SRC_SKYTRAVEL)skytravel_main.cpp	\
										$(SRC_SKYTRAVEL)windowtab_skytravel.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)skytravel_main.cpp -o$(OBJECT_DIR)skytravel_main.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_solarsystem.o :	$(SRC_SKYTRAVEL)windowtab_solarsystem.cpp	\
										$(SRC_SKYTRAVEL)windowtab_solarsystem.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)windowtab_solarsystem.cpp -o$(OBJECT_DIR)windowtab_solarsystem.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)KeplerEquations.o :		$(SRC_SKYTRAVEL)KeplerEquations.cpp	\
										$(SRC_SKYTRAVEL)KeplerEquations.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)KeplerEquations.cpp -o$(OBJECT_DIR)KeplerEquations.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_telescope.o :	$(SRC_DIR)windowtab_telescope.cpp	\
										$(SRC_DIR)windowtab_telescope.h		\
										$(SRC_DIR)windowtab.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_telescope.cpp -o$(OBJECT_DIR)windowtab_telescope.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_teleSettings.o :	$(SRC_DIR)windowtab_teleSettings.cpp	\
										$(SRC_DIR)windowtab_teleSettings.h		\
										$(SRC_DIR)windowtab.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_teleSettings.cpp -o$(OBJECT_DIR)windowtab_teleSettings.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_skytravel.o :	$(SRC_SKYTRAVEL)controller_skytravel.cpp	\
										$(SRC_DIR)controller_tscope_common.cpp		\
										$(SRC_DIR)controller_dome_common.cpp		\
										$(SRC_SKYTRAVEL)controller_skytravel.h		\
										$(SRC_SKYTRAVEL)SkyStruc.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)controller_skytravel.cpp -o$(OBJECT_DIR)controller_skytravel.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_remoteview.o :	$(SRC_DIR)controller_remoteview.cpp		\
										$(SRC_DIR)controller_remoteview.cpp		\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_remoteview.cpp -o$(OBJECT_DIR)controller_remoteview.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_time.o : 			$(SRC_SKYTRAVEL)windowtab_time.cpp			\
											$(SRC_SKYTRAVEL)windowtab_time.h			\
											$(SRC_DIR)windowtab.h					\
											$(SRC_DIR)alpaca_defs.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)windowtab_time.cpp -o$(OBJECT_DIR)windowtab_time.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_fov.o : 			$(SRC_SKYTRAVEL)windowtab_fov.cpp			\
										$(SRC_SKYTRAVEL)windowtab_fov.h				\
										$(SRC_SKYTRAVEL)cameraFOV.h					\
										$(SRC_DIR)windowtab.h						\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)windowtab_fov.cpp -o$(OBJECT_DIR)windowtab_fov.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)StarData.o :				$(SRC_SKYTRAVEL)StarData.c	\
										$(SRC_SKYTRAVEL)StarData.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)StarData.c -o$(OBJECT_DIR)StarData.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)MessierData.o :			$(SRC_SKYTRAVEL)MessierData.c	\
										$(SRC_SKYTRAVEL)StarData.h		\
										$(SRC_SKYTRAVEL)SkyStruc.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)MessierData.c -o$(OBJECT_DIR)MessierData.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)SAO_stardata.o :			$(SRC_SKYTRAVEL)SAO_stardata.c	\
										$(SRC_SKYTRAVEL)SAO_stardata.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)SAO_stardata.c -o$(OBJECT_DIR)SAO_stardata.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)aavso_data.o :				$(SRC_SKYTRAVEL)aavso_data.c	\
										$(SRC_SKYTRAVEL)aavso_data.h	\
										$(SRC_SKYTRAVEL)SkyStruc.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)aavso_data.c -o$(OBJECT_DIR)aavso_data.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)polaralign.o :				$(SRC_SKYTRAVEL)polaralign.cpp	\
										$(SRC_SKYTRAVEL)polaralign.h	\
										$(SRC_SKYTRAVEL)SkyStruc.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)polaralign.cpp -o$(OBJECT_DIR)polaralign.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_skytravel.o :	$(SRC_SKYTRAVEL)windowtab_skytravel.cpp	\
										$(SRC_SKYTRAVEL)windowtab_skytravel.h	\
										$(SRC_DIR)windowtab.h					\
										$(SRC_SKYTRAVEL)AsteroidData.h			\
										$(SRC_SKYTRAVEL)aavso_data.h			\
										$(SRC_SKYTRAVEL)StarData.h				\
										$(SRC_SKYTRAVEL)SkyStruc.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)windowtab_skytravel.cpp -o$(OBJECT_DIR)windowtab_skytravel.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_cpustats.o :		$(SRC_SKYTRAVEL)windowtab_cpustats.cpp	\
										$(SRC_SKYTRAVEL)windowtab_cpustats.h	\
										$(SRC_DIR)windowtab.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)windowtab_cpustats.cpp -o$(OBJECT_DIR)windowtab_cpustats.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_STsettings.o :	$(SRC_SKYTRAVEL)windowtab_STsettings.cpp	\
										$(SRC_SKYTRAVEL)windowtab_STsettings.h		\
										$(SRC_DIR)windowtab.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)windowtab_STsettings.cpp -o$(OBJECT_DIR)windowtab_STsettings.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_RemoteData.o :	$(SRC_SKYTRAVEL)windowtab_RemoteData.cpp	\
										$(SRC_SKYTRAVEL)windowtab_RemoteData.h		\
										$(SRC_DIR)windowtab.h						\
										$(SRC_SKYTRAVEL)RemoteImage.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)windowtab_RemoteData.cpp -o$(OBJECT_DIR)windowtab_RemoteData.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)eph.o :					$(SRC_SKYTRAVEL)eph.c	\
										$(SRC_SKYTRAVEL)eph.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)eph.c -o$(OBJECT_DIR)eph.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)SkyTravelTimeRoutines.o :	$(SRC_SKYTRAVEL)SkyTravelTimeRoutines.c	\
										$(SRC_SKYTRAVEL)SkyTravelTimeRoutines.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)SkyTravelTimeRoutines.c -o$(OBJECT_DIR)SkyTravelTimeRoutines.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)NGCcatalog.o :				$(SRC_SKYTRAVEL)NGCcatalog.c	\
										$(SRC_SKYTRAVEL)NGCcatalog.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)NGCcatalog.c -o$(OBJECT_DIR)NGCcatalog.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)OpenNGC.o :				$(SRC_SKYTRAVEL)OpenNGC.c	\
										$(SRC_SKYTRAVEL)OpenNGC.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)OpenNGC.c -o$(OBJECT_DIR)OpenNGC.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)milkyway.o :				$(SRC_SKYTRAVEL)milkyway.cpp	\
										$(SRC_SKYTRAVEL)milkyway.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)milkyway.cpp -o$(OBJECT_DIR)milkyway.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)StarCatalogHelper.o :		$(SRC_SKYTRAVEL)StarCatalogHelper.c	\
										$(SRC_SKYTRAVEL)StarCatalogHelper.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)StarCatalogHelper.c -o$(OBJECT_DIR)StarCatalogHelper.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)YaleStarCatalog.o :		$(SRC_SKYTRAVEL)YaleStarCatalog.c	\
										$(SRC_SKYTRAVEL)YaleStarCatalog.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)YaleStarCatalog.c -o$(OBJECT_DIR)YaleStarCatalog.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)HipparcosCatalog.o :		$(SRC_SKYTRAVEL)HipparcosCatalog.c	\
										$(SRC_SKYTRAVEL)HipparcosCatalog.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)HipparcosCatalog.c -o$(OBJECT_DIR)HipparcosCatalog.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)ConstellationData.o :		$(SRC_SKYTRAVEL)ConstellationData.c	\
										$(SRC_SKYTRAVEL)ConstellationData.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)ConstellationData.c -o$(OBJECT_DIR)ConstellationData.o

#-------------------------------------------------------------------------------------
#$(OBJECT_DIR)GaiaData.o :				$(SRC_SKYTRAVEL)GaiaData.c	\
#										$(SRC_SKYTRAVEL)GaiaData.h
#	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)GaiaData.c -o$(OBJECT_DIR)GaiaData.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)GaiaSQL.o :				$(SRC_SKYTRAVEL)GaiaSQL.cpp	\
										$(SRC_SKYTRAVEL)GaiaSQL.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)GaiaSQL.cpp -o$(OBJECT_DIR)GaiaSQL.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_GaiaRemote.o :	$(SRC_SKYTRAVEL)controller_GaiaRemote.cpp	\
										$(SRC_SKYTRAVEL)controller_GaiaRemote.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)controller_GaiaRemote.cpp -o$(OBJECT_DIR)controller_GaiaRemote.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_GaiaRemote.o :	$(SRC_SKYTRAVEL)windowtab_GaiaRemote.cpp	\
										$(SRC_DIR)windowtab.h						\
										$(SRC_SKYTRAVEL)windowtab_GaiaRemote.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)windowtab_GaiaRemote.cpp -o$(OBJECT_DIR)windowtab_GaiaRemote.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)AsteroidData.o :			$(SRC_SKYTRAVEL)AsteroidData.c	\
										$(SRC_SKYTRAVEL)AsteroidData.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)AsteroidData.c -o$(OBJECT_DIR)AsteroidData.o



#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_starlist.o : 	$(SRC_SKYTRAVEL)controller_starlist.cpp	\
										$(SRC_SKYTRAVEL)controller_starlist.h	\
										$(SRC_DIR)windowtab_about.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)controller_starlist.cpp -o$(OBJECT_DIR)controller_starlist.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_starlist.o : 	$(SRC_SKYTRAVEL)windowtab_starlist.cpp	\
										$(SRC_SKYTRAVEL)windowtab_starlist.h	\
										$(SRC_DIR)windowtab.h					\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)windowtab_starlist.cpp -o$(OBJECT_DIR)windowtab_starlist.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_constList.o :	$(SRC_SKYTRAVEL)windowtab_constList.cpp	\
										$(SRC_SKYTRAVEL)windowtab_constList.h	\
										$(SRC_DIR)windowtab.h					\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)windowtab_constList.cpp -o$(OBJECT_DIR)windowtab_constList.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_constList.o : 	$(SRC_SKYTRAVEL)controller_constList.cpp			\
												$(SRC_SKYTRAVEL)controller_constList.h		\
												$(SRC_DIR)windowtab_about.h					\
												$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)controller_constList.cpp -o$(OBJECT_DIR)controller_constList.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)RemoteImage.o : 			$(SRC_SKYTRAVEL)RemoteImage.cpp	\
										$(SRC_SKYTRAVEL)RemoteImage.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYTRAVEL)RemoteImage.cpp -o$(OBJECT_DIR)RemoteImage.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_alpacaUnit.o : 		$(SRC_DIR)controller_alpacaUnit.cpp		\
											$(SRC_DIR)controller_alpacaUnit.h		\
											$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)controller_alpacaUnit.cpp -o$(OBJECT_DIR)controller_alpacaUnit.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_libraries.o : 		$(SRC_DIR)windowtab_libraries.cpp		\
											$(SRC_DIR)windowtab_libraries.h		\
											$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_libraries.cpp -o$(OBJECT_DIR)windowtab_libraries.o



#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_alpacaUnit.o : 		$(SRC_DIR)windowtab_alpacaUnit.cpp		\
											$(SRC_DIR)windowtab_alpacaUnit.h		\
											$(SRC_DIR)windowtab.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)windowtab_alpacaUnit.cpp -o$(OBJECT_DIR)windowtab_alpacaUnit.o


#-------------------------------------------------------------------------------------
$(OBJECT_DIR)lx200_com.o :				$(SRC_DIR)lx200_com.c	\
										$(SRC_DIR)lx200_com.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)lx200_com.c -o$(OBJECT_DIR)lx200_com.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)linuxerrors.o :			$(SRC_DIR)linuxerrors.c	\
										$(SRC_DIR)linuxerrors.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_DIR)linuxerrors.c -o$(OBJECT_DIR)linuxerrors.o


SRC_SPECIAL			=	./src_special/

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_video.o : 		$(SRC_SPECIAL)windowtab_video.cpp	\
										$(SRC_SPECIAL)windowtab_video.h		\
										$(SRC_DIR)windowtab.h				\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SPECIAL)windowtab_video.cpp -o$(OBJECT_DIR)windowtab_video.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_video.o : 		$(SRC_SPECIAL)controller_video.cpp	\
										$(SRC_SPECIAL)controller_video.h	\
										$(SRC_DIR)windowtab_about.h			\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SPECIAL)controller_video.cpp -o$(OBJECT_DIR)controller_video.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)startextrathread.o : 		$(SRC_SPECIAL)startextrathread.cpp	\
										$(SRC_DIR)alpacadriver_helper.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SPECIAL)startextrathread.cpp -o$(OBJECT_DIR)startextrathread.o

##################################################################################
#		Servo source code
##################################################################################
#-------------------------------------------------------------------------------------
$(OBJECT_DIR)servo_mount_cfg.o : 		$(SRC_SERVO)servo_mount_cfg.c	\
										$(SRC_SERVO)servo_mount_cfg.h	\
										$(SRC_SERVO)servo_std_defs.h
	$(COMPILE) $(INCLUDES) $(SRC_SERVO)servo_mount_cfg.c -o$(OBJECT_DIR)servo_mount_cfg.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)servo_time.o : 			$(SRC_SERVO)servo_time.c	\
										$(SRC_SERVO)servo_time.h	\
										$(SRC_SERVO)servo_std_defs.h
	$(COMPILE) $(INCLUDES) $(SRC_SERVO)servo_time.c -o$(OBJECT_DIR)servo_time.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)servo_mount.o : 			$(SRC_SERVO)servo_mount.c	\
										$(SRC_SERVO)servo_mount.h	\
										$(SRC_SERVO)servo_std_defs.h
	$(COMPILE) $(INCLUDES) $(SRC_SERVO)servo_mount.c -o$(OBJECT_DIR)servo_mount.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)servo_motion.o : 			$(SRC_SERVO)servo_motion.c	\
										$(SRC_SERVO)servo_motion.h	\
										$(SRC_SERVO)servo_std_defs.h
	$(COMPILE) $(INCLUDES) $(SRC_SERVO)servo_motion.c -o$(OBJECT_DIR)servo_motion.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)servo_motion_cfg.o : 		$(SRC_SERVO)servo_motion_cfg.c	\
										$(SRC_SERVO)servo_motion_cfg.h	\
										$(SRC_SERVO)servo_std_defs.h
	$(COMPILE) $(INCLUDES) $(SRC_SERVO)servo_motion_cfg.c -o$(OBJECT_DIR)servo_motion_cfg.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)servo_observ_cfg.o : 		$(SRC_SERVO)servo_observ_cfg.c	\
										$(SRC_SERVO)servo_observ_cfg.h	\
										$(SRC_SERVO)servo_std_defs.h
	$(COMPILE) $(INCLUDES) $(SRC_SERVO)servo_observ_cfg.c -o$(OBJECT_DIR)servo_observ_cfg.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)servo_rc_utils.o : 		$(SRC_SERVO)servo_rc_utils.c	\
										$(SRC_SERVO)servo_rc_utils.h	\
										$(SRC_SERVO)servo_std_defs.h
	$(COMPILE) $(INCLUDES) $(SRC_SERVO)servo_rc_utils.c -o$(OBJECT_DIR)servo_rc_utils.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)servo_mc_core.o : 			$(SRC_SERVO)servo_mc_core.c	\
										$(SRC_SERVO)servo_mc_core.h	\
										$(SRC_SERVO)servo_std_defs.h
	$(COMPILE) $(INCLUDES) $(SRC_SERVO)servo_mc_core.c -o$(OBJECT_DIR)servo_mc_core.o



##################################################################################
#		SkyImage stuff
##################################################################################

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)controller_skyimage.o : 	$(SRC_SKYIMAGE)controller_skyimage.cpp	\
										$(SRC_SKYIMAGE)controller_skyimage.h	\
										$(SRC_DIR)controller.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYIMAGE)controller_skyimage.cpp -o$(OBJECT_DIR)controller_skyimage.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)windowtab_imageList.o : 	$(SRC_SKYIMAGE)windowtab_imageList.cpp	\
										$(SRC_SKYIMAGE)windowtab_imageList.h	\
										$(SRC_DIR)windowtab.h
	$(COMPILEPLUS) $(INCLUDES) $(SRC_SKYIMAGE)windowtab_imageList.cpp -o$(OBJECT_DIR)windowtab_imageList.o



##################################################################################
#		IMU source code
##################################################################################
#-------------------------------------------------------------------------------------
$(OBJECT_DIR)imu_lib.o : 				$(SRC_IMU)imu_lib.c			\
										$(SRC_IMU)imu_lib.h			\
										$(SRC_IMU)imu_lib_bno055.h	\
										$(SRC_IMU)getbno055.h
	$(COMPILE) $(INCLUDES) $(SRC_IMU)imu_lib.c -o$(OBJECT_DIR)imu_lib.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)imu_lib_LIS2DH12.o : 		$(SRC_IMU)imu_lib_LIS2DH12.c		\
										$(SRC_IMU)imu_lib_LIS2DH12.h
	$(COMPILE) $(INCLUDES) $(SRC_IMU)imu_lib_LIS2DH12.c -o$(OBJECT_DIR)imu_lib_LIS2DH12.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)imu_lib_bno055.o : 		$(SRC_IMU)imu_lib_bno055.c	\
										$(SRC_IMU)imu_lib_bno055.h	\
										$(SRC_IMU)getbno055.h
	$(COMPILE) $(INCLUDES) $(SRC_IMU)imu_lib_bno055.c -o$(OBJECT_DIR)imu_lib_bno055.o

#-------------------------------------------------------------------------------------
$(OBJECT_DIR)i2c_bno055.o : 			$(SRC_IMU)i2c_bno055.c	\
										$(SRC_IMU)getbno055.h
	$(COMPILE) $(INCLUDES) $(SRC_IMU)i2c_bno055.c -o$(OBJECT_DIR)i2c_bno055.o


