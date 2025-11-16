#!/usr/bin/env bash
####################################################################**********
#	AlpacaPi Setup Wizard
#	Interactive Bubble Gum workflow that mirrors setup-map.md
####################################################################**********

set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

####################################################################**********
#	Global Data Definitions
####################################################################**********
declare -a device_categories=(
	"Camera"
	"Filter Wheel"
	"Focuser"
	"Rotator"
	"Telescope"
	"Weather"
	"GPIO / Aux"
)

declare -A manufacturers_by_category=(
	["Camera"]="ZWO|QHY|ATIK|Player One|QSI|Simulator"
	["Filter Wheel"]="ZWO|Player One|Pegasus Astro|Simulator"
	["Focuser"]="ZWO|MoonLite|Pegasus Astro|Simulator"
	["Rotator"]="MoonLite|Pegasus Astro|Simulator"
	["Telescope"]="SkyWatcher|Rigel|iOptron|LX200|Simulator"
	["Weather"]="Unihedron|Raspberry Pi|Simulator"
	["GPIO / Aux"]="Raspberry Pi|Arduino|Simulator"
)

declare -a installed_drivers=()
declare -a pending_drivers=()
declare -a result_success=()
declare -a result_failed=()
declare -a log_lines=()

progress_pipe=""
progress_pid=""
progress_total_steps=0
progress_completed_steps=0

apply_pending_label="Apply pending changes and build AlpacaPi Server"
build_now_label="Build AlpacaPi Server (apply pending changes)"
manual_build_requested=false
gum_supports_progress=false

current_state="stateWelcome"
mode="ModeInstall"
selected_category=""
selected_manufacturer=""
installed_review_return_state="stateWelcome"
err_message=""
category_index=0
manufacturer_index=0
pending_index=0
installed_index=0
usb_rules_installed=false

log_dir="/var/log/AlpacaPi"
log_file="$log_dir/alpacapi_setup.log"
config_dir="$repo_root/config"
installed_list_file="$config_dir/installed_drivers.lst"
installed_json_file="$config_dir/installed_drivers.json"

####################################################################**********
#	Utility Helpers
####################################################################**********
banner()
{
	#*	Display a banner with rounded border
	#*	Purpose: Create a prominent title banner
	#*	Parameters:
	#*		$1 - Title text to display
	#*	Returns: None
	#*	Side Effects: Outputs styled text to stdout
	local title="$1"
	gum style \
		--border rounded \
		--align center \
		--width 70 \
		--margin "1 2" \
		--padding "1 2" \
		--bold \
		--foreground 45 \
		"$title"
}

subtitle()
{
	#*	Display a subtitle
	#*	Purpose: Create a subtle subtitle text
	#*	Parameters:
	#*		$@ - Subtitle text to display
	#*	Returns: None
	#*	Side Effects: Outputs styled text to stdout
	gum style \
		--width 70 \
		--align center \
		--foreground 244 \
		"$@"
}

section_title()
{
	#*	Display a section title
	#*	Purpose: Create a section heading
	#*	Parameters:
	#*		$@ - Section title text to display
	#*	Returns: None
	#*	Side Effects: Outputs styled text to stdout
	gum style \
		--width 70 \
		--align left \
		--foreground 45 \
		--bold \
		"$@"
}

ensure_gum()
{
	if ! command -v gum >/dev/null 2>&1
	then
		echo "ERROR: gum is required. Run ./scripts/configure_apps.sh first." >&2
		exit 1
	fi
	#*	Check if gum supports progress command
	#*	gum progress reads progress values (0.0 to 1.0) from stdin
	#*	Test if progress command actually exists by trying to run it
	#*	If it exits with error code, the command doesn't exist
	#*	We suppress both stdout and stderr to avoid cluttering output during detection
	if echo "0.0" 2>/dev/null | gum progress --title "test" >/dev/null 2>&1
	then
		#*	Command ran successfully - progress is available
		gum_supports_progress=true
	else
		#*	Command failed (exit code != 0) - progress is not available
		#*	This handles both "unexpected argument" and other errors
		gum_supports_progress=false
	fi
}

init_logging()
{
	#*	Try to create log directory in /var/log/AlpacaPi
	#*	If that fails (permissions), fall back to repo directory
	if [ ! -d "$log_dir" ]
	then
		if ! mkdir -p "$log_dir" 2>/dev/null
		then
			#*	Fallback to repo directory if /var/log isn't writable
			log_dir="$repo_root/logs"
			log_file="$log_dir/alpacapi_setup.log"
			mkdir -p "$log_dir" 2>/dev/null || true
		else
			chmod 755 "$log_dir" 2>/dev/null || true
		fi
	fi
	if [ ! -f "$log_file" ]
	then
		touch "$log_file" 2>/dev/null || true
		chmod 644 "$log_file" 2>/dev/null || true
	fi
	#*	Log the log file location for debugging
	echo "Log file: $log_file" >&2
}

log_event()
{
	local message="$1"
	local timestamp

	timestamp=$(date +"%Y-%m-%dT%H:%M:%S%z")
	if [ -w "$log_file" ]
	then
		printf "%s %s\n" "$timestamp" "$message" >>"$log_file"
	fi
}

load_installed_drivers()
{
	installed_drivers=()
	if [ -f "$installed_list_file" ]
	then
		while IFS= read -r line
		do
			[ -z "$line" ] && continue
			installed_drivers+=("$line")
		done <"$installed_list_file"
	elif [ -f "$installed_json_file" ] && command -v jq >/dev/null 2>&1
	then
		while IFS= read -r line
		do
			installed_drivers+=("$line")
		done < <(jq -r '.drivers[] | "\(.category)|\(.manufacturer)|\(.model)|\(.version)"' "$installed_json_file")
		persist_installed_drivers
	fi
}

format_pending_entry()
{
	local entry="$1"
	IFS='|' read -r action category manufacturer model <<<"$entry"
	printf "%s – %s / %s / %s" "$action" "$category" "$manufacturer" "$model"
}

format_installed_entry()
{
	local entry="$1"
	IFS='|' read -r category manufacturer model version <<<"$entry"
	if [ -n "$manufacturer" ] && [ -n "$category" ]
	then
		printf "%s – %s" "$manufacturer" "$category"
	elif [ -n "$manufacturer" ]
	then
		printf "%s" "$manufacturer"
	else
		printf "%s" "$entry"
	fi
}

show_error()
{
	if [ -n "$err_message" ]
	then
		gum style --foreground 196 --bold "$err_message"
		err_message=""
	fi
}

set_category_index()
{
	local name="$1"
	local idx=0
	for category in "${device_categories[@]}"
	do
		if [ "$category" = "$name" ]
		then
			category_index=$idx
			break
		fi
		idx=$((idx + 1))
	done
}

set_manufacturer_index()
{
	local target="$1"
	local idx=0
	IFS='|' read -r -a manufacturers <<<"${manufacturers_by_category["$selected_category"]}"
	for manufacturer in "${manufacturers[@]}"
	do
		if [ "$manufacturer" = "$target" ]
		then
			manufacturer_index=$idx
			break
		fi
		idx=$((idx + 1))
	done
}

add_pending_driver()
{
	local category="$1"
	local manufacturer="$2"
	local model="$3"
	local action="$4"
	pending_drivers+=("$action|$category|$manufacturer|$model")
	log_event "Queued $action for $category/$manufacturer/$model"
}

remove_pending_entry()
{
	local idx="$1"
	if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#pending_drivers[@]}" ]
	then
		return 1
	fi
	pending_drivers=("${pending_drivers[@]:0:$idx}" "${pending_drivers[@]:$((idx + 1))}")
	return 0
}

build_full_alpacapi()
{
	#*	This function is called when user requests a manual build with no pending drivers
	#*	Instead of building everything (which includes MoonLite), we build only installed drivers
	#*	This prevents MoonLite from being included when it's not selected
	
	local cpu_count build_log status custom_makefile

	#*	Load installed drivers and configure build flags from them
	load_installed_drivers
	if ! configure_build_flags_from_installed
	then
		log_event "WARNING: No installed drivers found - building with minimal configuration"
		#*	If no installed drivers, reset to minimal build (no MoonLite)
		reset_build_flags
	fi

	#*	Log build flags for debugging
	log_event "Build flags configured (from installed drivers):"
	log_event "  BUILD_FOCUSER_MOONLITE=$BUILD_FOCUSER_MOONLITE"
	log_event "  BUILD_ROTATOR_NITECRAWLER=$BUILD_ROTATOR_NITECRAWLER"
	log_event "  BUILD_FOCUSER=$BUILD_FOCUSER"
	log_event "  BUILD_ROTATOR=$BUILD_ROTATOR"

	custom_makefile=$(generate_selective_makefile)

	if command -v getconf >/dev/null 2>&1
	then
		cpu_count=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
	else
		cpu_count=1
	fi

	build_log=$(mktemp -t alpacapi_build.XXXXXX)

	if [ -f "$repo_root/alpacapi" ]
	then
		log_event "Removing existing alpacapi executable to force rebuild"
		rm -f "$repo_root/alpacapi"
	fi

	#*	Clean first so we always get a consistent build
	log_event "Cleaning all object files for fresh selective build"
	( cd "$repo_root" && make clean >/dev/null 2>&1 || true )
	
	#*	Also explicitly remove all .o files from Objectfiles directory
	if [ -d "$repo_root/Objectfiles" ]
	then
		find "$repo_root/Objectfiles" -name "*.o" -type f -delete 2>/dev/null || true
	fi
	
	#*	Explicitly remove MoonLite object files if not selected
	if [ "$BUILD_FOCUSER_MOONLITE" != true ] && [ "$BUILD_ROTATOR_NITECRAWLER" != true ]
	then
		rm -f "$repo_root/Objectfiles/focuserdriver_nc.o" 2>/dev/null || true
		rm -f "$repo_root/Objectfiles/rotatordriver_nc.o" 2>/dev/null || true
		rm -f "$repo_root/Objectfiles/moonlite_com.o" 2>/dev/null || true
		log_event "Removed MoonLite object files (not in installed drivers)"
	fi

	log_event "Starting AlpacaPi build (make -f $(basename "$custom_makefile") -j${cpu_count} alpacapi_selective)"

	#*	IMPORTANT: No --show-output (spinner only)
	#*	All make output goes into $build_log (not the screen)
	if gum spin \
		--title "Compiling AlpacaPi (installed drivers)" \
		-- bash -c "cd \"$repo_root\" && make -f \"$(basename "$custom_makefile")\" -j${cpu_count} alpacapi_selective >\"$build_log\" 2>&1"
	then
		status=0
	else
		status=$?
	fi

	#*	Load the captured log into the in-memory log_lines array
	if [ -s "$build_log" ]
	then
		while IFS= read -r line
		do
			log_lines+=("$line")
		done <"$build_log"
	fi
	rm -f "$build_log"

	#*	Post-build verification: Check if MoonLite objects were accidentally built
	if [ "$BUILD_FOCUSER_MOONLITE" != true ] && [ "$BUILD_ROTATOR_NITECRAWLER" != true ]
	then
		if [ -f "$repo_root/Objectfiles/focuserdriver_nc.o" ] || \
		   [ -f "$repo_root/Objectfiles/rotatordriver_nc.o" ] || \
		   [ -f "$repo_root/Objectfiles/moonlite_com.o" ]
		then
			log_event "ERROR: MoonLite object files were built but not in installed drivers!"
			log_event "ERROR: BUILD_FOCUSER_MOONLITE=$BUILD_FOCUSER_MOONLITE, BUILD_ROTATOR_NITECRAWLER=$BUILD_ROTATOR_NITECRAWLER"
			log_event "ERROR: These files may be linked into the executable"
			status=1
		fi
	fi

	#*	Verify the executable was actually created
	if [ "$status" -eq 0 ]
	then
		if [ ! -f "$repo_root/alpacapi" ]
		then
			log_event "ERROR: Build reported success but alpacapi executable not found"
			log_event "Build log may contain link errors - check for missing libraries"
			status=1
		else
			log_event "Build successful - alpacapi executable created at $repo_root/alpacapi"
		fi
	fi

	#*	Optional: one-line status message
	if [ "$status" -eq 0 ]
	then
		gum style --foreground 46 --bold --align center --width 60 \
			"AlpacaPi build completed successfully."
	else
		gum style --foreground 196 --bold --align center --width 60 \
			"AlpacaPi build failed (exit $status)."
	fi

	return "$status"
}

reset_build_flags()
{
	BUILD_CAMERA=false
	BUILD_CAMERA_ASI=false
	BUILD_CAMERA_ATIK=false
	BUILD_CAMERA_FLIR=false
	BUILD_CAMERA_QHY=false
	BUILD_CAMERA_TOUP=false

	BUILD_FILTERWHEEL=false
	BUILD_FILTERWHEEL_ZWO=false
	BUILD_FILTERWHEEL_ATIK=false

	BUILD_FOCUSER=false
	BUILD_FOCUSER_ZWO=false
	BUILD_FOCUSER_MOONLITE=false

	BUILD_ROTATOR=false
	BUILD_ROTATOR_NITECRAWLER=false

	BUILD_TELESCOPE=false
	BUILD_TELESCOPE_LX200=false
	BUILD_TELESCOPE_SKYWATCHER=false
	BUILD_TELESCOPE_SERVO=false
	BUILD_TELESCOPE_IOPTRON=false

	BUILD_OBSERVINGCONDITIONS=false
	BUILD_SWITCH=false
}

apply_selection_to_build_flags()
{
	local category="$1"
	local vendor="$2"

	case "$category" in
		"Camera")
			BUILD_CAMERA=true
			case "$vendor" in
				"ZWO"|"Player One")
					BUILD_CAMERA_ASI=true
					;;
				"ATIK")
					BUILD_CAMERA_ATIK=true
					;;
				"QHY")
					BUILD_CAMERA_QHY=true
					;;
				"ToupTek")
					BUILD_CAMERA_TOUP=true
					;;
				"FLIR")
					BUILD_CAMERA_FLIR=true
					;;
			esac
			;;
		"Filter Wheel")
			BUILD_FILTERWHEEL=true
			case "$vendor" in
				"ZWO")
					BUILD_FILTERWHEEL_ZWO=true
					;;
				"ATIK")
					BUILD_FILTERWHEEL_ATIK=true
					;;
			esac
			;;
		"Focuser")
			BUILD_FOCUSER=true
			case "$vendor" in
				"ZWO")
					BUILD_FOCUSER_ZWO=true
					;;
				"MoonLite")
					BUILD_FOCUSER_MOONLITE=true
					;;
			esac
			;;
		"Rotator")
			BUILD_ROTATOR=true
			case "$vendor" in
				"MoonLite")
					BUILD_ROTATOR_NITECRAWLER=true
					;;
			esac
			;;
		"Telescope")
			BUILD_TELESCOPE=true
			case "$vendor" in
				"iOptron")
					BUILD_TELESCOPE_IOPTRON=true
					;;
				"LX200")
					BUILD_TELESCOPE_LX200=true
					;;
				"SkyWatcher")
					BUILD_TELESCOPE_SKYWATCHER=true
					;;
				"Servo"|"Rigel")
					BUILD_TELESCOPE_SERVO=true
					;;
			esac
			;;
		"Weather")
			BUILD_OBSERVINGCONDITIONS=true
			;;
		"GPIO / Aux")
			BUILD_SWITCH=true
			;;
	esac
}

configure_build_flags_from_pending()
{
	local entry action category vendor model
	local has_selection=false

	reset_build_flags
	for entry in "${pending_drivers[@]}"
	do
		IFS='|' read -r action category vendor model <<<"$entry"
		if [ "$action" != "Install" ]
		then
			continue
		fi
		has_selection=true
		apply_selection_to_build_flags "$category" "$vendor"
	done

	if [ "$has_selection" = true ]
	then
		return 0
	else
		return 1
	fi
}

configure_build_flags_from_installed()
{
	local entry category vendor model version
	local has_selection=false

	reset_build_flags
	for entry in "${installed_drivers[@]}"
	do
		IFS='|' read -r category vendor model version <<<"$entry"
		[ -z "$category" ] && continue
		has_selection=true
		apply_selection_to_build_flags "$category" "$vendor"
	done

	if [ "$has_selection" = true ]
	then
		return 0
	else
		return 1
	fi
}

generate_selective_makefile()
{
	local custom_makefile="$repo_root/.Makefile.wizard"
	local has_opencv=false

	if pkg-config --exists opencv4 2>/dev/null || pkg-config --exists opencv 2>/dev/null || \
	   [ -f "/usr/include/opencv2/highgui/highgui_c.h" ] || [ -f "/usr/local/include/opencv2/highgui/highgui_c.h" ] || \
	   [ -f "/usr/include/opencv4/opencv2/highgui/highgui.hpp" ] || [ -f "/usr/local/include/opencv4/opencv2/highgui/highgui.hpp" ]
	then
		has_opencv=true
	fi

	cat >"$custom_makefile" <<'EOF'
#	Auto-generated by setup_wizard.sh
include Makefile

alpacapi_selective:	DEFINEFLAGS		+=	-D_ALPACA_PI_
alpacapi_selective:	DEFINEFLAGS		+=	-D_INCLUDE_ALPACA_EXTENSIONS_
alpacapi_selective:	DEFINEFLAGS		+=	-D_INCLUDE_HTTP_HEADER_
alpacapi_selective:	DEFINEFLAGS		+=	-D_USE_CAMERA_READ_THREAD_
alpacapi_selective:	DEFINEFLAGS		+=	-D_INCLUDE_MILLIS_
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_DISCOVERY_QUERRY_
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_CTRL_IMAGE_
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_LIVE_CONTROLLER_
EOF

	if [ "$has_opencv" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_USE_OPENCV_
EOF
	fi

	if [ "$BUILD_CAMERA" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_CAMERA_
EOF
		[ "$BUILD_CAMERA_ASI" = true ] && cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_ASI_
EOF
		[ "$BUILD_CAMERA_ATIK" = true ] && cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_ATIK_
EOF
		[ "$BUILD_CAMERA_FLIR" = true ] && cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_FLIR_
EOF
		[ "$BUILD_CAMERA_QHY" = true ] && cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_QHY_
EOF
		[ "$BUILD_CAMERA_TOUP" = true ] && cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_TOUP_
EOF
	fi

	if [ "$BUILD_FILTERWHEEL" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_FILTERWHEEL_
EOF
		[ "$BUILD_FILTERWHEEL_ZWO" = true ] && cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_FILTERWHEEL_ZWO_
EOF
		[ "$BUILD_FILTERWHEEL_ATIK" = true ] && cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_FILTERWHEEL_ATIK_
EOF
	fi

	if [ "$BUILD_FOCUSER" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_FOCUSER_
EOF
		[ "$BUILD_FOCUSER_ZWO" = true ] && cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_FOCUSER_ZWO_
EOF
		[ "$BUILD_FOCUSER_MOONLITE" = true ] && cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_FOCUSER_MOONLITE_
EOF
	fi

	if [ "$BUILD_ROTATOR" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_ROTATOR_
EOF
		[ "$BUILD_ROTATOR_NITECRAWLER" = true ] && cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_ROTATOR_NITECRAWLER_
EOF
	fi

	if [ "$BUILD_TELESCOPE" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_TELESCOPE_
EOF
		[ "$BUILD_TELESCOPE_IOPTRON" = true ] && cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_TELESCOPE_IOPTRON_
EOF
		[ "$BUILD_TELESCOPE_LX200" = true ] && cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_TELESCOPE_LX200_
EOF
		[ "$BUILD_TELESCOPE_SERVO" = true ] && cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_TELESCOPE_SERVO_
EOF
		[ "$BUILD_TELESCOPE_SKYWATCHER" = true ] && cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_TELESCOPE_SKYWATCH_
EOF
	fi

	[ "$BUILD_OBSERVINGCONDITIONS" = true ] && cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_OBSERVINGCONDITIONS_
EOF

	[ "$BUILD_SWITCH" = true ] && cat >>"$custom_makefile" <<'EOF'
alpacapi_selective:	DEFINEFLAGS		+=	-D_ENABLE_SWITCH_
EOF

	#*	Build selective object file lists (only selected drivers)
	cat >>"$custom_makefile" <<'EOF'
#*	Selective camera driver objects (base + selected vendors only)
SELECTIVE_CAMERA_OBJECTS=		\
			$(OBJECT_DIR)cameradriver.o				\
			$(OBJECT_DIR)cameradriverAnalysis.o		\
			$(OBJECT_DIR)cameradriver_auxinfo.o		\
			$(OBJECT_DIR)cameradriver_fits.o			\
			$(OBJECT_DIR)cameradriver_gps.o			\
			$(OBJECT_DIR)cameradriver_jpeg.o			\
			$(OBJECT_DIR)cameradriver_livewindow.o	\
			$(OBJECT_DIR)cameradriver_opencv.o		\
			$(OBJECT_DIR)cameradriver_overlay.o		\
			$(OBJECT_DIR)cameradriver_png.o			\
			$(OBJECT_DIR)cameradriver_readthread.o	\
			$(OBJECT_DIR)cameradriver_save.o			\
			$(OBJECT_DIR)NASA_moonphase.o			\
			$(OBJECT_DIR)multicam.o

#*	Selective filter wheel driver objects (base + selected vendors only)
SELECTIVE_FILTERWHEEL_OBJECTS=	\
			$(OBJECT_DIR)filterwheeldriver.o

#*	Selective focuser driver objects (base + selected vendors only)
SELECTIVE_FOCUSER_OBJECTS=		\
			$(OBJECT_DIR)focuserdriver.o

#*	Selective telescope driver objects (base + selected vendors only)
SELECTIVE_TELESCOPE_OBJECTS=	\
			$(OBJECT_DIR)telescopedriver.o			\
			$(OBJECT_DIR)telescopedriver_comm.o

alpacapi_selective:	$(DRIVER_OBJECTS)				\
			$(HELPER_OBJECTS)				\
			$(SERIAL_OBJECTS)				\
			$(SOCKET_OBJECTS)				\
EOF

	#*	Add camera objects (base + selected vendors) to dependencies
	if [ "$BUILD_CAMERA" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
			$(SELECTIVE_CAMERA_OBJECTS)			\
EOF
		#*	Add vendor-specific camera objects
		if [ "$BUILD_CAMERA_ASI" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)cameradriver_ASI.o		\
			$(ASI_CAMERA_OBJECTS)				\
EOF
		fi
		if [ "$BUILD_CAMERA_ATIK" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)cameradriver_ATIK.o		\
EOF
		fi
		if [ "$BUILD_CAMERA_FLIR" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)cameradriver_FLIR.o		\
EOF
		fi
		if [ "$BUILD_CAMERA_QHY" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)cameradriver_QHY.o		\
EOF
		fi
		if [ "$BUILD_CAMERA_TOUP" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)cameradriver_TOUP.o		\
EOF
		fi
		#*	Check for other camera vendors that might be selected
		#*	PlayerOne, QSI, SONY, OGMA, Simulator
		for entry in "${pending_drivers[@]}"
		do
			IFS='|' read -r action category vendor model <<<"$entry"
			if [ "$category" = "Camera" ] && [ "$action" = "Install" ]
			then
				case "$vendor" in
					"Player One")
						cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)cameradriver_PlayerOne.o	\
EOF
						;;
					"QSI")
						cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)cameradriver_QSI.o		\
EOF
						;;
					"SONY")
						cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)cameradriver_SONY.o		\
EOF
						;;
					"OGMA")
						cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)cameradriver_OGMA.o		\
EOF
						;;
					"Simulator")
						cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)cameradriver_sim.o		\
EOF
						;;
				esac
			fi
		done
	fi

	#*	Add filter wheel objects (base + selected vendors) to dependencies
	if [ "$BUILD_FILTERWHEEL" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
			$(SELECTIVE_FILTERWHEEL_OBJECTS)		\
EOF
		if [ "$BUILD_FILTERWHEEL_ZWO" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)filterwheeldriver_ZWO.o	\
			$(ZWO_EFW_OBJECTS)					\
EOF
		fi
		if [ "$BUILD_FILTERWHEEL_ATIK" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)filterwheeldriver_ATIK.o	\
EOF
		fi
		#*	Check for other filter wheel vendors
		for entry in "${pending_drivers[@]}"
		do
			IFS='|' read -r action category vendor model <<<"$entry"
			if [ "$category" = "Filter Wheel" ] && [ "$action" = "Install" ]
			then
				case "$vendor" in
					"Player One")
						cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)filterwheeldriver_Play1.o	\
EOF
						;;
					"QHY")
						cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)filterwheeldriver_QHY.o	\
EOF
						;;
					"Simulator")
						cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)filterwheeldriver_sim.o	\
EOF
						;;
				esac
			fi
		done
	fi

	#*	Add focuser objects (base + selected vendors) to dependencies
	if [ "$BUILD_FOCUSER" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
			$(SELECTIVE_FOCUSER_OBJECTS)			\
EOF
		if [ "$BUILD_FOCUSER_ZWO" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)focuserdriver_ZWO.o		\
EOF
		fi
		if [ "$BUILD_FOCUSER_MOONLITE" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)focuserdriver_nc.o		\
			$(OBJECT_DIR)moonlite_com.o			\
EOF
		fi
		#*	Check for simulator
		for entry in "${pending_drivers[@]}"
		do
			IFS='|' read -r action category vendor model <<<"$entry"
			if [ "$category" = "Focuser" ] && [ "$action" = "Install" ] && [ "$vendor" = "Simulator" ]
			then
				cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)focuserdriver_sim.o		\
EOF
			fi
		done
	fi

	#*	Add rotator objects to dependencies if selected
	if [ "$BUILD_ROTATOR" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)rotatordriver.o			\
EOF
		if [ "$BUILD_ROTATOR_NITECRAWLER" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)rotatordriver_nc.o		\
			$(OBJECT_DIR)moonlite_com.o			\
EOF
		fi
		#*	Check for simulator
		for entry in "${pending_drivers[@]}"
		do
			IFS='|' read -r action category vendor model <<<"$entry"
			if [ "$category" = "Rotator" ] && [ "$action" = "Install" ] && [ "$vendor" = "Simulator" ]
			then
				cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)rotatordriver_sim.o		\
EOF
			fi
		done
	fi

	#*	Add telescope objects (base + selected vendors) to dependencies
	if [ "$BUILD_TELESCOPE" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
			$(SELECTIVE_TELESCOPE_OBJECTS)		\
EOF
		if [ "$BUILD_TELESCOPE_IOPTRON" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)telescopedriver_iOptron.o	\
EOF
		fi
		if [ "$BUILD_TELESCOPE_LX200" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)telescopedriver_lx200.o	\
			$(OBJECT_DIR)lx200_com.o			\
EOF
		fi
		if [ "$BUILD_TELESCOPE_SKYWATCHER" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)telescopedriver_skywatch.o	\
EOF
		fi
		if [ "$BUILD_TELESCOPE_SERVO" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)telescopedriver_servo.o	\
EOF
		fi
		#*	Check for other telescope vendors
		for entry in "${pending_drivers[@]}"
		do
			IFS='|' read -r action category vendor model <<<"$entry"
			if [ "$category" = "Telescope" ] && [ "$action" = "Install" ]
			then
				case "$vendor" in
					"Rigel")
						cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)telescopedriver_Rigel.o	\
EOF
						;;
					"Simulator")
						cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)telescopedriver_sim.o	\
EOF
						;;
				esac
			fi
		done
	fi

	#*	Add observing conditions objects to dependencies if selected
	if [ "$BUILD_OBSERVINGCONDITIONS" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)obsconditionsdriver.o	\
EOF
		for entry in "${pending_drivers[@]}"
		do
			IFS='|' read -r action category vendor model <<<"$entry"
			if [ "$category" = "Weather" ] && [ "$action" = "Install" ]
			then
				case "$vendor" in
					"Raspberry Pi")
						cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)obsconditionsdriver_rpi.o	\
EOF
						;;
					"Simulator")
						cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)obsconditionsdriver_sim.o	\
EOF
						;;
				esac
			fi
		done
	fi

	#*	Add switch objects to dependencies if selected
	if [ "$BUILD_SWITCH" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)switchdriver.o			\
EOF
		for entry in "${pending_drivers[@]}"
		do
			IFS='|' read -r action category vendor model <<<"$entry"
			if [ "$category" = "GPIO / Aux" ] && [ "$action" = "Install" ]
			then
				case "$vendor" in
					"Raspberry Pi")
						cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)switchdriver_rpi.o		\
EOF
						;;
					"Simulator")
						cat >>"$custom_makefile" <<'EOF'
			$(OBJECT_DIR)switchdriver_sim.o		\
EOF
						;;
				esac
			fi
		done
	fi

	#*	Close dependency list and start link command
	#*	The link command must be part of the same target (immediately follows dependencies)
	#*	Note: LIVE_WINDOW_OBJECTS always needed since _ENABLE_LIVE_CONTROLLER_ is always defined
	if [ "$has_opencv" = true ]
	then
		#*	Last dependency line (no backslash), then immediately start link command
		cat >>"$custom_makefile" <<'EOF'
			$(LIVE_WINDOW_OBJECTS)
	$(LINK)  									\
		$(DRIVER_OBJECTS)						\
		$(HELPER_OBJECTS)						\
		$(SERIAL_OBJECTS)						\
		$(SOCKET_OBJECTS)						\
		$(LIVE_WINDOW_OBJECTS)					\
EOF
	else
		#*	OpenCV not enabled - but LIVE_WINDOW_OBJECTS still needed for controller code
		#*	Add it as last dependency, then start link command
		cat >>"$custom_makefile" <<'EOF'
			$(LIVE_WINDOW_OBJECTS)
	$(LINK)  									\
		$(DRIVER_OBJECTS)						\
		$(HELPER_OBJECTS)						\
		$(SERIAL_OBJECTS)						\
		$(SOCKET_OBJECTS)						\
		$(LIVE_WINDOW_OBJECTS)					\
EOF
	fi

	#*	Add camera objects to link command (selective)
	if [ "$BUILD_CAMERA" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
		$(SELECTIVE_CAMERA_OBJECTS)				\
EOF
		#*	Add vendor-specific camera objects
		if [ "$BUILD_CAMERA_ASI" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)cameradriver_ASI.o			\
		$(ASI_CAMERA_OBJECTS)					\
EOF
		fi
		if [ "$BUILD_CAMERA_ATIK" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)cameradriver_ATIK.o		\
EOF
		fi
		if [ "$BUILD_CAMERA_FLIR" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)cameradriver_FLIR.o		\
EOF
		fi
		if [ "$BUILD_CAMERA_QHY" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)cameradriver_QHY.o			\
EOF
		fi
		if [ "$BUILD_CAMERA_TOUP" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)cameradriver_TOUP.o		\
EOF
		fi
		#*	Add other camera vendors from pending list
		for entry in "${pending_drivers[@]}"
		do
			IFS='|' read -r action category vendor model <<<"$entry"
			if [ "$category" = "Camera" ] && [ "$action" = "Install" ]
			then
				case "$vendor" in
					"Player One")
						cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)cameradriver_PlayerOne.o	\
EOF
						;;
					"QSI")
						cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)cameradriver_QSI.o			\
EOF
						;;
					"SONY")
						cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)cameradriver_SONY.o		\
EOF
						;;
					"OGMA")
						cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)cameradriver_OGMA.o		\
EOF
						;;
					"Simulator")
						cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)cameradriver_sim.o			\
EOF
						;;
				esac
			fi
		done
	fi

	#*	Add filter wheel objects to link command (selective)
	if [ "$BUILD_FILTERWHEEL" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
		$(SELECTIVE_FILTERWHEEL_OBJECTS)		\
EOF
		if [ "$BUILD_FILTERWHEEL_ZWO" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)filterwheeldriver_ZWO.o	\
EOF
		fi
		if [ "$BUILD_FILTERWHEEL_ATIK" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)filterwheeldriver_ATIK.o	\
EOF
		fi
		#*	Add other filter wheel vendors
		for entry in "${pending_drivers[@]}"
		do
			IFS='|' read -r action category vendor model <<<"$entry"
			if [ "$category" = "Filter Wheel" ] && [ "$action" = "Install" ]
			then
				case "$vendor" in
					"Player One")
						cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)filterwheeldriver_Play1.o	\
EOF
						;;
					"QHY")
						cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)filterwheeldriver_QHY.o	\
EOF
						;;
					"Simulator")
						cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)filterwheeldriver_sim.o	\
EOF
						;;
				esac
			fi
		done
	fi

	#*	Add focuser objects to link command (selective)
	if [ "$BUILD_FOCUSER" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
		$(SELECTIVE_FOCUSER_OBJECTS)				\
EOF
		if [ "$BUILD_FOCUSER_ZWO" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)focuserdriver_ZWO.o		\
EOF
		fi
		if [ "$BUILD_FOCUSER_MOONLITE" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)focuserdriver_nc.o			\
		$(OBJECT_DIR)moonlite_com.o				\
EOF
		fi
		#*	Add simulator if selected
		for entry in "${pending_drivers[@]}"
		do
			IFS='|' read -r action category vendor model <<<"$entry"
			if [ "$category" = "Focuser" ] && [ "$action" = "Install" ] && [ "$vendor" = "Simulator" ]
			then
				cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)focuserdriver_sim.o		\
EOF
			fi
		done
	fi

	#*	Add rotator objects to link command if selected
	if [ "$BUILD_ROTATOR" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)rotatordriver.o			\
EOF
		if [ "$BUILD_ROTATOR_NITECRAWLER" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)rotatordriver_nc.o			\
		$(OBJECT_DIR)moonlite_com.o			\
EOF
		fi
		#*	Add simulator if selected
		for entry in "${pending_drivers[@]}"
		do
			IFS='|' read -r action category vendor model <<<"$entry"
			if [ "$category" = "Rotator" ] && [ "$action" = "Install" ] && [ "$vendor" = "Simulator" ]
			then
				cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)rotatordriver_sim.o		\
EOF
			fi
		done
	fi

	#*	Add telescope objects to link command (selective)
	if [ "$BUILD_TELESCOPE" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
		$(SELECTIVE_TELESCOPE_OBJECTS)			\
EOF
		if [ "$BUILD_TELESCOPE_IOPTRON" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)telescopedriver_iOptron.o	\
EOF
		fi
		if [ "$BUILD_TELESCOPE_LX200" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)telescopedriver_lx200.o	\
		$(OBJECT_DIR)lx200_com.o				\
EOF
		fi
		if [ "$BUILD_TELESCOPE_SKYWATCHER" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)telescopedriver_skywatch.o	\
EOF
		fi
		if [ "$BUILD_TELESCOPE_SERVO" = true ]
		then
			cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)telescopedriver_servo.o	\
EOF
		fi
		#*	Add other telescope vendors
		for entry in "${pending_drivers[@]}"
		do
			IFS='|' read -r action category vendor model <<<"$entry"
			if [ "$category" = "Telescope" ] && [ "$action" = "Install" ]
			then
				case "$vendor" in
					"Rigel")
						cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)telescopedriver_Rigel.o	\
EOF
						;;
					"Simulator")
						cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)telescopedriver_sim.o		\
EOF
						;;
				esac
			fi
		done
	fi

	#*	Add observing conditions objects if selected
	if [ "$BUILD_OBSERVINGCONDITIONS" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)obsconditionsdriver.o		\
EOF
		for entry in "${pending_drivers[@]}"
		do
			IFS='|' read -r action category vendor model <<<"$entry"
			if [ "$category" = "Weather" ] && [ "$action" = "Install" ]
			then
				case "$vendor" in
					"Raspberry Pi")
						cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)obsconditionsdriver_rpi.o	\
EOF
						;;
					"Simulator")
						cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)obsconditionsdriver_sim.o	\
EOF
						;;
				esac
			fi
		done
	fi

	#*	Add switch objects if selected
	if [ "$BUILD_SWITCH" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)switchdriver.o				\
EOF
		for entry in "${pending_drivers[@]}"
		do
			IFS='|' read -r action category vendor model <<<"$entry"
			if [ "$category" = "GPIO / Aux" ] && [ "$action" = "Install" ]
			then
				case "$vendor" in
					"Raspberry Pi")
						cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)switchdriver_rpi.o		\
EOF
						;;
					"Simulator")
						cat >>"$custom_makefile" <<'EOF'
		$(OBJECT_DIR)switchdriver_sim.o			\
EOF
						;;
				esac
			fi
		done
	fi

	if [ "$has_opencv" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
		$(OPENCV_LINK)							\
EOF
	fi

	#*	Add ZWO SDK library paths and runtime paths if needed
	#*	Note: These must come after OpenCV but before ZWO static libraries
	if [ "$BUILD_FOCUSER_ZWO" = true ] || [ "$BUILD_FILTERWHEEL_ZWO" = true ] || [ "$BUILD_CAMERA_ASI" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
		-L$(ZWO_EAF_LIB_DIR)					\
		-Wl,-rpath,$(ZWO_EAF_LIB_DIR)			\
EOF
	fi

	#*	Add ZWO EFW filter wheel static library (must come after library paths)
	if [ "$BUILD_FILTERWHEEL_ZWO" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
		$(ZWO_EFW_OBJECTS)						\
EOF
	fi

	#*	Add ZWO EAF focuser shared library if selected
	if [ "$BUILD_FOCUSER_ZWO" = true ]
	then
		cat >>"$custom_makefile" <<'EOF'
		-lEAFFocuser							\
EOF
	fi

	cat >>"$custom_makefile" <<'EOF'
		-ludev									\
		-lusb-1.0								\
		-lpthread								\
		-lcfitsio								\
		-o alpacapi
EOF

	echo "$custom_makefile"
}

install_usb_rules_for_selected()
{
	#*	Install USB rules based on selected drivers
	local rules_installed=0
	local rule_dir rules_file

	#*	Helper function to install a single USB rule file
	install_single_rule()
	{
		local rule_dir="$1"
		local rules_file="$2"
		
		if [ -f "/lib/udev/rules.d/$rules_file" ]
		then
			log_event "USB rule $rules_file already installed in /lib/udev"
			return 0
		elif [ -f "/etc/udev/rules.d/$rules_file" ]
		then
			log_event "USB rule $rules_file already installed in /etc/udev"
			return 0
		else
			if [ -f "$rule_dir/$rules_file" ]
			then
				log_event "Installing USB rule: $rules_file"
				#*	Try to install with sudo (may prompt for password)
				#*	Suppress stderr but capture exit code
				if sudo install "$rule_dir/$rules_file" /lib/udev/rules.d 2>/dev/null
				then
					log_event "Successfully installed $rules_file"
					return 0
				else
					log_event "WARNING: Failed to install $rules_file (sudo may have failed)"
					log_event "WARNING: You may need to install USB rules manually or run with sudo"
					return 1
				fi
			else
				#*	Rule file not found - this is not an error, just skip it
				return 1
			fi
		fi
	}

	#*	Check which drivers are selected and install corresponding USB rules
	for entry in "${pending_drivers[@]}"
	do
		IFS='|' read -r action category vendor model <<<"$entry"
		if [ "$action" != "Install" ]
		then
			continue
		fi

		case "$category" in
			"Camera")
				case "$vendor" in
					"ZWO")
						if [ -d "$repo_root/sdk/ZWO_ASI_SDK/lib" ]
						then
							install_single_rule "$repo_root/sdk/ZWO_ASI_SDK/lib" "asi.rules" && rules_installed=$((rules_installed + 1))
						fi
						;;
					"Player One")
						#*	Player One cameras use ASI-compatible SDK, but may have their own rules
						#*	Check for Player One specific rules first
						if [ -d "$repo_root/PlayerOne" ]
						then
							#*	Look for Player One SDK with udev rules
							for playerone_sdk_dir in "$repo_root/PlayerOne"/PlayerOne_Camera_SDK_*/udev
							do
								if [ -d "$playerone_sdk_dir" ]
								then
									install_single_rule "$playerone_sdk_dir" "99-player_one_astronomy.rules" && rules_installed=$((rules_installed + 1))
									break
								fi
							done
						fi
						#*	Also install ASI rules as Player One cameras are ASI-compatible
						if [ -d "$repo_root/sdk/ZWO_ASI_SDK/lib" ]
						then
							install_single_rule "$repo_root/sdk/ZWO_ASI_SDK/lib" "asi.rules" && rules_installed=$((rules_installed + 1))
						fi
						;;
					"ATIK")
						if [ -d "$repo_root/sdk/AtikCamerasSDK" ]
						then
							install_single_rule "$repo_root/sdk/AtikCamerasSDK" "99-atik.rules" && rules_installed=$((rules_installed + 1))
						fi
						;;
					"QHY")
						if [ -d "$repo_root/sdk/QHY/etc/udev/rules.d" ]
						then
							install_single_rule "$repo_root/sdk/QHY/etc/udev/rules.d" "85-qhyccd.rules" && rules_installed=$((rules_installed + 1))
						fi
						;;
					"ToupTek")
						if [ -d "$repo_root/sdk/toupcamsdk/linux/udev" ]
						then
							install_single_rule "$repo_root/sdk/toupcamsdk/linux/udev" "99-toupcam.rules" && rules_installed=$((rules_installed + 1))
						fi
						;;
					"FLIR")
						if [ -d "$repo_root/sdk/FLIR-SDK" ]
						then
							install_single_rule "$repo_root/sdk/FLIR-SDK" "40-flir-spinnaker.rules" && rules_installed=$((rules_installed + 1))
						fi
						;;
				esac
				;;
			"Filter Wheel")
				case "$vendor" in
					"ZWO")
						if [ -d "$repo_root/sdk/ZWO_EFW_SDK/lib" ]
						then
							install_single_rule "$repo_root/sdk/ZWO_EFW_SDK/lib" "efw.rules" && rules_installed=$((rules_installed + 1))
						fi
						;;
					"Player One")
						#*	Player One filter wheels may have their own SDK
						if [ -d "$repo_root/PlayerOne" ]
						then
							for playerone_fw_dir in "$repo_root/PlayerOne"/PlayerOne_FilterWheel_SDK_*/udev
							do
								if [ -d "$playerone_fw_dir" ]
								then
									install_single_rule "$playerone_fw_dir" "99-player_one_astronomy.rules" && rules_installed=$((rules_installed + 1))
									break
								fi
							done
						fi
						#*	Also check for ZWO EFW rules as they may be compatible
						if [ -d "$repo_root/sdk/ZWO_EFW_SDK/lib" ]
						then
							install_single_rule "$repo_root/sdk/ZWO_EFW_SDK/lib" "efw.rules" && rules_installed=$((rules_installed + 1))
						fi
						;;
				esac
				;;
			"Focuser")
				case "$vendor" in
					"ZWO")
						if [ -d "$repo_root/sdk/ZWO_EAF_SDK/lib" ]
						then
							install_single_rule "$repo_root/sdk/ZWO_EAF_SDK/lib" "eaf.rules" && rules_installed=$((rules_installed + 1))
						fi
						;;
				esac
				;;
		esac
	done

	if [ $rules_installed -gt 0 ]
	then
		log_event "Installed $rules_installed USB rule file(s) for selected drivers"
		log_event "NOTE: You may need to reboot or unplug/replug USB devices for rules to take effect"
	else
		log_event "No USB rules needed for selected drivers (or rules already installed)"
	fi
}

build_selected_alpacapi()
{
	local cpu_count build_log status custom_makefile config_status

	if ! configure_build_flags_from_pending
	then
		return 2
	fi

	#*	Log build flags for debugging
	log_event "Build flags configured:"
	log_event "  BUILD_FOCUSER_MOONLITE=$BUILD_FOCUSER_MOONLITE"
	log_event "  BUILD_ROTATOR_NITECRAWLER=$BUILD_ROTATOR_NITECRAWLER"
	log_event "  BUILD_FOCUSER=$BUILD_FOCUSER"
	log_event "  BUILD_ROTATOR=$BUILD_ROTATOR"

	#*	Install USB rules for selected drivers before building
	log_event "Installing USB device rules for selected drivers..."
	install_usb_rules_for_selected

	custom_makefile=$(generate_selective_makefile)

	if command -v getconf >/dev/null 2>&1
	then
		cpu_count=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
	else
		cpu_count=1
	fi

	#*	Clean all object files to ensure selective build only includes selected drivers
	#*	This is critical - we must remove ALL object files to prevent stale code from being linked
	log_event "Cleaning all object files for fresh selective build"
	( cd "$repo_root" && make clean >/dev/null 2>&1 )
	
	#*	Also explicitly remove all .o files from Objectfiles directory
	#*	This ensures no stale object files remain from previous builds
	if [ -d "$repo_root/Objectfiles" ]
	then
		find "$repo_root/Objectfiles" -name "*.o" -type f -delete 2>/dev/null || true
		log_event "Removed all object files from Objectfiles directory"
	fi
	
	#*	Remove executable to force full rebuild
	if [ -f "$repo_root/alpacapi" ]
	then
		log_event "Removing existing alpacapi executable to force selective rebuild"
		rm -f "$repo_root/alpacapi"
	fi
	
	#*	Explicitly remove MoonLite object files if not selected
	#*	This prevents them from being built or linked even if they exist from previous builds
	if [ "$BUILD_FOCUSER_MOONLITE" != true ] && [ "$BUILD_ROTATOR_NITECRAWLER" != true ]
	then
		rm -f "$repo_root/Objectfiles/focuserdriver_nc.o" 2>/dev/null || true
		rm -f "$repo_root/Objectfiles/rotatordriver_nc.o" 2>/dev/null || true
		rm -f "$repo_root/Objectfiles/moonlite_com.o" 2>/dev/null || true
		log_event "Removed MoonLite object files (not selected)"
	fi

	build_log=$(mktemp -t alpacapi_selective.XXXXXX)
	log_event "Starting selective AlpacaPi build (make -f $(basename "$custom_makefile") -j${cpu_count} alpacapi_selective)"
	log_event "Pending drivers: ${#pending_drivers[@]}"
	for entry in "${pending_drivers[@]}"
	do
		log_event "  Pending: $entry"
	done

	#*	Update progress before build starts
	advance_progress_bar
	
	#*	Run build with spinner showing live output
	#*	IMPORTANT: Use --show-output to show live make output in the TUI
	#*	tee writes the same output into $build_log so we can persist it
	if gum spin \
		--show-output \
		--title "Compiling AlpacaPi (selected drivers)" \
		-- bash -c "cd \"$repo_root\" && make -f \"$(basename "$custom_makefile")\" -j${cpu_count} alpacapi_selective 2>&1 | tee \"$build_log\""
	then
		status=0
	else
		status=$?
	fi

	if [ -s "$build_log" ]
	then
		while IFS= read -r line
		do
			log_lines+=("$line")
		done <"$build_log"
	fi
	
	#*	Verify the executable was actually created
	if [ "$status" -eq 0 ]
	then
		if [ ! -f "$repo_root/alpacapi" ]
		then
			log_event "ERROR: Build reported success but alpacapi executable not found"
			log_event "Build log may contain link errors - check for missing libraries"
			#*	Check for common link errors in the build log
			if [ -s "$build_log" ]
			then
				if grep -i "error\|undefined\|cannot find\|no such file" "$build_log" >/dev/null 2>&1
				then
					log_event "Link errors detected in build log:"
					grep -i "error\|undefined\|cannot find\|no such file" "$build_log" | head -10 | while IFS= read -r error_line
					do
						log_event "  $error_line"
					done
				fi
			fi
			status=1
		else
			log_event "Build successful - alpacapi executable created at $repo_root/alpacapi"
		fi
	fi
	
	#*	Post-build verification: Check if MoonLite objects were accidentally built
	#*	Note: If they were built, they're already linked into the executable, so we can't remove them now
	#*	But we log a warning so the user knows to do a clean build
	if [ "$BUILD_FOCUSER_MOONLITE" != true ] && [ "$BUILD_ROTATOR_NITECRAWLER" != true ]
	then
		if [ -f "$repo_root/Objectfiles/focuserdriver_nc.o" ] || \
		   [ -f "$repo_root/Objectfiles/rotatordriver_nc.o" ] || \
		   [ -f "$repo_root/Objectfiles/moonlite_com.o" ]
		then
			log_event "ERROR: MoonLite object files were built but not selected!"
			log_event "ERROR: BUILD_FOCUSER_MOONLITE=$BUILD_FOCUSER_MOONLITE, BUILD_ROTATOR_NITECRAWLER=$BUILD_ROTATOR_NITECRAWLER"
			log_event "ERROR: These files may be linked into the executable"
			log_event "ERROR: Run 'make clean' and rebuild if MoonLite code appears in runtime"
			#*	This is a critical error - the build included code that shouldn't be there
			status=1
		fi
	fi
	
	rm -f "$build_log"
	rm -f "$custom_makefile"
	return "$status"
}

show_pending_summary()
{
	if [ "${#pending_drivers[@]}" -eq 0 ]
	then
		gum style --foreground 244 --align center --width 60 "Pending queue: none"
		return
	fi

	gum style --foreground 46 --bold --align center --width 60 "Pending queue"
	for entry in "${pending_drivers[@]}"
	do
		gum style --align center --width 70 "  $(format_pending_entry "$entry")"
	done
}

ensure_config_dir()
{
	if [ ! -d "$config_dir" ]
	then
		mkdir -p "$config_dir"
	fi
}

start_progress_bar()
{
	progress_total_steps="$1"
	progress_completed_steps=0
	local title="${2:-Applying changes}"

	if [ "$progress_total_steps" -le 0 ]
	then
		progress_total_steps=1
	fi

	if [ "$gum_supports_progress" != true ]
	then
		gum style --align center --width 60 "$title (this may take a moment...)"
		progress_pipe=""
		progress_pid=""
		return
	fi

	progress_pipe=$(mktemp /tmp/alpaca_progress.XXXXXX)
	rm -f "$progress_pipe"
	mkfifo "$progress_pipe"

	gum progress --title "$title" --spinner dot <"$progress_pipe" &
	progress_pid=$!
	exec 3>"$progress_pipe"
	update_progress_bar 0
}

update_progress_bar()
{
	if [ "$gum_supports_progress" != true ] || [ -z "$progress_pipe" ]
	then
		return
	fi
	local value="$1"
	local ratio

	if [ "$progress_total_steps" -le 0 ]
	then
		ratio=1
	else
		ratio=$(awk -v completed="$value" -v total="$progress_total_steps" 'BEGIN { printf "%.4f", (total <= 0 ? 1 : completed / total) }')
	fi
	printf "%s\n" "$ratio" >&3
}

advance_progress_bar()
{
	if [ "$gum_supports_progress" != true ] || [ -z "$progress_pipe" ]
	then
		return
	fi
	progress_completed_steps=$((progress_completed_steps + 1))
	if [ "$progress_completed_steps" -gt "$progress_total_steps" ]
	then
		progress_completed_steps="$progress_total_steps"
	fi
	update_progress_bar "$progress_completed_steps"
}

finish_progress_bar()
{
	if [ "$gum_supports_progress" != true ] || [ -z "$progress_pipe" ]
	then
		return
	fi
	if [ -n "$progress_pipe" ]
	then
		if [ "$progress_completed_steps" -lt "$progress_total_steps" ]
		then
			progress_completed_steps="$progress_total_steps"
			update_progress_bar "$progress_completed_steps"
		fi
		exec 3>&-
		wait "$progress_pid" 2>/dev/null || true
		rm -f "$progress_pipe"
		progress_pipe=""
		progress_pid=""
	fi
}

persist_installed_drivers()
{
	ensure_config_dir
	local tmp_list tmp_json idx entry category manufacturer model version

	tmp_list=$(mktemp -t alpacapi_installed.XXXXXX)
	tmp_json=$(mktemp -t alpacapi_installed_json.XXXXXX)

	if [ "${#installed_drivers[@]}" -eq 0 ]
	then
		: >"$tmp_list"
		printf '{\n  "drivers": []\n}\n' >"$tmp_json"
	else
		for entry in "${installed_drivers[@]}"
		do
			printf "%s\n" "$entry" >>"$tmp_list"
		done

		printf '{\n  "drivers": [\n' >"$tmp_json"
		for idx in "${!installed_drivers[@]}"
		do
			entry="${installed_drivers[$idx]}"
			IFS='|' read -r category manufacturer model version <<<"$entry"
			printf '    {"category":"%s","manufacturer":"%s","model":"%s","version":"%s"}' \
				"$category" "$manufacturer" "$model" "$version" >>"$tmp_json"
			if [ "$idx" -lt $((${#installed_drivers[@]} - 1)) ]
			then
				printf ',\n' >>"$tmp_json"
			else
				printf '\n' >>"$tmp_json"
			fi
		done
		printf '  ]\n}\n' >>"$tmp_json"
	fi

	mv "$tmp_list" "$installed_list_file"
	mv "$tmp_json" "$installed_json_file"
}

add_installed_record()
{
	local entry="$1"
	for existing in "${installed_drivers[@]}"
	do
		if [ "$existing" = "$entry" ]
		then
			return 1
		fi
	done
	installed_drivers+=("$entry")
	return 0
}

remove_installed_record()
{
	local entry="$1"
	local new_list=()
	local removed=false

	for existing in "${installed_drivers[@]}"
	do
		if [ "$existing" = "$entry" ] && [ "$removed" = false ]
		then
			removed=true
			continue
		fi
		new_list+=("$existing")
	done

	if [ "$removed" = true ]
	then
		if [ "${#new_list[@]}" -eq 0 ]
		then
			installed_drivers=()
		else
			installed_drivers=("${new_list[@]}")
		fi
		return 0
	fi
	return 1
}

sync_installed_records_from_success()
{
	local changed=false
	local entry action category manufacturer model stored_entry

	for entry in "${result_success[@]}"
	do
		IFS='|' read -r action category manufacturer model <<<"$entry"
		stored_entry="${category}|${manufacturer}|${model}|n/a"
		case "$action" in
			"Install")
				if add_installed_record "$stored_entry"
				then
					changed=true
				fi
				;;
			"Remove")
				if remove_installed_record "$stored_entry"
				then
					changed=true
				fi
				;;
		esac
	done

	if [ "$changed" = true ]
	then
		persist_installed_drivers
	fi
}

####################################################################**********
#	State Implementations
####################################################################**********
state_welcome()
{
	clear
	banner "AlpacaPi Setup Wizard"
	subtitle "Install only the drivers you need. Review or remove later."
	show_error

	local options=("Start setup" "Quit")

	local choice
	choice=$(gum choose --cursor="➤" "${options[@]}") || exit 0

	case "$choice" in
		"Start setup")
			mode="ModeInstall"
			current_state="stateModeSelect"
			;;
		"$build_now_label")
			manual_build_requested=true
			current_state="stateInstallProgress"
			;;
		"Quit")
			exit 0
			;;
	esac
}

state_mode_select()
{
	clear
	banner "Choose Setup Mode"
	show_error

	local options=("Install new drivers" "Review installed drivers" "Remove existing drivers" "$build_now_label" "Back to welcome" "Quit")

	local choice
	choice=$(gum choose --cursor="➤" "${options[@]}") || exit 0

	case "$choice" in
		"Install new drivers")
			manual_build_requested=false
			mode="ModeInstall"
			current_state="stateDeviceCategorySelect"
			;;
		"Review installed drivers")
			manual_build_requested=false
			mode="ModeReview"
			installed_review_return_state="stateModeSelect"
			current_state="stateInstalledReview"
			;;
		"Remove existing drivers")
			manual_build_requested=false
			mode="ModeRemove"
			installed_review_return_state="stateModeSelect"
			current_state="stateInstalledReview"
			;;
		"$build_now_label")
			manual_build_requested=true
			current_state="stateInstallProgress"
			;;
		"Back to welcome")
			current_state="stateWelcome"
			;;
		"Quit")
			exit 0
			;;
	esac
}

state_device_category_select()
{
	clear
	banner "Select Device Category"
	subtitle "↑/↓ Select • Enter Next • choose menu option to review queue/back"
	show_error
	show_pending_summary

	local categories=("${device_categories[@]}")
	if [ "${#pending_drivers[@]}" -gt 0 ]
	then
		categories+=("Review pending queue")
	fi
	categories+=("Back")

	local selection
	selection=$(gum choose --cursor="➤" "${categories[@]}") || {
		current_state="stateModeSelect"
		return
	}

	case "$selection" in
		"Back")
			current_state="stateModeSelect"
			;;
		"Review pending queue")
			current_state="statePendingReview"
			;;
		*)
			selected_category="$selection"
			set_category_index "$selection"
			current_state="stateManufacturerSelect"
			;;
	esac
}

state_manufacturer_select()
{
	if [ -z "$selected_category" ]
	then
		err_message="Select a device category first."
		current_state="stateDeviceCategorySelect"
		return
	fi

	local manufacturers_string="${manufacturers_by_category["$selected_category"]:-""}"
	if [ -z "$manufacturers_string" ]
	then
		err_message="No manufacturers defined for $selected_category."
		current_state="stateDeviceCategorySelect"
		return
	fi

	IFS='|' read -r -a manufacturers <<<"$manufacturers_string"
	while true
	do
		clear
		banner "Select Manufacturer – $selected_category"
		subtitle "↑/↓ Select • Enter Queue • p Pending • b Back • q Quit"
		show_error

		local options=("${manufacturers[@]}")
		if [ "${#pending_drivers[@]}" -gt 0 ]
		then
			options+=("Review pending queue")
		fi
		options+=("Back to categories")

		local selection
		selection=$(gum choose --cursor="➤" "${options[@]}") || {
			current_state="stateDeviceCategorySelect"
			return
		}

		case "$selection" in
			"Back to categories")
				current_state="stateDeviceCategorySelect"
				return
				;;
			"Review pending queue")
				current_state="statePendingReview"
				return
				;;
			*)
				selected_manufacturer="$selection"
				set_manufacturer_index "$selection"
				add_pending_driver "$selected_category" "$selected_manufacturer" "All drivers" "Install"
				err_message="Queued $selection drivers for $selected_category."
				current_state="stateDeviceCategorySelect"
				return
				;;
		esac
	done
}

state_pending_review()
{
	if [ "${#pending_drivers[@]}" -eq 0 ]
	then
		err_message="No drivers in pending queue."
		current_state="stateDeviceCategorySelect"
		return
	fi

	while true
	do
		clear
		banner "Pending Changes"
		subtitle "↑/↓ Select • Enter Install • d Delete • b Back • q Quit"
		show_error

		local idx=0
		for entry in "${pending_drivers[@]}"
		do
			gum style "$(format_pending_entry "$entry")"
			idx=$((idx + 1))
		done

		local choice
		choice=$(gum choose --cursor="➤" \
			"$apply_pending_label" \
			"Remove an entry" \
			"Back to device selection" \
			"Quit") || exit 0

		case "$choice" in
			"$apply_pending_label")
				manual_build_requested=false
				current_state="stateInstallProgress"
				return
				;;
			"Remove an entry")
				prompt_remove_pending
				;;
			"Back to device selection")
				current_state="stateDeviceCategorySelect"
				return
				;;
			"Quit")
				exit 0
				;;
		esac
	done
}

prompt_remove_pending()
{
	if [ "${#pending_drivers[@]}" -eq 0 ]
	then
		err_message="No entries to delete."
		return
	fi

	local options=()
	local idx=0
	for entry in "${pending_drivers[@]}"
	do
		options+=("$idx: $(format_pending_entry "$entry")")
		idx=$((idx + 1))
	done

	local selection
	selection=$(gum choose --cursor="➤" "${options[@]}") || return

	local remove_index=${selection%%:*}
	if remove_pending_entry "$remove_index"
	then
		err_message="Removed selection."
	else
		err_message="Failed to remove selection."
	fi
}

state_installed_review()
{
	if [ "${#installed_drivers[@]}" -eq 0 ]
	then
		err_message="No installed drivers detected."
		current_state="$installed_review_return_state"
		return
	fi

	clear
	banner "Installed Drivers"
	if [ "$mode" = "ModeRemove" ]
	then
		subtitle "↑/↓ Select • r Remove • p Pending • b Back • q Quit"
	else
		subtitle "↑/↓ Select • b Back • q Quit"
	fi
	show_error

	local options=()
	for entry in "${installed_drivers[@]}"
	do
		options+=("$(format_installed_entry "$entry")")
	done
	options+=("Back")

	local selection
	selection=$(gum choose --cursor="➤" "${options[@]}") || {
		current_state="$installed_review_return_state"
		return
	}

	if [ "$selection" = "Back" ]
	then
		current_state="$installed_review_return_state"
		return
	fi

	if [ "$mode" = "ModeRemove" ]
	then
		local idx=0
		for entry in "${installed_drivers[@]}"
		do
			if [ "$(format_installed_entry "$entry")" = "$selection" ]
			then
				IFS='|' read -r category manufacturer model version <<<"$entry"
				add_pending_driver "$category" "$manufacturer" "$model" "Remove"
				err_message="Queued $model for removal."
				current_state="statePendingReview"
				return
			fi
			idx=$((idx + 1))
		done
	else
		current_state="$installed_review_return_state"
	fi
}

state_install_progress()
{
	local had_pending=false
	if [ "${#pending_drivers[@]}" -eq 0 ]
	then
		if [ "$manual_build_requested" != true ]
		then
			err_message="Nothing to install."
			current_state="statePendingReview"
			return
		fi
	else
		had_pending=true
	fi

	result_success=()
	result_failed=()
	log_lines=()
	local build_status=0
	
	#*	Calculate total steps: USB rules (1) + Build (1) + each pending driver (N)
	local total_steps=2
	if [ "${#pending_drivers[@]}" -gt 0 ]
	then
		total_steps=$((total_steps + ${#pending_drivers[@]}))
	fi

	start_progress_bar "$total_steps" "Applying changes"

	if [ "$had_pending" = true ]
	then
		#*	Update progress: USB rules installation (happens in build_selected_alpacapi)
		advance_progress_bar
		
		if ! build_selected_alpacapi
		then
			build_status=$?
			if [ "$build_status" -eq 2 ]
			then
				err_message="No driver selections available for selective build."
			else
				err_message="Selective build failed. Review log output."
			fi
		else
			log_lines+=("AlpacaPi build completed successfully.")
		fi
		
		#*	Update progress: Build completed
		advance_progress_bar
		
		#*	Add each pending driver to results
		for entry in "${pending_drivers[@]}"
		do
			if [ "$build_status" -eq 0 ]
			then
				result_success+=("$entry")
			else
				result_failed+=("$entry")
			fi
			advance_progress_bar
		done
		
		#*	Track if USB rules were installed (only if there were pending drivers)
		usb_rules_installed=false
		if [ "$build_status" -eq 0 ]
		then
			sync_installed_records_from_success
			#*	USB rules are installed during build_selected_alpacapi when there are pending drivers
			usb_rules_installed=true
		fi
	else
		#*	Manual build (no pending drivers)
		if ! build_full_alpacapi
		then
			build_status=$?
			err_message="Build failed. Review log output."
		else
			log_lines+=("AlpacaPi build completed successfully.")
		fi
		
		#*	Update progress: Build completed
		advance_progress_bar
		
		if [ "$build_status" -eq 0 ]
		then
			result_success=("Manual|System|AlpacaPi Server|Build")
		else
			result_failed=("Manual|System|AlpacaPi Server|Build")
		fi
		
		#*	For manual builds, USB rules are not installed (no driver selection)
		usb_rules_installed=false
	fi

	finish_progress_bar
	
	pending_drivers=()
	manual_build_requested=false
	current_state="stateResult"
}

state_result()
{
	clear
	banner "Setup Complete"
	show_error

	if [ "${#result_success[@]}" -gt 0 ]
	then
		gum style --foreground 46 --bold "Success:"
		for entry in "${result_success[@]}"
		do
			gum style "  $(format_pending_entry "$entry")"
		done
		
		#*	Show reboot notification if USB rules were installed
		if [ "$usb_rules_installed" = true ]
		then
			echo ""
			gum style --foreground 226 --bold --align center --width 70 "⚠️  IMPORTANT: Reboot Required"
			gum style --align center --width 70 "USB device rules have been installed."
			gum style --align center --width 70 "Please reboot your system for USB rules to take effect."
			gum style --align center --width 70 "Alternatively, unplug and replug USB devices."
			echo ""
		fi
	fi

	if [ "${#result_failed[@]}" -gt 0 ]
	then
		gum style --foreground 196 --bold "Failed:"
		for entry in "${result_failed[@]}"
		do
			gum style "  $(format_pending_entry "$entry")"
		done
	fi

	#*	Build menu options
	local options=("Back to welcome" "View log")
	
	#*	Add reboot option if USB rules were installed
	if [ "$usb_rules_installed" = true ]
	then
		options+=("Reboot now")
	fi
	
	options+=("Quit")

	local choice
	choice=$(gum choose --cursor="➤" "${options[@]}") || exit 0

	case "$choice" in
		"Back to welcome")
			current_state="stateWelcome"
			;;
		"View log")
			show_log
			;;
		"Reboot now")
			clear
			gum style --foreground 226 --bold --align center --width 70 "Reboot System"
			gum style --align center --width 70 "This will reboot your system now."
			echo ""
			if gum confirm "Reboot now?" --default="true"
			then
				log_event "User requested system reboot after build completion"
				gum style --align center --width 70 "Rebooting..."
				if sudo reboot
				then
					exit 0
				else
					err_message="Failed to reboot. You may need to run 'sudo reboot' manually."
					current_state="stateResult"
				fi
			else
				current_state="stateResult"
			fi
			;;
		"Quit")
			exit 0
			;;
	esac
}

show_log()
{
	clear
	gum style --foreground 45 --bold "Latest log entries"
	if [ "${#log_lines[@]}" -eq 0 ]
	then
		gum style "No log entries yet."
	else
		for line in "${log_lines[@]}"
		do
			gum style "$line"
		done
	fi
	gum confirm "Return to results?" >/dev/null 2>&1 || true
}

####################################################################**********
#	State Machine Runner
####################################################################**********
run_wizard()
{
	while true
	do
		case "$current_state" in
			"stateWelcome") state_welcome ;;
			"stateModeSelect") state_mode_select ;;
			"stateDeviceCategorySelect") state_device_category_select ;;
			"stateManufacturerSelect") state_manufacturer_select ;;
			"statePendingReview") state_pending_review ;;
			"stateInstalledReview") state_installed_review ;;
			"stateInstallProgress") state_install_progress ;;
			"stateResult") state_result ;;
			*)
				err_message="Unknown state $current_state."
				current_state="stateWelcome"
				;;
		esac
	done
}

####################################################################**********
#	Entry Point
####################################################################**********
main()
{
	ensure_gum
	init_logging
	load_installed_drivers
	run_wizard
}

main "$@"
