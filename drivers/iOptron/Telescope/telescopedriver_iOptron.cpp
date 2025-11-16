//**************************************************************************
//*	Name:			telescopedriver_iOptron.cpp
//*
//*	Author:			Mark Sproul (C) 2024
//*					Joey Troy (C) 2025
//*
//*	Description:	C++ Driver for Alpaca protocol
//*
//*					This driver implements an Alpaca Telescope
//*					talking to an iOptron mount
//*					via ethernet, USB or serial port
//*					Based on iOptron RS232 Command Language
//*					https://www.ioptron.com/Articles.asp?ID=295
//*****************************************************************************
//*	AlpacaPi is an open source project written in C/C++
//*
//*	Use of this source code for private or individual use is granted
//*	Use of this source code, in whole or in part for commercial purpose requires
//*	written agreement in advance.
//*
//*	You may use or modify this source code in any way you find useful, provided
//*	that you agree that the author(s) have no warranty, obligations or liability.  You
//*	must determine the suitability of this source code for your use.
//*
//*	Redistributions of this source code must retain this copyright notice.
//*****************************************************************************
//*
//*	References:		https://ascom-standards.org/api/
//*					https://www.ioptron.com/Articles.asp?ID=295
//*					INDIGO iOptron driver reference
//*****************************************************************************
//*	Edit History
//*****************************************************************************
//*	<MLS>	=	Mark L Sproul
//*	<JT>	=	Joey Troy
//*****************************************************************************
//*	Dec 20,	2024	<MLS> Created telescopedriver_iOptron.cpp
//*	Nov 11,	2025	<JT>  Initial implementation based on LX200 pattern
//*	Nov 11,	2025	<JT>  Adapted for iOptron command protocol
//*****************************************************************************


#ifdef _ENABLE_TELESCOPE_IOPTRON_

#include	<ctype.h>
#include	<stdlib.h>
#include	<stdio.h>
#include	<string.h>
#include	<stdbool.h>
#include	<stdint.h>
#include	<unistd.h>
#include	<math.h>
#include	<errno.h>
#include	<termios.h>
#include	<fcntl.h>
#include	<sys/socket.h>

#define _ENABLE_CONSOLE_DEBUG_
#include	"ConsoleDebug.h"

#include	"alpacadriver.h"
#include	"alpacadriver_helper.h"
#include	"helper_functions.h"
#include	"serialport.h"
#include	"linuxerrors.h"
#include	"html_common.h"

#include	"telescopedriver.h"
#include	"telescopedriver_comm.h"
#include	"telescopedriver_iOptron.h"
#include	"readconfigfile.h"
#include	"usbmanager.h"
#include	<sys/time.h>
#include	<unistd.h>

//#define	_DEBUG_IOPTRON_

//*	Config file names for each connection type
static const char	gIOptronUSBConfigFile[]		=	"ioptron-usb-config.txt";
static const char	gIOptronEthernetConfigFile[]	=	"ioptron-ethernet-config.txt";

//**************************************************************************************
//*	iOptron command protocol helper functions
//*	iOptron uses similar command format to LX200 but with some differences
//**************************************************************************************
static int	iOptron_SendCommand(	const int		socket_desc,
									const char		*cmdString,
									char			*returnBuffer,
									const int		maxBufferLen);
static bool	CheckForValidResponse(const char *iOptronResponseString);
static double	iOptron_ParseDegMinSec(char *dataBuffer);
static double	iOptron_ParseRA(char *dataBuffer);

//**************************************************************************************
//*	Try to find an available USB serial device
//*	Returns the first available device path, or NULL if none found
//*	Note: This is a best-guess - if multiple USB devices exist, user should configure
//*	the correct one via setup page or config file
//**************************************************************************************
static const char *FindAvailableUSBDevice(void)
{
int				usbCount;
int				iii;
int				accessRC;
const char		*commonPaths[]	=	{"/dev/ttyUSB0", "/dev/ttyUSB1", "/dev/ttyUSB2", "/dev/ttyACM0", "/dev/ttyACM1", NULL};
static char		foundPath[64];

	//*	Try common USB device paths in order
	//*	Returns first one that exists and is accessible
	//*	If multiple devices exist, user should configure the correct one
	for (iii = 0; commonPaths[iii] != NULL; iii++)
	{
		accessRC	=	access(commonPaths[iii], F_OK | R_OK | W_OK);
		if (accessRC == 0)
		{
			strcpy(foundPath, commonPaths[iii]);
			CONSOLE_DEBUG_W_STR("Auto-detected USB device", foundPath);
			CONSOLE_DEBUG("Note: If this is not the mount, configure correct device via setup page");
			return(foundPath);
		}
	}

	//*	No USB devices found in common paths
	CONSOLE_DEBUG("No USB device found via auto-detection");
	return(NULL);
}

//**************************************************************************************
void	CreateTelescopeObjects_iOptron(void)
{
const char		*autoDetectedPath;
const char		*defaultSerialPath;

	CONSOLE_DEBUG(__FUNCTION__);
	
	//*	Try to auto-detect USB serial device
	autoDetectedPath	=	FindAvailableUSBDevice();
	if (autoDetectedPath != NULL)
	{
		defaultSerialPath	=	autoDetectedPath;
	}
	else
	{
		//*	Fallback to common default - user can configure via setup page or config file
		defaultSerialPath	=	"/dev/ttyUSB0";
		CONSOLE_DEBUG("Using default USB path - configure via setup page or config file");
	}

	//*	Create USB/Serial instance
	//*	Config file will override the device path if it exists
	//*	User can also change it via the setup page
	new TelescopeDriveriOptron(kDevCon_Serial, defaultSerialPath);

	//*	Ethernet instance is only created if there's a config file for it
	//*	This prevents unnecessary connection attempts
	//*	Users can enable Ethernet via the setup page, which will create the config file

	//*	Note: Both instances are created, but only the one that successfully connects will be active
	//*	iOptron network ports:
	//*		CEM60-EC: Default Port 4030
	//*		HEM27: Default Port 8899
	//*		Most other mounts: Port 4030
	//*	Users can configure connection settings via:
	//*		1. Setup page (accessible via Alpaca web interface) - changes take effect immediately
	//*		2. Config files: ioptron-usb-config.txt or ioptron-ethernet-config.txt

	AddSupportedDevice(kDeviceType_Telescope, "iOptron", "", "");
}

//**************************************************************************************
//*	the device path is one of these options
//*		192.168.1.104:9999		(ethernet)
//*		/dev/ttyUSB0			(USB serial)
//*		/dev/ttyS0				(serial port)
//**************************************************************************************
TelescopeDriveriOptron::TelescopeDriveriOptron(DeviceConnectionType connectionType, const char *devicePath)
	:TelescopeDriverComm(connectionType, devicePath)
{
	CONSOLE_DEBUG(__FUNCTION__);
	//*	Set unique names based on connection type
	if (connectionType == kDevCon_Ethernet)
	{
		strcpy(cCommonProp.Name,		"Telescope-iOptron-Ethernet");
		strcpy(cCommonProp.Description,	"Telescope control using iOptron protocol (Ethernet)");
	}
	else
	{
		strcpy(cCommonProp.Name,		"Telescope-iOptron-USB");
		strcpy(cCommonProp.Description,	"Telescope control using iOptron protocol (USB/Serial)");
	}

	//*	setup the options for this driver
	cTelescopeProp.AlginmentMode			=	kAlignmentMode_algGermanPolar;
	cTelescopeProp.EquatorialSystem			=	kECT_equTopocentric;	//*	Topocentric coordinates (most common for amateur equatorial mounts)
	cTelescopeProp.CanSlew					=	true;	//*	Support synchronous slewing (required for ASCOM compatibility)
	cTelescopeProp.CanSlewAsync				=	true;
	cTelescopeProp.CanSync					=	true;
	cTelescopeProp.CanSetTracking			=	true;
	cTelescopeProp.CanMoveAxis[kAxis_RA]	=	true;
	cTelescopeProp.CanMoveAxis[kAxis_DEC]	=	true;
	cTelescopeProp.CanUnpark				=	true;
	cTelescopeProp.CanPark					=	true;
	cTelescopeProp.CanSetPark				=	true;
	cTelescopeProp.CanFindHome				=	true;
	cTelescopeProp.CanPulseGuide			=	true;
	cTelescopeProp.CanSetGuideRates			=	true;
	cTelescopeProp.CanSetDeclinationRate	=	true;
	cTelescopeProp.CanSetRightAscensionRate	=	true;
	cTelescopeProp.CanSlewAltAz				=	false;	//*	most iOptron mounts are equatorial
	cTelescopeProp.CanSlewAltAzAsync		=	false;
	cTelescopeProp.CanSyncAltAz				=	false;

	cTelescopeInfoValid						=	false;
	cIOptron_CommErrCnt						=	0;
	cTelescopeRA_String[0]					=	0;
	cTelescopeDEC_String[0]					=	0;
	cTelescopeStatus_String[0]				=	0;
	cWaitingForResponse						=	false;
	cLastCommandID							=	0;
	cQueuedCmdCnt							=	0;
	cSetupChangeOccured						=	false;

	//*	Enable setup support
	cDriverSupportsSetup					=	true;

	//*	Read configuration from file (if it exists)
	ReadIOptronConfig();

	//*	iOptron uses 115200 baud (per RS-232 Command Language v3.10)
	cBaudRate								=	B115200;

	//*	Set default axis rates for iOptron mounts
	cTelescopeProp.AxisRates[kAxis_RA].Minimum	=	0.0;
	cTelescopeProp.AxisRates[kAxis_RA].Maximum	=	3.0;	//*	degrees per second
	cTelescopeProp.AxisRates[kAxis_DEC].Minimum	=	0.0;
	cTelescopeProp.AxisRates[kAxis_DEC].Maximum	=	3.0;

	AlpacaConnect();
}

//**************************************************************************************
// Destructor
//**************************************************************************************
TelescopeDriveriOptron::~TelescopeDriveriOptron(void)
{
	CONSOLE_DEBUG(__FUNCTION__);
	AlpacaDisConnect();
}

//**************************************************************************************
//*	Disconnect from the mount
//**************************************************************************************
bool	TelescopeDriveriOptron::AlpacaDisConnect(void)
{
int		shutDownRetCode;
int		closeRetCode;

	CONSOLE_DEBUG(__FUNCTION__);

	//*	Stop the driver thread first
	TelescopeDriverComm::AlpacaDisConnect();

	//*	Close the connection based on connection type
	switch(cDeviceConnType)
	{
		case kDevCon_Ethernet:
			if (cSocket_desc > 0)
			{
				shutDownRetCode	=	shutdown(cSocket_desc, SHUT_RDWR);
				if (shutDownRetCode != 0)
				{
					CONSOLE_DEBUG_W_NUM("shutdown() error, errno\t=", errno);
				}
				closeRetCode	=	close(cSocket_desc);
				if (closeRetCode != 0)
				{
					CONSOLE_DEBUG_W_NUM("close() error, errno\t=", errno);
				}
				cSocket_desc	=	-1;
			}
			break;

		case kDevCon_USB:
		case kDevCon_Serial:
			if (cDeviceConnFileDesc >= 0)
			{
				closeRetCode	=	close(cDeviceConnFileDesc);
				if (closeRetCode != 0)
				{
					CONSOLE_DEBUG_W_NUM("close() error, errno\t=", errno);
				}
				cDeviceConnFileDesc	=	-1;
			}
			break;

		case kDevCon_Custom:
			break;
	}

	//*	Update connection state
	cTelescopeConnectionOpen	=	false;
	cCommonProp.Connected		=	false;
	cTelescopeInfoValid			=	false;
	cQueuedCmdCnt				=	0;	//*	Clear command queue
	cIOptron_CommErrCnt			=	0;

	return(true);
}

//**************************************************************************************
int32_t	TelescopeDriveriOptron::RunStateMachine(void)
{
	//*	this is where periodic updates happen
	//*	update telescope position, status, etc.
	return(1 * 1000 * 1000);	//*	return 1 second
}

//**************************************************************************************
bool	TelescopeDriveriOptron::SendCmdsFromQueue(void)
{
int		returnByteCnt;
char	returnBuffer[500];
int		iii;

	CONSOLE_DEBUG(__FUNCTION__);
	
	//*	Check if connection is actually open before trying to send commands
	if (!cTelescopeConnectionOpen)
	{
		return(false);
	}
	
	while (cQueuedCmdCnt > 0)
	{
		CONSOLE_DEBUG_W_STR("Sending", cCmdQueue[0].cmdString);
		if (cDeviceConnType == kDevCon_Ethernet)
		{
			//*	Check if socket is valid
			if (cSocket_desc <= 0)
			{
				return(false);
			}
			returnByteCnt	=	iOptron_SendCommand(	cSocket_desc,
														cCmdQueue[0].cmdString,
														returnBuffer,
														400);
		}
		else
		{
			//*	Serial/USB communication
			//*	Check if file descriptor is valid
			if (cDeviceConnFileDesc < 0)
			{
				return(false);
			}
			returnByteCnt	=	iOptron_SendCommand(	cDeviceConnFileDesc,
														cCmdQueue[0].cmdString,
														returnBuffer,
														400);
		}
		if (returnByteCnt > 0)
		{
			CONSOLE_DEBUG_W_STR("returnBuffer\t=", returnBuffer);
			Process_iOptronResponse(returnBuffer);
		}
		//*	shift queue
		for (iii=0; iii<cQueuedCmdCnt; iii++)
		{
			cCmdQueue[iii]	=	cCmdQueue[iii + 1];
		}
		cQueuedCmdCnt--;
		if (cQueuedCmdCnt > 0)
		{
			usleep(100000);	//*	100ms delay between commands
		}
	}
	return(true);
}

//**************************************************************************************
bool	TelescopeDriveriOptron::SendCmdsPeriodic(void)
{
int		returnByteCnt;
char	returnBuffer[500];
bool	isValid;

#ifdef _DEBUG_IOPTRON_
	CONSOLE_DEBUG(__FUNCTION__);
#endif // _DEBUG_IOPTRON_
	isValid	=	false;

	//*	Check if connection is actually open before trying to send commands
	if (!cTelescopeConnectionOpen)
	{
		return(false);
	}

	//--------------------------------------------------------------------------
	//*	Get RA and DEC - iOptron command :GEP# (returns both in one response)
	//*	Response format: sTTTTTTTTTTTTTTTTTnn#
	//*	Sign and first 8 digits: DEC (0.01 arc-second resolution)
	//*	9th to 17th digits: RA (0.01 arc-second resolution)
	//*	18th digit: side of pier (0=pier east, 1=pier west, 2=indeterminate)
	//*	19th digit: pointing state (0=counterweight up, 1=normal)
	if (cDeviceConnType == kDevCon_Ethernet)
	{
		//*	Check if socket is valid
		if (cSocket_desc <= 0)
		{
			return(false);
		}
		returnByteCnt	=	iOptron_SendCommand(cSocket_desc, ":GEP#", returnBuffer, 400);
	}
	else
	{
		//*	Check if file descriptor is valid
		if (cDeviceConnFileDesc < 0)
		{
			return(false);
		}
		returnByteCnt	=	iOptron_SendCommand(cDeviceConnFileDesc, ":GEP#", returnBuffer, 400);
	}
	if (returnByteCnt > 0)
	{
		isValid	=	Process_GEP_Response(returnBuffer);
		if (isValid)
		{
			cTelescopeInfoValid	=	true;
		}
		else
		{
			cIOptron_CommErrCnt++;
			cTelescopeInfoValid	=	false;
		}
		usleep(100000);	//*	100ms delay
	}
	else
	{
		cIOptron_CommErrCnt++;
	}

	//--------------------------------------------------------------------------
	//*	Get status - iOptron command :GLS#
	//*	This returns longitude, latitude and all kinds of status
	//*	Response format: sTTTTTTTTTTTTTTTTnnnnnn#
	//*	Includes GPS status, system status, tracking rates, etc.
	if (cDeviceConnType == kDevCon_Ethernet)
	{
		//*	Check if socket is valid
		if (cSocket_desc <= 0)
		{
			return(false);
		}
		returnByteCnt	=	iOptron_SendCommand(cSocket_desc, ":GLS#", returnBuffer, 400);
	}
	else
	{
		//*	Check if file descriptor is valid
		if (cDeviceConnFileDesc < 0)
		{
			return(false);
		}
		returnByteCnt	=	iOptron_SendCommand(cDeviceConnFileDesc, ":GLS#", returnBuffer, 400);
	}
	if (returnByteCnt > 0)
	{
		Process_GLS_Response(returnBuffer);
		usleep(100000);
	}

	return(isValid);
}

//*****************************************************************************
TYPE_ASCOM_STATUS	TelescopeDriveriOptron::Telescope_AbortSlew(char *alpacaErrMsg)
{
TYPE_ASCOM_STATUS		alpacaErrCode	=	kASCOM_Err_Success;

	CONSOLE_DEBUG(__FUNCTION__);

	//*	Validate connection before attempting to abort
	if (!cCommonProp.Connected || !cTelescopeConnectionOpen)
	{
		alpacaErrCode	=	kASCOM_Err_NotConnected;
		GENERATE_ALPACAPI_ERRMSG(alpacaErrMsg, "Telescope is not connected");
		return(alpacaErrCode);
	}
	//*	Clear command queue
	cQueuedCmdCnt	=	0;
	//*	iOptron abort command :Q#
	AddCmdToQueue(":Q#");
	cTelescopeProp.Slewing	=	false;

	return(alpacaErrCode);
}

//*****************************************************************************
TYPE_ASCOM_STATUS	TelescopeDriveriOptron::Telescope_FindHome(char *alpacaErrMsg)
{
TYPE_ASCOM_STATUS		alpacaErrCode	=	kASCOM_Err_Success;

	CONSOLE_DEBUG(__FUNCTION__);

	//*	Validate connection before attempting to find home
	if (!cCommonProp.Connected || !cTelescopeConnectionOpen)
	{
		alpacaErrCode	=	kASCOM_Err_NotConnected;
		GENERATE_ALPACAPI_ERRMSG(alpacaErrMsg, "Telescope is not connected");
		return(alpacaErrCode);
	}
	//*	iOptron home command :MH# (slew to zero position)
	AddCmdToQueue(":MH#");
	cTelescopeProp.Slewing	=	true;

	return(alpacaErrCode);
}

//*****************************************************************************
TYPE_ASCOM_STATUS	TelescopeDriveriOptron::Telescope_MoveAxis(	const int		axisNum,
																const double	moveRate_degPerSec,
																char			*alpacaErrMsg)
{
TYPE_ASCOM_STATUS		alpacaErrCode	=	kASCOM_Err_Success;

	CONSOLE_DEBUG(__FUNCTION__);
	CONSOLE_DEBUG_W_DBL("moveRate_degPerSec\t=", moveRate_degPerSec);

	//*	Validate connection before attempting to move axis
	if (!cCommonProp.Connected || !cTelescopeConnectionOpen)
	{
		alpacaErrCode	=	kASCOM_Err_NotConnected;
		GENERATE_ALPACAPI_ERRMSG(alpacaErrMsg, "Telescope is not connected");
		return(alpacaErrCode);
	}

	switch(axisNum)
	{
		case kAxis_RA:	//*	RA axis
			cTelescopeProp.Slewing	=	(moveRate_degPerSec != 0.0);
			if (moveRate_degPerSec > 0.0)
			{
				//*	Move west (increase RA) - lowercase command
				AddCmdToQueue(":mw#");
			}
			else if (moveRate_degPerSec < 0.0)
			{
				//*	Move east (decrease RA) - lowercase command
				AddCmdToQueue(":me#");
			}
			else
			{
				//*	Stop RA movement
				AddCmdToQueue(":qR#");
				cTelescopeProp.Slewing	=	false;
			}
			break;

		case kAxis_DEC:	//*	DEC axis
			cTelescopeProp.Slewing	=	(moveRate_degPerSec != 0.0);
			if (moveRate_degPerSec > 0.0)
			{
				//*	Move north (increase DEC) - lowercase command
				AddCmdToQueue(":ms#");
			}
			else if (moveRate_degPerSec < 0.0)
			{
				//*	Move south (decrease DEC) - lowercase command
				AddCmdToQueue(":mn#");
			}
			else
			{
				//*	Stop DEC movement
				AddCmdToQueue(":qD#");
				cTelescopeProp.Slewing	=	false;
			}
			break;

		default:
			alpacaErrCode	=	kASCOM_Err_InvalidValue;
			GENERATE_ALPACAPI_ERRMSG(alpacaErrMsg, "Invalid axis number");
			break;
	}
	return(alpacaErrCode);
}

//*****************************************************************************
TYPE_ASCOM_STATUS	TelescopeDriveriOptron::Telescope_Park(char *alpacaErrMsg)
{
TYPE_ASCOM_STATUS		alpacaErrCode	=	kASCOM_Err_Success;

	CONSOLE_DEBUG(__FUNCTION__);

	//*	Validate connection before attempting to park
	if (!cCommonProp.Connected || !cTelescopeConnectionOpen)
	{
		alpacaErrCode	=	kASCOM_Err_NotConnected;
		GENERATE_ALPACAPI_ERRMSG(alpacaErrMsg, "Telescope is not connected");
		return(alpacaErrCode);
	}
	//*	iOptron park command :MP1# (park to most recently defined parking position)
	AddCmdToQueue(":MP1#");
	cTelescopeProp.AtPark	=	true;
	cTelescopeProp.Slewing	=	true;

	return(alpacaErrCode);
}

//*****************************************************************************
TYPE_ASCOM_STATUS	TelescopeDriveriOptron::Telescope_SetPark(char *alpacaErrMsg)
{
TYPE_ASCOM_STATUS		alpacaErrCode	=	kASCOM_Err_Success;

	CONSOLE_DEBUG(__FUNCTION__);

	//*	Validate connection before attempting to set park position
	if (!cCommonProp.Connected || !cTelescopeConnectionOpen)
	{
		alpacaErrCode	=	kASCOM_Err_NotConnected;
		GENERATE_ALPACAPI_ERRMSG(alpacaErrMsg, "Telescope is not connected");
		return(alpacaErrCode);
	}
	//*	iOptron set park position - use current position
	//*	Note: This requires getting current Alt/Az and setting parking position
	//*	For now, we'll use :SZP# to set zero position as park position
	//*	TODO: Implement proper park position setting with :SPA# and :SPH#
	AddCmdToQueue(":SZP#");

	return(alpacaErrCode);
}

//*****************************************************************************
TYPE_ASCOM_STATUS	TelescopeDriveriOptron::Telescope_SlewToAltAz(	const double	newAlt_Degrees,
																	const double	newAz_Degrees,
																	char			*alpacaErrMsg)
{
TYPE_ASCOM_STATUS		alpacaErrCode	=	kASCOM_Err_NotImplemented;

	CONSOLE_DEBUG(__FUNCTION__);
	//*	Most iOptron mounts are equatorial, AltAz slewing may not be supported
	GENERATE_ALPACAPI_ERRMSG(alpacaErrMsg, "AltAz slewing not supported on this mount");
	return(alpacaErrCode);
}

//*****************************************************************************
TYPE_ASCOM_STATUS	TelescopeDriveriOptron::Telescope_SlewToRA_DEC(	const double	newRtAscen_Hours,
																	const double	newDeclination_Degrees,
																	char			*alpacaErrMsg)
{
TYPE_ASCOM_STATUS		alpacaErrCode	=	kASCOM_Err_Success;
char					commandString[48];

	CONSOLE_DEBUG(__FUNCTION__);

	//*	Validate connection before attempting to slew
	if (!cCommonProp.Connected)
	{
		alpacaErrCode	=	kASCOM_Err_NotConnected;
		GENERATE_ALPACAPI_ERRMSG(alpacaErrMsg, "Telescope is not connected");
		return(alpacaErrCode);
	}
	if (!cTelescopeConnectionOpen)
	{
		alpacaErrCode	=	kASCOM_Err_NotConnected;
		GENERATE_ALPACAPI_ERRMSG(alpacaErrMsg, "Telescope connection is not open");
		return(alpacaErrCode);
	}

	//*	Set target RA - iOptron command :SRATTTTTTTTT# (9 digits, 0.01 arc-second resolution)
	//*	RA in 0.01 arc-seconds = hours * 15 * 3600 * 100
	int64_t	ra_arcsec_01	=	(int64_t)(newRtAscen_Hours * 15.0 * 3600.0 * 100.0);
	if (ra_arcsec_01 < 0)
	{
		ra_arcsec_01	=	0;
	}
	if (ra_arcsec_01 > 129600000)
	{
		ra_arcsec_01	=	129600000;
	}
	sprintf(commandString, ":SRA%09lld#", (long long)ra_arcsec_01);
	AddCmdToQueue(commandString);

	//*	Set target DEC - iOptron command :SdsTTTTTTTT# (8 digits with sign, 0.01 arc-second resolution)
	//*	DEC in 0.01 arc-seconds = degrees * 3600 * 100
	int64_t	dec_arcsec_01	=	(int64_t)(newDeclination_Degrees * 3600.0 * 100.0);
	if (dec_arcsec_01 < -32400000)
	{
		dec_arcsec_01	=	-32400000;
	}
	if (dec_arcsec_01 > 32400000)
	{
		dec_arcsec_01	=	32400000;
	}
	if (dec_arcsec_01 >= 0)
	{
		sprintf(commandString, ":Sds+%08lld#", (long long)dec_arcsec_01);
	}
	else
	{
		sprintf(commandString, ":Sds-%08lld#", (long long)(-dec_arcsec_01));
	}
	AddCmdToQueue(commandString);

	//*	Slew command - iOptron command :MS1# (slew to normal position)
	AddCmdToQueue(":MS1#");
	cTelescopeProp.Slewing	=	true;

	return(alpacaErrCode);
}

//*****************************************************************************
TYPE_ASCOM_STATUS	TelescopeDriveriOptron::Telescope_SyncToRA_DEC(	const double	newRtAscen_Hours,
																	const double	newDeclination_Degrees,
																	char			*alpacaErrMsg)
{
TYPE_ASCOM_STATUS		alpacaErrCode	=	kASCOM_Err_Success;
char					commandString[48];

	CONSOLE_DEBUG(__FUNCTION__);

	//*	Validate connection before attempting to sync
	if (!cCommonProp.Connected)
	{
		alpacaErrCode	=	kASCOM_Err_NotConnected;
		GENERATE_ALPACAPI_ERRMSG(alpacaErrMsg, "Telescope is not connected");
		return(alpacaErrCode);
	}
	if (!cTelescopeConnectionOpen)
	{
		alpacaErrCode	=	kASCOM_Err_NotConnected;
		GENERATE_ALPACAPI_ERRMSG(alpacaErrMsg, "Telescope connection is not open");
		return(alpacaErrCode);
	}

	//*	Set target RA - iOptron command :SRATTTTTTTTT# (9 digits, 0.01 arc-second resolution)
	int64_t	ra_arcsec_01	=	(int64_t)(newRtAscen_Hours * 15.0 * 3600.0 * 100.0);
	if (ra_arcsec_01 < 0)
	{
		ra_arcsec_01	=	0;
	}
	if (ra_arcsec_01 > 129600000)
	{
		ra_arcsec_01	=	129600000;
	}
	sprintf(commandString, ":SRA%09lld#", (long long)ra_arcsec_01);
	AddCmdToQueue(commandString);

	//*	Set target DEC - iOptron command :SdsTTTTTTTT# (8 digits with sign, 0.01 arc-second resolution)
	int64_t	dec_arcsec_01	=	(int64_t)(newDeclination_Degrees * 3600.0 * 100.0);
	if (dec_arcsec_01 < -32400000)
	{
		dec_arcsec_01	=	-32400000;
	}
	if (dec_arcsec_01 > 32400000)
	{
		dec_arcsec_01	=	32400000;
	}
	if (dec_arcsec_01 >= 0)
	{
		sprintf(commandString, ":Sds+%08lld#", (long long)dec_arcsec_01);
	}
	else
	{
		sprintf(commandString, ":Sds-%08lld#", (long long)(-dec_arcsec_01));
	}
	AddCmdToQueue(commandString);

	//*	Sync command - iOptron command :CM#
	AddCmdToQueue(":CM#");

	return(alpacaErrCode);
}

//*****************************************************************************
TYPE_ASCOM_STATUS	TelescopeDriveriOptron::Telescope_TrackingOnOff(	const bool	newTrackingState,
																	char		*alpacaErrMsg)
{
TYPE_ASCOM_STATUS		alpacaErrCode	=	kASCOM_Err_Success;

	CONSOLE_DEBUG(__FUNCTION__);

	//*	Validate connection before attempting to change tracking
	if (!cCommonProp.Connected || !cTelescopeConnectionOpen)
	{
		alpacaErrCode	=	kASCOM_Err_NotConnected;
		GENERATE_ALPACAPI_ERRMSG(alpacaErrMsg, "Telescope is not connected");
		return(alpacaErrCode);
	}
	if (newTrackingState)
	{
		//*	Start tracking - iOptron command :ST1#
		AddCmdToQueue(":ST1#");
		cTelescopeProp.Tracking	=	true;
	}
	else
	{
		//*	Stop tracking - iOptron command :ST0#
		AddCmdToQueue(":ST0#");
		cTelescopeProp.Tracking	=	false;
	}

	return(alpacaErrCode);
}

//*****************************************************************************
TYPE_ASCOM_STATUS	TelescopeDriveriOptron::Telescope_TrackingRate(	TYPE_DriveRates newTrackingRate,
																	char			*alpacaErrMsg)
{
TYPE_ASCOM_STATUS		alpacaErrCode	=	kASCOM_Err_Success;
char					cmdString[16];

	CONSOLE_DEBUG(__FUNCTION__);

	//*	Validate connection before attempting to set tracking rate
	if (!cCommonProp.Connected || !cTelescopeConnectionOpen)
	{
		alpacaErrCode	=	kASCOM_Err_NotConnected;
		GENERATE_ALPACAPI_ERRMSG(alpacaErrMsg, "Telescope is not connected");
		return(alpacaErrCode);
	}
	//*	iOptron tracking rate command :RTn#
	//*	n = 0 (Sidereal), 1 (Lunar), 2 (Solar), 3 (King)
	switch(newTrackingRate)
	{
		case kDriveRate_driveSidereal:
			strcpy(cmdString, ":RT0#");
			break;
		case kDriveRate_driveLunar:
			strcpy(cmdString, ":RT1#");
			break;
		case kDriveRate_driveSolar:
			strcpy(cmdString, ":RT2#");
			break;
		case kDriveRate_driveKing:
			strcpy(cmdString, ":RT3#");
			break;
		default:
			alpacaErrCode	=	kASCOM_Err_InvalidValue;
			GENERATE_ALPACAPI_ERRMSG(alpacaErrMsg, "Invalid tracking rate");
			return(alpacaErrCode);
	}
	AddCmdToQueue(cmdString);
	cTelescopeProp.TrackingRate	=	newTrackingRate;

	return(alpacaErrCode);
}

//*****************************************************************************
TYPE_ASCOM_STATUS	TelescopeDriveriOptron::Telescope_UnPark(char *alpacaErrMsg)
{
TYPE_ASCOM_STATUS		alpacaErrCode	=	kASCOM_Err_Success;

	CONSOLE_DEBUG(__FUNCTION__);

	//*	Validate connection before attempting to unpark
	if (!cCommonProp.Connected || !cTelescopeConnectionOpen)
	{
		alpacaErrCode	=	kASCOM_Err_NotConnected;
		GENERATE_ALPACAPI_ERRMSG(alpacaErrMsg, "Telescope is not connected");
		return(alpacaErrCode);
	}
	//*	iOptron unpark command :MP0#
	AddCmdToQueue(":MP0#");
	cTelescopeProp.AtPark	=	false;

	return(alpacaErrCode);
}

//*****************************************************************************
//*	Process iOptron response
//*****************************************************************************
bool	TelescopeDriveriOptron::Process_iOptronResponse(char *dataBuffer)
{
bool	isValid;

	isValid	=	CheckForValidResponse(dataBuffer);
	if (isValid)
	{
		//*	Determine response type and process accordingly
		if (strncmp(dataBuffer, "+", 1) == 0 || strncmp(dataBuffer, "-", 1) == 0)
		{
			//*	Likely a coordinate response
			if (strchr(dataBuffer, ':') != NULL)
			{
				//*	Has RA format (HH:MM:SS)
				Process_RA_Response(dataBuffer);
			}
			else if (strchr(dataBuffer, '*') != NULL)
			{
				//*	Has DEC format (sDD*MM:SS)
				Process_DEC_Response(dataBuffer);
			}
		}
	}
	return(isValid);
}

//*****************************************************************************
//*	Process RA response
//*****************************************************************************
bool	TelescopeDriveriOptron::Process_RA_Response(char *dataBuffer)
{
double	hours_Dbl;
bool	isValid;

#ifdef _DEBUG_IOPTRON_
	CONSOLE_DEBUG_W_STR(__FUNCTION__, dataBuffer);
#endif // _DEBUG_IOPTRON_
	isValid	=	CheckForValidResponse(dataBuffer);
	if (isValid)
	{
		hours_Dbl	=	iOptron_ParseRA(dataBuffer);
		if ((hours_Dbl >= 0.0) && (hours_Dbl < 24.0))
		{
			if (strlen(dataBuffer) < 32)
			{
				strcpy(cTelescopeRA_String, dataBuffer);
			}
			cTelescopeProp.RightAscension	=	hours_Dbl;
		}
	}
	return(isValid);
}

//*****************************************************************************
//*	Process DEC response
//*****************************************************************************
bool	TelescopeDriveriOptron::Process_DEC_Response(char *dataBuffer)
{
double	degrees_Dbl;
bool	isValid;

	isValid	=	CheckForValidResponse(dataBuffer);
	if (isValid)
	{
		degrees_Dbl	=	iOptron_ParseDegMinSec(dataBuffer);
		if ((degrees_Dbl >= -90.0) && (degrees_Dbl <= 90.0))
		{
			if (strlen(dataBuffer) < 32)
			{
				strcpy(cTelescopeDEC_String, dataBuffer);
			}
			cTelescopeProp.Declination	=	degrees_Dbl;
		}
	}
	return(isValid);
}

//*****************************************************************************
//*	Process status response
//*****************************************************************************
bool	TelescopeDriveriOptron::Process_Status_Response(char *dataBuffer)
{
bool	isValid;

	isValid	=	CheckForValidResponse(dataBuffer);
	if (isValid)
	{
		if (strlen(dataBuffer) < 64)
		{
			strcpy(cTelescopeStatus_String, dataBuffer);
		}
		//*	Parse status bits to determine slewing, tracking, etc.
		//*	iOptron status format varies by model
		//*	TODO: Implement status parsing based on specific mount model
	}
	return(isValid);
}

//*****************************************************************************
//*	Process :GEP# response - Get RA and DEC
//*	Response format: sTTTTTTTTTTTTTTTTTnn#
//*	Sign and first 8 digits: DEC (0.01 arc-second resolution)
//*	9th to 17th digits: RA (0.01 arc-second resolution)
//*	18th digit: side of pier (0=pier east, 1=pier west, 2=indeterminate)
//*	19th digit: pointing state (0=counterweight up, 1=normal)
//*****************************************************************************
bool	TelescopeDriveriOptron::Process_GEP_Response(char *dataBuffer)
{
bool	isValid;
int		strLen;
char	decStr[16];
char	raStr[16];
int64_t	dec_arcsec_01;
int64_t	ra_arcsec_01;
double	dec_degrees;
double	ra_hours;
int		sign;

	isValid	=	CheckForValidResponse(dataBuffer);
	if (isValid)
	{
		strLen	=	strlen(dataBuffer);
		if (strLen >= 20)	//*	Sign + 19 digits + '#'
		{
			//*	Parse DEC (sign + first 8 digits)
			sign	=	(dataBuffer[0] == '-') ? -1 : 1;
			strncpy(decStr, &dataBuffer[1], 8);
			decStr[8]	=	0;
			dec_arcsec_01	=	atoll(decStr) * sign;
			dec_degrees		=	dec_arcsec_01 / (3600.0 * 100.0);

			//*	Parse RA (9th to 17th digits, 9 digits total)
			strncpy(raStr, &dataBuffer[9], 9);
			raStr[9]	=	0;
			ra_arcsec_01	=	atoll(raStr);
			ra_hours		=	ra_arcsec_01 / (15.0 * 3600.0 * 100.0);

			//*	Update telescope properties
			if ((dec_degrees >= -90.0) && (dec_degrees <= 90.0))
			{
				cTelescopeProp.Declination	=	dec_degrees;
			}
			if ((ra_hours >= 0.0) && (ra_hours < 24.0))
			{
				cTelescopeProp.RightAscension	=	ra_hours;
			}

			//*	Store string representations
			if (strlen(dataBuffer) < 32)
			{
				strcpy(cTelescopeDEC_String, dataBuffer);
			}
		}
	}
	return(isValid);
}

//*****************************************************************************
//*	Process :GLS# response - Get longitude, latitude and status
//*	Response format: sTTTTTTTTTTTTTTTTnnnnnn#
//*	Sign and first 8 digits: longitude (0.01 arc-second resolution)
//*	9th to 16th digits: latitude + 90 degrees (0.01 arc-second resolution)
//*	17th digit: GPS status (0=malfunction, 1=no data, 2=valid data)
//*	18th digit: system status (0=stopped, 1=tracking, 2=slewing, 3=guiding, 4=meridian flip, 5=tracking+PEC, 6=parked, 7=home)
//*	19th digit: tracking rates (0=sidereal, 1=lunar, 2=solar, 3=King, 4=custom)
//*	20th digit: moving speed (1-9)
//*	21st digit: time source (1=RS232/Ethernet, 2=hand controller, 3=GPS)
//*	22nd digit: hemisphere (0=South, 1=North)
//*****************************************************************************
bool	TelescopeDriveriOptron::Process_GLS_Response(char *dataBuffer)
{
bool	isValid;
int		strLen;
int		systemStatus;
int		trackingRate;

	isValid	=	CheckForValidResponse(dataBuffer);
	if (isValid)
	{
		strLen	=	strlen(dataBuffer);
		if (strLen >= 23)	//*	Sign + 22 digits + '#'
		{
			//*	Store status string
			if (strLen < 64)
			{
				strcpy(cTelescopeStatus_String, dataBuffer);
			}

			//*	Parse system status (18th digit, index 18)
			systemStatus	=	dataBuffer[18] - '0';
			switch(systemStatus)
			{
				case 0:	//*	Stopped at non-zero position
					cTelescopeProp.Slewing	=	false;
					cTelescopeProp.Tracking	=	false;
					break;
				case 1:	//*	Tracking
					cTelescopeProp.Slewing	=	false;
					cTelescopeProp.Tracking	=	true;
					break;
				case 2:	//*	Slewing
					cTelescopeProp.Slewing	=	true;
					cTelescopeProp.Tracking	=	false;
					break;
				case 3:	//*	Auto-guiding
					cTelescopeProp.Slewing	=	false;
					cTelescopeProp.Tracking	=	true;
					break;
				case 4:	//*	Meridian flipping
					cTelescopeProp.Slewing	=	true;
					cTelescopeProp.Tracking	=	false;
					break;
				case 5:	//*	Tracking with PEC
					cTelescopeProp.Slewing	=	false;
					cTelescopeProp.Tracking	=	true;
					break;
				case 6:	//*	Parked
					cTelescopeProp.AtPark	=	true;
					cTelescopeProp.Slewing	=	false;
					cTelescopeProp.Tracking	=	false;
					break;
				case 7:	//*	Stopped at zero position (home)
					cTelescopeProp.Slewing	=	false;
					cTelescopeProp.Tracking	=	false;
					break;
			}

			//*	Parse tracking rate (19th digit, index 19)
			trackingRate	=	dataBuffer[19] - '0';
			switch(trackingRate)
			{
				case 0:
					cTelescopeProp.TrackingRate	=	kDriveRate_driveSidereal;
					break;
				case 1:
					cTelescopeProp.TrackingRate	=	kDriveRate_driveLunar;
					break;
				case 2:
					cTelescopeProp.TrackingRate	=	kDriveRate_driveSolar;
					break;
				case 3:
					cTelescopeProp.TrackingRate	=	kDriveRate_driveKing;
					break;
				default:
					//*	Unknown tracking rate, default to sidereal
					cTelescopeProp.TrackingRate	=	kDriveRate_driveSidereal;
					break;
			}
		}
	}
	return(isValid);
}

//*****************************************************************************
//*	Send command to iOptron mount
//*****************************************************************************
static int	iOptron_SendCommand(	const int		socket_desc,
									const char		*cmdString,
									char			*returnBuffer,
									const int		maxBufferLen)
{
int		bytesWritten;
int		bytesRead;
int		totalBytesRead;
char	readChar;
fd_set	readFds;
struct timeval	timeout;

	CONSOLE_DEBUG_W_STR("iOptron_SendCommand", cmdString);
	returnBuffer[0]	=	0;
	totalBytesRead	=	0;

	//*	Send command
	bytesWritten	=	write(socket_desc, cmdString, strlen(cmdString));
	if (bytesWritten < 0)
	{
		CONSOLE_DEBUG_W_NUM("Write error, errno\t=", errno);
		return(0);
	}
	if (bytesWritten != (int)strlen(cmdString))
	{
		CONSOLE_DEBUG_W_NUM("Partial write, expected\t=", (int)strlen(cmdString));
		CONSOLE_DEBUG_W_NUM("Partial write, actual\t=", bytesWritten);
	}
	//*	Small delay to ensure command is sent (works for both serial and Ethernet)
	usleep(10000);	//*	10ms delay

	//*	Read response with timeout
	timeout.tv_sec	=	2;		//*	2 second timeout for iOptron mounts
	timeout.tv_usec	=	0;
	while (totalBytesRead < (maxBufferLen - 1))
	{
		struct timeval	selectTimeout;
		FD_ZERO(&readFds);
		FD_SET(socket_desc, &readFds);
		//*	Reset timeout for each select() call (select modifies the timeout structure)
		selectTimeout.tv_sec	=	2;
		selectTimeout.tv_usec	=	0;
		if (select(socket_desc + 1, &readFds, NULL, NULL, &selectTimeout) > 0)
		{
			bytesRead	=	read(socket_desc, &readChar, 1);
			if (bytesRead > 0)
			{
				returnBuffer[totalBytesRead++]	=	readChar;
				returnBuffer[totalBytesRead]		=	0;
				//*	iOptron commands typically end with '#'
				if (readChar == '#')
				{
					break;
				}
			}
			else if (bytesRead == 0)
			{
				//*	EOF or connection closed
				break;
			}
			else
			{
				//*	Read error
				CONSOLE_DEBUG_W_NUM("Read error, errno\t=", errno);
				break;
			}
		}
		else
		{
			//*	Timeout - no data available
			break;
		}
	}
	if (totalBytesRead > 0)
	{
		CONSOLE_DEBUG_W_STR("Response received\t=", returnBuffer);
	}
	else
	{
		CONSOLE_DEBUG("No response received from mount");
	}
	return(totalBytesRead);
}

//*****************************************************************************
//*	Check for valid iOptron response
//*****************************************************************************
static bool	CheckForValidResponse(const char *iOptronResponseString)
{
bool	isValid;
int		strLen;

	isValid	=	false;
	strLen	=	strlen(iOptronResponseString);
	if (strLen > 0)
	{
		//*	iOptron responses typically end with '#'
		if (iOptronResponseString[strLen-1] == '#')
		{
			isValid	=	true;
		}
	}
	return(isValid);
}

//*****************************************************************************
//*	Parse RA from iOptron format (HH:MM:SS#)
//*****************************************************************************
static double	iOptron_ParseRA(char *dataBuffer)
{
int		hours;
int		minutes;
int		seconds;
char	*charPtr;
double	hours_Dbl;
bool	isValid;

	hours		=	0;
	minutes		=	0;
	seconds		=	0;
	hours_Dbl	=	0.0;
	isValid		=	CheckForValidResponse(dataBuffer);
	if (isValid)
	{
		charPtr	=	dataBuffer;
		hours	=	atoi(charPtr);
		while (isdigit(*charPtr))
		{
			charPtr++;
		}
		if (*charPtr == ':')
		{
			charPtr++;
			minutes	=	atoi(charPtr);
			while (isdigit(*charPtr))
			{
				charPtr++;
			}
			if (*charPtr == ':')
			{
				charPtr++;
				seconds	=	atoi(charPtr);
			}
		}
		hours_Dbl	=	hours;
		hours_Dbl	+=	(1.0 * minutes) / 60.0;
		hours_Dbl	+=	(1.0 * seconds) / 3600.0;
		//*	Normalize to 0-24 range
		while (hours_Dbl >= 24.0)
		{
			hours_Dbl	-=	24.0;
		}
		while (hours_Dbl < 0.0)
		{
			hours_Dbl	+=	24.0;
		}
	}
	return(hours_Dbl);
}

//*****************************************************************************
//*	Parse DEC from iOptron format (sDD*MM:SS#)
//*****************************************************************************
static double	iOptron_ParseDegMinSec(char *dataBuffer)
{
int		degrees;
int		minutes;
int		seconds;
int		plusMinus;
char	*charPtr;
double	degrees_Dbl;
bool	isValid;

	degrees		=	0;
	minutes		=	0;
	seconds		=	0;
	degrees_Dbl	=	0.0;
	plusMinus	=	1;
	isValid		=	CheckForValidResponse(dataBuffer);
	if (isValid)
	{
		charPtr	=	dataBuffer;
		if (*charPtr == '+')
		{
			plusMinus	=	1;
			charPtr++;
		}
		else if (*charPtr == '-')
		{
			plusMinus	=	-1;
			charPtr++;
		}
		degrees	=	atoi(charPtr);
		while (isdigit(*charPtr))
		{
			charPtr++;
		}
		if (*charPtr == '*')
		{
			charPtr++;
			minutes	=	atoi(charPtr);
			while (isdigit(*charPtr))
			{
				charPtr++;
			}
			if (*charPtr == ':')
			{
				charPtr++;
				seconds	=	atoi(charPtr);
			}
		}
		degrees_Dbl	=	degrees;
		degrees_Dbl	+=	(1.0 * minutes) / 60.0;
		degrees_Dbl	+=	(1.0 * seconds) / 3600.0;
		degrees_Dbl	=	plusMinus * degrees_Dbl;
	}
	return(degrees_Dbl);
}

//*****************************************************************************
//*	Process config file entry callback
//*****************************************************************************
static void ProcessIOptronConfigEntry(const char *keyword, const char *value, void *userDataPtr)
{
TelescopeDriveriOptron	*iOptronObjPtr;

	iOptronObjPtr	=	(TelescopeDriveriOptron *)userDataPtr;
	if (iOptronObjPtr != NULL)
	{
		if (strcasecmp(keyword, "CONNTYPE") == 0)
		{
			if (strcasecmp(value, "serial") == 0 || strcasecmp(value, "usb") == 0)
			{
				iOptronObjPtr->cDeviceConnType	=	kDevCon_Serial;
			}
			else if (strcasecmp(value, "ethernet") == 0)
			{
				iOptronObjPtr->cDeviceConnType	=	kDevCon_Ethernet;
			}
		}
		else if (strcasecmp(keyword, "DEVPATH") == 0)
		{
			strcpy(iOptronObjPtr->cDeviceConnPath, value);
		}
		else if (strcasecmp(keyword, "IPADDR") == 0)
		{
			strcpy(iOptronObjPtr->cDeviceIPaddress, value);
			iOptronObjPtr->cIPaddrValid	=	true;
		}
		else if (strcasecmp(keyword, "PORT") == 0)
		{
			iOptronObjPtr->cTCPportNum	=	atoi(value);
		}
	}
}

//*****************************************************************************
//*	Read configuration from file
//*****************************************************************************
void	TelescopeDriveriOptron::ReadIOptronConfig(void)
{
int		linesRead;
const char	*configFile;

	CONSOLE_DEBUG(__FUNCTION__);
	
	//*	Select config file based on connection type
	if (cDeviceConnType == kDevCon_Ethernet)
	{
		configFile	=	gIOptronEthernetConfigFile;
	}
	else
	{
		configFile	=	gIOptronUSBConfigFile;
	}
	
	//*	Read config file
	linesRead	=	ReadGenericConfigFile(	configFile,
											'=',
											&ProcessIOptronConfigEntry,
											this);
	if (linesRead > 0)
	{
		CONSOLE_DEBUG_W_STR("Loaded config from", configFile);
		//*	Update device path for Ethernet if IP and port were loaded
		if (cDeviceConnType == kDevCon_Ethernet && cIPaddrValid)
		{
			char	newDevicePath[256];
			sprintf(newDevicePath, "%s:%d", cDeviceIPaddress, cTCPportNum);
			strcpy(cDeviceConnPath, newDevicePath);
		}
	}
	else
	{
		//*	No config file found - this is OK, driver will use defaults
		//*	For Serial: uses device path from constructor
		//*	For Ethernet: won't connect until configured via setup page
		CONSOLE_DEBUG_W_STR("No config file found (using defaults)", configFile);
	}
}

//*****************************************************************************
//*	Write configuration to file
//*****************************************************************************
void	TelescopeDriveriOptron::WriteIOptronConfig(void)
{
FILE				*filePointer;
struct timeval		timeStamp;
char				timeStampString[128];
const char			*configFile;

	CONSOLE_DEBUG(__FUNCTION__);
	
	//*	Select config file based on connection type
	if (cDeviceConnType == kDevCon_Ethernet)
	{
		configFile	=	gIOptronEthernetConfigFile;
	}
	else
	{
		configFile	=	gIOptronUSBConfigFile;
	}
	
	filePointer	=	fopen(configFile, "w");
	if (filePointer != NULL)
	{
		gettimeofday(&timeStamp, NULL);
		FormatDateTimeString_Local(&timeStamp, timeStampString);

		fprintf(filePointer, "#####################################################################\n");
		fprintf(filePointer, "#AlpacaPi Project - %s\n",	gFullVersionString);
		fprintf(filePointer, "#iOptron Telescope Driver config file\n");
		fprintf(filePointer, "#Created %s\n",				timeStampString);
		
		if (cDeviceConnType == kDevCon_Ethernet)
		{
			fprintf(filePointer, "CONNTYPE\t=\tEthernet\n");
			fprintf(filePointer, "IPADDR  \t=\t%s\n",		cDeviceIPaddress);
			fprintf(filePointer, "PORT    \t=\t%d\n",		cTCPportNum);
		}
		else
		{
			fprintf(filePointer, "CONNTYPE\t=\tSerial\n");
			fprintf(filePointer, "DEVPATH \t=\t%s\n",		cDeviceConnPath);
		}

		fclose(filePointer);
		CONSOLE_DEBUG_W_STR("Saved config to", configFile);
	}
}

//*****************************************************************************
//*	Setup form output
//*****************************************************************************
bool	TelescopeDriveriOptron::Setup_OutputForm(TYPE_GetPutRequestData *reqData, const char *formActionString)
{
int		mySocketFD;
char	lineBuff[512];
const char	iOptronTitle[]	=	"AlpacaPi iOptron Telescope Driver Setup";

	CONSOLE_DEBUG(__FUNCTION__);
	mySocketFD	=	reqData->socket;

	SocketWriteData(mySocketFD,	gHtmlHeader_html);
	SocketWriteData(mySocketFD,	"<!DOCTYPE html>\r\n");
	SocketWriteData(mySocketFD,	"<HTML lang=\"en\">\r\n");
	sprintf(lineBuff,			"<TITLE>%s</TITLE>\r\n", iOptronTitle);
	SocketWriteData(mySocketFD,	lineBuff);
	SocketWriteData(mySocketFD,	"<CENTER>\r\n");
	sprintf(lineBuff,			"<H1>%s</H1>\r\n", iOptronTitle);
	SocketWriteData(mySocketFD,	lineBuff);
	SocketWriteData(mySocketFD,	"</CENTER>\r\n");

	sprintf(lineBuff, "<form action=\"%s\">\r\n", formActionString);
	SocketWriteData(mySocketFD,	lineBuff);

	SocketWriteData(mySocketFD,	"<CENTER>\r\n");
	SocketWriteData(mySocketFD,	"<TABLE BORDER=1>\r\n");
	SocketWriteData(mySocketFD,	"<TR><TH COLSPAN=2>iOptron Mount Connection Settings</TH></TR>\r\n");

	//*	Connection type selection
	SocketWriteData(mySocketFD,	"<TR>\r\n");
	SocketWriteData(mySocketFD,	"<TD><label>Connection Type:</label></TD>\r\n");
	SocketWriteData(mySocketFD,	"<TD>\r\n");
	Setup_OutputRadioBtn(mySocketFD,	"conntype",	"serial",	"USB/Serial",	(cDeviceConnType == kDevCon_Serial || cDeviceConnType == kDevCon_USB));
	Setup_OutputRadioBtn(mySocketFD,	"conntype",	"ethernet",	"Ethernet",		(cDeviceConnType == kDevCon_Ethernet));
	SocketWriteData(mySocketFD,	"</TD>\r\n");
	SocketWriteData(mySocketFD,	"</TR>\r\n");

	//*	USB/Serial device path
	SocketWriteData(mySocketFD,	"<TR>\r\n");
	SocketWriteData(mySocketFD,	"<TD><label for=\"devpath\">USB/Serial Device Path:</label></TD>\r\n");
	SocketWriteData(mySocketFD,	"<TD>\r\n");
	sprintf(lineBuff,	"<input type=\"text\" id=\"devpath\" name=\"devpath\" value=\"%s\" size=\"30\">\r\n", cDeviceConnPath);
	SocketWriteData(mySocketFD,	lineBuff);
	SocketWriteData(mySocketFD,	"<BR><small>Examples: /dev/ttyUSB0, /dev/ttyACM0, /dev/ttyS0</small>\r\n");
	SocketWriteData(mySocketFD,	"</TD>\r\n");
	SocketWriteData(mySocketFD,	"</TR>\r\n");

	//*	Ethernet IP address and port
	SocketWriteData(mySocketFD,	"<TR>\r\n");
	SocketWriteData(mySocketFD,	"<TD><label for=\"ipaddr\">Ethernet IP Address:</label></TD>\r\n");
	SocketWriteData(mySocketFD,	"<TD>\r\n");
	if (cIPaddrValid)
	{
		sprintf(lineBuff,	"<input type=\"text\" id=\"ipaddr\" name=\"ipaddr\" value=\"%s\" size=\"20\">\r\n", cDeviceIPaddress);
	}
	else
	{
		sprintf(lineBuff,	"<input type=\"text\" id=\"ipaddr\" name=\"ipaddr\" value=\"\" size=\"20\">\r\n");
	}
	SocketWriteData(mySocketFD,	lineBuff);
	SocketWriteData(mySocketFD,	"</TD>\r\n");
	SocketWriteData(mySocketFD,	"</TR>\r\n");

	SocketWriteData(mySocketFD,	"<TR>\r\n");
	SocketWriteData(mySocketFD,	"<TD><label for=\"port\">Ethernet Port:</label></TD>\r\n");
	SocketWriteData(mySocketFD,	"<TD>\r\n");
	sprintf(lineBuff,	"<input type=\"number\" id=\"port\" name=\"port\" value=\"%d\" min=\"1\" max=\"65535\">\r\n", cTCPportNum);
	SocketWriteData(mySocketFD,	lineBuff);
	SocketWriteData(mySocketFD,	"<BR><small>Default: 4030 (CEM60-EC), 8899 (HEM27)</small>\r\n");
	SocketWriteData(mySocketFD,	"</TD>\r\n");
	SocketWriteData(mySocketFD,	"</TR>\r\n");

	//*	Save button
	SocketWriteData(mySocketFD,	"<TR>\r\n");
	SocketWriteData(mySocketFD,	"<TD COLSPAN=2><CENTER>\r\n");
	SocketWriteData(mySocketFD,	"<input type=\"submit\" value=\"Save\">\r\n");
	SocketWriteData(mySocketFD,	"</TD>\r\n");
	SocketWriteData(mySocketFD,	"</TR>\r\n");

	SocketWriteData(mySocketFD,	"</TABLE>\r\n");
	SocketWriteData(mySocketFD,	"</CENTER>\r\n");
	SocketWriteData(mySocketFD,	"</form>\r\n");
	SocketWriteData(mySocketFD,	"</HTML>\r\n");

	return(true);
}

//*****************************************************************************
//*	Setup save initialization
//*****************************************************************************
void	TelescopeDriveriOptron::Setup_SaveInit(void)
{
	CONSOLE_DEBUG(__FUNCTION__);
	cSetupChangeOccured	=	false;
}

//*****************************************************************************
//*	Setup save finish - reconnect with new settings
//*****************************************************************************
void	TelescopeDriveriOptron::Setup_SaveFinish(void)
{
char	newDevicePath[256];

	CONSOLE_DEBUG(__FUNCTION__);
	if (cSetupChangeOccured)
	{
		CONSOLE_DEBUG("Connection settings changed, reconnecting...");
		//*	Disconnect current connection
		AlpacaDisConnect();
		
		//*	Update connection path based on connection type
		if (cDeviceConnType == kDevCon_Ethernet)
		{
			//*	Build IP:PORT string
			sprintf(newDevicePath, "%s:%d", cDeviceIPaddress, cTCPportNum);
			strcpy(cDeviceConnPath, newDevicePath);
		}
		//*	For serial, cDeviceConnPath is already updated
		
		//*	Reconnect with new settings
		AlpacaConnect();
		
		//*	Save settings to config file
		WriteIOptronConfig();
		
		cSetupChangeOccured	=	false;
	}
}

//*****************************************************************************
//*	Process setup form keywords
//*****************************************************************************
bool	TelescopeDriveriOptron::Setup_ProcessKeyword(const char *keyword, const char *valueString)
{
	CONSOLE_DEBUG_W_2STR("kw:value", keyword, valueString);

	if (strcasecmp(keyword, "conntype") == 0)
	{
		//*	Connection type selection
		if (strcasecmp(valueString, "serial") == 0)
		{
			if (cDeviceConnType != kDevCon_Serial && cDeviceConnType != kDevCon_USB)
			{
				cDeviceConnType		=	kDevCon_Serial;
				cSetupChangeOccured	=	true;
			}
		}
		else if (strcasecmp(valueString, "ethernet") == 0)
		{
			if (cDeviceConnType != kDevCon_Ethernet)
			{
				cDeviceConnType		=	kDevCon_Ethernet;
				cSetupChangeOccured	=	true;
			}
		}
	}
	else if (strcasecmp(keyword, "devpath") == 0)
	{
		//*	USB/Serial device path
		size_t	slen;
		slen	=	strlen(valueString);
		if (slen > 0 && slen < sizeof(cDeviceConnPath))
		{
			if (strcmp(valueString, cDeviceConnPath) != 0)
			{
				strcpy(cDeviceConnPath, valueString);
				cSetupChangeOccured	=	true;
			}
		}
	}
	else if (strcasecmp(keyword, "ipaddr") == 0)
	{
		//*	Ethernet IP address
		int		dotCounter;
		size_t	slen;
		uint32_t	iii;
		dotCounter	=	0;
		slen		=	strlen(valueString);
		if ((slen >= 7) && (slen < sizeof(cDeviceIPaddress)))
		{
			for (iii = 0; iii < slen; iii++)
			{
				if (valueString[iii] == '.')
				{
					dotCounter++;
				}
			}
			if (dotCounter == 3)
			{
				if (strcmp(valueString, cDeviceIPaddress) != 0)
				{
					strcpy(cDeviceIPaddress, valueString);
					cIPaddrValid		=	true;
					cSetupChangeOccured	=	true;
				}
			}
			else
			{
				CONSOLE_DEBUG_W_STR("Invalid IP address\t=", valueString);
			}
		}
	}
	else if (strcasecmp(keyword, "port") == 0)
	{
		//*	Ethernet port number
		int		newPortNumber;
		newPortNumber	=	atoi(valueString);
		if ((newPortNumber > 0) && (newPortNumber <= 65535))
		{
			if (newPortNumber != cTCPportNum)
			{
				cTCPportNum			=	newPortNumber;
				cSetupChangeOccured	=	true;
			}
		}
		else
		{
			CONSOLE_DEBUG_W_NUM("Invalid port number\t=", newPortNumber);
		}
	}

	return(true);
}

#endif // _ENABLE_TELESCOPE_IOPTRON_

